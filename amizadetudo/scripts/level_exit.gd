extends Area2D

@export_range(1, 2) var player_index := 1

var _player_ready := false

signal readiness_changed(player: int, is_ready: bool)

@onready var label: Label = $Label
@onready var frame: Polygon2D = $Frame


func _ready() -> void:
	add_to_group("level_exits")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visual()


func is_player_ready() -> bool:
	return _player_ready


func _on_body_entered(body: Node2D) -> void:
	if body.get("player_index") == player_index:
		_player_ready = true
		_update_visual()
		readiness_changed.emit(player_index, true)


func _on_body_exited(body: Node2D) -> void:
	if body.get("player_index") == player_index:
		_player_ready = false
		_update_visual()
		readiness_changed.emit(player_index, false)


func _update_visual() -> void:
	frame.color = Color("8dff9a") if _player_ready else Color("e8efff")
	label.text = "PRONTO" if _player_ready else "P%d" % player_index
