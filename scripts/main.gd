extends Node2D

const TILE_SIZE := 48

@onready var player_one: CharacterBody2D = $Players/PlayerOne
@onready var player_two: CharacterBody2D = $Players/PlayerTwo
@onready var camera: Camera2D = $SharedCamera
@onready var status: Label = $CanvasLayer/Status
@onready var player_one_deaths: Label = $CanvasLayer/PlayerOneDeaths
@onready var player_two_deaths: Label = $CanvasLayer/PlayerTwoDeaths

var _death_tweens: Dictionary[int, Tween] = {}


func _ready() -> void:
	_configure_input_map()
	_set_start_positions()
	player_one.level_map = $TileMapLayer
	player_two.level_map = $TileMapLayer
	player_one.died.connect(_on_player_died)
	player_two.died.connect(_on_player_died)
	_assign_controllers()
	player_one.set_other_player(player_two)
	player_two.set_other_player(player_one)
	for level_exit in get_tree().get_nodes_in_group("level_exits"):
		level_exit.readiness_changed.connect(_on_exit_readiness_changed)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(delta: float) -> void:
	var midpoint := (player_one.global_position + player_two.global_position) * 0.5
	camera.global_position = camera.global_position.lerp(midpoint, minf(delta * 5.0, 1.0))
	status.text = "P1 [%s]: %s (A/D + Espaco + Shift)\nP2 [%s]: %s (Setas + Cima + Enter)" % [
		_polarity_name(player_one.polarity),
		_device_name(player_one.joypad_id),
		_polarity_name(player_two.polarity),
		_device_name(player_two.joypad_id)
	]


func _polarity_name(pol: int) -> String:
	return "Norte / Vermelho" if pol == 0 else "Sul / Azul"


func _assign_controllers() -> void:
	var devices := Input.get_connected_joypads()
	player_one.set_joypad(devices[0] if devices.size() > 0 else -1)
	player_two.set_joypad(devices[1] if devices.size() > 1 else -1)


func _configure_input_map() -> void:
	_add_key_action("p1_left", KEY_A)
	_add_key_action("p1_right", KEY_D)
	_add_key_action("p1_jump", KEY_SPACE)
	_add_key_action("p1_toggle_polarity", KEY_SHIFT)
	_add_key_action("p2_left", KEY_LEFT)
	_add_key_action("p2_right", KEY_RIGHT)
	_add_key_action("p2_jump", KEY_UP)
	_add_key_action("p2_toggle_polarity", KEY_ENTER)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_assign_controllers()


func _set_start_positions() -> void:
	var start_one := get_node_or_null("StartPlayerOne") as Marker2D
	var start_two := get_node_or_null("StartPlayerTwo") as Marker2D
	if start_one:
		player_one.set_spawn_point(start_one.global_position)
	if start_two:
		player_two.set_spawn_point(start_two.global_position)


func _on_exit_readiness_changed(_player_index: int, _is_ready: bool) -> void:
	var exits := get_tree().get_nodes_in_group("level_exits")
	if exits.size() != 2:
		return
	for level_exit in exits:
		if not level_exit.is_player_ready():
			return
	player_one.set_controls_enabled(false)
	player_two.set_controls_enabled(false)
	LevelManager.advance_level()


func _on_player_died(player_index: int, death_count: int) -> void:
	var label := player_one_deaths if player_index == 1 else player_two_deaths
	if _death_tweens.has(player_index):
		_death_tweens[player_index].kill()
	label.text = "P%d Mortes: %d" % [player_index, death_count]
	label.modulate.a = 1.0
	label.show()
	var tween := create_tween()
	_death_tweens[player_index] = tween
	tween.tween_interval(1.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.hide)


func _device_name(device: int) -> String:
	return Input.get_joy_name(device) if device >= 0 else "teclado"
