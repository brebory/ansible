class_name NeonWesternHUD
extends CanvasLayer

## Neon Spaghetti Western holographic battle HUD.
## Features western-notched glowing panels, Wanted Turn Order strip, Saloon Command Deck,
## Squad Status Cards, Enemy Overhead Plates, 3D-projected floating damage popups,
## and live shader recolor button.

signal skill_selected(skill_id: String)
signal target_selected(target_id: String)
signal confirm_action_pressed()
signal recolor_squad_pressed()
signal restart_battle_pressed()

const HOLO_SHADER: Shader = preload("res://shaders/neon_western_holo.gdshader")

const COL_BG := Color(0.07, 0.04, 0.13, 0.90)
const COL_BG_DARK := Color(0.04, 0.02, 0.08, 0.94)
const COL_AMBER := Color(1.0, 0.72, 0.26, 1.0)
const COL_CYAN := Color(0.20, 0.96, 1.0, 1.0)
const COL_MAGENTA := Color(1.0, 0.24, 0.62, 1.0)
const COL_CRIMSON := Color(1.0, 0.25, 0.30, 1.0)
const COL_GREEN := Color(0.32, 1.0, 0.64, 1.0)
const COL_TEXT := Color(0.98, 0.94, 0.86, 1.0)
const COL_MUTED := Color(0.70, 0.66, 0.76, 1.0)

var _root: Control
var _round_label: Label
var _net_badge: Label
var _cam_badge: Label
var _palette_btn: Button
var _turn_strip: HBoxContainer
var _dispatch_label: Label

var _command_panel: PanelContainer
var _actor_header_label: Label
var _actor_ap_label: Label
var _skill_buttons: Array[Button] = []
var _skill_desc_label: Label
var _target_row: HBoxContainer
var _fire_btn: Button
var _enemy_banner: PanelContainer
var _enemy_banner_label: Label

var _squad_container: VBoxContainer
var _enemy_plates_layer: Control
var _popups_layer: Control
var _end_modal: PanelContainer
var _end_title: Label
var _end_body: Label

var _enemy_plates: Dictionary = {}
var _current_skill_id: String = ""
var _current_target_id: String = ""


func _ready() -> void:
	layer = 10
	_build_ui()


func _make_western_style(border_col: Color, bg_col: Color = COL_BG, border_w: int = 2, corner_cut: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.border_width_left = border_w + 2
	sb.border_width_right = border_w + 2
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = corner_cut
	sb.corner_radius_top_right = corner_cut
	sb.corner_radius_bottom_left = corner_cut
	sb.corner_radius_bottom_right = corner_cut
	sb.corner_detail = 1 # Octagonal notched western saloon corners!
	sb.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.28)
	sb.shadow_size = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _style_neon_button(btn: Button, accent: Color) -> void:
	btn.add_theme_stylebox_override("normal", _make_western_style(accent, Color(0.10, 0.05, 0.18, 0.92), 2, 6))
	btn.add_theme_stylebox_override("hover", _make_western_style(COL_AMBER, Color(0.18, 0.09, 0.28, 0.96), 2, 6))
	btn.add_theme_stylebox_override("pressed", _make_western_style(COL_CYAN, Color(0.24, 0.14, 0.34, 1.0), 3, 6))
	btn.add_theme_stylebox_override("focus", _make_western_style(COL_AMBER, Color(0.16, 0.08, 0.25, 0.96), 3, 6))
	btn.add_theme_stylebox_override("disabled", _make_western_style(Color(0.32, 0.28, 0.38, 0.65), Color(0.06, 0.04, 0.09, 0.72), 1, 6))
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_AMBER)
	btn.add_theme_color_override("font_pressed_color", COL_CYAN)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.50))


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "NeonWesternHUDRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Enemy overhead HP plates sit behind HUD chrome
	_enemy_plates_layer = Control.new()
	_enemy_plates_layer.name = "EnemyPlatesLayer"
	_enemy_plates_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_enemy_plates_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_enemy_plates_layer)

	# === TOP BAR: Outpost Emblem | Wanted Turn Timeline | Camera & Recolor ===
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 18
	top_bar.offset_right = -18
	top_bar.offset_top = 14
	top_bar.offset_bottom = 78
	top_bar.add_theme_constant_override("separation", 12)
	_root.add_child(top_bar)

	# Left Title Sign
	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", _make_western_style(COL_AMBER, COL_BG, 2, 8))
	top_bar.add_child(title_panel)
	var title_vb := VBoxContainer.new()
	title_vb.add_theme_constant_override("separation", 2)
	title_panel.add_child(title_vb)

	_round_label = Label.new()
	_round_label.name = "RoundLabel"
	_round_label.text = "★ ANSIBLE OUTPOST // ROUND 1"
	_round_label.add_theme_color_override("font_color", COL_AMBER)
	_round_label.add_theme_font_size_override("font_size", 15)
	title_vb.add_child(_round_label)

	_net_badge = Label.new()
	_net_badge.name = "NetBadge"
	_net_badge.text = "LOCAL SIM // RUST-PARITY"
	_net_badge.add_theme_color_override("font_color", COL_CYAN)
	_net_badge.add_theme_font_size_override("font_size", 11)
	title_vb.add_child(_net_badge)

	# Center Wanted Turn Order Timeline
	var turn_panel := PanelContainer.new()
	turn_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_panel.add_theme_stylebox_override("panel", _make_western_style(COL_CYAN, COL_BG_DARK, 2, 8))
	top_bar.add_child(turn_panel)
	var turn_vb := VBoxContainer.new()
	turn_vb.add_theme_constant_override("separation", 4)
	turn_panel.add_child(turn_vb)

	var turn_hdr := Label.new()
	turn_hdr.text = "HIGH-NOON TURN ORDER"
	turn_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_hdr.add_theme_color_override("font_color", COL_MUTED)
	turn_hdr.add_theme_font_size_override("font_size", 10)
	turn_vb.add_child(turn_hdr)

	_turn_strip = HBoxContainer.new()
	_turn_strip.name = "TurnOrderStrip"
	_turn_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_turn_strip.add_theme_constant_override("separation", 6)
	turn_vb.add_child(_turn_strip)

	# Right Camera Badge + Live Shader Recolor Button
	var right_vb := VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 4)
	top_bar.add_child(right_vb)

	var cam_panel := PanelContainer.new()
	cam_panel.add_theme_stylebox_override("panel", _make_western_style(COL_MAGENTA, COL_BG, 2, 6))
	right_vb.add_child(cam_panel)
	_cam_badge = Label.new()
	_cam_badge.name = "CameraBadge"
	_cam_badge.text = "CAM // ESTABLISHING SWEEP"
	_cam_badge.add_theme_color_override("font_color", COL_MAGENTA)
	_cam_badge.add_theme_font_size_override("font_size", 11)
	cam_panel.add_child(_cam_badge)

	_palette_btn = Button.new()
	_palette_btn.name = "RecolorSquadButton"
	_palette_btn.text = "[R] SHADER: SUNSET NEON"
	_palette_btn.add_theme_font_size_override("font_size", 11)
	_style_neon_button(_palette_btn, COL_CYAN)
	_palette_btn.pressed.connect(func() -> void: recolor_squad_pressed.emit())
	right_vb.add_child(_palette_btn)

	# === TOP-CENTER FRONTIER DISPATCH TICKER ===
	var dispatch_panel := PanelContainer.new()
	dispatch_panel.name = "DispatchPanel"
	dispatch_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dispatch_panel.offset_left = -320
	dispatch_panel.offset_right = 320
	dispatch_panel.offset_top = 86
	dispatch_panel.offset_bottom = 118
	dispatch_panel.add_theme_stylebox_override("panel", _make_western_style(Color(1.0, 0.72, 0.26, 0.65), Color(0.05, 0.03, 0.10, 0.78), 1, 6))
	_root.add_child(dispatch_panel)

	_dispatch_label = Label.new()
	_dispatch_label.name = "DispatchLabel"
	_dispatch_label.text = "FRONTIER AMBUSH — DRAW IRON, DRIFTERS!"
	_dispatch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dispatch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dispatch_label.add_theme_color_override("font_color", COL_TEXT)
	_dispatch_label.add_theme_font_size_override("font_size", 13)
	dispatch_panel.add_child(_dispatch_label)

	# === BOTTOM-LEFT: SALOON COMMAND DECK ===
	_command_panel = PanelContainer.new()
	_command_panel.name = "SaloonCommandDeck"
	_command_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_command_panel.offset_left = 18
	_command_panel.offset_right = 560
	_command_panel.offset_top = -238
	_command_panel.offset_bottom = -16
	_command_panel.add_theme_stylebox_override("panel", _make_western_style(COL_AMBER, COL_BG, 2, 10))
	var holo_mat := ShaderMaterial.new()
	holo_mat.shader = HOLO_SHADER
	holo_mat.set_shader_parameter("glow_color", COL_AMBER)
	_command_panel.material = holo_mat
	_root.add_child(_command_panel)

	var cmd_vb := VBoxContainer.new()
	cmd_vb.add_theme_constant_override("separation", 7)
	_command_panel.add_child(cmd_vb)

	var cmd_hdr := HBoxContainer.new()
	cmd_vb.add_child(cmd_hdr)
	_actor_header_label = Label.new()
	_actor_header_label.name = "ActiveActorHeader"
	_actor_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actor_header_label.text = "★ VEGA VANCE — HUMAN GUNSLINGER"
	_actor_header_label.add_theme_color_override("font_color", COL_AMBER)
	_actor_header_label.add_theme_font_size_override("font_size", 15)
	cmd_hdr.add_child(_actor_header_label)

	_actor_ap_label = Label.new()
	_actor_ap_label.name = "ActiveActorAP"
	_actor_ap_label.text = "AP: ◆◆◇◇"
	_actor_ap_label.add_theme_color_override("font_color", COL_CYAN)
	_actor_ap_label.add_theme_font_size_override("font_size", 14)
	cmd_hdr.add_child(_actor_ap_label)

	var skill_grid := GridContainer.new()
	skill_grid.name = "SkillGrid"
	skill_grid.columns = 2
	skill_grid.add_theme_constant_override("h_separation", 8)
	skill_grid.add_theme_constant_override("v_separation", 6)
	cmd_vb.add_child(skill_grid)

	for i in range(4):
		var btn := Button.new()
		btn.name = "SkillButton_%d" % i
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(240, 38)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)
		_style_neon_button(btn, COL_CYAN)
		skill_grid.add_child(btn)
		_skill_buttons.append(btn)

	_skill_desc_label = Label.new()
	_skill_desc_label.name = "SkillDescLabel"
	_skill_desc_label.text = "Select a frontier skill and target."
	_skill_desc_label.add_theme_color_override("font_color", COL_MUTED)
	_skill_desc_label.add_theme_font_size_override("font_size", 12)
	_skill_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cmd_vb.add_child(_skill_desc_label)

	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 8)
	cmd_vb.add_child(footer_row)

	_target_row = HBoxContainer.new()
	_target_row.name = "TargetRow"
	_target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_row.add_theme_constant_override("separation", 6)
	footer_row.add_child(_target_row)

	_fire_btn = Button.new()
	_fire_btn.name = "FireActionButton"
	_fire_btn.text = "★ DRAW [ENTER]"
	_fire_btn.custom_minimum_size = Vector2(142, 36)
	_fire_btn.add_theme_font_size_override("font_size", 13)
	_style_neon_button(_fire_btn, COL_AMBER)
	_fire_btn.pressed.connect(func() -> void: confirm_action_pressed.emit())
	footer_row.add_child(_fire_btn)

	# Enemy turn status banner (replaces command deck during enemy turns)
	_enemy_banner = PanelContainer.new()
	_enemy_banner.name = "EnemyTurnBanner"
	_enemy_banner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_enemy_banner.offset_left = 18
	_enemy_banner.offset_right = 460
	_enemy_banner.offset_top = -90
	_enemy_banner.offset_bottom = -20
	_enemy_banner.add_theme_stylebox_override("panel", _make_western_style(COL_CRIMSON, COL_BG_DARK, 2, 10))
	_enemy_banner.visible = false
	_root.add_child(_enemy_banner)

	_enemy_banner_label = Label.new()
	_enemy_banner_label.text = "OUTLAW MOVE IN PROGRESS..."
	_enemy_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enemy_banner_label.add_theme_color_override("font_color", COL_CRIMSON)
	_enemy_banner_label.add_theme_font_size_override("font_size", 15)
	_enemy_banner.add_child(_enemy_banner_label)

	# === BOTTOM-RIGHT: DRIFTER SQUAD WANTED CARDS ===
	var squad_panel := PanelContainer.new()
	squad_panel.name = "DrifterSquadPanel"
	squad_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	squad_panel.offset_left = -388
	squad_panel.offset_right = -18
	squad_panel.offset_top = -286
	squad_panel.offset_bottom = -16
	squad_panel.add_theme_stylebox_override("panel", _make_western_style(COL_CYAN, COL_BG, 2, 10))
	_root.add_child(squad_panel)

	var sq_outer := VBoxContainer.new()
	sq_outer.add_theme_constant_override("separation", 6)
	squad_panel.add_child(sq_outer)

	var sq_hdr := Label.new()
	sq_hdr.text = "DRIFTER SQUAD // ANSIBLE EXPEDITION"
	sq_hdr.add_theme_color_override("font_color", COL_CYAN)
	sq_hdr.add_theme_font_size_override("font_size", 12)
	sq_outer.add_child(sq_hdr)

	_squad_container = VBoxContainer.new()
	_squad_container.name = "SquadCardsList"
	_squad_container.add_theme_constant_override("separation", 6)
	sq_outer.add_child(_squad_container)

	# === VICTORY / DEFEAT MODAL ===
	_end_modal = PanelContainer.new()
	_end_modal.name = "BattleEndModal"
	_end_modal.set_anchors_preset(Control.PRESET_CENTER)
	_end_modal.offset_left = -240
	_end_modal.offset_right = 240
	_end_modal.offset_top = -115
	_end_modal.offset_bottom = 115
	_end_modal.add_theme_stylebox_override("panel", _make_western_style(COL_AMBER, COL_BG_DARK, 3, 12))
	_end_modal.visible = false
	_root.add_child(_end_modal)

	var end_vb := VBoxContainer.new()
	end_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	end_vb.add_theme_constant_override("separation", 12)
	_end_modal.add_child(end_vb)

	_end_title = Label.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_color_override("font_color", COL_AMBER)
	_end_title.add_theme_font_size_override("font_size", 24)
	end_vb.add_child(_end_title)

	_end_body = Label.new()
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body.add_theme_color_override("font_color", COL_TEXT)
	_end_body.add_theme_font_size_override("font_size", 14)
	end_vb.add_child(_end_body)

	var restart_btn := Button.new()
	restart_btn.name = "RestartBattleButton"
	restart_btn.text = "★ RIDE AGAIN (NEW SKIRMISH)"
	restart_btn.custom_minimum_size = Vector2(240, 40)
	_style_neon_button(restart_btn, COL_CYAN)
	restart_btn.pressed.connect(func() -> void: restart_battle_pressed.emit())
	end_vb.add_child(restart_btn)

	# Floating damage/status popups render on top of all HUD panels
	_popups_layer = Control.new()
	_popups_layer.name = "PopupsLayer"
	_popups_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popups_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_popups_layer)


func set_camera_label(label: String) -> void:
	if _cam_badge != null:
		_cam_badge.text = label


func set_network_label(label: String) -> void:
	if _net_badge != null:
		_net_badge.text = label


func set_palette_label(preset_name: String) -> void:
	if _palette_btn != null:
		_palette_btn.text = "[R] SHADER: " + preset_name.to_upper()


func set_dispatch(msg: String) -> void:
	if _dispatch_label != null:
		_dispatch_label.text = msg


func refresh_state(engine: BattleEngine, selected_skill_id: String, selected_target_id: String, input_unlocked: bool) -> void:
	_current_skill_id = selected_skill_id
	_current_target_id = selected_target_id
	_round_label.text = "★ ANSIBLE OUTPOST // ROUND %d" % int(engine.state.get("round", 1))

	# Update turn timeline strip
	for child in _turn_strip.get_children():
		child.queue_free()
	var upcoming := engine.get_upcoming_turn_ids(6)
	for i in range(upcoming.size()):
		var c := engine.get_combatant(upcoming[i])
		if c.is_empty():
			continue
		var chip := PanelContainer.new()
		var is_first := i == 0
		var col := COL_CYAN if String(c["faction"]) == "player" else COL_CRIMSON
		if is_first:
			col = COL_AMBER
		chip.add_theme_stylebox_override("panel", _make_western_style(col, Color(0.11, 0.06, 0.20, 0.95) if is_first else Color(0.06, 0.03, 0.11, 0.85), 2 if is_first else 1, 5))
		var lbl := Label.new()
		var short_name := String(c["name"]).split(" ")[0].to_upper()
		lbl.text = ("▶ " if is_first else "") + short_name
		lbl.add_theme_color_override("font_color", col if is_first else COL_TEXT)
		lbl.add_theme_font_size_override("font_size", 11)
		chip.add_child(lbl)
		_turn_strip.add_child(chip)

	# Update Drifter Squad cards
	for child in _squad_container.get_children():
		child.queue_free()
	var active_id := engine.get_active_combatant_id()
	for c in engine.state.get("combatants", []):
		if String(c["faction"]) != "player":
			continue
		_squad_container.add_child(_build_squad_card(c, String(c["id"]) == active_id))

	# Update enemy overhead plates data
	for c in engine.state.get("combatants", []):
		if String(c["faction"]) == "enemy":
			_ensure_enemy_plate(c, String(c["id"]) == selected_target_id)

	# Update Command Deck vs Enemy Banner
	var active := engine.get_combatant(active_id)
	var outcome := String(engine.state.get("outcome", "ongoing"))
	if outcome != "ongoing":
		_command_panel.visible = false
		_enemy_banner.visible = false
		return

	if active.is_empty() or String(active["faction"]) != "player" or not input_unlocked:
		_command_panel.visible = false
		_enemy_banner.visible = not active.is_empty()
		if not active.is_empty():
			if String(active["faction"]) == "enemy":
				_enemy_banner_label.text = "☠ OUTLAW TURN — %s TAKING AIM!" % String(active["name"]).to_upper()
			else:
				_enemy_banner_label.text = "★ %s EXECUTING ACTION..." % String(active["name"]).to_upper()
		return

	_command_panel.visible = true
	_enemy_banner.visible = false
	_actor_header_label.text = "★ %s — %s %s" % [
		String(active["name"]).to_upper(),
		String(active["species_label"]),
		String(active["role_label"]),
	]
	_actor_ap_label.text = "AP: " + _format_pips(int(active["ap"]), int(active["max_ap"]))

	var skills: Array = active["skills"]
	var selected_skill: Dictionary = {}
	for i in range(_skill_buttons.size()):
		var btn := _skill_buttons[i]
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])
		if i < skills.size():
			var s: Dictionary = skills[i]
			var sid := String(s["id"])
			var cost := int(s["ap_cost"])
			var affordable := int(active["ap"]) >= cost
			btn.visible = true
			btn.disabled = not affordable
			var cost_tag := "FREE" if cost == 0 else ("%d AP" % cost)
			btn.text = "[%d] %s  (%s)" % [i + 1, String(s["name"]).to_upper(), cost_tag]
			var is_sel := sid == selected_skill_id
			_style_neon_button(btn, COL_AMBER if is_sel else COL_CYAN)
			btn.pressed.connect(func() -> void: skill_selected.emit(sid))
			if is_sel:
				selected_skill = s
		else:
			btn.visible = false

	if not selected_skill.is_empty():
		_skill_desc_label.text = String(selected_skill["description"])

	# Target selector buttons
	for child in _target_row.get_children():
		child.queue_free()
	var tmode := String(selected_skill.get("target_mode", "single_enemy"))
	if tmode == "all_enemies":
		var all_lbl := Label.new()
		all_lbl.text = "TARGET: ALL OUTLAWS IN LINE-UP"
		all_lbl.add_theme_color_override("font_color", COL_MAGENTA)
		all_lbl.add_theme_font_size_override("font_size", 12)
		_target_row.add_child(all_lbl)
	elif tmode == "self_only":
		var self_lbl := Label.new()
		self_lbl.text = "TARGET: SELF (%s)" % String(active["name"]).to_upper()
		self_lbl.add_theme_color_override("font_color", COL_GREEN)
		self_lbl.add_theme_font_size_override("font_size", 12)
		_target_row.add_child(self_lbl)
	else:
		var faction := "player" if tmode == "single_ally" else "enemy"
		var candidates := engine.get_living_by_faction(faction)
		for cand in candidates:
			var cid := String(cand["id"])
			var tbtn := Button.new()
			tbtn.name = "TargetBtn_" + cid
			tbtn.text = String(cand["name"]).split(" ")[0].to_upper()
			tbtn.add_theme_font_size_override("font_size", 11)
			var is_tsel := cid == selected_target_id
			_style_neon_button(tbtn, COL_AMBER if is_tsel else (COL_GREEN if faction == "player" else COL_CRIMSON))
			tbtn.pressed.connect(func() -> void: target_selected.emit(cid))
			_target_row.add_child(tbtn)


func _build_squad_card(c: Dictionary, is_active: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var border := COL_AMBER if is_active else (COL_CYAN if bool(c["alive"]) else Color(0.35, 0.30, 0.40))
	card.add_theme_stylebox_override("panel", _make_western_style(border, Color(0.11, 0.06, 0.20, 0.94) if is_active else COL_BG_DARK, 2 if is_active else 1, 6))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	card.add_child(vb)

	var top := HBoxContainer.new()
	vb.add_child(top)
	var name_lbl := Label.new()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text = "%s%s [%s]" % [("▶ " if is_active else ""), String(c["name"]).to_upper(), String(c["species_label"])]
	name_lbl.add_theme_color_override("font_color", COL_AMBER if is_active else (COL_TEXT if bool(c["alive"]) else COL_MUTED))
	name_lbl.add_theme_font_size_override("font_size", 12)
	top.add_child(name_lbl)

	var ap_lbl := Label.new()
	ap_lbl.text = _format_pips(int(c["ap"]), int(c["max_ap"]))
	ap_lbl.add_theme_color_override("font_color", COL_CYAN)
	ap_lbl.add_theme_font_size_override("font_size", 11)
	top.add_child(ap_lbl)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	vb.add_child(hp_row)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 13)
	bar.max_value = int(c["max_hp"])
	bar.value = int(c["hp"])
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	var pct := float(c["hp"]) / maxf(1.0, float(c["max_hp"]))
	fill.bg_color = COL_GREEN if pct > 0.45 else (COL_AMBER if pct > 0.22 else COL_CRIMSON)
	fill.corner_radius_top_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.10, 0.24, 0.9)
	bar.add_theme_stylebox_override("background", bg)
	hp_row.add_child(bar)

	var hp_lbl := Label.new()
	hp_lbl.text = "%d/%d" % [int(c["hp"]), int(c["max_hp"])]
	hp_lbl.add_theme_color_override("font_color", COL_TEXT)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_row.add_child(hp_lbl)

	var st_tags := _format_statuses(c.get("statuses", []))
	if st_tags != "":
		var st_lbl := Label.new()
		st_lbl.text = st_tags
		st_lbl.add_theme_color_override("font_color", COL_MAGENTA)
		st_lbl.add_theme_font_size_override("font_size", 10)
		vb.add_child(st_lbl)
	return card


func _ensure_enemy_plate(c: Dictionary, is_targeted: bool) -> void:
	var cid := String(c["id"])
	var plate: PanelContainer
	if _enemy_plates.has(cid):
		plate = _enemy_plates[cid]
	else:
		plate = PanelContainer.new()
		plate.name = "EnemyPlate_" + cid
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_enemy_plates_layer.add_child(plate)
		_enemy_plates[cid] = plate

	plate.visible = bool(c["alive"])
	if not plate.visible:
		return

	plate.add_theme_stylebox_override("panel", _make_western_style(COL_AMBER if is_targeted else COL_CRIMSON, Color(0.08, 0.03, 0.12, 0.85), 2 if is_targeted else 1, 5))
	for child in plate.get_children():
		child.queue_free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	plate.add_child(vb)

	var lbl := Label.new()
	lbl.text = "%s%s" % [("◎ " if is_targeted else ""), String(c["name"]).to_upper()]
	lbl.add_theme_color_override("font_color", COL_AMBER if is_targeted else COL_TEXT)
	lbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(118, 9)
	bar.max_value = int(c["max_hp"])
	bar.value = int(c["hp"])
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = COL_CRIMSON
	bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(bar)

	var st_tags := _format_statuses(c.get("statuses", []))
	if st_tags != "":
		var st_lbl := Label.new()
		st_lbl.text = st_tags
		st_lbl.add_theme_color_override("font_color", COL_AMBER)
		st_lbl.add_theme_font_size_override("font_size", 10)
		vb.add_child(st_lbl)


func update_enemy_plate_positions(camera: Camera3D, actors: Dictionary) -> void:
	if camera == null:
		return
	for cid in _enemy_plates.keys():
		var plate: PanelContainer = _enemy_plates[cid]
		if not plate.visible or not actors.has(cid):
			continue
		var actor: DrifterActor3D = actors[cid]
		var world_p := actor.get_head_world_position()
		if camera.is_position_behind(world_p):
			plate.visible = false
			continue
		var screen_p := camera.unproject_position(world_p)
		plate.position = screen_p - Vector2(plate.size.x * 0.5, plate.size.y + 8.0)


func spawn_floating_popup(camera: Camera3D, world_pos: Vector3, text: String, color: Color) -> void:
	if camera == null or camera.is_position_behind(world_pos):
		return
	var screen_p := camera.unproject_position(world_pos)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08, 1.0))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.position = Vector2(clampf(screen_p.x - 46.0, 40.0, 1120.0), maxf(142.0, screen_p.y - 18.0))
	_popups_layer.add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 68.0, 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.05).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)


func show_battle_end(outcome: String, scrap: int, holo_data: int) -> void:
	_command_panel.visible = false
	_enemy_banner.visible = false
	_end_modal.visible = true
	if outcome == "victory":
		_end_title.text = "★ FRONTIER BOUNTY CLAIMED ★"
		_end_title.add_theme_color_override("font_color", COL_AMBER)
		_end_body.text = "Outlaw gang cleared! Time ticks forward at the Ansible.\nSalvage Recovered: +%d Scrap  |  +%d Holo-Data" % [scrap, holo_data]
	else:
		_end_title.text = "☠ SQUAD RETREATED TO ANSIBLE ☠"
		_end_title.add_theme_color_override("font_color", COL_CRIMSON)
		_end_body.text = "Emergency beacon engaged.\nPartial Telemetry Salvaged: +%d Scrap  |  +%d Holo-Data" % [scrap, holo_data]


func hide_battle_end() -> void:
	if _end_modal != null:
		_end_modal.visible = false


func _format_pips(cur: int, max_v: int) -> String:
	var out := ""
	for i in range(max_v):
		out += "◆" if i < cur else "◇"
	return out


func _format_statuses(statuses: Array) -> String:
	var parts: PackedStringArray = []
	for s in statuses:
		if int(s["turns_remaining"]) > 0:
			parts.append("[%s %dT]" % [String(s["kind"]).to_upper(), int(s["turns_remaining"])])
	return " ".join(parts)
