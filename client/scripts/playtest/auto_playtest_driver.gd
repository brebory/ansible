class_name AutoPlaytestDriver
extends Node

## Automated playtest showcase director for Ansible's battle vertical slice.
## Triggered when launched with `--auto-playtest` (used by scripts/record_playtest.sh
## for deterministic MovieWriter + ffmpeg footage generation) or toggled via F9.

var enabled: bool = false
var auto_quit_on_finish: bool = false
var _turn_count: int = 0
var _recolor_demo_done: bool = false


func configure_from_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var all_args := OS.get_cmdline_args()
	for a in args + all_args:
		if a == "--auto-playtest":
			enabled = true
		elif a == "--auto-quit":
			auto_quit_on_finish = true


func choose_demo_action(engine: BattleEngine, active: Dictionary) -> Dictionary:
	_turn_count += 1
	var living_enemies := engine.get_living_by_faction("enemy")
	var living_players := engine.get_living_by_faction("player")
	if living_enemies.is_empty():
		return {}

	var actor_id := String(active["id"])
	var ap := int(active["ap"])

	# Pick lowest-HP or marked target for crisp focus fire
	var target: Dictionary = living_enemies[0]
	for e in living_enemies:
		for s in e.get("statuses", []):
			if String(s["kind"]) == "marked":
				target = e
				break

	# Choreographed showcase variety across all 3 drifter classes
	var chosen_skill_id := String(active["skills"][0]["id"])
	var chosen_target_id := String(target["id"])

	if actor_id == "drifter_vega":
		if _turn_count == 1 and ap >= 1:
			chosen_skill_id = "deadeye_mark"
		elif ap >= 2 and living_enemies.size() >= 2:
			chosen_skill_id = "fan_hammer"
		else:
			chosen_skill_id = "quickdraw"
	elif actor_id == "drifter_syl":
		# Heal if an ally dipped below 65% HP, else AoE Neon Flare or Holo-Lasso
		var wounded: Dictionary = {}
		for p in living_players:
			if float(p["hp"]) / float(p["max_hp"]) < 0.65:
				wounded = p
				break
		if not wounded.is_empty() and ap >= 1:
			chosen_skill_id = "med_stim"
			chosen_target_id = String(wounded["id"])
		elif ap >= 2 and living_enemies.size() >= 2:
			chosen_skill_id = "solar_flare"
		else:
			chosen_skill_id = "holo_lasso"
	elif actor_id == "drifter_krix":
		if ap >= 2:
			chosen_skill_id = "rail_buckshot"
		elif _turn_count <= 4 and ap >= 1:
			chosen_skill_id = "overdrive_stim"
			chosen_target_id = actor_id
		else:
			chosen_skill_id = "scatter_blast"

	return {
		"actor_id": actor_id,
		"skill_id": chosen_skill_id,
		"target_id": chosen_target_id,
	}


func should_demo_recolor() -> bool:
	if enabled and not _recolor_demo_done and _turn_count == 2:
		_recolor_demo_done = true
		return true
	return false
