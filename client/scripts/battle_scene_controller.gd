class_name BattleSceneController
extends Node3D

## Orchestrates the Ansible PS1-era Final Fantasy Turn-Based Battle Vertical Slice:
## - Builds the Neon Spaghetti Western space-frontier canyon arena
## - Spawns 3v3 low-poly recolorable 3D Drifters & Outlaws in line-up formation
## - Directs cinematic camera angles, VFX plasma bolts/sparks, HUD, and Nakama/local sim
## - Supports keyboard, mouse/touch, godot-mcp-runtime, and --auto-playtest video capture

var _net: NakamaClientAdapter
var _cam_rig: BattleCameraRig
var _hud: NeonWesternHUD
var _playtest: AutoPlaytestDriver

var _actors: Dictionary = {}
var _vfx_root: Node3D
var _palette_preset_idx: int = 0

var _selected_skill_id: String = ""
var _selected_target_id: String = ""
var _input_unlocked: bool = false
var _busy: bool = false

const PLAYER_SLOTS := [
	Vector3(-4.4, 0.0, -2.5),
	Vector3(-4.9, 0.0, 0.0),
	Vector3(-4.4, 0.0, 2.5),
]
const ENEMY_SLOTS := [
	Vector3(4.4, 0.0, -2.4),
	Vector3(4.9, 0.0, 0.0),
	Vector3(4.4, 0.0, 2.4),
]


func _ready() -> void:
	_vfx_root = Node3D.new()
	_vfx_root.name = "VFXRoot"
	add_child(_vfx_root)

	_build_frontier_arena()

	_net = NakamaClientAdapter.new()
	_net.name = "NakamaClientAdapter"
	add_child(_net)

	_cam_rig = BattleCameraRig.new()
	_cam_rig.name = "BattleCameraRig"
	add_child(_cam_rig)

	_hud = NeonWesternHUD.new()
	_hud.name = "NeonWesternHUD"
	add_child(_hud)

	_playtest = AutoPlaytestDriver.new()
	_playtest.name = "AutoPlaytestDriver"
	_playtest.configure_from_cmdline()
	add_child(_playtest)

	_cam_rig.camera_mode_changed.connect(_hud.set_camera_label)
	_net.connection_mode_changed.connect(_hud.set_network_label)
	_hud.skill_selected.connect(_on_skill_selected)
	_hud.target_selected.connect(_on_target_selected)
	_hud.confirm_action_pressed.connect(_on_confirm_action)
	_hud.recolor_squad_pressed.connect(_cycle_squad_palette)
	_hud.restart_battle_pressed.connect(_start_new_battle)

	_start_new_battle()


func _process(_delta: float) -> void:
	if _hud != null and _cam_rig != null:
		_hud.update_enemy_plate_positions(_cam_rig.camera, _actors)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	if k.keycode == KEY_R:
		_cycle_squad_palette()
		return
	if k.keycode == KEY_F9:
		_playtest.enabled = not _playtest.enabled
		_hud.set_dispatch("AUTO-PLAYTEST %s" % ("ENABLED" if _playtest.enabled else "DISABLED"))
		if _playtest.enabled and _input_unlocked and not _busy:
			_run_auto_playtest_step()
		return

	if not _input_unlocked or _busy:
		return

	var engine := _net.get_engine()
	var active := engine.get_combatant(engine.get_active_combatant_id())
	if active.is_empty() or String(active["faction"]) != "player":
		return
	var skills: Array = active["skills"]

	match k.keycode:
		KEY_1:
			if skills.size() > 0:
				_on_skill_selected(String(skills[0]["id"]))
		KEY_2:
			if skills.size() > 1:
				_on_skill_selected(String(skills[1]["id"]))
		KEY_3:
			if skills.size() > 2:
				_on_skill_selected(String(skills[2]["id"]))
		KEY_4:
			if skills.size() > 3:
				_on_skill_selected(String(skills[3]["id"]))
		KEY_LEFT, KEY_A:
			_cycle_target(-1)
		KEY_RIGHT, KEY_D:
			_cycle_target(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_on_confirm_action()


func _start_new_battle() -> void:
	_busy = true
	_input_unlocked = false
	_hud.hide_battle_end()

	for child in _actors.values():
		if is_instance_valid(child):
			child.queue_free()
	_actors.clear()

	_net.start_battle("frontier_skirmish", 2026)
	var engine := _net.get_engine()

	for c in engine.state["combatants"]:
		var actor := DrifterActor3D.new()
		var slot: int = int(c["slot_index"])
		var pos: Vector3 = PLAYER_SLOTS[slot] if String(c["faction"]) == "player" else ENEMY_SLOTS[slot]
		var palette := DrifterRoster.get_palette_for(String(c["id"]), _palette_preset_idx)
		add_child(actor)
		actor.setup(c, palette, pos)
		_actors[String(c["id"])] = actor

	_hud.set_palette_label(DrifterRoster.get_preset_name(_palette_preset_idx))
	_hud.set_dispatch("★ OUTLAWS ON THE HORIZON — ANSIBLE SQUAD FORMING LINE-UP!")
	_cam_rig.set_mode_establishing()
	_hud.refresh_state(engine, "", "", false)

	# Let the classic PlayStation-era establishing sweep breathe before turn 1
	await get_tree().create_timer(2.1).timeout
	_busy = false
	_begin_current_turn()


func _begin_current_turn() -> void:
	var engine := _net.get_engine()
	if String(engine.state.get("outcome", "ongoing")) != "ongoing":
		return

	var active_id := engine.get_active_combatant_id()
	var active := engine.get_combatant(active_id)
	if active.is_empty():
		return

	for cid in _actors.keys():
		var a: DrifterActor3D = _actors[cid]
		a.set_active_turn(cid == active_id)
		a.set_targeted(false)

	if String(active["faction"]) == "player":
		_selected_skill_id = String(active["skills"][0]["id"])
		_ensure_valid_target_for_skill(active, _selected_skill_id)
		_input_unlocked = true
		var actor_node: DrifterActor3D = _actors[active_id]
		_cam_rig.set_mode_command_over_shoulder(actor_node.home_position, Vector3(4.5, 1.3, 0.0))
		_hud.set_dispatch("★ %s'S TURN — CHOOSE FRONTIER ACTION" % String(active["name"]).to_upper())
		_hud.refresh_state(engine, _selected_skill_id, _selected_target_id, true)

		if _playtest.enabled:
			_run_auto_playtest_step()
	else:
		_input_unlocked = false
		_hud.refresh_state(engine, "", "", false)
		_hud.set_dispatch("☠ %s PREPARES TO STRIKE..." % String(active["name"]).to_upper())
		await get_tree().create_timer(0.65).timeout
		_execute_turn_action({})


func _run_auto_playtest_step() -> void:
	if _busy:
		return
	var engine := _net.get_engine()
	var active := engine.get_combatant(engine.get_active_combatant_id())
	if active.is_empty() or String(active["faction"]) != "player":
		return

	var demo := _playtest.choose_demo_action(engine, active)
	if demo.is_empty():
		return

	if _playtest.should_demo_recolor():
		await get_tree().create_timer(0.35).timeout
		_cycle_squad_palette()

	_on_skill_selected(String(demo["skill_id"]))
	if String(demo.get("target_id", "")) != "":
		_on_target_selected(String(demo["target_id"]))
	await get_tree().create_timer(0.85).timeout
	if _input_unlocked and not _busy:
		_on_confirm_action()


func _on_skill_selected(skill_id: String) -> void:
	if not _input_unlocked or _busy:
		return
	var engine := _net.get_engine()
	var active := engine.get_combatant(engine.get_active_combatant_id())
	if active.is_empty():
		return
	_selected_skill_id = skill_id
	_ensure_valid_target_for_skill(active, skill_id)
	_hud.refresh_state(engine, _selected_skill_id, _selected_target_id, true)


func _on_target_selected(target_id: String) -> void:
	if not _input_unlocked or _busy:
		return
	_selected_target_id = target_id
	var engine := _net.get_engine()
	for cid in _actors.keys():
		(_actors[cid] as DrifterActor3D).set_targeted(cid == _selected_target_id)
	var active_id := engine.get_active_combatant_id()
	if _actors.has(active_id) and _actors.has(_selected_target_id) and active_id != _selected_target_id:
		_cam_rig.set_mode_target_lock(
			(_actors[active_id] as DrifterActor3D).home_position,
			(_actors[_selected_target_id] as DrifterActor3D).home_position
		)
	_hud.refresh_state(engine, _selected_skill_id, _selected_target_id, true)


func _cycle_target(step: int) -> void:
	var engine := _net.get_engine()
	var active := engine.get_combatant(engine.get_active_combatant_id())
	if active.is_empty():
		return
	var skill := _find_skill(active, _selected_skill_id)
	var tmode := String(skill.get("target_mode", "single_enemy"))
	if tmode != "single_enemy" and tmode != "single_ally":
		return
	var faction := "player" if tmode == "single_ally" else "enemy"
	var candidates := engine.get_living_by_faction(faction)
	if candidates.is_empty():
		return
	var idx := 0
	for i in range(candidates.size()):
		if String(candidates[i]["id"]) == _selected_target_id:
			idx = i
			break
	idx = posmod(idx + step, candidates.size())
	_on_target_selected(String(candidates[idx]["id"]))


func _ensure_valid_target_for_skill(active: Dictionary, skill_id: String) -> void:
	var engine := _net.get_engine()
	var skill := _find_skill(active, skill_id)
	var tmode := String(skill.get("target_mode", "single_enemy"))
	for a in _actors.values():
		(a as DrifterActor3D).set_targeted(false)

	if tmode == "self_only":
		_selected_target_id = String(active["id"])
	elif tmode == "all_enemies":
		var enemies := engine.get_living_by_faction("enemy")
		_selected_target_id = String(enemies[0]["id"]) if not enemies.is_empty() else ""
		for e in enemies:
			if _actors.has(String(e["id"])):
				(_actors[String(e["id"])] as DrifterActor3D).set_targeted(true)
	elif tmode == "single_ally":
		var allies := engine.get_living_by_faction("player")
		var valid := false
		for p in allies:
			if String(p["id"]) == _selected_target_id:
				valid = true
				break
		if not valid and not allies.is_empty():
			_selected_target_id = String(allies[0]["id"])
		if _actors.has(_selected_target_id):
			(_actors[_selected_target_id] as DrifterActor3D).set_targeted(true)
	else:
		var enemies := engine.get_living_by_faction("enemy")
		var valid := false
		for e in enemies:
			if String(e["id"]) == _selected_target_id:
				valid = true
				break
		if not valid and not enemies.is_empty():
			_selected_target_id = String(enemies[0]["id"])
		if _actors.has(_selected_target_id):
			(_actors[_selected_target_id] as DrifterActor3D).set_targeted(true)


func _find_skill(actor: Dictionary, skill_id: String) -> Dictionary:
	for s in actor.get("skills", []):
		if String(s["id"]) == skill_id:
			return s
	return {}


func _on_confirm_action() -> void:
	if not _input_unlocked or _busy:
		return
	var engine := _net.get_engine()
	var active_id := engine.get_active_combatant_id()
	_execute_turn_action({
		"actor_id": active_id,
		"skill_id": _selected_skill_id,
		"target_id": _selected_target_id,
	})


func _execute_turn_action(action: Dictionary) -> void:
	_busy = true
	_input_unlocked = false
	var engine := _net.get_engine()
	var acting_id := engine.get_active_combatant_id()
	var result := _net.submit_action(action)
	if not bool(result.get("ok", false)):
		_hud.set_dispatch("INVALID ACTION: " + String(result.get("error", "")))
		_busy = false
		_input_unlocked = true
		return

	_hud.refresh_state(engine, _selected_skill_id, _selected_target_id, false)
	var events: Array = result.get("events", [])
	await _play_event_sequence(acting_id, events)

	# Sync guard domes after turn finishes
	for c in engine.state["combatants"]:
		var cid := String(c["id"])
		if _actors.has(cid):
			var guarding := false
			for st in c.get("statuses", []):
				if String(st["kind"]) == "guard" and int(st["turns_remaining"]) > 0:
					guarding = true
			(_actors[cid] as DrifterActor3D).set_guarding(guarding)

	_busy = false
	var outcome := String(engine.state.get("outcome", "ongoing"))
	if outcome == "ongoing":
		_begin_current_turn()
	elif _playtest.enabled and _playtest.auto_quit_on_finish:
		await get_tree().create_timer(2.6).timeout
		get_tree().quit(0)


func _play_event_sequence(acting_id: String, events: Array) -> void:
	var engine := _net.get_engine()
	var actor_node: DrifterActor3D = _actors.get(acting_id, null)

	for ev in events:
		var ev_type := String(ev.get("type", ""))
		match ev_type:
			"upkeep_status_tick":
				var tid := String(ev["actor_id"])
				if _actors.has(tid):
					var node: DrifterActor3D = _actors[tid]
					node.play_hit_recoil(false)
					_hud.spawn_floating_popup(_cam_rig.camera, node.get_head_world_position(), "BURN %d" % int(ev["delta_hp"]), Color(1.0, 0.45, 0.16))
					_hud.set_dispatch("🔥 %s TAKES %d BURN DAMAGE!" % [String(engine.get_combatant(tid)["name"]).to_upper(), abs(int(ev["delta_hp"]))])
					await get_tree().create_timer(0.45).timeout
			"trigger_fired":
				_hud.set_dispatch("⚡ TRIGGER: %s (%s)" % [String(ev["trigger_name"]).to_upper(), String(ev["detail"])])
				await get_tree().create_timer(0.30).timeout
			"camera_cue":
				var cue := String(ev.get("cue", ""))
				if cue == "action_cut_in" and actor_node != null:
					var tid := String(ev.get("target_id", ""))
					var t_pos := (_actors[tid] as DrifterActor3D).home_position if _actors.has(tid) else Vector3.ZERO
					_cam_rig.set_mode_action_cutin(actor_node.home_position, t_pos, actor_node.is_player)
				elif cue == "victory_orbit":
					_cam_rig.set_mode_victory_orbit(Vector3(-4.5, 0.2, 0.0))
			"skill_executed":
				var sname := String(ev["skill_name"])
				var cname := String(engine.get_combatant(acting_id).get("name", acting_id))
				_hud.set_dispatch("★ %s USES %s!" % [cname.to_upper(), sname.to_upper()])
				if actor_node != null:
					actor_node.play_attack_lunge()
					_spawn_muzzle_flash(actor_node.get_muzzle_world_position(), Color(0.24, 0.96, 1.0) if actor_node.is_player else Color(1.0, 0.28, 0.35))
				await get_tree().create_timer(0.55).timeout
			"damage_dealt":
				var tid := String(ev["target_id"])
				var amt := int(ev["amount"])
				var is_crit := bool(ev["is_crit"])
				if _actors.has(tid) and actor_node != null:
					var tnode: DrifterActor3D = _actors[tid]
					_cam_rig.set_mode_impact_focus(tnode.home_position, actor_node.home_position)
					await _spawn_plasma_bolt(actor_node.get_muzzle_world_position(), tnode.home_position + Vector3(0.0, 1.25, 0.0), Color(1.0, 0.72, 0.24) if actor_node.is_player else Color(1.0, 0.22, 0.42))
					tnode.play_hit_recoil(is_crit)
					_cam_rig.trigger_shake(0.45 if is_crit else 0.24)
					_spawn_impact_sparks(tnode.home_position + Vector3(0.0, 1.25, 0.0), Color(1.0, 0.80, 0.24) if is_crit else Color(0.24, 0.96, 1.0))
					var tag := ("CRIT! -%d" % amt) if is_crit else ("-%d" % amt)
					if bool(ev["marked_bonus"]):
						tag += " [MARK]"
					if bool(ev["guarded"]):
						tag += " [GUARD]"
					_hud.spawn_floating_popup(_cam_rig.camera, tnode.get_head_world_position(), tag, Color(1.0, 0.82, 0.20) if is_crit else Color(1.0, 0.32, 0.36))
					_hud.refresh_state(engine, _selected_skill_id, _selected_target_id, false)
					await get_tree().create_timer(0.42).timeout
			"healing_applied":
				var tid := String(ev["target_id"])
				if _actors.has(tid):
					var tnode: DrifterActor3D = _actors[tid]
					_spawn_impact_sparks(tnode.home_position + Vector3(0.0, 1.25, 0.0), Color(0.30, 1.0, 0.65))
					_hud.spawn_floating_popup(_cam_rig.camera, tnode.get_head_world_position(), "+%d HP" % int(ev["amount"]), Color(0.30, 1.0, 0.65))
					_hud.refresh_state(engine, _selected_skill_id, _selected_target_id, false)
					await get_tree().create_timer(0.42).timeout
			"status_applied":
				var tid := String(ev["target_id"])
				if _actors.has(tid):
					var tnode: DrifterActor3D = _actors[tid]
					var st_name := String(ev["status"]).to_upper()
					_hud.spawn_floating_popup(_cam_rig.camera, tnode.get_head_world_position() + Vector3(0.0, 0.35, 0.0), "+%s" % st_name, Color(1.0, 0.28, 0.68))
					await get_tree().create_timer(0.22).timeout
			"combatant_defeated":
				var cid := String(ev["combatant_id"])
				if _actors.has(cid):
					(_actors[cid] as DrifterActor3D).set_defeated()
					_hud.set_dispatch("☠ %s IS DOWN!" % String(ev["name"]).to_upper())
					await get_tree().create_timer(0.50).timeout
			"battle_ended":
				_hud.refresh_state(engine, "", "", false)
				_hud.show_battle_end(String(ev["outcome"]), int(ev["scrap_reward"]), int(ev["holo_data_reward"]))
				_hud.set_dispatch("★ SKIRMISH COMPLETE — RETURNING TELEMETRY TO ANSIBLE")


func _cycle_squad_palette() -> void:
	_palette_preset_idx = (_palette_preset_idx + 1) % DrifterRoster.PALETTE_PRESETS.size()
	var preset_name := DrifterRoster.get_preset_name(_palette_preset_idx)
	for cid in ["drifter_vega", "drifter_krix", "drifter_syl"]:
		if _actors.has(cid):
			(_actors[cid] as DrifterActor3D).apply_palette(DrifterRoster.get_palette_for(cid, _palette_preset_idx))
	_hud.set_palette_label(preset_name)
	_hud.set_dispatch("🎨 RECOLORABLE DRIFTER SHADER -> %s" % preset_name.to_upper())


# ============================================================================
# VFX Helpers (Plasma Bolts, Muzzle Flashes, Neon Impact Sparks)
# ============================================================================

func _spawn_muzzle_flash(pos: Vector3, col: Color) -> void:
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	flash.mesh = sm
	flash.material_override = mat
	_vfx_root.add_child(flash)
	flash.global_position = pos
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector3(2.2, 2.2, 2.2), 0.14)
	tw.tween_callback(flash.queue_free)


func _spawn_plasma_bolt(from_pos: Vector3, to_pos: Vector3, col: Color) -> void:
	var bolt := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.14, 1.15)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	bolt.mesh = bm
	bolt.material_override = mat
	_vfx_root.add_child(bolt)
	bolt.look_at_from_position(from_pos, to_pos, Vector3.UP)

	var tw := create_tween()
	tw.tween_property(bolt, "global_position", to_pos, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	bolt.queue_free()


func _spawn_impact_sparks(pos: Vector3, col: Color) -> void:
	for i in range(7):
		var spark := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 0.12)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		spark.mesh = bm
		spark.material_override = mat
		_vfx_root.add_child(spark)
		spark.global_position = pos

		var angle := float(i) * (TAU / 7.0)
		var dest := pos + Vector3(cos(angle) * 1.15, 0.65 + (i % 3) * 0.25, sin(angle) * 1.15)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "global_position", dest, 0.32).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "scale", Vector3.ONE * 0.05, 0.32)
		tw.chain().tween_callback(spark.queue_free)


# ============================================================================
# Neon Spaghetti Western Frontier Mesa Arena
# ============================================================================

func _build_frontier_arena() -> void:
	# Twilight space-western sky & atmospheric environment
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.05, 0.03, 0.14)
	sky_mat.sky_horizon_color = Color(0.46, 0.14, 0.28)
	sky_mat.ground_bottom_color = Color(0.10, 0.04, 0.06)
	sky_mat.ground_horizon_color = Color(0.32, 0.12, 0.18)
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.22, 0.38)
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.11, 0.22)
	env.fog_density = 0.011

	var world_env := WorldEnvironment.new()
	world_env.name = "FrontierEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Warm golden-hour sunset sun + cool cyan rim fill
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.78, 0.54)
	sun.light_energy = 1.65
	sun.rotation_degrees = Vector3(-34.0, -35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	var cyan_fill := OmniLight3D.new()
	cyan_fill.light_color = Color(0.20, 0.92, 1.0)
	cyan_fill.light_energy = 2.6
	cyan_fill.omni_range = 24.0
	cyan_fill.position = Vector3(-6.5, 4.5, 4.5)
	add_child(cyan_fill)

	var magenta_fill := OmniLight3D.new()
	magenta_fill.light_color = Color(1.0, 0.22, 0.58)
	magenta_fill.light_energy = 2.6
	magenta_fill.omni_range = 24.0
	magenta_fill.position = Vector3(6.5, 4.5, -4.0)
	add_child(magenta_fill)

	# Red-rock desert mesa combat floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(72.0, 72.0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.30, 0.15, 0.14)
	floor_mat.roughness = 0.94
	floor_mesh.mesh = plane
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)

	# Glowing neon holographic duel-lane strip down the center of the frontier arena
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(1.0, 0.68, 0.22)
	for z_off in [-3.8, 3.8]:
		var rail := MeshInstance3D.new()
		var rbox := BoxMesh.new()
		rbox.size = Vector3(13.0, 0.04, 0.08)
		rail.mesh = rbox
		rail.material_override = line_mat
		rail.position = Vector3(0.0, 0.03, z_off)
		add_child(rail)

	var center_mark := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.08, 0.04, 7.6)
	var cyan_mat := StandardMaterial3D.new()
	cyan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan_mat.albedo_color = Color(0.20, 0.96, 1.0)
	center_mark.mesh = cbox
	center_mark.material_override = cyan_mat
	center_mark.position = Vector3(0.0, 0.03, 0.0)
	add_child(center_mark)

	# Distant Red-Rock Canyon Mesas & Silhouette Spires
	var mesa_mat := StandardMaterial3D.new()
	mesa_mat.albedo_color = Color(0.22, 0.09, 0.14)
	mesa_mat.roughness = 0.95
	var mesa_specs := [
		[Vector3(-14.0, 3.2, -16.0), Vector3(8.5, 6.4, 5.2)],
		[Vector3(-2.5, 2.2, -20.0), Vector3(10.0, 4.4, 5.0)],
		[Vector3(12.5, 3.8, -15.5), Vector3(9.0, 7.6, 5.5)],
		[Vector3(18.0, 2.5, -5.0), Vector3(5.5, 5.0, 9.0)],
		[Vector3(-18.5, 2.6, -4.0), Vector3(5.5, 5.2, 8.5)],
	]
	for spec in mesa_specs:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[1]
		m.mesh = bm
		m.material_override = mesa_mat
		m.position = spec[0]
		add_child(m)

	# Distant Neon Ansible Relay Pylons & Saloon Arch Silhouette
	var pylon_mat := StandardMaterial3D.new()
	pylon_mat.albedo_color = Color(0.12, 0.08, 0.18)
	var magenta_neon := StandardMaterial3D.new()
	magenta_neon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	magenta_neon.albedo_color = Color(1.0, 0.24, 0.62)

	for px in [-7.5, 7.5]:
		var pylon := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.65, 6.2, 0.65)
		pylon.mesh = pm
		pylon.material_override = pylon_mat
		pylon.position = Vector3(px, 3.1, -9.2)
		add_child(pylon)

		var beacon := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(0.82, 0.28, 0.82)
		beacon.mesh = bmesh
		beacon.material_override = cyan_mat if px < 0 else magenta_neon
		beacon.position = Vector3(px, 5.8, -9.2)
		add_child(beacon)

	# Western saloon crossbeam neon sign in the distance
	var beam := MeshInstance3D.new()
	var beam_m := BoxMesh.new()
	beam_m.size = Vector3(15.6, 0.34, 0.34)
	beam.mesh = beam_m
	beam.material_override = line_mat
	beam.position = Vector3(0.0, 5.4, -9.2)
	add_child(beam)

	# Huge Ringed Gas Giant looming over the dusty horizon!
	var planet := MeshInstance3D.new()
	var psphere := SphereMesh.new()
	psphere.radius = 9.5
	psphere.height = 19.0
	psphere.radial_segments = 24
	psphere.rings = 14
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.62, 0.22, 0.42)
	planet.mesh = psphere
	planet.material_override = pmat
	planet.position = Vector3(5.0, 15.0, -56.0)
	add_child(planet)

	var ring := MeshInstance3D.new()
	var rtorus := TorusMesh.new()
	rtorus.inner_radius = 12.2
	rtorus.outer_radius = 15.6
	rtorus.rings = 32
	rtorus.ring_segments = 6
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(1.0, 0.68, 0.30)
	ring.mesh = rtorus
	ring.material_override = rmat
	ring.position = planet.position
	ring.scale = Vector3(1.0, 0.16, 1.0)
	ring.rotation_degrees = Vector3(22.0, 0.0, -18.0)
	add_child(ring)
