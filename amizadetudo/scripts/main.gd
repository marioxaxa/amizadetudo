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
	player_one.level_map = $TileMapLayer
	player_two.level_map = $TileMapLayer
	player_one.died.connect(_on_player_died)
	player_two.died.connect(_on_player_died)
	_assign_controllers()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(delta: float) -> void:
	var midpoint := (player_one.global_position + player_two.global_position) * 0.5
	camera.global_position = camera.global_position.lerp(midpoint, minf(delta * 5.0, 1.0))
	status.text = "P1: %s   P2: %s\nTeclado: A/D + Espaco | Setas + Enter" % [_device_name(player_one.joypad_id), _device_name(player_two.joypad_id)]


func _assign_controllers() -> void:
	var devices := Input.get_connected_joypads()
	player_one.set_joypad(devices[0] if devices.size() > 0 else -1)
	player_two.set_joypad(devices[1] if devices.size() > 1 else -1)


func _configure_input_map() -> void:
	_add_key_action("p1_left", KEY_A)
	_add_key_action("p1_right", KEY_D)
	_add_key_action("p1_jump", KEY_SPACE)
	_add_key_action("p2_left", KEY_LEFT)
	_add_key_action("p2_right", KEY_RIGHT)
	_add_key_action("p2_jump", KEY_ENTER)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_assign_controllers()


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
