"""Reviewed fault knowledge base loader, safety validator, and matcher.

Strictly serves ONLY expert-reviewed records (`expert_review_status == 'reviewed'`)
and enforces automated safety guardrails against dangerous DIY instructions.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from .severity_rules import DecisionSeverity, SeverityRuleEngine

RiskLevel = Literal["safe", "caution", "high"]


@dataclass(frozen=True)
class KnowledgeBaseStep:
    id: str
    title: str
    instructions: str
    risk_level: RiskLevel
    is_checkable: bool
    estimated_minutes: int | None = None


@dataclass(frozen=True)
class KnowledgeBaseRecord:
    id: str
    device_category: str
    fault_category: str
    related_symptoms: list[str]
    possible_causes: list[str]
    severity: DecisionSeverity
    safety_warnings: list[str]
    recommended_initial_checks: list[KnowledgeBaseStep]
    troubleshooting_steps: list[KnowledgeBaseStep]
    escalation_requirements: str
    emergency_guidance: str | None
    expert_review_status: str


class FaultKnowledgeBase:
    def __init__(
        self,
        kb_path: Path,
        severity_engine: SeverityRuleEngine,
    ) -> None:
        self._kb_path = kb_path
        self._prohibited = severity_engine.prohibited_diy_patterns
        self._records: list[KnowledgeBaseRecord] = []
        self._load()

    def _load(self) -> None:
        with self._kb_path.open("r", encoding="utf-8") as fp:
            raw = json.load(fp)

        loaded: list[KnowledgeBaseRecord] = []
        for entry in raw.get("records", []):
            # Strictly exclude any unreviewed or draft record from production recommendations.
            if entry.get("expert_review_status") != "reviewed":
                continue

            initial_checks = [
                self._parse_step(s)
                for s in entry.get("recommended_initial_checks", [])
            ]
            steps = [
                self._parse_step(s)
                for s in entry.get("troubleshooting_steps", [])
            ]

            self._validate_safety_guardrails(entry["id"], [*initial_checks, *steps])

            loaded.append(
                KnowledgeBaseRecord(
                    id=str(entry["id"]),
                    device_category=str(entry["device_category"]).strip().lower(),
                    fault_category=str(entry["fault_category"]).strip(),
                    related_symptoms=[str(s) for s in entry.get("related_symptoms", [])],
                    possible_causes=[str(c) for c in entry.get("possible_causes", [])],
                    severity=entry.get("severity", "medium"),
                    safety_warnings=[str(w) for w in entry.get("safety_warnings", [])],
                    recommended_initial_checks=initial_checks,
                    troubleshooting_steps=steps,
                    escalation_requirements=str(entry.get("escalation_requirements", "")),
                    emergency_guidance=entry.get("emergency_guidance"),
                    expert_review_status="reviewed",
                )
            )
        self._records = loaded

    def _parse_step(self, raw_step: dict) -> KnowledgeBaseStep:
        risk = str(raw_step.get("risk_level", "caution")).lower()
        if risk not in ("safe", "caution", "high"):
            risk = "caution"
        # Completion checkboxes are ONLY permitted for safe non-hazardous steps.
        is_checkable = bool(raw_step.get("is_checkable", False)) and risk == "safe"
        return KnowledgeBaseStep(
            id=str(raw_step["id"]),
            title=str(raw_step["title"]),
            instructions=str(raw_step["instructions"]),
            risk_level=risk,  # type: ignore[arg-type]
            is_checkable=is_checkable,
            estimated_minutes=raw_step.get("estimated_minutes"),
        )

    def _validate_safety_guardrails(
        self,
        record_id: str,
        steps: list[KnowledgeBaseStep],
    ) -> None:
        for step in steps:
            combined = f"{step.title} {step.instructions}".lower()
            for banned in self._prohibited:
                if banned in combined:
                    raise ValueError(
                        f"Knowledge base record '{record_id}' step '{step.id}' "
                        f"violates safety guardrail ('{banned}')."
                    )

    @property
    def reviewed_records(self) -> list[KnowledgeBaseRecord]:
        return list(self._records)

    def match_record(
        self,
        *,
        device_category: str,
        fault_category: str,
        symptoms: list[str],
    ) -> tuple[KnowledgeBaseRecord | None, float]:
        """Finds the best reviewed KB record for the device & predicted fault.
        Returns `(record, relevance_score)` or `(None, 0.0)` when unsupported.
        """
        norm_device = device_category.strip().lower()
        norm_fault = fault_category.strip().lower()
        norm_symptoms = {s.strip().lower() for s in symptoms}

        best_record: KnowledgeBaseRecord | None = None
        best_score = 0.0

        for record in self._records:
            if record.device_category != norm_device:
                continue

            score = 0.0
            rec_fault = record.fault_category.lower()
            if rec_fault == norm_fault:
                score += 1.0
            elif norm_fault in rec_fault or rec_fault in norm_fault:
                score += 0.75
            else:
                fault_tokens = {w for w in norm_fault.split() if len(w) > 3}
                rec_tokens = {w for w in rec_fault.split() if len(w) > 3}
                if fault_tokens and rec_tokens:
                    overlap = len(fault_tokens & rec_tokens) / len(fault_tokens | rec_tokens)
                    score += overlap * 0.6

            rec_symptoms = {s.strip().lower() for s in record.related_symptoms}
            if norm_symptoms and rec_symptoms:
                sym_overlap = len(norm_symptoms & rec_symptoms) / len(norm_symptoms)
                score += sym_overlap * 0.5

            if score > best_score and score >= 0.45:
                best_score = score
                best_record = record

        return best_record, round(best_score, 3)
