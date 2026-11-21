pub mod battle;
pub mod types;

use std::slice;

use crate::battle::{create_default_battle, evaluate_shared_squad_reward, step_battle};
use crate::types::{BattleStepRequest, SharedSquadRewardRequest};

// ============================================================================
// WASM Linear-Memory ABI (invoked by Nakama Go server via wazero)
// ============================================================================

#[no_mangle]
pub extern "C" fn alloc(len: usize) -> *mut u8 {
    let mut buf = Vec::<u8>::with_capacity(len);
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    ptr
}

/// Releases a linear-memory buffer previously allocated by [`alloc`].
///
/// # Safety
/// `ptr` must have been allocated by [`alloc`] with capacity `len` and not yet freed.
#[no_mangle]
pub unsafe extern "C" fn dealloc(ptr: *mut u8, len: usize) {
    if !ptr.is_null() && len > 0 {
        let _ = Vec::from_raw_parts(ptr, len, len);
    }
}

fn pack_output(bytes: Vec<u8>) -> u64 {
    let len = bytes.len() as u64;
    let ptr = bytes.as_ptr() as u64;
    std::mem::forget(bytes);
    (ptr << 32) | len
}

unsafe fn read_utf8(ptr: *const u8, len: usize) -> Result<String, String> {
    if ptr.is_null() {
        return Err("null input pointer".into());
    }
    let slice = slice::from_raw_parts(ptr, len);
    String::from_utf8(slice.to_vec()).map_err(|e| format!("invalid utf-8: {e}"))
}

#[derive(serde::Deserialize)]
struct NewBattleInput {
    battle_id: String,
    seed: u64,
}

/// Initializes a deterministic default 3v3 battle from a JSON input buffer.
///
/// # Safety
/// `ptr` must point to `len` valid readable bytes of UTF-8 JSON in WASM linear memory.
#[no_mangle]
pub unsafe extern "C" fn wasm_battle_new(ptr: *const u8, len: usize) -> u64 {
    let json_out = match read_utf8(ptr, len)
        .and_then(|s| serde_json::from_str::<NewBattleInput>(&s).map_err(|e| e.to_string()))
    {
        Ok(inp) => {
            let state = create_default_battle(inp.battle_id, inp.seed);
            serde_json::to_vec(&state).unwrap_or_else(|e| format!("{{\"error\":\"{e}\"}}").into_bytes())
        }
        Err(err) => format!("{{\"error\":\"{err}\"}}").into_bytes(),
    };
    pack_output(json_out)
}

/// Advances a battle by one turn from a JSON `BattleStepRequest` buffer.
///
/// # Safety
/// `ptr` must point to `len` valid readable bytes of UTF-8 JSON in WASM linear memory.
#[no_mangle]
pub unsafe extern "C" fn wasm_battle_step(ptr: *const u8, len: usize) -> u64 {
    let json_out = match read_utf8(ptr, len)
        .and_then(|s| serde_json::from_str::<BattleStepRequest>(&s).map_err(|e| e.to_string()))
    {
        Ok(req) => {
            let resp = step_battle(req);
            serde_json::to_vec(&resp).unwrap_or_else(|e| format!("{{\"ok\":false,\"error\":\"{e}\"}}").into_bytes())
        }
        Err(err) => format!("{{\"ok\":false,\"error\":\"{err}\"}}").into_bytes(),
    };
    pack_output(json_out)
}

/// Evaluates daily-capped cooperation rewards for a shared Drifter Squad borrow.
///
/// # Safety
/// `ptr` must point to `len` valid readable bytes of UTF-8 JSON in WASM linear memory.
#[no_mangle]
pub unsafe extern "C" fn wasm_shared_squad_reward(ptr: *const u8, len: usize) -> u64 {
    let json_out = match read_utf8(ptr, len)
        .and_then(|s| serde_json::from_str::<SharedSquadRewardRequest>(&s).map_err(|e| e.to_string()))
    {
        Ok(req) => {
            let resp = evaluate_shared_squad_reward(&req);
            serde_json::to_vec(&resp).unwrap_or_else(|e| format!("{{\"allowed\":false,\"reason\":\"{e}\"}}").into_bytes())
        }
        Err(err) => format!("{{\"allowed\":false,\"reason\":\"{err}\"}}").into_bytes(),
    };
    pack_output(json_out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::*;

    #[test]
    fn default_battle_initializes_sorted_by_speed() {
        let state = create_default_battle("test-1".into(), 42);
        assert_eq!(state.combatants.len(), 6);
        assert_eq!(state.turn_order[0], "drifter_vega"); // speed 16
        assert_eq!(state.turn_order[1], "drifter_syl"); // speed 15
        assert_eq!(state.outcome, BattleOutcome::Ongoing);
    }

    #[test]
    fn turn_pipeline_applies_marked_bonus_and_guard_reduction() {
        let state = create_default_battle("test-2".into(), 99);
        // Vega marks Redline Kid
        let step1 = step_battle(BattleStepRequest {
            state,
            action: Some(BattleActionInput {
                actor_id: "drifter_vega".into(),
                skill_id: "deadeye_mark".into(),
                target_id: Some("enemy_deadeye".into()),
            }),
        });
        assert!(step1.ok, "expected ok: {:?}", step1.error);
        let deadeye = step1
            .state
            .combatants
            .iter()
            .find(|c| c.id == "enemy_deadeye")
            .unwrap();
        assert!(deadeye.statuses.iter().any(|s| s.kind == StatusKind::Marked));

        // Syl hits Marked Redline Kid with Holo-Lasso and receives Marked bonus
        let step2 = step_battle(BattleStepRequest {
            state: step1.state,
            action: Some(BattleActionInput {
                actor_id: "drifter_syl".into(),
                skill_id: "holo_lasso".into(),
                target_id: Some("enemy_deadeye".into()),
            }),
        });
        assert!(step2.ok);
        let dmg_ev = step2.events.iter().find_map(|e| match e {
            BattleEvent::DamageDealt { marked_bonus, amount, .. } => Some((*marked_bonus, *amount)),
            _ => None,
        });
        assert!(dmg_ev.is_some());
        assert!(dmg_ev.unwrap().0, "Marked bonus should trigger");
        assert!(dmg_ev.unwrap().1 > 20);
    }

    #[test]
    fn full_deterministic_battle_reaches_victory_and_replays_identically() {
        fn run_sim(seed: u64) -> (BattleOutcome, u32, i32) {
            let mut state = create_default_battle("sim".into(), seed);
            for _ in 0..40 {
                if state.outcome != BattleOutcome::Ongoing {
                    break;
                }
                let active_id = state.turn_order[state.current_turn_idx].clone();
                let actor = state.combatants.iter().find(|c| c.id == active_id).unwrap().clone();
                let action = if actor.faction == Faction::Player {
                    let target = state
                        .combatants
                        .iter()
                        .find(|c| c.faction == Faction::Enemy && c.alive)
                        .map(|c| c.id.clone());
                    // Use AoE skill if affordable, else basic attack
                    let skill = actor
                        .skills
                        .iter()
                        .find(|s| s.ap_cost <= actor.ap && s.target_mode == TargetMode::AllEnemies)
                        .or_else(|| actor.skills.first())
                        .unwrap();
                    Some(BattleActionInput {
                        actor_id: actor.id,
                        skill_id: skill.id.clone(),
                        target_id: target,
                    })
                } else {
                    None // AI chooses
                };

                let resp = step_battle(BattleStepRequest { state, action });
                assert!(resp.ok, "step failed: {:?}", resp.error);
                state = resp.state;
            }
            let total_player_hp: i32 = state
                .combatants
                .iter()
                .filter(|c| c.faction == Faction::Player)
                .map(|c| c.hp)
                .sum();
            (state.outcome, state.round, total_player_hp)
        }

        let r1 = run_sim(2026);
        let r2 = run_sim(2026);
        assert_eq!(r1, r2, "simulation must be 100% deterministic");
        assert_eq!(r1.0, BattleOutcome::Victory);
    }

    #[test]
    fn shared_squad_reward_enforces_daily_cap_and_blocks_self_borrow() {
        let self_req = SharedSquadRewardRequest {
            lender_user_id: "u1".into(),
            borrower_user_id: "u1".into(),
            squad_power_tier: 3,
            earned_today: 0,
            daily_cap: 100,
        };
        assert!(!evaluate_shared_squad_reward(&self_req).allowed);

        let near_cap = SharedSquadRewardRequest {
            lender_user_id: "u1".into(),
            borrower_user_id: "u2".into(),
            squad_power_tier: 3, // base 30
            earned_today: 85,
            daily_cap: 100,
        };
        let res = evaluate_shared_squad_reward(&near_cap);
        assert!(res.allowed);
        assert_eq!(res.lender_scrap_granted, 15);
        assert_eq!(res.new_earned_today, 100);
        assert!(res.cap_reached);
    }
}
