class_name DrifterActor3D
extends Node3D

## Procedural low-poly 3D character mesh builder & animator for Ansible Drifters and Outlaws.
## Uses vertex-color channels (R=primary, G=accent, B=skin/chitin, A=emissive) driven by
## res://shaders/drifter_recolor.gdshader so every model is live-recolorable on WebGL2.

const RECOLOR_SHADER: Shader = preload("res://shaders/drifter_recolor.gdshader")

const CH_PRIMARY := Color(1.0, 0.0, 0.0, 0.0)
const CH_ACCENT := Color(0.0, 1.0, 0.0, 0.0)
const CH_SKIN := Color(0.0, 0.0, 1.0, 0.0)
const CH_EMISSIVE := Color(0.0, 0.0, 0.0, 1.0)
const CH_TRIM_GLOW := Color(0.0, 0.65, 0.0, 0.75)

var combatant_id: String = ""
var species: String = "human"
var is_player: bool = true
var home_position: Vector3 = Vector3.ZERO
var is_alive: bool = true

var _rig_root: Node3D
var _mesh_instance: MeshInstance3D
var _shader_mat: ShaderMaterial
var _turn_ring: MeshInstance3D
var _target_reticle: Node3D
var _guard_dome: MeshInstance3D
var _muzzle_point: Marker3D

var _anim_time: float = 0.0
var _hit_flash_timer: float = 0.0
var _recoil_offset: Vector3 = Vector3.ZERO
var _lunge_offset: Vector3 = Vector3.ZERO
var _is_active_turn: bool = false
var _is_targeted: bool = false
var _is_guarding: bool = false
var _death_tilt: float = 0.0


func setup(data: Dictionary, palette: Dictionary, world_pos: Vector3) -> void:
	combatant_id = String(data["id"])
	species = String(data["species"])
	is_player = String(data["faction"]) == "player"
	home_position = world_pos
	global_position = world_pos
	name = "Actor_" + combatant_id

	_rig_root = Node3D.new()
	_rig_root.name = "RigRoot"
	add_child(_rig_root)

	# Face across the arena (+X for players, -X for enemies)
	_rig_root.rotation.y = PI * 0.5 if is_player else -PI * 0.5

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = RECOLOR_SHADER
	apply_palette(palette)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "LowPolyBody"
	_mesh_instance.mesh = _build_species_mesh(species, combatant_id)
	_mesh_instance.material_override = _shader_mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_rig_root.add_child(_mesh_instance)

	_muzzle_point = Marker3D.new()
	_muzzle_point.position = Vector3(0.0, 1.25, 0.78)
	_rig_root.add_child(_muzzle_point)

	_build_ground_indicators()
	_anim_time = float(int(data["slot_index"])) * 1.15


func apply_palette(palette: Dictionary) -> void:
	if _shader_mat == null:
		return
	_shader_mat.set_shader_parameter("primary_color", palette["primary"])
	_shader_mat.set_shader_parameter("accent_color", palette["accent"])
	_shader_mat.set_shader_parameter("skin_color", palette["skin"])
	_shader_mat.set_shader_parameter("emissive_color", palette["emissive"])
	_shader_mat.set_shader_parameter("rim_color", palette["emissive"])


func get_muzzle_world_position() -> Vector3:
	return _muzzle_point.global_position if _muzzle_point != null else global_position + Vector3(0.0, 1.3, 0.0)


func get_head_world_position() -> Vector3:
	return global_position + Vector3(0.0, 2.35, 0.0)


func set_active_turn(active: bool) -> void:
	_is_active_turn = active
	if _turn_ring != null:
		_turn_ring.visible = active and is_alive
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("rim_amount", 0.75 if active else 0.25)


func set_targeted(targeted: bool) -> void:
	_is_targeted = targeted
	if _target_reticle != null:
		_target_reticle.visible = targeted and is_alive


func set_guarding(guarding: bool) -> void:
	_is_guarding = guarding
	if _guard_dome != null:
		_guard_dome.visible = guarding and is_alive


func play_attack_lunge() -> void:
	var dir := Vector3(1.0, 0.0, 0.0) if is_player else Vector3(-1.0, 0.0, 0.0)
	_lunge_offset = dir * 1.15


func play_hit_recoil(is_crit: bool = false) -> void:
	_hit_flash_timer = 0.26 if is_crit else 0.16
	var back := Vector3(-1.0, 0.0, 0.0) if is_player else Vector3(1.0, 0.0, 0.0)
	_recoil_offset = back * (0.75 if is_crit else 0.42) + Vector3(0.0, 0.14, 0.0)
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("hit_flash_color", Color(1.0, 0.85, 0.25) if is_crit else Color(1.0, 0.92, 0.92))


func set_defeated() -> void:
	is_alive = false
	set_active_turn(false)
	set_targeted(false)
	set_guarding(false)


func _process(delta: float) -> void:
	_anim_time += delta

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		if _shader_mat != null:
			_shader_mat.set_shader_parameter("hit_flash", clampf(_hit_flash_timer / 0.18, 0.0, 1.0))

	_lunge_offset = _lunge_offset.lerp(Vector3.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	_recoil_offset = _recoil_offset.lerp(Vector3.ZERO, clampf(delta * 8.5, 0.0, 1.0))

	if is_alive:
		var bob := sin(_anim_time * 3.1) * 0.055
		var sway := sin(_anim_time * 1.8) * 0.03
		global_position = home_position + _lunge_offset + _recoil_offset + Vector3(0.0, bob, 0.0)
		if _rig_root != null:
			_rig_root.rotation.z = sway
			_rig_root.rotation.x = 0.0
	else:
		_death_tilt = lerpf(_death_tilt, 1.48, clampf(delta * 5.0, 0.0, 1.0))
		global_position = home_position + Vector3(0.0, -0.58 * (_death_tilt / 1.48), 0.0)
		if _rig_root != null:
			_rig_root.rotation.x = -_death_tilt

	if _turn_ring != null and _turn_ring.visible:
		_turn_ring.rotation.y += delta * 1.8
		var s := 1.0 + sin(_anim_time * 5.0) * 0.07
		_turn_ring.scale = Vector3(s, 1.0, s)

	if _target_reticle != null and _target_reticle.visible:
		_target_reticle.rotation.y -= delta * 2.8
		_target_reticle.position.y = 1.35 + sin(_anim_time * 5.5) * 0.10


func _build_ground_indicators() -> void:
	# Glowing neon ground ring for active combatant
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.88
	torus.rings = 16
	torus.ring_segments = 8
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.22, 0.96, 1.0) if is_player else Color(1.0, 0.24, 0.45)
	_turn_ring = MeshInstance3D.new()
	_turn_ring.mesh = torus
	_turn_ring.material_override = ring_mat
	_turn_ring.position = Vector3(0.0, 0.05, 0.0)
	_turn_ring.visible = false
	add_child(_turn_ring)

	# Spinning western bounty crosshairs reticle for targeted enemy
	_target_reticle = Node3D.new()
	_target_reticle.position = Vector3(0.0, 1.35, 0.0)
	_target_reticle.visible = false
	add_child(_target_reticle)

	var ret_mat := StandardMaterial3D.new()
	ret_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ret_mat.albedo_color = Color(1.0, 0.72, 0.20)
	var ret_ring := MeshInstance3D.new()
	var r_mesh := TorusMesh.new()
	r_mesh.inner_radius = 0.82
	r_mesh.outer_radius = 0.92
	r_mesh.rings = 12
	r_mesh.ring_segments = 6
	ret_ring.mesh = r_mesh
	ret_ring.material_override = ret_mat
	ret_ring.rotation.x = PI * 0.5
	_target_reticle.add_child(ret_ring)

	for i in range(4):
		var prong := MeshInstance3D.new()
		var pbox := BoxMesh.new()
		pbox.size = Vector3(0.08, 0.34, 0.08)
		prong.mesh = pbox
		prong.material_override = ret_mat
		var a := float(i) * PI * 0.5
		prong.position = Vector3(cos(a) * 0.98, sin(a) * 0.98, 0.0)
		prong.rotation.z = a + PI * 0.5
		_target_reticle.add_child(prong)

	# Translucent cyan holo-shield dome when Guarding
	var dome := SphereMesh.new()
	dome.radius = 1.05
	dome.height = 2.1
	dome.radial_segments = 12
	dome.rings = 6
	var dome_mat := StandardMaterial3D.new()
	dome_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dome_mat.albedo_color = Color(0.22, 0.96, 1.0, 0.22)
	dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_guard_dome = MeshInstance3D.new()
	_guard_dome.mesh = dome
	_guard_dome.material_override = dome_mat
	_guard_dome.position = Vector3(0.0, 1.1, 0.0)
	_guard_dome.visible = false
	add_child(_guard_dome)


# ============================================================================
# Low-Poly Procedural Geometry Helpers (SurfaceTool with 4-channel mask colors)
# ============================================================================

func _add_box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color, rot_euler: Vector3 = Vector3.ZERO) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_append_primitive(st, bm, center, col, rot_euler)


func _add_cyl(st: SurfaceTool, center: Vector3, top_r: float, bot_r: float, h: float, segs: int, col: Color, rot_euler: Vector3 = Vector3.ZERO) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	_append_primitive(st, cm, center, col, rot_euler)


func _append_primitive(st: SurfaceTool, prim: PrimitiveMesh, center: Vector3, col: Color, rot_euler: Vector3) -> void:
	var arrays := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis := Basis.from_euler(rot_euler)

	st.set_color(col)
	for idx in indices:
		var n := (basis * norms[idx]).normalized()
		var v := basis * verts[idx] + center
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(v)


func _build_species_mesh(sp: String, cid: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	if sp == "outlaw_bot":
		# Scrap-Hound MK4: angular quadruped robo-hound with thermal jaw & mono-eye
		_add_box(st, Vector3(0.0, 0.78, 0.0), Vector3(0.68, 0.46, 1.25), CH_PRIMARY)
		_add_box(st, Vector3(0.0, 1.05, 0.15), Vector3(0.50, 0.18, 0.65), CH_ACCENT)
		# Head + glowing furnace jaw
		_add_box(st, Vector3(0.0, 0.96, 0.78), Vector3(0.46, 0.36, 0.52), CH_SKIN)
		_add_box(st, Vector3(0.0, 1.04, 1.04), Vector3(0.32, 0.11, 0.08), CH_EMISSIVE)
		_add_box(st, Vector3(0.0, 0.80, 0.96), Vector3(0.34, 0.12, 0.24), CH_EMISSIVE)
		# 4 mechanical legs
		for sx in [-0.30, 0.30]:
			for sz in [-0.46, 0.44]:
				_add_box(st, Vector3(sx, 0.38, sz), Vector3(0.16, 0.74, 0.18), CH_SKIN, Vector3(0.15 if sz > 0 else -0.15, 0.0, 0.0))
				_add_box(st, Vector3(sx, 0.08, sz + (0.06 if sz > 0 else -0.06)), Vector3(0.20, 0.14, 0.24), CH_ACCENT)
		# Rear thruster fin
		_add_box(st, Vector3(0.0, 1.06, -0.58), Vector3(0.12, 0.42, 0.28), CH_TRIM_GLOW, Vector3(-0.35, 0.0, 0.0))
		return st.commit()

	# Humanoid / Alien Frontier Drifter base anatomy
	var height_scale: float = 1.0
	var shoulder_w: float = 0.72
	if sp == "chitinoid":
		height_scale = 1.12
		shoulder_w = 0.96
	elif sp == "vexari":
		height_scale = 1.08
		shoulder_w = 0.62
	elif cid == "enemy_baron":
		height_scale = 1.15
		shoulder_w = 0.92

	# Boots & legs
	_add_box(st, Vector3(-0.18, 0.42, 0.0), Vector3(0.20, 0.82, 0.22), CH_SKIN)
	_add_box(st, Vector3(0.18, 0.42, 0.0), Vector3(0.20, 0.82, 0.22), CH_SKIN)
	_add_box(st, Vector3(-0.18, 0.10, 0.05), Vector3(0.22, 0.20, 0.32), CH_ACCENT)
	_add_box(st, Vector3(0.18, 0.10, 0.05), Vector3(0.22, 0.20, 0.32), CH_ACCENT)

	# Futuristic cowboy poncho / flowing duster coat
	_add_cyl(st, Vector3(0.0, 0.98 * height_scale, 0.0), 0.34 * (shoulder_w / 0.72), 0.56 * (shoulder_w / 0.72), 0.92 * height_scale, 6, CH_PRIMARY)
	# Neon poncho hem trim & belt buckle
	_add_cyl(st, Vector3(0.0, 0.58 * height_scale, 0.0), 0.54 * (shoulder_w / 0.72), 0.57 * (shoulder_w / 0.72), 0.10, 6, CH_TRIM_GLOW)
	_add_box(st, Vector3(0.0, 0.92 * height_scale, 0.28), Vector3(0.26, 0.14, 0.14), CH_EMISSIVE)

	# Shoulders & arms
	_add_box(st, Vector3(0.0, 1.38 * height_scale, 0.0), Vector3(shoulder_w, 0.26, 0.36), CH_PRIMARY)
	if sp == "chitinoid" or cid == "enemy_baron":
		# Broad armored pauldrons
		_add_box(st, Vector3(-shoulder_w * 0.52, 1.44 * height_scale, 0.0), Vector3(0.26, 0.30, 0.42), CH_ACCENT, Vector3(0.0, 0.0, 0.28))
		_add_box(st, Vector3(shoulder_w * 0.52, 1.44 * height_scale, 0.0), Vector3(0.26, 0.30, 0.42), CH_ACCENT, Vector3(0.0, 0.0, -0.28))

	# Aiming right arm + left bracing arm
	_add_box(st, Vector3(-shoulder_w * 0.48, 1.16 * height_scale, 0.24), Vector3(0.18, 0.22, 0.54), CH_PRIMARY, Vector3(-0.18, 0.0, 0.0))
	_add_box(st, Vector3(shoulder_w * 0.48, 1.12 * height_scale, 0.12), Vector3(0.18, 0.42, 0.20), CH_PRIMARY, Vector3(-0.35, 0.0, 0.0))

	# Head & Species Silhouette
	var head_y := 1.72 * height_scale
	if sp == "vexari":
		# Tall sleek alien cranium + glowing dual bioluminescent antennae + neon bandana
		_add_cyl(st, Vector3(0.0, head_y + 0.04, 0.0), 0.16, 0.20, 0.44, 6, CH_SKIN)
		_add_box(st, Vector3(0.0, head_y + 0.04, 0.18), Vector3(0.26, 0.09, 0.08), CH_EMISSIVE)
		_add_cyl(st, Vector3(-0.12, head_y + 0.40, -0.04), 0.02, 0.05, 0.42, 5, CH_EMISSIVE, Vector3(-0.28, 0.0, 0.25))
		_add_cyl(st, Vector3(0.12, head_y + 0.40, -0.04), 0.02, 0.05, 0.42, 5, CH_EMISSIVE, Vector3(-0.28, 0.0, -0.25))
		# Wide futuristic flat-brim ranger disc hat hovering slightly behind antennae
		_add_cyl(st, Vector3(0.0, head_y + 0.18, -0.02), 0.52, 0.56, 0.06, 8, CH_PRIMARY)
		_add_cyl(st, Vector3(0.0, head_y + 0.22, -0.02), 0.26, 0.30, 0.12, 8, CH_TRIM_GLOW)
	elif sp == "chitinoid":
		# Armored beetle-mandible helmet + ranger brim + glowing triple-eye visor
		_add_box(st, Vector3(0.0, head_y, 0.02), Vector3(0.40, 0.38, 0.42), CH_SKIN)
		_add_box(st, Vector3(0.0, head_y + 0.03, 0.24), Vector3(0.32, 0.10, 0.06), CH_EMISSIVE)
		_add_box(st, Vector3(-0.18, head_y + 0.26, -0.08), Vector3(0.08, 0.30, 0.12), CH_ACCENT, Vector3(-0.35, 0.0, 0.32))
		_add_box(st, Vector3(0.18, head_y + 0.26, -0.08), Vector3(0.08, 0.30, 0.12), CH_ACCENT, Vector3(-0.35, 0.0, -0.32))
		# Wide cowboy hat resting over horns
		_add_cyl(st, Vector3(0.0, head_y + 0.18, 0.0), 0.58, 0.62, 0.06, 8, CH_PRIMARY)
		_add_cyl(st, Vector3(0.0, head_y + 0.30, 0.0), 0.26, 0.32, 0.22, 7, CH_PRIMARY)
		_add_cyl(st, Vector3(0.0, head_y + 0.22, 0.0), 0.33, 0.34, 0.06, 7, CH_EMISSIVE)
	else:
		# Classic Human / Void-Raider Frontier Cowboy silhouette!
		_add_box(st, Vector3(0.0, head_y, 0.0), Vector3(0.32, 0.34, 0.34), CH_SKIN)
		# Neon holo-visor / bandana
		_add_box(st, Vector3(0.0, head_y + 0.04, 0.17), Vector3(0.30, 0.09, 0.06), CH_EMISSIVE)
		_add_box(st, Vector3(0.0, head_y - 0.12, 0.14), Vector3(0.34, 0.14, 0.16), CH_ACCENT)
		# Iconic wide-brim neon-banded Stetson hat!
		var brim_r := 0.64 if cid == "enemy_baron" else 0.56
		_add_cyl(st, Vector3(0.0, head_y + 0.18, 0.0), brim_r, brim_r + 0.04, 0.06, 8, CH_PRIMARY)
		_add_cyl(st, Vector3(0.0, head_y + 0.34, 0.0), 0.24, 0.30, 0.28, 7, CH_PRIMARY)
		_add_cyl(st, Vector3(0.0, head_y + 0.23, 0.0), 0.31, 0.32, 0.07, 7, CH_EMISSIVE)

	# Weapon silhouette per role
	if sp == "vexari":
		# Glowing Holo-Lasso Relay Staff
		_add_cyl(st, Vector3(-0.34, 1.15 * height_scale, 0.42), 0.04, 0.04, 1.85, 6, CH_ACCENT, Vector3(0.22, 0.0, 0.0))
		_add_cyl(st, Vector3(-0.34, 2.02 * height_scale, 0.60), 0.18, 0.06, 0.28, 6, CH_EMISSIVE)
	elif sp == "chitinoid" or cid == "enemy_baron":
		# Heavy Plasma Coach-Gun / Void Carbine
		_add_box(st, Vector3(-shoulder_w * 0.46, 1.16 * height_scale, 0.68), Vector3(0.16, 0.20, 0.96), CH_ACCENT)
		_add_box(st, Vector3(-shoulder_w * 0.46, 1.22 * height_scale, 1.05), Vector3(0.12, 0.10, 0.32), CH_EMISSIVE)
	else:
		# Twin Neon-Barrel Plasma Revolvers
		_add_box(st, Vector3(-0.34, 1.18 * height_scale, 0.62), Vector3(0.10, 0.16, 0.46), CH_ACCENT)
		_add_box(st, Vector3(-0.34, 1.21 * height_scale, 0.80), Vector3(0.08, 0.08, 0.22), CH_EMISSIVE)
		_add_box(st, Vector3(0.36, 1.05 * height_scale, 0.32), Vector3(0.10, 0.16, 0.38), CH_ACCENT)
		_add_box(st, Vector3(0.36, 1.08 * height_scale, 0.48), Vector3(0.08, 0.08, 0.16), CH_EMISSIVE)

	return st.commit()
