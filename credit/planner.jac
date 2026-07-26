"""LumiNode - Path Planning Orchestrator.

Delegates to the Strategic Credit Limit & Utilization Sequencing agent
(credit/sequencing_agent.jac) to find the optimal order and timing for the
discovered actions, then persists the result as one SimulationResult node.
"""

import from .model { CreditProfile, Action, SimulationResult, ActionStepRecord, ProducesResult }
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

    step_records: list[ActionStepRecord] = [];
    for s in optimal.ordered_steps {
        step_records.append(ActionStepRecord(
            action_type=s.action_type,
            description=s.description,
            score_impact=s.score_impact,
            days_to_effect=s.days_to_effect,
            difficulty=s.difficulty,
            cumulative_score=s.cumulative_score
        ));
    }

    result = SimulationResult(
        path_name=optimal.path_name,
        starting_score=profile.current_score,
        projected_score=optimal.projected_final_score,
        total_days=optimal.total_days,
        total_actions=len(step_records),
        confidence=optimal.confidence,
        counterintuitive_insight=optimal.counterintuitive_insight,
        steps=step_records
    );
    profile +>:ProducesResult():+> result;
}
