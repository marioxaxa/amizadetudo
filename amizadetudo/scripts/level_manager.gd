extends Node

const LEVELS := [
	"res://levels/level_01.tscn",
	"res://levels/level_02.tscn",
	"res://levels/level_03.tscn",
	"res://levels/level_04.tscn"
]

var _is_transitioning := false
var _fade: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	layer.add_child(_fade)
	add_child(layer)


func advance_level() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	var fade_out := create_tween()
	fade_out.tween_property(_fade, "color:a", 1.0, 0.5)
	await fade_out.finished
	var current_index := LEVELS.find(get_tree().current_scene.scene_file_path)
	var next_index := (current_index + 1) % LEVELS.size()
	get_tree().change_scene_to_file(LEVELS[next_index])
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, 0.5)
	await fade_in.finished
	_is_transitioning = false
