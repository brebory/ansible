class_name BattleCameraRig
extends Node3D

## PlayStation-era Final Fantasy cinematic battle camera rig.
## Supports smooth crane sweeps, dramatic hard cuts, Dutch-angle close-ups,
## over-the-shoulder command framing, impact shake, and victory orbits.

signal camera_mode_changed(mode_label: String)

enum Mode {
	ESTABLISHING_SWEEP,
	IDLE_ORBIT,
	COMMAND_OVER_SHOULDER,
	TARGET_LOCK,
	ACTION_CUTIN,
	IMPACT_FOCUS,
	VICTORY_ORBIT,
}

var camera: Camera3D
var current_mode: Mode = Mode.ESTABLISHING_SWEEP

var _desired_pos := Vector3(0.0, 5.2, 11.5)
var _desired_look := Vector3(0.0, 1.3, 0.0)
var _desired_fov: float = 48.0
var _desired_roll_deg: float = 0.0

var _current_look := Vector3(0.0, 1.3, 0.0)
var _current_roll_deg: float = 0.0
var _lerp_speed: float = 4.5
var _mode_time: float = 0.0

var _focus_actor_pos := Vector3(-4.2, 1.2, 0.0)
var _focus_target_pos := Vector3(4.2, 1.2, 0.0)
var _focus_actor_is_player := true

var _shake_intensity: float = 0.0
var _shake_decay: float = 4.2
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 9001
	camera = Camera3D.new()
	camera.name = "BattleCamera3D"
	camera.current = true
	camera.fov = 50.0
	camera.near = 0.1
	camera.far = 260.0
	add_child(camera)
	set_mode_establishing()


func get_mode_label() -> String:
	match current_mode:
		Mode.ESTABLISHING_SWEEP:
			return "CAM // ESTABLISHING SWEEP"
		Mode.IDLE_ORBIT:
			return "CAM // FRONTIER DRIFT"
		Mode.COMMAND_OVER_SHOULDER:
			return "CAM // HIGH-NOON SHOULDER"
		Mode.TARGET_LOCK:
			return "CAM // DEADEYE LOCK"
		Mode.ACTION_CUTIN:
			return "CAM // PS1 ACTION CUT-IN"
		Mode.IMPACT_FOCUS:
			return "CAM // IMPACT ANGLE"
		Mode.VICTORY_ORBIT:
			return "CAM // VICTORY SWEEP"
	return "CAM // LIVE"


func set_mode_establishing() -> void:
	current_mode = Mode.ESTABLISHING_SWEEP
	_mode_time = 0.0
	_lerp_speed = 3.2
	_desired_roll_deg = -2.5
	_desired_fov = 50.0
	camera.global_position = Vector3(-9.5, 6.8, 12.2)
	_current_look = Vector3(0.6, 1.2, 0.0)
	camera_mode_changed.emit(get_mode_label())


func set_mode_idle_orbit() -> void:
	current_mode = Mode.IDLE_ORBIT
	_mode_time = 0.0
	_lerp_speed = 2.8
	_desired_roll_deg = 0.0
	_desired_fov = 46.0
	camera_mode_changed.emit(get_mode_label())


func set_mode_command_over_shoulder(actor_pos: Vector3, enemy_center: Vector3) -> void:
	current_mode = Mode.COMMAND_OVER_SHOULDER
	_mode_time = 0.0
	_focus_actor_pos = actor_pos
	_focus_target_pos = enemy_center
	_focus_actor_is_player = true
	_lerp_speed = 5.2
	_desired_fov = 45.0
	_desired_roll_deg = -1.8

	# Classic FF7/FF8 low over-the-shoulder framing behind active drifter toward enemy line-up
	var side_z: float = 2.45 if actor_pos.z >= 0.0 else -2.45
	_desired_pos = actor_pos + Vector3(-3.8, 2.05, side_z)
	_desired_look = enemy_center.lerp(actor_pos + Vector3(2.2, 1.35, 0.0), 0.25)
	camera_mode_changed.emit(get_mode_label())


func set_mode_target_lock(actor_pos: Vector3, target_pos: Vector3) -> void:
	current_mode = Mode.TARGET_LOCK
	_mode_time = 0.0
	_focus_actor_pos = actor_pos
	_focus_target_pos = target_pos
	_lerp_speed = 6.0
	_desired_fov = 41.0
	_desired_roll_deg = -2.4

	var dir := (target_pos - actor_pos).normalized()
	var side := Vector3(-dir.z, 0.0, dir.x) * 2.1
	_desired_pos = actor_pos - dir * 3.4 + side + Vector3(0.0, 1.9, 0.0)
	_desired_look = target_pos + Vector3(0.0, 1.25, 0.0)
	camera_mode_changed.emit(get_mode_label())


func set_mode_action_cutin(actor_pos: Vector3, target_pos: Vector3, is_player: bool) -> void:
	current_mode = Mode.ACTION_CUTIN
	_mode_time = 0.0
	_focus_actor_pos = actor_pos
	_focus_target_pos = target_pos
	_focus_actor_is_player = is_player
	_lerp_speed = 9.0
	_desired_fov = 34.0
	_desired_roll_deg = -6.5 if is_player else 6.5

	# Hard dramatic PS1-era close-up cut-in looking slightly up at the shooter's hat/visor
	var front_x: float = 2.55 if is_player else -2.55
	var side_z: float = 1.65 if is_player else -1.65
	var cut_pos := actor_pos + Vector3(front_x, 1.35, side_z)
	var cut_look := actor_pos + Vector3(0.0, 1.48, 0.0)
	_desired_pos = cut_pos
	_desired_look = cut_look

	# Instant PS1 hard cut for maximum cinematic punch!
	camera.global_position = cut_pos
	_current_look = cut_look
	camera.fov = 37.0
	camera_mode_changed.emit(get_mode_label())


func set_mode_impact_focus(target_pos: Vector3, attacker_pos: Vector3) -> void:
	current_mode = Mode.IMPACT_FOCUS
	_mode_time = 0.0
	_focus_target_pos = target_pos
	_focus_actor_pos = attacker_pos
	_lerp_speed = 8.5
	_desired_fov = 40.0
	_desired_roll_deg = 4.2

	var from_dir := (attacker_pos - target_pos).normalized()
	var side := Vector3(-from_dir.z, 0.0, from_dir.x) * 2.6
	_desired_pos = target_pos + from_dir * 3.8 + side + Vector3(0.0, 1.85, 0.0)
	_desired_look = target_pos + Vector3(0.0, 1.25, 0.0)
	camera_mode_changed.emit(get_mode_label())


func set_mode_victory_orbit(squad_center: Vector3) -> void:
	current_mode = Mode.VICTORY_ORBIT
	_mode_time = 0.0
	_focus_actor_pos = squad_center
	_lerp_speed = 3.8
	_desired_fov = 44.0
	_desired_roll_deg = -2.0
	camera_mode_changed.emit(get_mode_label())


func trigger_shake(intensity: float = 0.35) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)


func _process(delta: float) -> void:
	_mode_time += delta

	match current_mode:
		Mode.ESTABLISHING_SWEEP:
			var t := clampf(_mode_time / 2.2, 0.0, 1.0)
			var ease_t := 1.0 - pow(1.0 - t, 3.0)
			_desired_pos = Vector3(
				lerpf(-9.0, 0.8, ease_t),
				lerpf(6.2, 3.2, ease_t),
				lerpf(11.6, 8.8, ease_t)
			)
			_desired_look = Vector3(lerpf(0.8, 0.0, ease_t), 1.35, 0.0)
			_desired_roll_deg = lerpf(-3.0, 0.0, ease_t)
		Mode.IDLE_ORBIT:
			var angle := _mode_time * 0.24
			_desired_pos = Vector3(sin(angle) * 4.2, 3.3 + sin(_mode_time * 0.5) * 0.25, 9.2 + cos(angle) * 1.4)
			_desired_look = Vector3(0.0, 1.35, 0.0)
		Mode.COMMAND_OVER_SHOULDER:
			# Subtle handheld breathing drift
			var sway := sin(_mode_time * 1.3) * 0.16
			_desired_pos.y = _focus_actor_pos.y + 2.05 + sin(_mode_time * 0.9) * 0.08
			_desired_look.z = _focus_target_pos.z + sway
		Mode.ACTION_CUTIN:
			# Slow dramatic dolly-in during close-up
			var pull := minf(_mode_time * 0.55, 0.45)
			var front_x: float = (2.55 - pull) if _focus_actor_is_player else (-2.55 + pull)
			var side_z: float = 1.65 if _focus_actor_is_player else -1.65
			_desired_pos = _focus_actor_pos + Vector3(front_x, 1.35 + pull * 0.15, side_z)
			_desired_look = _focus_actor_pos + Vector3(0.0, 1.50, 0.0)
		Mode.VICTORY_ORBIT:
			var a := _mode_time * 0.72 + 0.55
			_desired_pos = _focus_actor_pos + Vector3(cos(a) * 5.2, 1.9 + sin(a * 0.6) * 0.3, sin(a) * 5.2)
			_desired_look = _focus_actor_pos + Vector3(0.0, 1.35, 0.0)

	var weight := clampf(delta * _lerp_speed, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(_desired_pos, weight)
	_current_look = _current_look.lerp(_desired_look, weight)
	camera.fov = lerpf(camera.fov, _desired_fov, weight)
	_current_roll_deg = lerpf(_current_roll_deg, _desired_roll_deg, weight)

	var shake_offset := Vector3.ZERO
	if _shake_intensity > 0.005:
		shake_offset = Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-0.5, 0.5)
		) * _shake_intensity
		_shake_intensity = maxf(0.0, _shake_intensity - delta * _shake_decay)

	var final_pos := camera.global_position + shake_offset
	if final_pos.distance_squared_to(_current_look) > 0.001:
		camera.look_at_from_position(final_pos, _current_look, Vector3.UP)
		camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(_current_roll_deg))
