extends SceneTree

func _init() -> void:
	print("--- Running Magnet Mechanics Tests ---")
	var failures: int = 0
	failures += test_input_mapping()
	failures += test_player_polarity_and_cooldown()
	failures += test_magnetic_force()
	failures += test_aura_properties()
	failures += test_scene_integration()
	failures += test_glued_state_and_force_cancellation()
	failures += test_glued_synchronized_movement()
	failures += test_glued_repulsion_burst()
	failures += test_glued_gravity_in_air()
	failures += test_vertical_repulsion_burst()
	failures += test_mid_air_jump_push()
	failures += test_stacked_super_jump()
	
	if failures > 0:
		print("FAILED: %d tests failed" % failures)
		quit(1)
	else:
		print("ALL TESTS PASSED!")
		quit(0)


func assert_true(condition: bool, msg: String) -> int:
	if not condition:
		printerr("Assertion failed: %s" % msg)
		return 1
	return 0


func test_input_mapping() -> int:
	print("Testing input mapping...")
	var main_scene = load("res://scripts/main.gd").new()
	main_scene._configure_input_map()
	
	var err := 0
	# Check p2_jump has KEY_UP
	err += assert_true(InputMap.has_action("p2_jump"), "p2_jump action exists")
	var p2_jump_events = InputMap.action_get_events("p2_jump")
	var has_up = false
	var has_enter = false
	for ev in p2_jump_events:
		if ev is InputEventKey:
			if ev.physical_keycode == KEY_UP or ev.keycode == KEY_UP:
				has_up = true
			if ev.physical_keycode == KEY_ENTER or ev.keycode == KEY_ENTER:
				has_enter = true
	err += assert_true(has_up, "p2_jump contains KEY_UP")
	err += assert_true(not has_enter, "p2_jump does NOT contain KEY_ENTER")
	
	# Check p1_toggle_polarity has KEY_SHIFT
	err += assert_true(InputMap.has_action("p1_toggle_polarity"), "p1_toggle_polarity action exists")
	var p1_toggle_events = InputMap.action_get_events("p1_toggle_polarity")
	var has_shift = false
	for ev in p1_toggle_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_SHIFT or ev.keycode == KEY_SHIFT):
			has_shift = true
	err += assert_true(has_shift, "p1_toggle_polarity contains KEY_SHIFT")
	
	# Check p2_toggle_polarity has KEY_ENTER
	err += assert_true(InputMap.has_action("p2_toggle_polarity"), "p2_toggle_polarity action exists")
	var p2_toggle_events = InputMap.action_get_events("p2_toggle_polarity")
	var has_toggle_enter = false
	for ev in p2_toggle_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_ENTER or ev.keycode == KEY_ENTER):
			has_toggle_enter = true
	err += assert_true(has_toggle_enter, "p2_toggle_polarity contains KEY_ENTER")
	
	main_scene.free()
	return err


func test_player_polarity_and_cooldown() -> int:
	print("Testing player polarity and cooldown...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var player = player_script.new()
	var err := 0
	
	err += assert_true(player.get("polarity") != null, "player has polarity property")
	err += assert_true(player.has_method("toggle_polarity"), "player has toggle_polarity method")
	if not player.has_method("toggle_polarity"):
		player.free()
		return err
	
	# Initial polarity
	var initial_pol = player.polarity
	var toggled_1 = player.toggle_polarity()
	err += assert_true(toggled_1 == true, "first toggle_polarity succeeds")
	err += assert_true(player.polarity != initial_pol, "polarity changed after first toggle")
	
	# Immediate second toggle should fail due to cooldown
	var toggled_2 = player.toggle_polarity()
	err += assert_true(toggled_2 == false, "second immediate toggle fails due to cooldown")
	
	# Advance time partially (0.5s)
	player._physics_process(0.5)
	var toggled_3 = player.toggle_polarity()
	err += assert_true(toggled_3 == false, "toggle after 0.5s still fails (cooldown is 1.0s)")
	
	# Advance time remaining (0.6s)
	player._physics_process(0.6)
	var toggled_4 = player.toggle_polarity()
	err += assert_true(toggled_4 == true, "toggle after 1.1s succeeds")
	err += assert_true(player.polarity == initial_pol, "polarity returned to initial state")
	
	player.free()
	return err


func test_magnetic_force() -> int:
	print("Testing magnetic force calculation...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var p1 = player_script.new()
	var p2 = player_script.new()
	p1.position = Vector2(100, 200)
	p2.position = Vector2(200, 200)
	p1.aura_radius = 120.0
	p2.aura_radius = 120.0
	
	var err := 0
	err += assert_true(p1.has_method("calculate_magnetic_force"), "player has calculate_magnetic_force method")
	err += assert_true(p1.magnetic_strength > 0.0, "magnetic_strength is positive")
	if not p1.has_method("calculate_magnetic_force"):
		p1.free()
		p2.free()
		return err
	
	# Case 1: Same polarity (NORTH and NORTH) -> Repulsion
	p1.polarity = p1.Polarity.NORTH
	p2.polarity = p2.Polarity.NORTH
	var rep_force_p1: Vector2 = p1.calculate_magnetic_force(p2)
	var rep_force_p2: Vector2 = p2.calculate_magnetic_force(p1)
	err += assert_true(rep_force_p1.x < 0, "p1 repelled left (force.x < 0)")
	err += assert_true(rep_force_p2.x > 0, "p2 repelled right (force.x > 0)")
	
	# Case 2: Opposite polarity (NORTH and SOUTH) -> Attraction
	p1.polarity = p1.Polarity.NORTH
	p2.polarity = p2.Polarity.SOUTH
	var att_force_p1: Vector2 = p1.calculate_magnetic_force(p2)
	var att_force_p2: Vector2 = p2.calculate_magnetic_force(p1)
	err += assert_true(att_force_p1.x > 0, "p1 attracted right (force.x > 0)")
	err += assert_true(att_force_p2.x < 0, "p2 attracted left (force.x < 0)")
	
	# Case 3: Outside aura range (dist = 300 > 240) -> Zero force
	p2.position = Vector2(400, 200)
	var out_force_p1: Vector2 = p1.calculate_magnetic_force(p2)
	err += assert_true(out_force_p1 == Vector2.ZERO, "out of range produces Vector2.ZERO")
	
	p1.free()
	p2.free()
	return err


func test_aura_properties() -> int:
	print("Testing aura properties and colors...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var player = player_script.new()
	var err := 0
	
	err += assert_true(player.has_method("get_aura_color"), "player has get_aura_color helper method")
	if not player.has_method("get_aura_color"):
		player.free()
		return err
	
	player.polarity = player.Polarity.NORTH
	var north_color: Color = player.get_aura_color()
	err += assert_true(north_color.r > north_color.b, "North aura is predominantly red (r > b)")
	
	player.polarity = player.Polarity.SOUTH
	var south_color: Color = player.get_aura_color()
	err += assert_true(south_color.b > south_color.r, "South aura is predominantly blue (b > r)")
	
	player.free()
	return err


func test_scene_integration() -> int:
	print("Testing scene integration (node_2d.tscn)...")
	var scene_res = load("res://node_2d.tscn")
	var scene = scene_res.instantiate()
	var err := 0
	
	var p1 = scene.get_node_or_null("Players/PlayerOne")
	var p2 = scene.get_node_or_null("Players/PlayerTwo")
	err += assert_true(p1 != null, "scene has Players/PlayerOne")
	err += assert_true(p2 != null, "scene has Players/PlayerTwo")
	
	if p1 and p2:
		err += assert_true(p1.polarity == 0, "PlayerOne configured with North polarity (0)")
		err += assert_true(p2.polarity == 1, "PlayerTwo configured with South polarity (1)")
		scene.player_one = p1
		scene.player_two = p2
		scene._ready()
		err += assert_true(p1.other_player == p2, "PlayerOne references PlayerTwo after ready")
		err += assert_true(p2.other_player == p1, "PlayerTwo references PlayerOne after ready")
	
	scene.free()
	return err


func test_glued_state_and_force_cancellation() -> int:
	print("Testing glued (COLADOS) state and force cancellation...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var p1 = player_script.new()
	var p2 = player_script.new()
	p1.set_other_player(p2)
	p2.set_other_player(p1)
	p1.polarity = p1.Polarity.NORTH
	p2.polarity = p2.Polarity.SOUTH
	
	var err := 0
	err += assert_true(p1.get("is_glued") != null, "player has is_glued property")
	if p1.get("is_glued") == null:
		p1.free()
		p2.free()
		return err
	
	# Close distance (30px), opposite polarities -> should enter is_glued state
	p1.position = Vector2(100, 200)
	p2.position = Vector2(130, 200)
	p1.update_glued_state()
	p2.update_glued_state()
	err += assert_true(p1.is_glued == true, "p1 is_glued is true when touching with opposite polarities")
	err += assert_true(p2.is_glued == true, "p2 is_glued is true when touching with opposite polarities")
	
	# When glued, continuous magnetic force must be zero
	var force_when_glued = p1.calculate_magnetic_force(p2)
	err += assert_true(force_when_glued == Vector2.ZERO, "magnetic force is ZERO when glued")
	
	# When far away (distance 100px), not glued
	p2.position = Vector2(200, 200)
	p1.update_glued_state()
	err += assert_true(p1.is_glued == false, "p1 is_glued is false when far away")
	
	p1.free()
	p2.free()
	return err


func test_glued_synchronized_movement() -> int:
	print("Testing glued synchronized movement and jump...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var p1 = player_script.new()
	var p2 = player_script.new()
	p1.set_other_player(p2)
	p2.set_other_player(p1)
	p1.is_glued = true
	p2.is_glued = true
	
	var err := 0
	err += assert_true(p1.has_method("_get_movement_input"), "p1 has _get_movement_input method")
	err += assert_true(p1.has_method("_is_jump_held"), "p1 has _is_jump_held method")
	err += assert_true("simulated_input" in p1, "player supports simulated_input for movement testing")
	
	if "simulated_input" in p1:
		p1.set("simulated_input", 0.0)
		p2.set("simulated_input", 1.0)
		err += assert_true(p1._get_movement_input() == 1.0, "p1 moves right when p2 moves right while glued")
		err += assert_true(p2._get_movement_input() == 1.0, "p2 moves right while glued")
		
		# Test simulated jump
		p1.set("simulated_jump", false)
		p2.set("simulated_jump", true)
		err += assert_true(p1._is_jump_held() == true, "p1 jump is held when p2 jump is held while glued")
		err += assert_true(p2._is_jump_held() == true, "p2 jump is held while glued")
	
	p1.free()
	p2.free()
	return err


func test_glued_repulsion_burst() -> int:
	print("Testing glued repulsion burst when toggling polarity...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var p1 = player_script.new()
	var p2 = player_script.new()
	p1.set_other_player(p2)
	p2.set_other_player(p1)
	p1.polarity = p1.Polarity.NORTH
	p2.polarity = p2.Polarity.SOUTH
	p1.position = Vector2(100, 200)
	p2.position = Vector2(130, 200)
	p1.is_glued = true
	p2.is_glued = true
	
	var err := 0
	# p1 toggles polarity (becomes SOUTH, matching p2 -> causes separation burst)
	p1.toggle_polarity()
	err += assert_true(p1.is_glued == false, "p1 is no longer glued after repulsion toggle")
	err += assert_true(p2.is_glued == false, "p2 is no longer glued after repulsion toggle")
	err += assert_true(p1.velocity.x < -300.0, "p1 receives explosive burst to the left (velocity.x < -300)")
	err += assert_true(p2.velocity.x > 300.0, "p2 receives explosive burst to the right (velocity.x > 300)")
	err += assert_true(p1.has_method("play_repulsion_burst_effect"), "player has play_repulsion_burst_effect method")
	
	p1.free()
	p2.free()
	return err


func test_glued_gravity_in_air() -> int:
	print("Testing glued gravity in mid-air...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var p1 = player_script.new()
	var p2 = player_script.new()
	p1.set_other_player(p2)
	p2.set_other_player(p1)
	p1.is_glued = true
	p2.is_glued = true
	p1.velocity.y = -500.0
	p2.velocity.y = -500.0
	
	var err := 0
	err += assert_true(p1.has_method("is_touching_ground"), "player has is_touching_ground method")
	if not p1.has_method("is_touching_ground"):
		p1.free()
		p2.free()
		return err
	
	p1._physics_process(0.1)
	p2._physics_process(0.1)
	
	# Gravity (1500 * 0.1 = 150) should increase velocity.y from -500 to -350
	err += assert_true(p1.velocity.y > -500.0, "gravity increases p1 velocity.y in air when glued")
	err += assert_true(p2.velocity.y > -500.0, "gravity increases p2 velocity.y in air when glued")
	
	p1.free()
	p2.free()
	return err


func test_vertical_repulsion_burst() -> int:
	print("Testing vertical repulsion burst (player above another)...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var p1 = player_script.new()
	var p2 = player_script.new()
	p1.set_other_player(p2)
	p2.set_other_player(p1)
	p1.polarity = p1.Polarity.NORTH
	p2.polarity = p2.Polarity.SOUTH
	# p1 is above p2
	p1.position = Vector2(100, 170)
	p2.position = Vector2(100, 200)
	p1.is_glued = true
	p2.is_glued = true
	
	var err := 0
	p1.toggle_polarity()
	err += assert_true(p1.is_glued == false, "p1 is no longer glued after vertical repulsion")
	err += assert_true(p2.is_glued == false, "p2 is no longer glued after vertical repulsion")
	err += assert_true(p1.velocity.y < -500.0, "p1 (above) is propelled strongly upward (velocity.y < -500)")
	err += assert_true(p2.velocity.y > 300.0, "p2 (below) is propelled downward (velocity.y > 300)")
	
	p1.free()
	p2.free()
	return err


func test_mid_air_jump_push() -> int:
	print("Testing mid-air jump repulsion force...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var p1 = player_script.new()
	var p2 = player_script.new()
	p1.set_other_player(p2)
	p2.set_other_player(p1)
	p1.polarity = p1.Polarity.NORTH
	p2.polarity = p2.Polarity.NORTH
	# In air: p1 above p2
	p1.position = Vector2(100, 160)
	p2.position = Vector2(100, 200)
	
	var err := 0
	var f1: Vector2 = p1.calculate_magnetic_force(p2)
	var f2: Vector2 = p2.calculate_magnetic_force(p1)
	err += assert_true(f1.y < 0.0, "p1 pushed upward in air by repelling p2")
	err += assert_true(f2.y > 0.0, "p2 pushed downward in air by repelling p1")
	
	# Diagonal air jump push
	p1.position = Vector2(70, 160)
	p2.position = Vector2(100, 200)
	var f1_diag: Vector2 = p1.calculate_magnetic_force(p2)
	var f2_diag: Vector2 = p2.calculate_magnetic_force(p1)
	err += assert_true(f1_diag.x < 0.0 and f1_diag.y < 0.0, "diagonal push pushes p1 up and left")
	err += assert_true(f2_diag.x > 0.0 and f2_diag.y > 0.0, "diagonal push pushes p2 down and right")
	
	p1.free()
	p2.free()
	return err


func test_stacked_super_jump() -> int:
	print("Testing stacked super jump (player on top of another)...")
	var player_script = load("res://scripts/character_body_2d.gd")
	var p1 = player_script.new()
	var p2 = player_script.new()
	p1.set_other_player(p2)
	p2.set_other_player(p1)
	p1.polarity = p1.Polarity.NORTH
	p2.polarity = p2.Polarity.SOUTH
	# Real collision height: p1 at y=158, p2 at y=200 (vertical difference 42px)
	p1.position = Vector2(100, 158)
	p2.position = Vector2(100, 200)
	
	var err := 0
	p1.update_glued_state()
	p2.update_glued_state()
	err += assert_true(p1.is_glued == true, "players are glued when stacked vertically at 42px")
	
	# P1 toggles polarity (causes super-jump launch upward)
	p1.toggle_polarity()
	err += assert_true(p1.velocity.y <= -1000.0, "p1 (top player) launches upward with super jump velocity (<= -1000)")
	err += assert_true(p2.velocity.y >= 500.0, "p2 (bottom player) is pushed downward (>= 500)")
	
	p1.free()
	p2.free()
	return err











