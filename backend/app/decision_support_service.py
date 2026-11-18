"""Separate Decision Support Engine converting predicted faults into safe,
severity-aware, ranked, and expert-reviewed repair recommendations.
"""

from __future__ import annotations

from .knowledge_base import FaultKnowledgeBase, KnowledgeBaseStep
from .schemas import (
    DecisionSupportPlan,
    DecisionSupportRequest,
    EscalationGuidance,
    RecommendationItem,
)
from .severity_rules import DecisionSeverity, SeverityRuleEngine

_RISK_SAFETY_RANK: dict[str, int] = {
    "safe": 3,
    "caution": 2,
    "high": 1,
}


class DecisionSupportService:
    def __init__(
        self,
        *,
        knowledge_base: FaultKnowledgeBase,
        severity_engine: SeverityRuleEngine,
    ) -> None:
        self._kb = knowledge_base
        self._severity_engine = severity_engine

    def build_plan(self, request: DecisionSupportRequest) -> DecisionSupportPlan:
        matched_record, relevance_score = self._kb.match_record(
            device_category=request.device_category,
            fault_category=request.predicted_fault,
            symptoms=request.symptoms,
        )

        # Severity is strictly determined by safety rules + reviewed KB baseline,
        # NEVER downgraded by low ML confidence.
        severity_eval = self._severity_engine.evaluate(
            symptoms=request.symptoms,
            predicted_fault=request.predicted_fault,
            description=request.description,
            operating_conditions=request.operating_conditions,
            kb_baseline_severity=matched_record.severity if matched_record else None,
        )

        # Case 1: No reviewed knowledge-base record matches this fault category.
        # Strictly avoid inventing unsupported repair instructions!
        if matched_record is None:
            return self._build_unmatched_safe_fallback(
                request=request,
                severity=severity_eval.severity,
                severity_rationale=severity_eval.rationale,
                is_dangerous=severity_eval.is_dangerous,
                stop_using_device=severity_eval.stop_using_device,
            )

        # Case 2: Matched expert-reviewed record.
        # If safety rules elevated this to HIGH / dangerous, suppress any casual DIY steps
        # and prioritize immediate safety isolation + professional escalation.
        if severity_eval.is_dangerous:
            return self._build_high_risk_plan(
                request=request,
                record=matched_record,
                relevance_score=relevance_score,
                severity_rationale=severity_eval.rationale,
            )

        initial_check_step = (
            matched_record.recommended_initial_checks[0]
            if matched_record.recommended_initial_checks
            else None
        )

        ranked_steps = self._rank_steps(
            steps=[
                *matched_record.recommended_initial_checks,
                *matched_record.troubleshooting_steps,
            ],
            severity=severity_eval.severity,
            relevance_score=relevance_score,
            is_dangerous=False,
        )

        first_check_item = (
            self._to_recommendation_item(
                step=initial_check_step,
                step_number=1,
                rank_score=min(
                    1.0,
                    round(0.95 + min(relevance_score, 1.0) * 0.05, 3),
                ),
                severity=severity_eval.severity,
            )
            if initial_check_step is not None
            else (ranked_steps[0] if ranked_steps else None)
        )

        return DecisionSupportPlan(
            diagnosis_id=request.diagnosis_id,
            report_id=request.report_id,
            predicted_fault=request.predicted_fault,
            device_category=request.device_category,
            device_name=request.device_name or request.device_category,
            severity=severity_eval.severity,
            severity_rationale=severity_eval.rationale,
            is_dangerous_fault=False,
            immediate_safety_banner=None,
            likely_cause=" ".join(matched_record.possible_causes),
            first_recommended_check=first_check_item,
            recommendations=ranked_steps,
            safety_warnings=matched_record.safety_warnings,
            escalation=EscalationGuidance(
                requires_technician=severity_eval.severity == "medium",
                stop_using_device=False,
                when_to_escalate=matched_record.escalation_requirements,
                emergency_guidance=matched_record.emergency_guidance,
            ),
            expert_review_status=matched_record.expert_review_status,
            knowledge_base_record_id=matched_record.id,
        )

    def _build_high_risk_plan(
        self,
        *,
        request: DecisionSupportRequest,
        record,
        relevance_score: float,
        severity_rationale: str,
    ) -> DecisionSupportPlan:
        # For high-risk faults, include ONLY high-safety/isolation/escalation steps
        # and ensure completion checkboxes are disabled (never DIY-checked).
        safety_steps = [
            step
            for step in [*record.recommended_initial_checks, *record.troubleshooting_steps]
            if step.risk_level == "high"
        ]

        if not safety_steps:
            safety_steps = [
                KnowledgeBaseStep(
                    id="safety_stop_and_isolate",
                    title="Stop using the device immediately",
                    instructions=(
                        "Power off the device if safe to do so, disconnect from mains power "
                        "at the wall outlet or breaker without touching damaged cables, and "
                        "keep the area clear."
                    ),
                    risk_level="high",
                    is_checkable=False,
                    estimated_minutes=2,
                ),
                KnowledgeBaseStep(
                    id="safety_contact_qualified_tech",
                    title="Contact a qualified technician",
                    instructions=(
                        "Do not open the equipment or perform DIY repairs. Arrange an "
                        "inspection by a licensed or manufacturer-authorized technician."
                    ),
                    risk_level="high",
                    is_checkable=False,
                    estimated_minutes=15,
                ),
            ]

        ranked = self._rank_steps(
            steps=safety_steps,
            severity="high",
            relevance_score=relevance_score,
            is_dangerous=True,
        )

        warnings = list(record.safety_warnings)
        if not warnings:
            warnings = [
                "Stop using the device immediately due to potential safety hazard.",
                "Do not open electrical enclosures, handle live wiring, or bypass safety mechanisms.",
            ]

        return DecisionSupportPlan(
            diagnosis_id=request.diagnosis_id,
            report_id=request.report_id,
            predicted_fault=request.predicted_fault,
            device_category=request.device_category,
            device_name=request.device_name or request.device_category,
            severity="high",
            severity_rationale=severity_rationale,
            is_dangerous_fault=True,
            immediate_safety_banner=(
                "High-Risk Safety Warning: Stop using this device immediately. "
                "Do not attempt DIY disassembly or electrical repair. Seek qualified "
                "technician assistance or contact emergency services if smoke, fire, "
                "or chemical odor is present."
            ),
            likely_cause=" ".join(record.possible_causes),
            first_recommended_check=ranked[0] if ranked else None,
            recommendations=ranked,
            safety_warnings=warnings,
            escalation=EscalationGuidance(
                requires_technician=True,
                stop_using_device=True,
                when_to_escalate=record.escalation_requirements
                or "Immediate inspection by a qualified technician is required before further use.",
                emergency_guidance=record.emergency_guidance
                or "If you observe smoke, sparks, active overheating, or chemical fumes, evacuate the area and contact emergency services immediately.",
            ),
            expert_review_status=record.expert_review_status,
            knowledge_base_record_id=record.id,
        )

    def _build_unmatched_safe_fallback(
        self,
        *,
        request: DecisionSupportRequest,
        severity: DecisionSeverity,
        severity_rationale: str,
        is_dangerous: bool,
        stop_using_device: bool,
    ) -> DecisionSupportPlan:
        fallback_step = RecommendationItem(
            id="kb_unmatched_escalate",
            step_number=1,
            title="Consult a qualified technician",
            instructions=(
                "No expert-reviewed troubleshooting guide is currently available for this "
                "specific fault category. Avoid unverified DIY disassembly and share your "
                "FixWise symptom report with a qualified repair technician."
            ),
            priority="high" if is_dangerous else "medium",
            risk_level="high" if is_dangerous else "caution",
            is_checkable=False,
            safety_note="Do not open electrical equipment or bypass safety mechanisms.",
            rank_score=1.0,
        )

        return DecisionSupportPlan(
            diagnosis_id=request.diagnosis_id,
            report_id=request.report_id,
            predicted_fault=request.predicted_fault,
            device_category=request.device_category,
            device_name=request.device_name or request.device_category,
            severity=severity,
            severity_rationale=severity_rationale,
            is_dangerous_fault=is_dangerous,
            immediate_safety_banner=(
                "High-Risk Safety Warning: Stop using this device immediately and seek "
                "qualified technician or emergency assistance."
                if is_dangerous
                else None
            ),
            likely_cause=(
                "An expert-reviewed cause description has not yet been published in the "
                "FixWise knowledge base for this exact fault category."
            ),
            first_recommended_check=fallback_step,
            recommendations=[fallback_step],
            safety_warnings=[
                "Do not attempt unverified repairs or open internal electrical housings.",
                "Disconnect power safely if abnormal heat, odor, or electrical tripping occurs.",
            ],
            escalation=EscalationGuidance(
                requires_technician=True,
                stop_using_device=stop_using_device,
                when_to_escalate=(
                    "Contact a qualified technician for diagnosis and repair, as no "
                    "reviewed self-service steps exist for this fault category."
                ),
                emergency_guidance=(
                    "If smoke, sparks, or burning odor occur, evacuate and contact emergency services."
                    if is_dangerous
                    else None
                ),
            ),
            expert_review_status="pending_review",
            knowledge_base_record_id=None,
        )

    def _rank_steps(
        self,
        *,
        steps: list[KnowledgeBaseStep],
        severity: DecisionSeverity,
        relevance_score: float,
        is_dangerous: bool,
    ) -> list[RecommendationItem]:
        """Ranks recommendations deterministically by safety, fault relevance,
        severity alignment, and KB suitability.
        """
        deduped: list[KnowledgeBaseStep] = []
        seen: set[str] = set()
        for step in steps:
            if step.id not in seen:
                seen.add(step.id)
                deduped.append(step)

        def sort_key(pair: tuple[int, KnowledgeBaseStep]) -> tuple[int, int]:
            original_idx, step = pair
            if is_dangerous:
                # For dangerous faults, preserve strict immediate-isolation ordering.
                return (0, original_idx)
            # For safe/medium faults, prioritize lowest-risk checks first, then KB order.
            safety_priority = -_RISK_SAFETY_RANK.get(step.risk_level, 1)
            return (safety_priority, original_idx)

        ordered = [s for _, s in sorted(enumerate(deduped), key=sort_key)]
        results: list[RecommendationItem] = []
        for idx, step in enumerate(ordered, start=1):
            base_safety = _RISK_SAFETY_RANK.get(step.risk_level, 1) / 3.0
            rank_score = round(
                min(1.0, (base_safety * 0.5) + (min(relevance_score, 1.0) * 0.35) + 0.15),
                3,
            )
            results.append(
                self._to_recommendation_item(
                    step=step,
                    step_number=idx,
                    rank_score=rank_score,
                    severity=severity,
                )
            )
        return results

    @staticmethod
    def _to_recommendation_item(
        *,
        step: KnowledgeBaseStep,
        step_number: int,
        rank_score: float,
        severity: DecisionSeverity,
    ) -> RecommendationItem:
        priority = (
            "high"
            if severity == "high" or step.risk_level == "high"
            else ("medium" if step.risk_level == "caution" else "low")
        )
        return RecommendationItem(
            id=step.id,
            step_number=step_number,
            title=step.title,
            instructions=step.instructions,
            description=step.instructions,
            priority=priority,
            risk_level=step.risk_level,
            is_checkable=step.is_checkable and severity != "high",
            estimated_minutes=step.estimated_minutes,
            rank_score=rank_score,
        )
