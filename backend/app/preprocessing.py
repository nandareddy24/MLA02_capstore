"""Shared scikit-learn feature preprocessing used identically in training and inference.

Follows strict featurization ordering: preprocessing pipelines are fit exclusively
on training splits and serialized alongside the trained classifier artifact.
"""

from __future__ import annotations

import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, OrdinalEncoder

from .schemas import DiagnosisRequest

DEVICE_AGE_ORDER = [
    "Unknown",
    "Less than 1 year",
    "1–2 years",
    "2–4 years",
    "4–6 years",
    "Over 6 years",
]

NOMINAL_COLUMNS = [
    "device_category",
    "manufacturer",
    "operating_environment",
    "started_when",
    "error_code_prefix",
]

ORDINAL_COLUMNS = ["device_age"]


def extract_error_code_prefix(error_code: str | None) -> str:
    """Normalizes an optional error code to a clean categorical feature token."""
    if not error_code or not error_code.strip():
        return "NONE"
    token = error_code.strip().upper().split()[0]
    return token[:16]


def build_feature_dataframe(
    request: DiagnosisRequest,
    known_symptoms: list[str],
) -> pd.DataFrame:
    """Converts a validated DiagnosisRequest into a 1-row pandas DataFrame matching
    the exact column layout expected by the trained scikit-learn Pipeline.
    """
    normalized_reported = {s.strip().lower() for s in request.symptoms}
    row: dict[str, object] = {
        "device_category": request.device.category.strip().lower(),
        "manufacturer": (request.device.manufacturer or "Unknown").strip(),
        "device_age": (
            request.device.age
            if request.device.age in DEVICE_AGE_ORDER
            else "Unknown"
        ),
        "operating_environment": (
            request.device.operating_environment or "Unknown"
        ).strip(),
        "started_when": (request.started_when or "Unknown").strip(),
        "error_code_prefix": extract_error_code_prefix(request.error_code),
        "symptom_count": float(len(request.symptoms)),
        "has_error_code": 1.0 if request.error_code else 0.0,
    }

    for symptom_key in known_symptoms:
        col_name = symptom_column_name(symptom_key)
        row[col_name] = 1.0 if symptom_key.strip().lower() in normalized_reported else 0.0

    return pd.DataFrame([row])


def symptom_column_name(symptom_label: str) -> str:
    """Deterministic feature column name for a structured symptom indicator."""
    slug = "".join(
        ch if ch.isalnum() else "_" for ch in symptom_label.strip().lower()
    )
    while "__" in slug:
        slug = slug.replace("__", "_")
    return f"sym_{slug.strip('_')}"


def build_preprocessor(known_symptoms: list[str]) -> ColumnTransformer:
    """Creates the reusable scikit-learn ColumnTransformer for FixWise classifiers."""
    numeric_columns = [
        "symptom_count",
        "has_error_code",
        *[symptom_column_name(s) for s in known_symptoms],
    ]

    nominal_pipeline = Pipeline(
        steps=[
            ("impute", SimpleImputer(strategy="constant", fill_value="Unknown")),
            (
                "encode",
                OneHotEncoder(handle_unknown="ignore", sparse_output=False),
            ),
        ]
    )

    ordinal_pipeline = Pipeline(
        steps=[
            ("impute", SimpleImputer(strategy="constant", fill_value="Unknown")),
            (
                "encode",
                OrdinalEncoder(
                    categories=[DEVICE_AGE_ORDER],
                    handle_unknown="use_encoded_value",
                    unknown_value=-1,
                ),
            ),
        ]
    )

    numeric_pipeline = Pipeline(
        steps=[
            ("impute", SimpleImputer(strategy="constant", fill_value=0.0)),
        ]
    )

    return ColumnTransformer(
        transformers=[
            ("nominal", nominal_pipeline, NOMINAL_COLUMNS),
            ("ordinal", ordinal_pipeline, ORDINAL_COLUMNS),
            ("numeric", numeric_pipeline, numeric_columns),
        ],
        remainder="drop",
    )
