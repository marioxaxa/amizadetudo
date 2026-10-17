extends Node2D

const TILE_SIZE := 48

@onready var player_one: CharacterBody2D = $Players/PlayerOne
@onready var player_two: CharacterBody2D = $Players/PlayerTwo
@onready var camera: Camera2D = $SharedCamera
@onready var status: Label = $CanvasLayer/Status


func _ready() -> void:
	_configure_input_map()
	_build_level()
	_assign_controllers()
	player_one.set_other_player(player_two)
	player_two.set_other_player(player_one)
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


func _device_name(device: int) -> String:
	return Input.get_joy_name(device) if device >= 0 else "teclado"


func _build_level() -> void:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color("28354f"))
	for x in range(TILE_SIZE):
		for y in range(6):
			image.set_pixel(x, y, Color("55d6ff"))
	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i.ZERO)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.add_source(source, 0)
	var tile_data := source.get_tile_data(Vector2i.ZERO, 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(0, 0), Vector2(TILE_SIZE, 0), Vector2(TILE_SIZE, TILE_SIZE), Vector2(0, TILE_SIZE)]))
	$TileMapLayer.tile_set = tile_set

	for x in range(-8, 48):
		_set_tile(x, 11)
	for x in range(4, 8):
		_set_tile(x, 8)
	for x in range(12, 17):
		_set_tile(x, 7)
	for x in range(22, 26):
		_set_tile(x, 9)
	for x in range(31, 38):
		_set_tile(x, 6)


func _set_tile(x: int, y: int) -> void:
	$TileMapLayer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
