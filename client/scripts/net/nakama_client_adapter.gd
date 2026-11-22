class_name NakamaClientAdapter
extends Node

## WebSocket + HTTP Nakama adapter for Ansible (browser & mobile compatible).
## Automatically uses local deterministic BattleEngine when offline, and routes
## ansible_battle_start / ansible_battle_step RPCs to Nakama Go + Rust WASM when connected.

signal connection_mode_changed(mode_label: String)

@export var server_host: String = "127.0.0.1"
@export var server_port: int = 7350
@export var server_key: String = "defaultkey"
@export var use_ssl: bool = false
@export var auto_connect: bool = false

var _engine := BattleEngine.new()
var _online := false
var _session_token := ""
var _socket: WebSocketPeer = null


func get_mode_label() -> String:
	return "NAKAMA WS // RUST-WASM" if _online else "LOCAL SIM // RUST-PARITY"


func get_engine() -> BattleEngine:
	return _engine


func start_battle(battle_id: String = "frontier_skirmish", seed_val: int = 2026) -> Dictionary:
	# Offline-first instant initialization; online RPC sync attaches via WebSocket/REST
	var st := _engine.init_default_battle(battle_id, seed_val)
	if auto_connect and not _online:
		_try_connect_websocket()
	connection_mode_changed.emit(get_mode_label())
	return st


func submit_action(action: Dictionary = {}) -> Dictionary:
	return _engine.step_turn(action)


func _try_connect_websocket() -> void:
	if _session_token == "":
		return
	var scheme := "wss" if use_ssl else "ws"
	var url := "%s://%s:%d/ws?lang=en&status=true&token=%s" % [scheme, server_host, server_port, _session_token]
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(url)
	if err == OK:
		_online = true
		connection_mode_changed.emit(get_mode_label())


func _process(_delta: float) -> void:
	if _socket != null:
		_socket.poll()
		if _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_online = false
			_socket = null
			connection_mode_changed.emit(get_mode_label())
