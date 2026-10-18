extends CharacterBody2D

enum Polarity {
	NORTH,
	SOUTH
}

@export_group("Player Settings")
@export var player_index := 1
@export var player_color := Color("55d6ff")

@export_group("Movement")
@export var tile_magnetic_radius := 148.0
@export var tile_magnetic_glue_distance := 54.0
@export var max_speed := 300.0
@export var acceleration := 2200.0
@export var deceleration := 2600.0

@export_group("Jump & Gravity")
@export var jump_velocity := -540.0
@export var gravity := 1500.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12
@export var respawn_delay := 2.0

@export_group("Magnetism")
@export var polarity: Polarity = Polarity.NORTH
@export var polarity_cooldown := 1.0
@export var aura_radius := 60.0
@export var magnetic_strength := 4000.0
@export var player_magnetic_strength := 1500.0
@export var magnetic_wall_hold_time := 0.5
@export var magnetic_wall_slide_speed := 85.0
@export var magnetic_hover_height := 54.0
@export var magnetic_hover_activation_height := 80.0
@export var magnetic_hover_horizontal_margin := 16.0
@export var magnetic_hover_spring_strength := 55.0
@export var magnetic_hover_damping := 12.0
@export var magnetic_hover_burst_delay := 0.5
@export var magnetic_hover_bob_amplitude := 4.0
@export var magnetic_hover_bob_frequency := 1.6
@export var magnetic_wall_slide_acceleration := 140.0

@export_group("Repulsion & Burst")
@export var super_jump_speed := 1050.0
@export var stacked_push_down_speed := 600.0
@export var horizontal_burst_speed := 850.0
@export var horizontal_burst_lift := -260.0
@export var magnetic_wall_burst_lift := -420.0

# --- Constants ---
const GLUE_DISTANCE := 38.0

# --- Game & Player State ---
var joypad_id := -1
var level_map: TileMapLayer
var other_player: CharacterBody2D = null
var is_glued := false

# --- Timers & Input State ---
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jump_was_held := false
var _is_dead := false
var _spawn_position := Vector2.ZERO
var _cooldown_timer := 0.0
var _toggle_was_held := false
var _controls_enabled := true
var _magnetic_tile_attached := false
var _attached_tile_field := 0
var _attached_tile_position := Vector2.ZERO
var _magnetic_floor_contact := false
var _magnetic_wall_contact := false
var _magnetic_hovering := false
var _magnetic_wall_hold_timer := 0.0
var _magnetic_hover_target := Vector2.ZERO
var _magnetic_hover_ignore_timer := 0.0
var _magnetic_detach_timer := 0.0
var _magnetic_hover_time := 0.0
var _magnetic_wall_slide_timer := 0.0

# --- Visual Effects ---
var aura_pulse := 1.0

# --- Testing / Simulation Stubs ---
var simulated_input = null
var simulated_jump = null

# --- Node References ---
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
	_magnetic_hover_ignore_timer = maxf(_magnetic_hover_ignore_timer - delta, 0.0)
	_magnetic_detach_timer = maxf(_magnetic_detach_timer - delta, 0.0)
	if not is_instance_valid(other_player) and is_inside_tree():
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child is CharacterBody2D and child != self:
					other_player = child
					break

	update_glued_state()
	_update_magnetic_tile_effects(delta)
	_magnetic_hover_time = _magnetic_hover_time + delta if _magnetic_hovering else 0.0

	var ground_contact := is_touching_ground()
	if is_glued and is_instance_valid(other_player):
		ground_contact = ground_contact or other_player.is_touching_ground()

	if ground_contact:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if _magnetic_hovering:
		# Hover takes priority over floor contact so a hard landing is pulled back up.
		var bob_offset := sin(_magnetic_hover_time * TAU * magnetic_hover_bob_frequency) * magnetic_hover_bob_amplitude
		var spring_offset := _magnetic_hover_target.y + bob_offset - global_position.y
		var spring_acceleration := spring_offset * magnetic_hover_spring_strength - velocity.y * magnetic_hover_damping
		velocity.y += spring_acceleration * delta
	elif not ground_contact:
		if _magnetic_wall_contact:
			if _magnetic_wall_hold_timer > 0.0:
				velocity.y = 0.0
			else:
				var slide_speed := magnetic_wall_slide_speed
				if _magnetic_wall_slide_timer > 1.0:
					slide_speed += (_magnetic_wall_slide_timer - 1.0) * magnetic_wall_slide_acceleration
				velocity.y = move_toward(velocity.y, slide_speed, gravity * 1.5 * delta)
		else:
			velocity.y += gravity * delta

	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	var toggle_held := _is_toggle_held()
	if toggle_held and not _toggle_was_held:
		toggle_polarity()
	_toggle_was_held = toggle_held

	var input_direction := _get_movement_input()
	var speed_multiplier := 0.65 if _magnetic_floor_contact else 1.0
	var target_speed := input_direction * max_speed * speed_multiplier
	var rate := acceleration if not is_zero_approx(input_direction) else deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

	var jump_held := _is_jump_held()
	if jump_held and not _jump_was_held:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_jump_was_held = jump_held

	var jumped := _jump_buffer_timer > 0.0 and (ground_contact or _coyote_timer > 0.0)
	if jumped:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		# Let the jump clear a magnetic surface before its holding force resumes.
		_magnetic_detach_timer = 0.12
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
		if ground_contact and magnet_force.y < 0.0:
			magnet_force.y = 0.0
		velocity += magnet_force * delta
	if _magnetic_detach_timer <= 0.0:
		_apply_tile_attachment_force(delta)

	if is_inside_tree():
		move_and_slide()
	_check_hazard()


func _update_magnetic_tile_effects(delta: float) -> void:
	var was_touching_magnetic_wall := _magnetic_wall_contact
	_magnetic_tile_attached = false
	_magnetic_floor_contact = false
	_magnetic_wall_contact = false
	_magnetic_hovering = false
	if _magnetic_detach_timer > 0.0:
		return
	if level_map == null:
		return

	var center_cell := level_map.local_to_map(level_map.to_local(global_position))
	var cell_radius := ceili(tile_magnetic_radius / float(level_map.tile_set.tile_size.x))
	var closest_opposite_distance := INF
	var closest_opposite_position := Vector2.ZERO
	var closest_opposite_field := 0
	var same_field := polarity + 1
	var closest_same_field_below_distance := INF
	var closest_same_field_below_position := Vector2.ZERO

	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell := Vector2i(x, y)
			var tile_data := level_map.get_cell_tile_data(cell)
			if tile_data == null:
				continue
			var field := int(tile_data.get_custom_data("magnetic_field"))
			if field == 0:
				continue
			var tile_position := level_map.to_global(level_map.map_to_local(cell))
			var offset := global_position - tile_position
			var distance := offset.length()
			if distance <= 0.001:
				offset = Vector2.UP
				distance = 0.001
			if field == same_field and distance < tile_magnetic_radius:
				var falloff := 1.0 - distance / tile_magnetic_radius
				var repulsion := offset.normalized() * magnetic_strength * 0.72 * falloff * falloff * delta
				var hover_half_width := float(level_map.tile_set.tile_size.x) * 0.5 + magnetic_hover_horizontal_margin
				var is_above_tile := offset.y < -8.0 and -offset.y <= magnetic_hover_activation_height
				if is_above_tile:
					# The spring controls vertical hover; keep only lateral repulsion here.
					velocity.x += repulsion.x
					if absf(offset.x) <= hover_half_width and distance < closest_same_field_below_distance:
						closest_same_field_below_distance = distance
						closest_same_field_below_position = tile_position
				else:
					velocity += repulsion
			elif distance < closest_opposite_distance:
				closest_opposite_distance = distance
				closest_opposite_position = tile_position
				closest_opposite_field = field

	if closest_opposite_field == 0 or closest_opposite_distance > tile_magnetic_glue_distance:
		_attached_tile_field = 0
		_magnetic_hovering = closest_same_field_below_distance < INF and _magnetic_hover_ignore_timer <= 0.0
		if _magnetic_hovering:
			_magnetic_hover_target = closest_same_field_below_position + Vector2.UP * magnetic_hover_height
		_magnetic_wall_hold_timer = 0.0
		_magnetic_wall_slide_timer = 0.0
		return

	_magnetic_tile_attached = true
	_attached_tile_field = closest_opposite_field
	_attached_tile_position = closest_opposite_position
	var toward_tile := closest_opposite_position - global_position
	velocity += toward_tile.normalized() * magnetic_strength * 0.32 * delta
	# Floor magnets keep horizontal movement, but reduce it while holding the player down.
	_magnetic_floor_contact = is_on_floor() and toward_tile.y > absf(toward_tile.x)
	_magnetic_wall_contact = not is_on_floor() and absf(toward_tile.x) > absf(toward_tile.y)
	if _magnetic_wall_contact:
		if not was_touching_magnetic_wall:
			_magnetic_wall_hold_timer = magnetic_wall_hold_time
			_magnetic_wall_slide_timer = 0.0
		else:
			_magnetic_wall_hold_timer = maxf(_magnetic_wall_hold_timer - delta, 0.0)
			if _magnetic_wall_hold_timer <= 0.0:
				_magnetic_wall_slide_timer += delta
	else:
		_magnetic_wall_hold_timer = 0.0
		_magnetic_wall_slide_timer = 0.0


func _apply_tile_attachment_force(delta: float) -> void:
	if not _magnetic_tile_attached:
		return
	var toward_tile := _attached_tile_position - global_position
	if toward_tile.length_squared() < 0.001:
		return
	if _magnetic_wall_contact:
		# Reapply attraction after movement input so an opposite wall holds the player.
		velocity.x = move_toward(velocity.x, signf(toward_tile.x) * 760.0, magnetic_strength * 3.0 * delta)
		if _magnetic_wall_hold_timer > 0.0:
			velocity.y = 0.0


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

func _get_raw_movement_input() -> float:
	if simulated_input != null:
		return float(simulated_input)
	var left_action := "p1_left" if player_index == 1 else "p2_left"
	var right_action := "p1_right" if player_index == 1 else "p2_right"
	if not InputMap.has_action(left_action) or not InputMap.has_action(right_action):
		return 0.0
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
	if not InputMap.has_action(action):
		return false
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
	var was_attached_to_tile := _magnetic_tile_attached
	var was_attached_to_magnetic_wall := _magnetic_wall_contact
	var attached_tile_position := _attached_tile_position
	var attached_tile_field := _attached_tile_field
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
				
				# Directional launch calculation based on relative position on head
				var dx: float = top_player.global_position.x - bottom_player.global_position.x
				var side := signf(dx)
				if is_zero_approx(side):
					side = 1.0 if player_index == 1 else -1.0
				
				var launch_dir: Vector2
				if absf(dx) <= 6.0:
					# Centered on the flat part of the head: purely vertical launch
					launch_dir = Vector2(0.0, -1.0)
					top_player.velocity.x = 0.0
					top_player.velocity.y = -super_jump_speed
					bottom_player.velocity.x = 0.0
					bottom_player.velocity.y = stacked_push_down_speed
				else:
					# On diagonal chamfer: directional diagonal launch
					var offset_ratio: float = clampf((absf(dx) - 6.0) / 12.0, 0.0, 1.0)
					var lateral_ratio: float = 0.35 + 0.40 * offset_ratio
					launch_dir = Vector2(side * lateral_ratio, -1.0).normalized()
					
					top_player.velocity = launch_dir * super_jump_speed
					bottom_player.velocity.x = -side * (absf(top_player.velocity.x) * 0.45)
					bottom_player.velocity.y = stacked_push_down_speed
				
				top_player.play_repulsion_burst_effect(-launch_dir)
				bottom_player.play_repulsion_burst_effect(launch_dir)
			else:
				velocity.x = -dir.x * horizontal_burst_speed
				other_player.velocity.x = dir.x * horizontal_burst_speed
				velocity.y = minf(velocity.y, horizontal_burst_lift)
				other_player.velocity.y = minf(other_player.velocity.y, horizontal_burst_lift)
				
				play_repulsion_burst_effect(-dir)
				other_player.play_repulsion_burst_effect(dir)

	if was_attached_to_tile and attached_tile_field == polarity + 1:
		var burst_direction := global_position - attached_tile_position
		if burst_direction.length_squared() < 0.001:
			burst_direction = Vector2.UP
		velocity = burst_direction.normalized() * 850.0
		velocity.y = minf(velocity.y, magnetic_wall_burst_lift if was_attached_to_magnetic_wall else -260.0)
		_magnetic_tile_attached = false
		_attached_tile_field = 0
		_magnetic_hover_ignore_timer = magnetic_hover_burst_delay
		play_repulsion_burst_effect(burst_direction)
	
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
	if not InputMap.has_action(action):
		return false
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
	var magnitude := player_magnetic_strength * (0.35 + 0.65 * proximity)
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
