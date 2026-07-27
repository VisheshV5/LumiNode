"""LumiNode - Path Planning Orchestrator.

Delegates to the Strategic Credit Limit & Utilization Sequencing agent
(credit/sequencing_agent.jac) to find the optimal order and timing for the
discovered actions, then persists the result as one SimulationResult node.
"""

import from .model {
    CreditProfile, Action, SimulationResult, ActionStepRecord, ProducesResult,
    _clamp_action_impact, _static_impact_ceiling, _apply_factor_decay, _path_confidence
}
import from .sequencing_agent { sequence_credit_actions, _fallback_optimal_path }

"""Re-plan the optimal action sequence for the current profile and persist it."""
def optimize_path {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return; }
    profile = profiles[0];

    actions = [profile -->][?:Action];
    if len(actions) == 0 { return; }

    action_data: list[dict] = [];
    for a in actions {
        action_data.append({
            "id": jid(a),
            "type": a.action_type,
            "description": a.description,
            "impact": a.estimated_score_impact,
            "days": a.time_to_effect_days,
            "difficulty": a.difficulty,
            "risk": a.risk_level
        });
    }

    try {
        optimal = sequence_credit_actions(
            current_score=profile.current_score,
            target_score=profile.target_score,
            available_actions=action_data
        );
    } except Exception {
        optimal = _fallback_optimal_path(profile.current_score, profile.target_score, action_data);
    }

    # ── Score-impact enforcement ──────────────────────────────────────────
    # Governs BOTH the agent path and the deterministic fallback, so every
    # number the UI shows traces back to the sourced model in credit/model.jac.
    # Clamp each step to its ceiling, decay steps that share a FICO factor,
    # then rebuild the running total - the planner's own cumulative_score is
    # discarded because it was derived from the pre-clamp figures.
    # The discovery stage already sized each action against this person's real
    # utilization, so its figure is a TIGHTER bound than the static per-type
    # ceiling (which is only the physical 5-band maximum). Sequencing may
    # reorder actions; it may not inflate one past what live data supported.
    discovered_ceiling: dict[str, int] = {};
    for a in actions {
        prior = discovered_ceiling.get(a.action_type, -9999);
        if a.estimated_score_impact > prior {
            discovered_ceiling[a.action_type] = a.estimated_score_impact;
        }
    }

    step_types: list[str] = [];
    clamped: list[int] = [];
    for s in optimal.ordered_steps {
        step_types.append(s.action_type);
        ceiling = _static_impact_ceiling(s.action_type);
        live = discovered_ceiling.get(s.action_type, ceiling);
        if live < ceiling { ceiling = live; }
        clamped.append(_clamp_action_impact(s.score_impact, ceiling));
    }
    final_impacts = _apply_factor_decay(step_types, clamped);

    # A step worth 0 points (a paydown crossing no threshold band) or worth
    # negative points (a new account's near-term dip) is not a recommendation -
    # it is noise at best and counterproductive advice at worst. Dropped here
    # rather than upstream so it survives decay: a step can legitimately fall
    # to 0 only after its factor has already been spent by an earlier step.
    step_records: list[ActionStepRecord] = [];
    kept_types: list[str] = [];
    kept_impacts: list[int] = [];
    running = profile.current_score;
    i = 0;
    for s in optimal.ordered_steps {
        impact = final_impacts[i];
        i = i + 1;
        if impact <= 0 { continue; }
        running = running + impact;
        if running > 850 { running = 850; }
        kept_types.append(s.action_type);
        kept_impacts.append(impact);
        step_records.append(ActionStepRecord(
            action_type=s.action_type,
            description=s.description,
            score_impact=impact,
            days_to_effect=s.days_to_effect,
            difficulty=s.difficulty,
            cumulative_score=running
        ));
    }

    result = SimulationResult(
        path_name=optimal.path_name,
        starting_score=profile.current_score,
        projected_score=running,
        total_days=optimal.total_days,
        total_actions=len(step_records),
        confidence=_path_confidence(kept_types, kept_impacts),
        counterintuitive_insight=optimal.counterintuitive_insight,
        steps=step_records
    );
    profile +>:ProducesResult():+> result;
}
