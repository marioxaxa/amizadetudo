extends SceneTree

func _init() -> void:
	print("--- Running Magnet Mechanics Tests ---")
	var failures: int = 0
	failures += test_input_mapping()
	failures += test_player_polarity_and_cooldown()
	failures += test_magnetic_force()
	failures += test_aura_properties()
	failures += test_scene_integration()
	
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
	err += assert_true(p1.magnetic_strength >= 9000.0, "magnetic_strength is 9000.0 (5x increase)")
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




