extends Control

@onready var start_button: Button = $CenterContainer/Panel/VBoxContainer/StartButton


func _ready() -> void:
	start_button.grab_focus()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/level_01.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
