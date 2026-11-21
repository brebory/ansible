extends SceneTree

## Headless GDScript test suite for Ansible's BattleEngine and DrifterRoster.
## Run via: godot --headless --path client --script res://tests/test_battle_engine.gd

var _failures: int = 0


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		printerr("FAIL: " + msg)
		_failures += 1
	else:
		print("  OK: " + msg)


func _initialize() -> void:
	print("=== Ansible Godot BattleEngine Headless Tests ===")
	_test_initialization_and_turn_order()
	_test_marked_and_burn_pipeline()
	_test_full_deterministic_battle()

	if _failures > 0:
		printerr("Tests failed: %d failure(s)" % _failures)
		quit(1)
	else:
		print("ALL GODOT BATTLE TESTS PASSED!")
		quit(0)


func _test_initialization_and_turn_order() -> void:
	var eng := BattleEngine.new()
	eng.init_default_battle("t1", 2026)
	_assert(eng.state["combatants"].size() == 6, "3v3 default encounter has 6 combatants")
	_assert(eng.get_active_combatant_id() == "drifter_vega", "Vega (speed 16) acts first")
	_assert(DrifterRoster.PALETTE_PRESETS.size() >= 3, "At least 3 recolorable shader presets available")


func _test_marked_and_burn_pipeline() -> void:
	var eng := BattleEngine.new()
	eng.init_default_battle("t2", 42)

	var r1 := eng.step_turn({
		"actor_id": "drifter_vega",
		"skill_id": "deadeye_mark",
		"target_id": "enemy_deadeye",
	})
	_assert(bool(r1["ok"]), "Vega Bounty Mark succeeds")
	var deadeye := eng.get_combatant("enemy_deadeye")
	var has_mark := false
	for s in deadeye["statuses"]:
		if String(s["kind"]) == "marked":
			has_mark = true
	_assert(has_mark, "Bounty Mark applies 'marked' status to Redline Kid")

	var r2 := eng.step_turn({
		"actor_id": "drifter_syl",
		"skill_id": "holo_lasso",
		"target_id": "enemy_deadeye",
	})
	_assert(bool(r2["ok"]), "Syl Holo-Lasso succeeds on Marked target")
	var marked_triggered := false
	for ev in r2["events"]:
		if String(ev.get("type", "")) == "damage_dealt" and bool(ev.get("marked_bonus", false)):
			marked_triggered = true
	_assert(marked_triggered, "Marked target receives +35% marked_bonus damage")


func _test_full_deterministic_battle() -> void:
	var run_sim := func(seed_val: int) -> Array:
		var eng := BattleEngine.new()
		eng.init_default_battle("det", seed_val)
		var driver := AutoPlaytestDriver.new()
		driver.enabled = true
		for _turn in range(50):
			if String(eng.state["outcome"]) != "ongoing":
				break
			var active := eng.get_combatant(eng.get_active_combatant_id())
			var act := {}
			if String(active["faction"]) == "player":
				act = driver.choose_demo_action(eng, active)
			var res := eng.step_turn(act)
			_assert(bool(res["ok"]), "Step ok on round %d (%s)" % [int(eng.state["round"]), String(active["id"])])
		var total_hp := 0
		for p in eng.get_living_by_faction("player"):
			total_hp += int(p["hp"])
		driver.free()
		return [String(eng.state["outcome"]), int(eng.state["round"]), total_hp]

	var a: Array = run_sim.call(2026)
	var b: Array = run_sim.call(2026)
	_assert(a == b, "Battle simulation is 100% deterministic across runs")
	_assert(a[0] == "victory", "AutoPlaytestDriver clears the default outlaw gang (outcome=%s)" % a[0])
