class_name BattleEngine
extends RefCounted

## Deterministic turn-based combat engine mirroring sim-core/src/battle.rs.
## Implements the ansible-text-specifications pipeline:
## Upkeep -> Pre-Exec Validation -> Pre-Exec Triggers -> Execute Action ->
## Post-Exec Validation -> Post-Exec Triggers -> EndTurn.

var state: Dictionary = {}


func init_default_battle(battle_id: String = "frontier_skirmish", seed_val: int = 2026) -> Dictionary:
	var combatants: Array[Dictionary] = DrifterRoster.create_default_combatants()
	var order_pairs: Array[Dictionary] = []
	for c in combatants:
		order_pairs.append({"speed": int(c["speed"]), "slot": int(c["slot_index"]), "id": String(c["id"])})
	order_pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["speed"] != b["speed"]:
			return int(a["speed"]) > int(b["speed"])
		return int(a["slot"]) < int(b["slot"])
	)
	var turn_order: Array[String] = []
	for p in order_pairs:
		turn_order.append(String(p["id"]))

	state = {
		"battle_id": battle_id,
		"seed": seed_val,
		"rng_state": (seed_val ^ 0x5A5A1234) & 0x7FFFFFFF,
		"round": 1,
		"turn_order": turn_order,
		"current_turn_idx": 0,
		"outcome": "ongoing",
		"combatants": combatants,
	}
	return state


func _next_rng(max_exclusive: int) -> int:
	if max_exclusive <= 0:
		return 0
	var x: int = int(state["rng_state"])
	if x == 0:
		x = 133791
	x = (x * 1103515245 + 12345) & 0x7FFFFFFF
	state["rng_state"] = x
	return x % max_exclusive


func get_active_combatant_id() -> String:
	var order: Array = state.get("turn_order", [])
	if order.is_empty():
		return ""
	return String(order[int(state["current_turn_idx"])])


func get_combatant(cid: String) -> Dictionary:
	for c in state.get("combatants", []):
		if String(c["id"]) == cid:
			return c
	return {}


func get_living_by_faction(faction: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in state.get("combatants", []):
		if String(c["faction"]) == faction and bool(c["alive"]):
			out.append(c)
	return out


func get_upcoming_turn_ids(count: int = 6) -> Array[String]:
	var order: Array = state.get("turn_order", [])
	var out: Array[String] = []
	if order.is_empty():
		return out
	var idx: int = int(state["current_turn_idx"])
	var safety: int = 0
	while out.size() < count and safety < order.size() * 4:
		var cid := String(order[idx])
		var c := get_combatant(cid)
		if not c.is_empty() and bool(c["alive"]):
			out.append(cid)
		idx = (idx + 1) % order.size()
		safety += 1
	return out


func _has_status(c: Dictionary, kind: String) -> bool:
	for s in c.get("statuses", []):
		if String(s["kind"]) == kind and int(s["turns_remaining"]) > 0:
			return true
	return false


func _apply_or_refresh_status(c: Dictionary, kind: String, turns: int, potency: int) -> void:
	var statuses: Array = c["statuses"]
	for s in statuses:
		if String(s["kind"]) == kind:
			s["turns_remaining"] = maxi(int(s["turns_remaining"]), turns)
			s["potency"] = maxi(int(s["potency"]), potency)
			return
	statuses.append({
		"kind": kind,
		"turns_remaining": turns,
		"potency": potency,
	})


func _advance_to_next_living_actor() -> void:
	var order: Array = state["turn_order"]
	if order.is_empty():
		return
	for _i in range(order.size()):
		var next_idx: int = int(state["current_turn_idx"]) + 1
		if next_idx >= order.size():
			next_idx = 0
			state["round"] = int(state["round"]) + 1
		state["current_turn_idx"] = next_idx
		var c := get_combatant(String(order[next_idx]))
		if not c.is_empty() and bool(c["alive"]):
			return


func _check_outcome(events: Array[Dictionary]) -> String:
	var players_alive := not get_living_by_faction("player").is_empty()
	var enemies_alive := not get_living_by_faction("enemy").is_empty()
	if not enemies_alive:
		state["outcome"] = "victory"
		events.append({"type": "camera_cue", "cue": "victory_orbit", "actor_id": "", "target_id": ""})
		events.append({
			"type": "battle_ended",
			"outcome": "victory",
			"scrap_reward": 65,
			"holo_data_reward": 18,
		})
	elif not players_alive:
		state["outcome"] = "defeat"
		events.append({"type": "camera_cue", "cue": "defeat_pan", "actor_id": "", "target_id": ""})
		events.append({
			"type": "battle_ended",
			"outcome": "defeat",
			"scrap_reward": 10,
			"holo_data_reward": 2,
		})
	return String(state["outcome"])


func _pick_enemy_ai_action(actor: Dictionary) -> Dictionary:
	var skills: Array = actor["skills"]
	var chosen: Dictionary = skills[0]
	for s in skills:
		if int(s["ap_cost"]) <= int(actor["ap"]) and int(s["ap_cost"]) > int(chosen["ap_cost"]):
			chosen = s

	var living_players := get_living_by_faction("player")
	var target_id := ""
	for p in living_players:
		if _has_status(p, "marked"):
			target_id = String(p["id"])
			break
	if target_id == "" and not living_players.is_empty():
		var pick := _next_rng(living_players.size())
		target_id = String(living_players[pick]["id"])

	return {
		"actor_id": String(actor["id"]),
		"skill_id": String(chosen["id"]),
		"target_id": target_id,
	}


func step_turn(action: Dictionary = {}) -> Dictionary:
	var events: Array[Dictionary] = []
	if String(state.get("outcome", "ongoing")) != "ongoing":
		return {"ok": false, "error": "Battle has already ended", "state": state, "events": events}

	var current_id := get_active_combatant_id()
	var actor := get_combatant(current_id)
	if actor.is_empty() or not bool(actor["alive"]):
		_advance_to_next_living_actor()
		return {"ok": true, "error": "", "state": state, "events": events}

	# === 1. UPKEEP ===
	var ap_before: int = int(actor["ap"])
	actor["ap"] = mini(ap_before + 1, int(actor["max_ap"]))
	events.append({
		"type": "turn_started",
		"round": int(state["round"]),
		"actor_id": current_id,
		"ap_restored": int(actor["ap"]) - ap_before,
	})

	var burn_total: int = 0
	for s in actor["statuses"]:
		if String(s["kind"]) == "burn" and int(s["turns_remaining"]) > 0:
			burn_total += int(s["potency"])
	if burn_total > 0:
		actor["hp"] = maxi(0, int(actor["hp"]) - burn_total)
		events.append({
			"type": "upkeep_status_tick",
			"actor_id": current_id,
			"status": "burn",
			"delta_hp": -burn_total,
			"remaining_hp": int(actor["hp"]),
		})
		if int(actor["hp"]) == 0:
			actor["alive"] = false
			events.append({
				"type": "combatant_defeated",
				"combatant_id": current_id,
				"name": String(actor["name"]),
			})
			if _check_outcome(events) == "ongoing":
				_advance_to_next_living_actor()
			return {"ok": true, "error": "", "state": state, "events": events}

	# Resolve action (explicit player input or deterministic AI)
	var resolved_action: Dictionary = action
	if resolved_action.is_empty():
		if String(actor["faction"]) == "enemy":
			resolved_action = _pick_enemy_ai_action(actor)
		else:
			return {"ok": false, "error": "Player turn requires an explicit action", "state": state, "events": events}

	# === 2. PRE-EXEC VALIDATION ===
	if String(resolved_action.get("actor_id", "")) != current_id:
		return {"ok": false, "error": "Out-of-turn action", "state": state, "events": events}

	var skill_id := String(resolved_action.get("skill_id", ""))
	var skill: Dictionary = {}
	for s in actor["skills"]:
		if String(s["id"]) == skill_id:
			skill = s
			break
	if skill.is_empty():
		return {"ok": false, "error": "Unknown skill: " + skill_id, "state": state, "events": events}
	if int(actor["ap"]) < int(skill["ap_cost"]):
		return {"ok": false, "error": "Insufficient AP for " + String(skill["name"]), "state": state, "events": events}

	var actor_faction := String(actor["faction"])
	var enemy_faction := "enemy" if actor_faction == "player" else "player"
	var targets: Array[Dictionary] = []
	var tmode := String(skill["target_mode"])
	if tmode == "self_only":
		targets.append(actor)
	elif tmode == "all_enemies":
		targets = get_living_by_faction(enemy_faction)
	elif tmode == "single_enemy":
		var tid := String(resolved_action.get("target_id", ""))
		var t := get_combatant(tid)
		if t.is_empty() or not bool(t["alive"]) or String(t["faction"]) != enemy_faction:
			return {"ok": false, "error": "Invalid enemy target: " + tid, "state": state, "events": events}
		targets.append(t)
	elif tmode == "single_ally":
		var tid := String(resolved_action.get("target_id", current_id))
		var t := get_combatant(tid)
		if t.is_empty() or not bool(t["alive"]) or String(t["faction"]) != actor_faction:
			return {"ok": false, "error": "Invalid ally target: " + tid, "state": state, "events": events}
		targets.append(t)

	# === 3. PRE-EXEC TRIGGERS ===
	var overclock_active := _has_status(actor, "overclock")
	if overclock_active and not bool(skill["is_heal"]) and int(skill["base_power"]) > 0:
		events.append({
			"type": "trigger_fired",
			"source_id": current_id,
			"trigger_name": "Overclock Surge",
			"detail": "+30% skill output",
		})

	# === 4. EXECUTE ACTION ===
	actor["ap"] = int(actor["ap"]) - int(skill["ap_cost"])
	var primary_tid := String(targets[0]["id"]) if not targets.is_empty() else ""
	events.append({
		"type": "camera_cue",
		"cue": "action_cut_in",
		"actor_id": current_id,
		"target_id": primary_tid,
	})
	events.append({
		"type": "skill_executed",
		"actor_id": current_id,
		"skill_id": skill_id,
		"skill_name": String(skill["name"]),
		"ap_spent": int(skill["ap_cost"]),
	})

	for target in targets:
		if bool(skill["is_heal"]):
			var heal_amt: int = int(skill["base_power"]) + int(actor["tech"]) / 2
			target["hp"] = mini(int(target["max_hp"]), int(target["hp"]) + heal_amt)
			events.append({
				"type": "healing_applied",
				"actor_id": current_id,
				"target_id": String(target["id"]),
				"amount": heal_amt,
				"remaining_hp": int(target["hp"]),
			})
		elif int(skill["base_power"]) > 0:
			var scaling: int = int(actor["tech"]) if (skill_id == "solar_flare" or skill_id == "holo_lasso") else int(actor["aim"])
			var raw: int = maxi(6, int(skill["base_power"]) + scaling / 2 - int(target["grit"]) / 4)
			var crit_chance: int = 10 + int(skill["crit_bonus_pct"])
			var is_crit: bool = _next_rng(100) < crit_chance
			var dmg: int = raw
			if is_crit:
				dmg = (dmg * 150) / 100
			if overclock_active:
				dmg = (dmg * 130) / 100
			var marked_bonus := _has_status(target, "marked")
			if marked_bonus:
				dmg = (dmg * 135) / 100
			var guarded := _has_status(target, "guard")
			if guarded:
				dmg = (dmg * 55) / 100
			dmg = maxi(1, dmg)
			target["hp"] = maxi(0, int(target["hp"]) - dmg)

			events.append({
				"type": "camera_cue",
				"cue": "impact_shake",
				"actor_id": current_id,
				"target_id": String(target["id"]),
			})
			events.append({
				"type": "damage_dealt",
				"actor_id": current_id,
				"target_id": String(target["id"]),
				"amount": dmg,
				"is_crit": is_crit,
				"guarded": guarded,
				"marked_bonus": marked_bonus,
				"remaining_hp": int(target["hp"]),
			})
			if int(target["hp"]) == 0 and bool(target["alive"]):
				target["alive"] = false
				events.append({
					"type": "combatant_defeated",
					"combatant_id": String(target["id"]),
					"name": String(target["name"]),
				})

		var status_kind := String(skill.get("apply_status", ""))
		if status_kind != "" and bool(target["alive"]):
			_apply_or_refresh_status(target, status_kind, int(skill["status_turns"]), int(skill["status_potency"]))
			events.append({
				"type": "status_applied",
				"actor_id": current_id,
				"target_id": String(target["id"]),
				"status": status_kind,
				"turns": int(skill["status_turns"]),
			})

	# === 5 & 6. POST-EXEC VALIDATION & TRIGGERS ===
	if _check_outcome(events) != "ongoing":
		return {"ok": true, "error": "", "state": state, "events": events}

	# === 7. END TURN ===
	var remaining_statuses: Array = []
	for s in actor["statuses"]:
		s["turns_remaining"] = int(s["turns_remaining"]) - 1
		if int(s["turns_remaining"]) > 0:
			remaining_statuses.append(s)
	actor["statuses"] = remaining_statuses

	_advance_to_next_living_actor()
	var next_id := get_active_combatant_id()
	var next_actor := get_combatant(next_id)
	if not next_actor.is_empty() and String(next_actor["faction"]) == "player":
		events.append({
			"type": "camera_cue",
			"cue": "command_over_shoulder",
			"actor_id": next_id,
			"target_id": "",
		})

	return {"ok": true, "error": "", "state": state, "events": events}
