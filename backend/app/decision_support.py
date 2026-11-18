"""Rule-based decision support for severity classification, evidence extraction,
and honest uncertainty messaging.

Severity is strictly derived from explicit safety & operational risk rules —
NEVER from an ML model's confidence score.
"""

from __future__ import annotations

from typing import Literal

from .schemas import AlternativeFault, DiagnosticEvidence, DiagnosisRequest, UncertaintyNotice

SeverityLevel = Literal["low", "medium", "high", "critical"]

_CRITICAL_KEYWORDS = (
    "swollen",
    "swelling",
    "burning",
    "smoke",
    "spark",
    "breaker trip",
    "trips circuit breaker",
    "chemical odor",
    "electric shock",
    "short circuit",
)

_HIGH_KEYWORDS = (
    "overheat",
    "excessive chassis heat",
    "water leak",
    "dripping",
    "violent shaking",
    "grinding",
    "clicking relay",
    "unexpected shutdown",
    "shuts down abruptly",
    "does not power on",
    "no power",
    "coil freezing",
)

_MEDIUM_KEYWORDS = (
    "not charging",
    "rapid battery drain",
    "not cooling",
    "not draining",
    "not filling",
    "warm air",
    "blank screen",
    "boot loop",
    "flicker",
    "crash",
    "no spin",
    "stops mid-cycle",
)

UNCERTAINTY_PROBABILITY_MARGIN = 0.15


def evaluate_severity(
    request: DiagnosisRequest,
    predicted_fault: str,
) -> tuple[SeverityLevel, str]:
    """Determines fault severity strictly from domain safety & operational rules."""
    combined_signals = " ".join(
        [
            *request.symptoms,
            request.description or "",
            request.operating_conditions or "",
            predicted_fault,
        ]
    ).lower()

    for keyword in _CRITICAL_KEYWORDS:
        if keyword in combined_signals:
            return (
                "critical",
                f"Elevated to Critical by safety rules due to potential electrical, thermal, or chemical hazard indicator ('{keyword}'). Immediate isolation and qualified technician inspection advised.",
            )

    for keyword in _HIGH_KEYWORDS:
        if keyword in combined_signals:
            return (
                "high",
                f"Classified as High severity by decision-support rules due to operational or component-damage risk ('{keyword}').",
            )

    for keyword in _MEDIUM_KEYWORDS:
        if keyword in combined_signals:
            return (
                "medium",
                f"Classified as Medium severity by decision-support rules because core device functionality is impaired ('{keyword}').",
            )

    if len(request.symptoms) >= 3:
        return (
            "medium",
            "Classified as Medium severity by decision-support rules because multiple concurrent symptoms were reported.",
        )

    return (
        "low",
        "Classified as Low severity by decision-support rules because no acute safety or major functional failure indicators were reported.",
    )


def build_evidence(request: DiagnosisRequest) -> list[DiagnosticEvidence]:
    """Constructs transparent diagnostic evidence from user-reported inputs."""
    evidence: list[DiagnosticEvidence] = []

    for symptom in request.symptoms:
        evidence.append(
            DiagnosticEvidence(
                signal_type="symptom",
                source="Reported Symptom",
                detail=symptom,
            )
        )

    if request.error_code:
        evidence.append(
            DiagnosticEvidence(
                signal_type="error_code",
                source="Device Error Code",
                detail=f"Reported code '{request.error_code}' included in model feature encoding.",
            )
        )

    context_parts: list[str] = []
    if request.device.age:
        context_parts.append(f"Age: {request.device.age}")
    if request.device.operating_environment:
        context_parts.append(f"Environment: {request.device.operating_environment}")
    if request.started_when:
        context_parts.append(f"Onset: {request.started_when}")
    if request.operating_conditions and request.operating_conditions.strip():
        context_parts.append(f"Conditions: {request.operating_conditions}")

    if context_parts:
        evidence.append(
            DiagnosticEvidence(
                signal_type="context",
                source="Operating Context",
                detail=" • ".join(context_parts),
            )
        )

    return evidence


def build_uncertainty_notice(
    top_probability: float | None,
    ranked_alternatives: list[AlternativeFault],
    confidence_is_calibrated: bool,
) -> UncertaintyNotice:
    """Communicates honest diagnostic uncertainty whenever competing faults have
    similar probabilities or when the classifier probabilities are uncalibrated.
    """
    if not confidence_is_calibrated or top_probability is None:
        return UncertaintyNotice(
            is_uncertain=True,
            message=(
                "Probability estimates are not calibrated for this model artifact. "
                "Review the ranked alternative causes and verify physically before replacing parts."
            ),
        )

    if ranked_alternatives:
        second_prob = ranked_alternatives[0].probability
        if second_prob is not None and (top_probability - second_prob) < UNCERTAINTY_PROBABILITY_MARGIN:
            return UncertaintyNotice(
                is_uncertain=True,
                message=(
                    "Multiple fault categories show similar likelihood based on the reported symptoms. "
                    "Inspect the alternative causes below or capture additional symptoms/error codes."
                ),
            )

    if top_probability < 0.55:
        return UncertaintyNotice(
            is_uncertain=True,
            message=(
                "The top fault category has modest relative likelihood. "
                "Treat this output as a starting point for structured inspection rather than a confirmed fault."
            ),
        )

    return UncertaintyNotice(is_uncertain=False)
