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

const GRAVITY := 1500.0
const GLUE_DISTANCE := 38.0

var joypad_id := -1
var other_player: CharacterBody2D = null
var is_glued := false
var simulated_input = null
var simulated_jump = null
var aura_pulse := 1.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jump_was_held := false
var _cooldown_timer := 0.0
var _toggle_was_held := false

@onready var visual: Polygon2D = get_node_or_null("Visual")
@onready var nameplate: Label = get_node_or_null("Nameplate")


func _ready() -> void:
	if visual:
		visual.color = player_color
	if nameplate:
		nameplate.text = "P%d" % player_index
	queue_redraw()


func set_joypad(device_id: int) -> void:
	joypad_id = device_id


func _physics_process(delta: float) -> void:
	if not is_instance_valid(other_player) and is_inside_tree():
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child is CharacterBody2D and child != self:
					other_player = child
					break

	update_glued_state()

	var ground_contact := is_touching_ground()
	if is_glued and is_instance_valid(other_player):
		ground_contact = ground_contact or other_player.is_touching_ground()

	if ground_contact:
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

	if _jump_buffer_timer > 0.0 and (ground_contact or _coyote_timer > 0.0):
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_play_jump_tween()
		if is_glued and is_instance_valid(other_player):
			other_player.velocity.y = jump_velocity
			other_player._jump_buffer_timer = 0.0
			other_player._coyote_timer = 0.0
			other_player._play_jump_tween()

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


func _get_raw_movement_input() -> float:
	if simulated_input != null:
		return float(simulated_input)
	var left_action := "p1_left" if player_index == 1 else "p2_left"
	var right_action := "p1_right" if player_index == 1 else "p2_right"
	var keyboard_input := Input.get_axis(left_action, right_action)
	var controller_input := 0.0
	if joypad_id >= 0 and Input.get_connected_joypads().has(joypad_id):
		controller_input = Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X)
	return controller_input if absf(controller_input) > absf(keyboard_input) else keyboard_input


func _get_movement_input() -> float:
	var raw_self := _get_raw_movement_input()
	if is_glued and is_instance_valid(other_player):
		var raw_other: float = other_player._get_raw_movement_input()
		return clampf(raw_self + raw_other, -1.0, 1.0)
	return raw_self


func _is_raw_jump_held() -> bool:
	if simulated_jump != null:
		return bool(simulated_jump)
	var action := "p1_jump" if player_index == 1 else "p2_jump"
	var controller_jump := joypad_id >= 0 and Input.get_connected_joypads().has(joypad_id) and Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_A)
	return Input.is_action_pressed(action) or controller_jump


func _is_jump_held() -> bool:
	var self_jump := _is_raw_jump_held()
	if is_glued and is_instance_valid(other_player):
		return self_jump or other_player._is_raw_jump_held()
	return self_jump


func _play_jump_tween() -> void:
	if not visual:
		return
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(0.78, 1.22), 0.08)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func toggle_polarity() -> bool:
	if _cooldown_timer > 0.0:
		return false
	
	var was_glued_before := is_glued or is_in_contact_with_other()
	polarity = Polarity.SOUTH if polarity == Polarity.NORTH else Polarity.NORTH
	_cooldown_timer = polarity_cooldown
	
	if was_glued_before and is_instance_valid(other_player):
		if polarity == other_player.polarity:
			is_glued = false
			other_player.is_glued = false
			
			var diff := other_player.global_position - global_position
			var dir := Vector2.RIGHT if player_index == 1 else Vector2.LEFT
			if diff.length() > 0.001:
				dir = diff.normalized()
			
			var is_vertical := absf(dir.y) >= 0.35
			if is_vertical:
				var top_player: CharacterBody2D = self if global_position.y < other_player.global_position.y else other_player
				var bottom_player: CharacterBody2D = other_player if top_player == self else self
				
				# Player on top receives a huge super jump launch!
				var super_jump_speed := 1050.0
				top_player.velocity.y = -super_jump_speed
				top_player.velocity.x = -dir.x * 350.0 if top_player == self else dir.x * 350.0
				
				# Player below is pushed firmly downward
				bottom_player.velocity.y = 600.0
				bottom_player.velocity.x = -dir.x * 350.0 if bottom_player == self else dir.x * 350.0
			else:
				var burst_speed := 850.0
				velocity.x = -dir.x * burst_speed
				other_player.velocity.x = dir.x * burst_speed
				velocity.y = minf(velocity.y, -260.0)
				other_player.velocity.y = minf(other_player.velocity.y, -260.0)
			
			play_repulsion_burst_effect(-dir)
			other_player.play_repulsion_burst_effect(dir)
	
	queue_redraw()
	return true


func play_repulsion_burst_effect(dir: Vector2) -> void:
	if visual and is_inside_tree():
		var tween := create_tween()
		var stretch := Vector2(1.35, 0.75)
		if absf(dir.y) > absf(dir.x):
			stretch = Vector2(0.75, 1.35)
		var recoil_scale := Vector2(stretch.y, stretch.x)
		tween.tween_property(visual, "scale", stretch, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual, "scale", recoil_scale, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(visual, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if is_inside_tree():
		var aura_tween := create_tween()
		aura_pulse = 1.6
		queue_redraw()
		aura_tween.tween_property(self, "aura_pulse", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		aura_tween.parallel().tween_method(func(_v): queue_redraw(), 0.0, 1.0, 0.3)
	else:
		aura_pulse = 1.0


func _is_toggle_held() -> bool:
	var action := "p1_toggle_polarity" if player_index == 1 else "p2_toggle_polarity"
	var controller_toggle := joypad_id >= 0 and Input.get_connected_joypads().has(joypad_id) and (Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_X) or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_B))
	return Input.is_action_pressed(action) or controller_toggle


func set_other_player(other: CharacterBody2D) -> void:
	other_player = other


func is_in_contact_with_other() -> bool:
	if not is_instance_valid(other_player):
		return false
	var diff := other_player.global_position - global_position
	if absf(diff.x) <= 38.0 and absf(diff.y) <= 32.0:
		return true
	if absf(diff.x) <= 28.0 and absf(diff.y) <= 50.0:
		return true
	if diff.length() <= 44.0:
		return true
	return false


func update_glued_state() -> void:
	if not is_instance_valid(other_player):
		is_glued = false
		return
	if polarity == other_player.polarity:
		is_glued = false
		return
	if is_in_contact_with_other():
		is_glued = true
		other_player.is_glued = true
	elif is_glued:
		var dist := global_position.distance_to(other_player.global_position)
		if dist > 55.0:
			is_glued = false


func is_touching_ground() -> bool:
	if not is_on_floor():
		return false
	var count := get_slide_collision_count()
	if count == 0:
		return true
	for i in range(count):
		var collision := get_slide_collision(i)
		if collision.get_collider() != other_player:
			if collision.get_normal().y < -0.5:
				return true
	return false


func calculate_magnetic_force(other: Node2D) -> Vector2:
	if is_glued:
		return Vector2.ZERO
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
	var fill_alpha := 0.22 if is_glued else 0.16
	var fill_color := Color(base_color.r, base_color.g, base_color.b, fill_alpha)
	var ring_color := Color(base_color.r, base_color.g, base_color.b, 0.75)
	
	draw_circle(Vector2.ZERO, aura_radius, fill_color)
	draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 64, ring_color, 2.5, true)
	
	var inner_ring := Color(base_color.r, base_color.g, base_color.b, 0.28)
	draw_arc(Vector2.ZERO, aura_radius * 0.65, 0.0, TAU, 48, inner_ring, 1.5, true)

	if aura_pulse > 1.01:
		var wave_radius := aura_radius * aura_pulse
		var wave_fade := clampf((aura_pulse - 1.0) / 0.6, 0.0, 1.0)
		var wave_color := Color(1.0, 1.0, 1.0, 0.75 * wave_fade)
		draw_arc(Vector2.ZERO, wave_radius, 0.0, TAU, 64, wave_color, 3.0 * wave_fade, true)
