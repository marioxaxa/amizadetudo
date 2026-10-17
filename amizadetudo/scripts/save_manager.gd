extends Node

const SAVE_PATH := "user://save_game.json"

var death_counts := {1: 0, 2: 0}


func _ready() -> void:
	_load_save()


func register_death(player_index: int) -> int:
	death_counts[player_index] = get_death_count(player_index) + 1
	_save()
	return death_counts[player_index]


func get_death_count(player_index: int) -> int:
	return int(death_counts.get(player_index, 0))


func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		death_counts[1] = int(data.get("player_1_deaths", 0))
		death_counts[2] = int(data.get("player_2_deaths", 0))


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"player_1_deaths": get_death_count(1),
		"player_2_deaths": get_death_count(2)
	}))
