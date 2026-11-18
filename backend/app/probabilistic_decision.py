"""Isolated Bayesian probability updating & decision-theory module.

Kept strictly separate from basic rule-based recommendations.
Per FixWise capstone integrity rules:
- Never invents prior probabilities.
- Never fabricates expected repair/failure costs.
- Executes ONLY when validated empirical historical priors and cost matrices
  are explicitly provided.
"""

from __future__ import annotations

from dataclasses import dataclass


class ProbabilisticInputsUnavailableError(ValueError):
    """Raised when empirical priors or validated cost assumptions are missing."""


@dataclass(frozen=True)
class EmpiricalPriors:
    fault_priors: dict[str, float]
    likelihoods_given_fault: dict[str, dict[str, float]]
    source_reference: str


def compute_bayesian_posterior(
    *,
    observed_evidence: list[str],
    priors: EmpiricalPriors | None,
) -> dict[str, float]:
    """Computes normalized posterior probabilities given validated empirical priors.
    Refuses to run without verified historical data.
    """
    if priors is None or not priors.fault_priors or not priors.source_reference.strip():
        raise ProbabilisticInputsUnavailableError(
            "Bayesian updating requires validated empirical prior probabilities "
            "and historical likelihood data. FixWise does not invent priors."
        )

    total_prior = sum(priors.fault_priors.values())
    if total_prior <= 0:
        raise ProbabilisticInputsUnavailableError("Empirical priors must sum to > 0.")

    unnormalized: dict[str, float] = {}
    for fault, prior in priors.fault_priors.items():
        if prior < 0:
            raise ProbabilisticInputsUnavailableError(
                f"Invalid negative prior for '{fault}'."
            )
        likelihood = 1.0
        ev_map = priors.likelihoods_given_fault.get(fault, {})
        for ev in observed_evidence:
            if ev not in ev_map:
                raise ProbabilisticInputsUnavailableError(
                    f"Missing validated likelihood P({ev} | {fault})."
                )
            likelihood *= ev_map[ev]
        unnormalized[fault] = prior * likelihood

    norm = sum(unnormalized.values())
    if norm <= 0:
        raise ProbabilisticInputsUnavailableError(
            "Posterior normalization factor is zero for the supplied evidence."
        )

    return {fault: round(val / norm, 4) for fault, val in unnormalized.items()}
