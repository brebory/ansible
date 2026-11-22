use crate::types::*;

/// Deterministic xorshift64 PRNG so Nakama WASM and local runs produce identical rolls.
pub fn next_rng(state: &mut u64) -> u64 {
    let mut x = if *state == 0 { 0x9E37_79B9_7F4A_7C15 } else { *state };
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *state = x;
    x
}

fn rng_range(state: &mut u64, max_exclusive: u64) -> u64 {
    if max_exclusive == 0 {
        return 0;
    }
    next_rng(state) % max_exclusive
}

pub fn create_default_battle(battle_id: String, seed: u64) -> BattleState {
    let combatants = vec![
        // Player Squad: 3 futuristic-cowboy Drifters (Human + 2 Alien species)
        Combatant {
            id: "drifter_vega".into(),
            name: "Vega Vance".into(),
            faction: Faction::Player,
            species: Species::Human,
            role: DrifterRole::Gunslinger,
            slot_index: 0,
            max_hp: 95,
            hp: 95,
            max_ap: 4,
            ap: 2,
            grit: 10,
            aim: 17,
            tech: 11,
            speed: 16,
            alive: true,
            statuses: vec![],
            skills: vec![
                SkillDef {
                    id: "quickdraw".into(),
                    name: "Quickdraw".into(),
                    description: "High-noon plasma revolver shot with boosted crit chance.".into(),
                    ap_cost: 0,
                    base_power: 22,
                    target_mode: TargetMode::SingleEnemy,
                    is_heal: false,
                    apply_status: None,
                    status_turns: 0,
                    status_potency: 0,
                    crit_bonus_pct: 20,
                },
                SkillDef {
                    id: "fan_hammer".into(),
                    name: "Fan the Hammer".into(),
                    description: "Sweeps neon-hot rounds across every outlaw in the line-up.".into(),
                    ap_cost: 2,
                    base_power: 18,
                    target_mode: TargetMode::AllEnemies,
                    is_heal: false,
                    apply_status: Some(StatusKind::Burn),
                    status_turns: 2,
                    status_potency: 7,
                    crit_bonus_pct: 10,
                },
                SkillDef {
                    id: "deadeye_mark".into(),
                    name: "Bounty Mark".into(),
                    description: "Locks a holo-bounty tag onto a foe (+35% incoming damage).".into(),
                    ap_cost: 1,
                    base_power: 14,
                    target_mode: TargetMode::SingleEnemy,
                    is_heal: false,
                    apply_status: Some(StatusKind::Marked),
                    status_turns: 3,
                    status_potency: 35,
                    crit_bonus_pct: 15,
                },
                SkillDef {
                    id: "dust_guard".into(),
                    name: "Duster Guard".into(),
                    description: "Hunker behind holo-kevlar (-45% damage taken for 1 turn).".into(),
                    ap_cost: 0,
                    base_power: 0,
                    target_mode: TargetMode::SelfOnly,
                    is_heal: false,
                    apply_status: Some(StatusKind::Guard),
                    status_turns: 1,
                    status_potency: 45,
                    crit_bonus_pct: 0,
                },
            ],
        },
        Combatant {
            id: "drifter_krix".into(),
            name: "Krix-9".into(),
            faction: Faction::Player,
            species: Species::Chitinoid,
            role: DrifterRole::Vanguard,
            slot_index: 1,
            max_hp: 130,
            hp: 130,
            max_ap: 4,
            ap: 2,
            grit: 18,
            aim: 13,
            tech: 10,
            speed: 12,
            alive: true,
            statuses: vec![],
            skills: vec![
                SkillDef {
                    id: "scatter_blast".into(),
                    name: "Scatter Blast".into(),
                    description: "Heavy coach-gun plasma slug built for frontier brawls.".into(),
                    ap_cost: 0,
                    base_power: 24,
                    target_mode: TargetMode::SingleEnemy,
                    is_heal: false,
                    apply_status: None,
                    status_turns: 0,
                    status_potency: 0,
                    crit_bonus_pct: 10,
                },
                SkillDef {
                    id: "rail_buckshot".into(),
                    name: "Canyon Breaker".into(),
                    description: "Concussive rail-charge blast scorching an enemy with plasma burn.".into(),
                    ap_cost: 2,
                    base_power: 34,
                    target_mode: TargetMode::SingleEnemy,
                    is_heal: false,
                    apply_status: Some(StatusKind::Burn),
                    status_turns: 2,
                    status_potency: 9,
                    crit_bonus_pct: 15,
                },
                SkillDef {
                    id: "aegis_poncho".into(),
                    name: "Aegis Stance".into(),
                    description: "Brace carapace and holo-poncho to soak incoming fire.".into(),
                    ap_cost: 0,
                    base_power: 0,
                    target_mode: TargetMode::SelfOnly,
                    is_heal: false,
                    apply_status: Some(StatusKind::Guard),
                    status_turns: 2,
                    status_potency: 45,
                    crit_bonus_pct: 0,
                },
                SkillDef {
                    id: "overdrive_stim".into(),
                    name: "Overclock".into(),
                    description: "Supercharge weapons for +30% damage over 2 turns.".into(),
                    ap_cost: 1,
                    base_power: 0,
                    target_mode: TargetMode::SelfOnly,
                    is_heal: false,
                    apply_status: Some(StatusKind::Overclock),
                    status_turns: 2,
                    status_potency: 30,
                    crit_bonus_pct: 0,
                },
            ],
        },
        Combatant {
            id: "drifter_syl".into(),
            name: "Syl Ora".into(),
            faction: Faction::Player,
            species: Species::Vexari,
            role: DrifterRole::TechShaman,
            slot_index: 2,
            max_hp: 88,
            hp: 88,
            max_ap: 4,
            ap: 2,
            grit: 9,
            aim: 13,
            tech: 18,
            speed: 15,
            alive: true,
            statuses: vec![],
            skills: vec![
                SkillDef {
                    id: "holo_lasso".into(),
                    name: "Holo-Lasso".into(),
                    description: "Arc-whip tether that zaps and Marks a target.".into(),
                    ap_cost: 0,
                    base_power: 19,
                    target_mode: TargetMode::SingleEnemy,
                    is_heal: false,
                    apply_status: Some(StatusKind::Marked),
                    status_turns: 2,
                    status_potency: 35,
                    crit_bonus_pct: 12,
                },
                SkillDef {
                    id: "med_stim".into(),
                    name: "Ansible Mend".into(),
                    description: "Nanite tonic restoring an ally's hull and vitality.".into(),
                    ap_cost: 1,
                    base_power: 34,
                    target_mode: TargetMode::SingleAlly,
                    is_heal: true,
                    apply_status: None,
                    status_turns: 0,
                    status_potency: 0,
                    crit_bonus_pct: 0,
                },
                SkillDef {
                    id: "solar_flare".into(),
                    name: "Neon Flare".into(),
                    description: "Ignites the dust lane with an orbital plasma surge hitting all foes.".into(),
                    ap_cost: 2,
                    base_power: 22,
                    target_mode: TargetMode::AllEnemies,
                    is_heal: false,
                    apply_status: Some(StatusKind::Burn),
                    status_turns: 2,
                    status_potency: 8,
                    crit_bonus_pct: 10,
                },
                SkillDef {
                    id: "overclock_ally".into(),
                    name: "Relay Surge".into(),
                    description: "Boosts an ally with Overclock (+30% damage for 2 turns).".into(),
                    ap_cost: 1,
                    base_power: 0,
                    target_mode: TargetMode::SingleAlly,
                    is_heal: false,
                    apply_status: Some(StatusKind::Overclock),
                    status_turns: 2,
                    status_potency: 30,
                    crit_bonus_pct: 0,
                },
            ],
        },
        // Enemy Outlaw Squad
        Combatant {
            id: "enemy_deadeye".into(),
            name: "Redline Kid".into(),
            faction: Faction::Enemy,
            species: Species::VoidRaider,
            role: DrifterRole::Raider,
            slot_index: 0,
            max_hp: 78,
            hp: 78,
            max_ap: 4,
            ap: 2,
            grit: 9,
            aim: 15,
            tech: 10,
            speed: 14,
            alive: true,
            statuses: vec![],
            skills: vec![
                SkillDef {
                    id: "rust_revolver".into(),
                    name: "Rust Revolver".into(),
                    description: "Snapped six-shooter plasma bolt.".into(),
                    ap_cost: 0,
                    base_power: 17,
                    target_mode: TargetMode::SingleEnemy,
                    is_heal: false,
                    apply_status: None,
                    status_turns: 0,
                    status_potency: 0,
                    crit_bonus_pct: 15,
                },
                SkillDef {
                    id: "tracer_shot".into(),
                    name: "Tracer Tag".into(),
                    description: "Paints a drifter with a targeting flare.".into(),
                    ap_cost: 1,
                    base_power: 14,
                    target_mode: TargetMode::SingleEnemy,
                    is_heal: false,
                    apply_status: Some(StatusKind::Marked),
                    status_turns: 2,
                    status_potency: 35,
                    crit_bonus_pct: 10,
                },
            ],
        },
        Combatant {
            id: "enemy_hound".into(),
            name: "Scrap-Hound MK4".into(),
            faction: Faction::Enemy,
            species: Species::OutlawBot,
            role: DrifterRole::Raider,
            slot_index: 1,
            max_hp: 96,
            hp: 96,
            max_ap: 4,
            ap: 2,
            grit: 14,
            aim: 12,
            tech: 12,
            speed: 11,
            alive: true,
            statuses: vec![],
            skills: vec![
                SkillDef {
                    id: "arc_chomp".into(),
                    name: "Plasma Maul".into(),
                    description: "Leaping thermal jaw strike.".into(),
                    ap_cost: 0,
                    base_power: 19,
                    target_mode: TargetMode::SingleEnemy,
                    is_heal: false,
                    apply_status: Some(StatusKind::Burn),
                    status_turns: 2,
                    status_potency: 6,
                    crit_bonus_pct: 5,
                },
            ],
        },
        Combatant {
            id: "enemy_baron".into(),
            name: "Baron Vex".into(),
            faction: Faction::Enemy,
            species: Species::VoidRaider,
            role: DrifterRole::Raider,
            slot_index: 2,
            max_hp: 105,
            hp: 105,
            max_ap: 4,
            ap: 2,
            grit: 15,
            aim: 14,
            tech: 14,
            speed: 13,
            alive: true,
            statuses: vec![],
            skills: vec![
                SkillDef {
                    id: "baron_carbine".into(),
                    name: "Void Carbine".into(),
                    description: "Heavy frontier repeater burst.".into(),
                    ap_cost: 0,
                    base_power: 18,
                    target_mode: TargetMode::SingleEnemy,
                    is_heal: false,
                    apply_status: None,
                    status_turns: 0,
                    status_potency: 0,
                    crit_bonus_pct: 10,
                },
                SkillDef {
                    id: "dust_barrage".into(),
                    name: "Cinder Barrage".into(),
                    description: "Blasts the entire drifter line-up with scorching shrapnel.".into(),
                    ap_cost: 2,
                    base_power: 13,
                    target_mode: TargetMode::AllEnemies,
                    is_heal: false,
                    apply_status: Some(StatusKind::Burn),
                    status_turns: 2,
                    status_potency: 5,
                    crit_bonus_pct: 5,
                },
            ],
        },
    ];

    let mut turn_order: Vec<(i32, u8, String)> = combatants
        .iter()
        .map(|c| (c.speed, c.slot_index, c.id.clone()))
        .collect();
    turn_order.sort_by(|a, b| b.0.cmp(&a.0).then_with(|| a.1.cmp(&b.1)));
    let turn_ids: Vec<String> = turn_order.into_iter().map(|(_, _, id)| id).collect();

    BattleState {
        battle_id,
        seed,
        rng_state: seed ^ 0xA5A5_5A5A_1234_5678,
        round: 1,
        turn_order: turn_ids,
        current_turn_idx: 0,
        outcome: BattleOutcome::Ongoing,
        combatants,
    }
}

pub fn active_combatant_id(state: &BattleState) -> Option<&str> {
    state.turn_order.get(state.current_turn_idx).map(|s| s.as_str())
}

fn find_idx(state: &BattleState, id: &str) -> Option<usize> {
    state.combatants.iter().position(|c| c.id == id)
}

fn has_status(c: &Combatant, kind: StatusKind) -> bool {
    c.statuses.iter().any(|s| s.kind == kind && s.turns_remaining > 0)
}

fn apply_or_refresh_status(c: &mut Combatant, kind: StatusKind, turns: u8, potency: i32) {
    if let Some(existing) = c.statuses.iter_mut().find(|s| s.kind == kind) {
        existing.turns_remaining = existing.turns_remaining.max(turns);
        existing.potency = existing.potency.max(potency);
    } else {
        c.statuses.push(StatusInstance {
            kind,
            turns_remaining: turns,
            potency,
        });
    }
}

fn check_outcome(state: &mut BattleState, events: &mut Vec<BattleEvent>) -> BattleOutcome {
    let any_player = state
        .combatants
        .iter()
        .any(|c| c.faction == Faction::Player && c.alive);
    let any_enemy = state
        .combatants
        .iter()
        .any(|c| c.faction == Faction::Enemy && c.alive);

    if !any_enemy {
        state.outcome = BattleOutcome::Victory;
        events.push(BattleEvent::CameraCue {
            cue: CameraCueKind::VictoryOrbit,
            actor_id: None,
            target_id: None,
        });
        events.push(BattleEvent::BattleEnded {
            outcome: BattleOutcome::Victory,
            scrap_reward: 65,
            holo_data_reward: 18,
        });
    } else if !any_player {
        state.outcome = BattleOutcome::Defeat;
        events.push(BattleEvent::CameraCue {
            cue: CameraCueKind::DefeatPan,
            actor_id: None,
            target_id: None,
        });
        events.push(BattleEvent::BattleEnded {
            outcome: BattleOutcome::Defeat,
            scrap_reward: 10,
            holo_data_reward: 2,
        });
    }
    state.outcome
}

fn advance_to_next_living_actor(state: &mut BattleState) {
    let total = state.turn_order.len();
    if total == 0 {
        return;
    }
    for _ in 0..total {
        state.current_turn_idx += 1;
        if state.current_turn_idx >= total {
            state.current_turn_idx = 0;
            state.round += 1;
        }
        let id = state.turn_order[state.current_turn_idx].clone();
        if let Some(idx) = find_idx(state, &id) {
            if state.combatants[idx].alive {
                return;
            }
        }
    }
}

fn pick_enemy_ai_action(state: &mut BattleState, actor_idx: usize) -> BattleActionInput {
    let actor = &state.combatants[actor_idx];
    let affordable: Vec<SkillDef> = actor
        .skills
        .iter()
        .filter(|s| s.ap_cost <= actor.ap)
        .cloned()
        .collect();

    // Prefer AoE/special skill when AP allows, otherwise basic attack
    let chosen_skill = affordable
        .iter()
        .max_by_key(|s| s.ap_cost)
        .cloned()
        .unwrap_or_else(|| actor.skills[0].clone());

    let living_players: Vec<&Combatant> = state
        .combatants
        .iter()
        .filter(|c| c.faction == Faction::Player && c.alive)
        .collect();

    // Target Marked drifter if present, else deterministic pick weighted toward lowest HP
    let target_id = if let Some(marked) = living_players.iter().find(|p| has_status(p, StatusKind::Marked)) {
        Some(marked.id.clone())
    } else if !living_players.is_empty() {
        let pick = rng_range(&mut state.rng_state, living_players.len() as u64) as usize;
        Some(living_players[pick].id.clone())
    } else {
        None
    };

    BattleActionInput {
        actor_id: state.combatants[actor_idx].id.clone(),
        skill_id: chosen_skill.id,
        target_id,
    }
}

/// Executes a single turn through the canonical ansible-text-specifications pipeline:
/// Upkeep -> Pre-Exec Validation -> Pre-Exec Triggers -> Execute Action ->
/// Post-Exec Validation -> Post-Exec Triggers -> EndTurn.
pub fn step_battle(mut req: BattleStepRequest) -> BattleStepResponse {
    let mut events = Vec::new();
    let state = &mut req.state;

    if state.outcome != BattleOutcome::Ongoing {
        return BattleStepResponse {
            ok: false,
            error: Some("Battle has already ended".into()),
            state: req.state,
            events,
        };
    }

    // Ensure current actor is alive
    let current_id = match active_combatant_id(state) {
        Some(id) => id.to_string(),
        None => {
            return BattleStepResponse {
                ok: false,
                error: Some("Empty turn order".into()),
                state: req.state,
                events,
            }
        }
    };
    let actor_idx = match find_idx(state, &current_id) {
        Some(i) if state.combatants[i].alive => i,
        _ => {
            advance_to_next_living_actor(state);
            return BattleStepResponse {
                ok: true,
                error: None,
                state: req.state,
                events,
            };
        }
    };

    // === 1. UPKEEP ===
    let ap_before = state.combatants[actor_idx].ap;
    let max_ap = state.combatants[actor_idx].max_ap;
    state.combatants[actor_idx].ap = (ap_before + 1).min(max_ap);
    let ap_restored = state.combatants[actor_idx].ap - ap_before;

    events.push(BattleEvent::TurnStarted {
        round: state.round,
        actor_id: current_id.clone(),
        ap_restored,
    });

    // Resolve beginning-of-turn Burn damage
    let burn_potency: i32 = state.combatants[actor_idx]
        .statuses
        .iter()
        .filter(|s| s.kind == StatusKind::Burn && s.turns_remaining > 0)
        .map(|s| s.potency)
        .sum();

    if burn_potency > 0 {
        state.combatants[actor_idx].hp = (state.combatants[actor_idx].hp - burn_potency).max(0);
        let rem = state.combatants[actor_idx].hp;
        events.push(BattleEvent::UpkeepStatusTick {
            actor_id: current_id.clone(),
            status: StatusKind::Burn,
            delta_hp: -burn_potency,
            remaining_hp: rem,
        });
        if rem == 0 {
            state.combatants[actor_idx].alive = false;
            events.push(BattleEvent::CombatantDefeated {
                combatant_id: current_id.clone(),
                name: state.combatants[actor_idx].name.clone(),
            });
            if check_outcome(state, &mut events) == BattleOutcome::Ongoing {
                advance_to_next_living_actor(state);
            }
            return BattleStepResponse {
                ok: true,
                error: None,
                state: req.state,
                events,
            };
        }
    }

    // Determine action (provided by player, or chosen deterministically for Enemy AI)
    let action = match req.action {
        Some(a) => a,
        None => {
            if state.combatants[actor_idx].faction == Faction::Enemy {
                pick_enemy_ai_action(state, actor_idx)
            } else {
                return BattleStepResponse {
                    ok: false,
                    error: Some("Player turn requires an explicit action".into()),
                    state: req.state,
                    events,
                };
            }
        }
    };

    // === 2. PRE-EXEC VALIDATION ===
    if action.actor_id != current_id {
        return BattleStepResponse {
            ok: false,
            error: Some(format!(
                "Out-of-turn action: expected {}, got {}",
                current_id, action.actor_id
            )),
            state: req.state,
            events,
        };
    }

    let skill = match state.combatants[actor_idx]
        .skills
        .iter()
        .find(|s| s.id == action.skill_id)
        .cloned()
    {
        Some(s) => s,
        None => {
            return BattleStepResponse {
                ok: false,
                error: Some(format!("Unknown skill '{}' for {}", action.skill_id, current_id)),
                state: req.state,
                events,
            }
        }
    };

    if state.combatants[actor_idx].ap < skill.ap_cost {
        return BattleStepResponse {
            ok: false,
            error: Some(format!(
                "Insufficient AP for {}: need {}, have {}",
                skill.name, skill.ap_cost, state.combatants[actor_idx].ap
            )),
            state: req.state,
            events,
        };
    }

    // Resolve valid target indices
    let actor_faction = state.combatants[actor_idx].faction;
    let target_indices: Vec<usize> = match skill.target_mode {
        TargetMode::SelfOnly => vec![actor_idx],
        TargetMode::AllEnemies => state
            .combatants
            .iter()
            .enumerate()
            .filter(|(_, c)| c.faction != actor_faction && c.alive)
            .map(|(i, _)| i)
            .collect(),
        TargetMode::SingleEnemy => {
            let Some(tid) = action.target_id.as_deref() else {
                return BattleStepResponse {
                    ok: false,
                    error: Some("SingleEnemy skill requires target_id".into()),
                    state: req.state,
                    events,
                };
            };
            match find_idx(state, tid) {
                Some(i) if state.combatants[i].alive && state.combatants[i].faction != actor_faction => vec![i],
                _ => {
                    return BattleStepResponse {
                        ok: false,
                        error: Some(format!("Invalid enemy target '{}'", tid)),
                        state: req.state,
                        events,
                    }
                }
            }
        }
        TargetMode::SingleAlly => {
            let tid = action.target_id.as_deref().unwrap_or(&current_id);
            match find_idx(state, tid) {
                Some(i) if state.combatants[i].alive && state.combatants[i].faction == actor_faction => vec![i],
                _ => {
                    return BattleStepResponse {
                        ok: false,
                        error: Some(format!("Invalid ally target '{}'", tid)),
                        state: req.state,
                        events,
                    }
                }
            }
        }
    };

    // === 3. PRE-EXEC TRIGGERS ===
    let overclock_active = has_status(&state.combatants[actor_idx], StatusKind::Overclock);
    if overclock_active && !skill.is_heal && skill.base_power > 0 {
        events.push(BattleEvent::TriggerFired {
            source_id: current_id.clone(),
            trigger_name: "Overclock Surge".into(),
            detail: "+30% skill output".into(),
        });
    }

    // === 4. EXECUTE ACTION ===
    state.combatants[actor_idx].ap -= skill.ap_cost;
    let primary_target_id = target_indices
        .first()
        .map(|&i| state.combatants[i].id.clone());

    events.push(BattleEvent::CameraCue {
        cue: CameraCueKind::ActionCutIn,
        actor_id: Some(current_id.clone()),
        target_id: primary_target_id.clone(),
    });
    events.push(BattleEvent::SkillExecuted {
        actor_id: current_id.clone(),
        skill_id: skill.id.clone(),
        skill_name: skill.name.clone(),
        ap_spent: skill.ap_cost,
    });

    let actor_aim = state.combatants[actor_idx].aim;
    let actor_tech = state.combatants[actor_idx].tech;

    for t_idx in target_indices {
        if skill.is_heal {
            let heal_amt = skill.base_power + (actor_tech / 2);
            let max_hp = state.combatants[t_idx].max_hp;
            state.combatants[t_idx].hp = (state.combatants[t_idx].hp + heal_amt).min(max_hp);
            events.push(BattleEvent::HealingApplied {
                actor_id: current_id.clone(),
                target_id: state.combatants[t_idx].id.clone(),
                amount: heal_amt,
                remaining_hp: state.combatants[t_idx].hp,
            });
        } else if skill.base_power > 0 {
            let scaling = if skill.id == "solar_flare" || skill.id == "holo_lasso" {
                actor_tech
            } else {
                actor_aim
            };
            let target_grit = state.combatants[t_idx].grit;
            let raw = (skill.base_power + (scaling / 2) - (target_grit / 4)).max(6);

            let crit_chance = (10 + skill.crit_bonus_pct) as u64;
            let roll = rng_range(&mut state.rng_state, 100);
            let is_crit = roll < crit_chance;

            let mut dmg = raw;
            if is_crit {
                dmg = (dmg * 150) / 100;
            }
            if overclock_active {
                dmg = (dmg * 130) / 100;
            }

            let marked_bonus = has_status(&state.combatants[t_idx], StatusKind::Marked);
            if marked_bonus {
                dmg = (dmg * 135) / 100;
            }
            let guarded = has_status(&state.combatants[t_idx], StatusKind::Guard);
            if guarded {
                dmg = (dmg * 55) / 100;
            }
            dmg = dmg.max(1);

            state.combatants[t_idx].hp = (state.combatants[t_idx].hp - dmg).max(0);
            let rem = state.combatants[t_idx].hp;

            events.push(BattleEvent::CameraCue {
                cue: CameraCueKind::ImpactShake,
                actor_id: Some(current_id.clone()),
                target_id: Some(state.combatants[t_idx].id.clone()),
            });
            events.push(BattleEvent::DamageDealt {
                actor_id: current_id.clone(),
                target_id: state.combatants[t_idx].id.clone(),
                amount: dmg,
                is_crit,
                guarded,
                marked_bonus,
                remaining_hp: rem,
            });

            if rem == 0 && state.combatants[t_idx].alive {
                state.combatants[t_idx].alive = false;
                events.push(BattleEvent::CombatantDefeated {
                    combatant_id: state.combatants[t_idx].id.clone(),
                    name: state.combatants[t_idx].name.clone(),
                });
            }
        }

        // Apply status effect if target is still alive
        if let Some(status_kind) = skill.apply_status {
            if state.combatants[t_idx].alive {
                apply_or_refresh_status(
                    &mut state.combatants[t_idx],
                    status_kind,
                    skill.status_turns,
                    skill.status_potency,
                );
                events.push(BattleEvent::StatusApplied {
                    actor_id: current_id.clone(),
                    target_id: state.combatants[t_idx].id.clone(),
                    status: status_kind,
                    turns: skill.status_turns,
                });
            }
        }
    }

    // === 5 & 6. POST-EXEC VALIDATION & TRIGGERS ===
    if check_outcome(state, &mut events) != BattleOutcome::Ongoing {
        return BattleStepResponse {
            ok: true,
            error: None,
            state: req.state,
            events,
        };
    }

    // === 7. END TURN ===
    // Decrement actor's active status timers at the end of their turn
    for st in &mut state.combatants[actor_idx].statuses {
        if st.turns_remaining > 0 {
            st.turns_remaining -= 1;
        }
    }
    state.combatants[actor_idx]
        .statuses
        .retain(|s| s.turns_remaining > 0);

    advance_to_next_living_actor(state);

    if let Some(next_id) = active_combatant_id(state) {
        if let Some(next_idx) = find_idx(state, next_id) {
            if state.combatants[next_idx].faction == Faction::Player {
                events.push(BattleEvent::CameraCue {
                    cue: CameraCueKind::CommandOverShoulder,
                    actor_id: Some(next_id.to_string()),
                    target_id: None,
                });
            }
        }
    }

    BattleStepResponse {
        ok: true,
        error: None,
        state: req.state,
        events,
    }
}

/// Server-authoritative cooperation reward calculator for Shared Drifter Squads.
/// Prevents self-borrowing and strictly clamps lender payouts to `daily_cap`.
pub fn evaluate_shared_squad_reward(req: &SharedSquadRewardRequest) -> SharedSquadRewardResponse {
    if req.lender_user_id == req.borrower_user_id {
        return SharedSquadRewardResponse {
            allowed: false,
            reason: "Cannot borrow your own shared drifter squad".into(),
            lender_scrap_granted: 0,
            borrower_bonus_scrap: 0,
            new_earned_today: req.earned_today,
            cap_reached: req.earned_today >= req.daily_cap,
        };
    }

    let tier = req.squad_power_tier.clamp(1, 5);
    let base_lender_reward = 15 + (tier * 5);
    let borrower_bonus = 10 + (tier * 3);

    let remaining = (req.daily_cap - req.earned_today).max(0);
    let granted = base_lender_reward.min(remaining);
    let new_total = req.earned_today + granted;

    SharedSquadRewardResponse {
        allowed: true,
        reason: if granted == 0 {
            "Borrow succeeded (lender already at daily reward cap)".into()
        } else {
            "Cooperation reward granted".into()
        },
        lender_scrap_granted: granted,
        borrower_bonus_scrap: borrower_bonus,
        new_earned_today: new_total,
        cap_reached: new_total >= req.daily_cap,
    }
}
