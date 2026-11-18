"""Model artifact loader and inference wrapper for scikit-learn Decision Tree /
Random Forest classifiers.

Strictly never trains on synthetic/random data and never returns fabricated predictions
when a real trained artifact is absent.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import joblib
import numpy as np

from .preprocessing import build_feature_dataframe
from .schemas import AlternativeFault, DiagnosisRequest


class ModelNotAvailableError(RuntimeError):
    """Raised when no real trained model artifact is installed."""


@dataclass(frozen=True)
class ModelPrediction:
    predicted_fault: str
    ranked_alternatives: list[AlternativeFault]
    confidence: float | None
    confidence_is_calibrated: bool
    model_version: str
    algorithm: str


class ModelRegistry:
    """Loads a real trained scikit-learn artifact (Pipeline + metadata JSON) from disk."""

    def __init__(
        self,
        artifact_path: Path,
        metadata_path: Path,
    ) -> None:
        self._artifact_path = artifact_path
        self._metadata_path = metadata_path
        self._pipeline: Any = None
        self._metadata: dict[str, Any] = {}
        self._load_error: str | None = None
        self.reload()

    @property
    def is_ready(self) -> bool:
        return self._pipeline is not None and bool(self._metadata)

    @property
    def load_error(self) -> str | None:
        return self._load_error

    @property
    def metadata(self) -> dict[str, Any]:
        return dict(self._metadata)

    def reload(self) -> None:
        self._pipeline = None
        self._metadata = {}
        self._load_error = None

        if not self._artifact_path.exists() or not self._metadata_path.exists():
            self._load_error = (
                "Model integration is pending: no trained FixWise scikit-learn model "
                "artifact was found at backend/artifacts/fixwise_model.joblib. "
                "Train and evaluate a Decision Tree or Random Forest model on a real "
                "dataset using backend/ml/train.py."
            )
            return

        try:
            with self._metadata_path.open("r", encoding="utf-8") as fp:
                metadata = json.load(fp)
            if not isinstance(metadata, dict) or not metadata.get("known_symptoms"):
                raise ValueError("Model metadata is missing required 'known_symptoms' schema.")
            if not metadata.get("evaluated_on_held_out_test", False):
                raise ValueError(
                    "Model artifact has not been verified on a held-out test dataset."
                )
            pipeline = joblib.load(self._artifact_path)
            self._pipeline = pipeline
            self._metadata = metadata
        except Exception as exc:
            self._load_error = f"Failed to load trained model artifact: {exc}"

    def predict(self, request: DiagnosisRequest, top_k_alternatives: int = 3) -> ModelPrediction:
        if not self.is_ready:
            raise ModelNotAvailableError(
                self._load_error or "Diagnosis model artifact is not loaded."
            )

        known_symptoms: list[str] = list(self._metadata["known_symptoms"])
        features_df = build_feature_dataframe(request, known_symptoms)

        predicted_label = str(self._pipeline.predict(features_df)[0])
        is_calibrated = bool(self._metadata.get("is_calibrated", False))
        model_version = str(self._metadata.get("model_version", "unversioned"))
        algorithm = str(self._metadata.get("algorithm", type(self._pipeline).__name__))

        ranked_alternatives: list[AlternativeFault] = []
        confidence: float | None = None

        if hasattr(self._pipeline, "predict_proba"):
            probabilities = np.asarray(self._pipeline.predict_proba(features_df)[0], dtype=float)
            classes = [str(c) for c in self._pipeline.classes_]
            order = np.argsort(probabilities)[::-1]

            top_idx = int(order[0])
            predicted_label = classes[top_idx]
            if is_calibrated:
                confidence = round(float(probabilities[top_idx]), 4)

            for idx in order[1 : 1 + top_k_alternatives]:
                prob = float(probabilities[int(idx)])
                if prob <= 0.0:
                    continue
                ranked_alternatives.append(
                    AlternativeFault(
                        fault_category=classes[int(idx)],
                        probability=round(prob, 4) if is_calibrated else None,
                    )
                )

        return ModelPrediction(
            predicted_fault=predicted_label,
            ranked_alternatives=ranked_alternatives,
            confidence=confidence,
            confidence_is_calibrated=is_calibrated,
            model_version=model_version,
            algorithm=algorithm,
        )
