extends CharacterBody2D

enum Polarity {
	NORTH,
	SOUTH
}

@export var player_index := 1
@export var player_color := Color("55d6ff")
@export var polarity: Polarity = Polarity.NORTH
@export var aura_radius := 60.0
@export var polarity_cooldown := 1.0
@export var magnetic_strength := 4000.0
@export var max_speed := 300.0
@export var acceleration := 2200.0
@export var deceleration := 2600.0
@export var jump_velocity := -540.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12
@export var respawn_delay := 2.0

const GRAVITY := 1500.0

var joypad_id := -1
var level_map: TileMapLayer
var other_player: CharacterBody2D = null
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jump_was_held := false
var _is_dead := false
var _spawn_position := Vector2.ZERO
var _cooldown_timer := 0.0
var _toggle_was_held := false
var _controls_enabled := true

@onready var visual: Polygon2D = get_node_or_null("Visual")
@onready var nameplate: Label = get_node_or_null("Nameplate")

signal died(player: int, death_count: int)


func _ready() -> void:
	if visual:
		visual.color = player_color
	if nameplate:
		nameplate.text = "P%d" % player_index
	_spawn_position = global_position
	queue_redraw()


func set_joypad(device_id: int) -> void:
	joypad_id = device_id


func set_spawn_point(spawn_position: Vector2) -> void:
	_spawn_position = spawn_position
	global_position = spawn_position


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _is_dead or not _controls_enabled:
		return
	var was_on_floor := is_on_floor()
	if was_on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y += GRAVITY * delta

	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	var toggle_held := _is_toggle_held()
	if toggle_held and not _toggle_was_held:
		toggle_polarity()
	_toggle_was_held = toggle_held

	var input_direction := _get_movement_input()
	var target_speed := input_direction * max_speed
	var rate := acceleration if not is_zero_approx(input_direction) else deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

	var jump_held := _is_jump_held()
	if jump_held and not _jump_was_held:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_jump_was_held = jump_held

	if _jump_buffer_timer > 0.0 and (was_on_floor or _coyote_timer > 0.0):
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_play_jump_tween()

	if not is_instance_valid(other_player) and is_inside_tree():
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child is CharacterBody2D and child != self:
					other_player = child
					break

	if is_instance_valid(other_player):
		var magnet_force := calculate_magnetic_force(other_player)
		velocity += magnet_force * delta

	if is_inside_tree():
		move_and_slide()
	_check_hazard()


func _check_hazard() -> void:
	if level_map == null:
		return
	for offset_x in [-12.0, 0.0, 12.0]:
		var map_position := level_map.local_to_map(level_map.to_local(global_position + Vector2(offset_x, 18.0)))
		var tile_data := level_map.get_cell_tile_data(map_position)
		if tile_data != null and tile_data.get_custom_data("hazard") == true:
			die()
			return


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector2.ZERO
	visible = false
	var save_manager := get_node_or_null("/root/SaveManager")
	var death_count: int = save_manager.register_death(player_index) if save_manager != null else 0
	died.emit(player_index, death_count)
	await get_tree().create_timer(respawn_delay).timeout
	global_position = _spawn_position
	velocity = Vector2.ZERO
	visible = true
	_is_dead = false


func _get_movement_input() -> float:
	var left_action := "p1_left" if player_index == 1 else "p2_left"
	var right_action := "p1_right" if player_index == 1 else "p2_right"
	var keyboard_input := Input.get_axis(left_action, right_action)
	var controller_input := 0.0
	if joypad_id >= 0 and Input.get_connected_joypads().has(joypad_id):
		controller_input = Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X)
	return controller_input if absf(controller_input) > absf(keyboard_input) else keyboard_input


func _is_jump_held() -> bool:
	var action := "p1_jump" if player_index == 1 else "p2_jump"
	var controller_jump := joypad_id >= 0 and Input.get_connected_joypads().has(joypad_id) and Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_A)
	return Input.is_action_pressed(action) or controller_jump


func _play_jump_tween() -> void:
	if not visual:
		return
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(0.78, 1.22), 0.08)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func toggle_polarity() -> bool:
	if _cooldown_timer > 0.0:
		return false
	polarity = Polarity.SOUTH if polarity == Polarity.NORTH else Polarity.NORTH
	_cooldown_timer = polarity_cooldown
	queue_redraw()
	return true


func _is_toggle_held() -> bool:
	var action := "p1_toggle_polarity" if player_index == 1 else "p2_toggle_polarity"
	var controller_toggle := joypad_id >= 0 and Input.get_connected_joypads().has(joypad_id) and (Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_X) or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_B))
	return Input.is_action_pressed(action) or controller_toggle


func set_other_player(other: CharacterBody2D) -> void:
	other_player = other


func calculate_magnetic_force(other: Node2D) -> Vector2:
	if not is_instance_valid(other):
		return Vector2.ZERO
	var other_aura_radius: float = other.get("aura_radius") if other.get("aura_radius") != null else aura_radius
	var max_dist := aura_radius + other_aura_radius
	var diff := other.global_position - global_position
	var dist := diff.length()
	if dist <= 0.001 or dist >= max_dist:
		return Vector2.ZERO
	
	var dir := diff / dist
	var other_pol = other.get("polarity")
	if other_pol == null:
		return Vector2.ZERO
	
	var is_repelling: bool = (polarity == other_pol)
	var force_dir: Vector2 = -dir if is_repelling else dir
	
	var proximity := 1.0 - (dist / max_dist)
	var magnitude := magnetic_strength * (0.35 + 0.65 * proximity)
	return force_dir * magnitude


func get_aura_color() -> Color:
	return Color("ff3b30") if polarity == Polarity.NORTH else Color("0a84ff")


func _draw() -> void:
	var base_color := get_aura_color()
	var fill_color := Color(base_color.r, base_color.g, base_color.b, 0.16)
	var ring_color := Color(base_color.r, base_color.g, base_color.b, 0.75)
	
	draw_circle(Vector2.ZERO, aura_radius, fill_color)
	draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 64, ring_color, 2.5, true)
	
	var inner_ring := Color(base_color.r, base_color.g, base_color.b, 0.28)
	draw_arc(Vector2.ZERO, aura_radius * 0.65, 0.0, TAU, 48, inner_ring, 1.5, true)
