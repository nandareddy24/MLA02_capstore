"""Training and held-out evaluation pipeline for FixWise fault diagnosis models.

Strictly requires a REAL labeled CSV dataset — never generates synthetic or random
training samples. Follows strict featurization ordering: splits into train, validation,
and held-out test sets BEFORE fitting any encoder or imputer.

Usage:
    python -m ml.train --dataset path/to/real_fault_dataset.csv --model-version 1.0.0
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import joblib
import pandas as pd
from sklearn.calibration import CalibratedClassifierCV
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.tree import DecisionTreeClassifier

from app.preprocessing import (
    DEVICE_AGE_ORDER,
    build_preprocessor,
    extract_error_code_prefix,
    symptom_column_name,
)

REQUIRED_COLUMNS = {"device_category", "symptoms", "fault_category"}


def load_and_prepare_dataframe(csv_path: Path) -> tuple[pd.DataFrame, pd.Series, list[str]]:
    if not csv_path.exists():
        raise FileNotFoundError(
            f"Dataset file not found at '{csv_path}'. Supply a real labeled CSV dataset."
        )

    raw_df = pd.read_csv(csv_path)
    missing_cols = REQUIRED_COLUMNS - set(raw_df.columns)
    if missing_cols:
        raise ValueError(f"Dataset is missing required columns: {sorted(missing_cols)}")

    # Drop rows without valid target fault_category or symptoms.
    df = raw_df.dropna(subset=["device_category", "symptoms", "fault_category"]).copy()
    df["fault_category"] = df["fault_category"].astype(str).str.strip()
    df = df[df["fault_category"] != ""]
    if len(df) < 20:
        raise ValueError(
            f"Dataset has only {len(df)} valid labeled rows; insufficient for train/validation/test evaluation."
        )

    parsed_symptoms: list[list[str]] = [
        [s.strip() for s in str(raw).split("|") if s.strip()]
        for raw in df["symptoms"]
    ]
    known_symptoms = sorted({sym for row in parsed_symptoms for sym in row})

    features = pd.DataFrame(
        {
            "device_category": df["device_category"].astype(str).str.strip().str.lower(),
            "manufacturer": df.get("manufacturer", pd.Series("Unknown", index=df.index))
            .fillna("Unknown")
            .astype(str)
            .str.strip(),
            "device_age": df.get("device_age", pd.Series("Unknown", index=df.index))
            .fillna("Unknown")
            .astype(str)
            .map(lambda v: v if v in DEVICE_AGE_ORDER else "Unknown"),
            "operating_environment": df.get(
                "operating_environment", pd.Series("Unknown", index=df.index)
            )
            .fillna("Unknown")
            .astype(str)
            .str.strip(),
            "started_when": df.get("started_when", pd.Series("Unknown", index=df.index))
            .fillna("Unknown")
            .astype(str)
            .str.strip(),
            "error_code_prefix": df.get("error_code", pd.Series("", index=df.index))
            .fillna("")
            .astype(str)
            .map(extract_error_code_prefix),
            "symptom_count": [float(len(row)) for row in parsed_symptoms],
            "has_error_code": [
                1.0 if str(code).strip() else 0.0
                for code in df.get("error_code", pd.Series("", index=df.index)).fillna("")
            ],
        },
        index=df.index,
    )

    for symptom in known_symptoms:
        col = symptom_column_name(symptom)
        target_lower = symptom.lower()
        features[col] = [
            1.0 if any(item.lower() == target_lower for item in row) else 0.0
            for row in parsed_symptoms
        ]

    return features, df["fault_category"], known_symptoms


def train_and_evaluate(
    *,
    dataset_path: Path,
    output_dir: Path,
    model_version: str,
    calibrate: bool = True,
) -> dict:
    X, y, known_symptoms = load_and_prepare_dataframe(dataset_path)

    # Strict featurization ordering: split BEFORE fitting any preprocessor.
    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.20,
        random_state=42,
        stratify=y,
    )

    candidates = {
        "DecisionTreeClassifier": DecisionTreeClassifier(
            max_depth=12,
            min_samples_leaf=2,
            class_weight="balanced",
            random_state=42,
        ),
        "RandomForestClassifier": RandomForestClassifier(
            n_estimators=200,
            max_depth=16,
            min_samples_leaf=2,
            class_weight="balanced",
            random_state=42,
            n_jobs=-1,
        ),
    }

    min_class_count = int(y_train.value_counts().min())
    cv_folds = min(5, max(2, min_class_count))
    cv = StratifiedKFold(n_splits=cv_folds, shuffle=True, random_state=42)

    cv_scores: dict[str, float] = {}
    for name, estimator in candidates.items():
        pipe = Pipeline(
            steps=[
                ("preprocess", build_preprocessor(known_symptoms)),
                ("classifier", estimator),
            ]
        )
        scores = cross_val_score(pipe, X_train, y_train, cv=cv, scoring="f1_macro")
        cv_scores[name] = float(scores.mean())

    best_name = max(cv_scores, key=cv_scores.__getitem__)
    best_estimator = candidates[best_name]

    use_calibration = calibrate and min_class_count >= 3
    final_classifier = (
        CalibratedClassifierCV(
            best_estimator,
            method="sigmoid",
            cv=min(3, min_class_count),
        )
        if use_calibration
        else best_estimator
    )

    final_pipeline = Pipeline(
        steps=[
            ("preprocess", build_preprocessor(known_symptoms)),
            ("classifier", final_classifier),
        ]
    )
    final_pipeline.fit(X_train, y_train)

    y_pred = final_pipeline.predict(X_test)
    labels = sorted(y.unique().tolist())

    metrics = {
        "cv_macro_f1_by_model": cv_scores,
        "held_out_test_accuracy": round(float(accuracy_score(y_test, y_pred)), 4),
        "held_out_test_macro_f1": round(
            float(f1_score(y_test, y_pred, average="macro", zero_division=0)),
            4,
        ),
        "held_out_test_weighted_f1": round(
            float(f1_score(y_test, y_pred, average="weighted", zero_division=0)),
            4,
        ),
        "held_out_confusion_matrix": confusion_matrix(
            y_test, y_pred, labels=labels
        ).tolist(),
        "held_out_classification_report": classification_report(
            y_test, y_pred, output_dict=True, zero_division=0
        ),
        "train_samples": int(len(X_train)),
        "held_out_test_samples": int(len(X_test)),
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    artifact_path = output_dir / "fixwise_model.joblib"
    metadata_path = output_dir / "model_metadata.json"

    joblib.dump(final_pipeline, artifact_path)

    metadata = {
        "model_version": model_version,
        "algorithm": best_name,
        "is_calibrated": use_calibration,
        "evaluated_on_held_out_test": True,
        "classes": labels,
        "known_symptoms": known_symptoms,
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "metrics": metrics,
    }
    with metadata_path.open("w", encoding="utf-8") as fp:
        json.dump(metadata, fp, indent=2)

    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Train and evaluate FixWise Decision Tree / Random Forest models on a real dataset."
    )
    parser.add_argument("--dataset", required=True, type=Path, help="Path to labeled CSV dataset.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "artifacts",
    )
    parser.add_argument("--model-version", default="1.0.0")
    parser.add_argument("--no-calibrate", action="store_true")
    args = parser.parse_args()

    metadata = train_and_evaluate(
        dataset_path=args.dataset,
        output_dir=args.output_dir,
        model_version=args.model_version,
        calibrate=not args.no_calibrate,
    )
    print(json.dumps(metadata["metrics"], indent=2))


if __name__ == "__main__":
    main()
