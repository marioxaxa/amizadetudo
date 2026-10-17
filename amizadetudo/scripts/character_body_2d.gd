extends CharacterBody2D

@export var player_index := 1
@export var player_color := Color("55d6ff")
@export var max_speed := 300.0
@export var acceleration := 2200.0
@export var deceleration := 2600.0
@export var jump_velocity := -540.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12

const GRAVITY := 1500.0

var joypad_id := -1
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jump_was_held := false

@onready var visual: Polygon2D = $Visual
@onready var nameplate: Label = $Nameplate


func _ready() -> void:
	visual.color = player_color
	nameplate.text = "P%d" % player_index


func set_joypad(device_id: int) -> void:
	joypad_id = device_id


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	if was_on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y += GRAVITY * delta

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

	move_and_slide()


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
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(0.78, 1.22), 0.08)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
