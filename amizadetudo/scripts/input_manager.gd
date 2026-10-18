extends Node


func _ready() -> void:
	configure_actions()


static func configure_actions() -> void:
	_add_key_action("p1_left", KEY_A)
	_add_key_action("p1_right", KEY_D)
	_add_key_action("p1_jump", KEY_SPACE)
	_add_key_action("p1_toggle_polarity", KEY_SHIFT)
	_add_key_action("p2_left", KEY_LEFT)
	_add_key_action("p2_right", KEY_RIGHT)
	_add_key_action("p2_jump", KEY_UP)
	_add_key_action("p2_toggle_polarity", KEY_ENTER)


static func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
