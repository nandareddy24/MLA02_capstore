"""Configurable, expert-reviewed severity rule engine for FixWise.

Maps reported symptoms, fault categories, and safety indicators to:
- `safe` (low-risk informational checks)
- `medium` (troubleshooting requiring caution / possible technician help)
- `high` (hazardous conditions requiring stop-use & qualified/emergency assistance)

CRITICAL INVARIANT: Model confidence NEVER downgrades or overrides a safety rule.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

DecisionSeverity = Literal["safe", "medium", "high"]

_SEVERITY_ORDER: dict[DecisionSeverity, int] = {
    "safe": 0,
    "medium": 1,
    "high": 2,
}


@dataclass(frozen=True)
class SeverityEvaluation:
    severity: DecisionSeverity
    rationale: str
    triggered_rule: str | None
    stop_using_device: bool
    is_dangerous: bool


class SeverityRuleEngine:
    def __init__(self, rules_path: Path) -> None:
        self._rules_path = rules_path
        with rules_path.open("r", encoding="utf-8") as fp:
            self._config = json.load(fp)
        if self._config.get("review_status") != "reviewed":
            raise ValueError("Severity rules configuration must be expert-reviewed.")

    @property
    def prohibited_diy_patterns(self) -> list[str]:
        return [
            str(p).lower()
            for p in self._config.get("prohibited_diy_patterns", [])
        ]

    def evaluate(
        self,
        *,
        symptoms: list[str],
        predicted_fault: str,
        description: str | None = None,
        operating_conditions: str | None = None,
        kb_baseline_severity: DecisionSeverity | None = None,
    ) -> SeverityEvaluation:
        """Evaluates safety rules strictly from clinical/technical signals and KB baseline.
        Intentionally takes NO model confidence parameter so low confidence can never
        weaken a safety classification.
        """
        combined = " ".join(
            [
                *symptoms,
                predicted_fault,
                description or "",
                operating_conditions or "",
            ]
        ).lower()

        for keyword in self._config.get("high_risk_keywords", []):
            kw = str(keyword).lower()
            if kw in combined:
                return SeverityEvaluation(
                    severity="high",
                    rationale=(
                        f"Classified as High risk by FixWise safety rules due to potential "
                        f"hazard indicator ('{keyword}'). Stop using the device and seek "
                        f"qualified professional assistance."
                    ),
                    triggered_rule=f"high_risk_keyword:{keyword}",
                    stop_using_device=True,
                    is_dangerous=True,
                )

        if kb_baseline_severity == "high":
            return SeverityEvaluation(
                severity="high",
                rationale=(
                    "Classified as High risk based on the expert-reviewed knowledge-base "
                    "safety profile for this fault category. Stop using the device and "
                    "contact a qualified technician."
                ),
                triggered_rule="kb_baseline:high",
                stop_using_device=True,
                is_dangerous=True,
            )

        for keyword in self._config.get("medium_risk_keywords", []):
            kw = str(keyword).lower()
            if kw in combined:
                final_sev: DecisionSeverity = self._max_severity(
                    "medium", kb_baseline_severity
                )
                return SeverityEvaluation(
                    severity=final_sev,
                    rationale=(
                        f"Classified as Medium severity because reported signal ('{keyword}') "
                        f"requires cautious verification and may need professional assistance."
                    ),
                    triggered_rule=f"medium_risk_keyword:{keyword}",
                    stop_using_device=False,
                    is_dangerous=False,
                )

        if kb_baseline_severity == "medium" or len(symptoms) >= 3:
            return SeverityEvaluation(
                severity="medium",
                rationale=(
                    "Classified as Medium severity due to multiple concurrent symptoms "
                    "or the reviewed fault category profile. Proceed with caution."
                ),
                triggered_rule="kb_or_multi_symptom:medium",
                stop_using_device=False,
                is_dangerous=False,
            )

        return SeverityEvaluation(
            severity="safe",
            rationale=(
                "Classified as Safe (low risk) because no acute electrical, thermal, "
                "or mechanical hazard indicators were reported. Initial non-invasive "
                "checks are appropriate."
            ),
            triggered_rule="default:safe",
            stop_using_device=False,
            is_dangerous=False,
        )

    @staticmethod
    def _max_severity(
        a: DecisionSeverity,
        b: DecisionSeverity | None,
    ) -> DecisionSeverity:
        if b is None:
            return a
        return a if _SEVERITY_ORDER[a] >= _SEVERITY_ORDER[b] else b
