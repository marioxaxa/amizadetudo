extends Area2D

enum AllowedPlayer {
	ANY,
	PLAYER_ONE,
	PLAYER_TWO
}

@export var allowed_player: AllowedPlayer = AllowedPlayer.PLAYER_ONE

var _players_inside: Dictionary[int, Node2D] = {}

signal readiness_changed(player: int, is_ready: bool)

@onready var label: Label = $Label
@onready var frame: Polygon2D = $Frame


func _ready() -> void:
	add_to_group("level_exits")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visual()


func is_player_ready() -> bool:
	return not _players_inside.is_empty()


func get_ready_player_indices() -> Array[int]:
	var player_indices: Array[int] = []
	for player in _players_inside.values():
		if is_instance_valid(player) and player.player_index not in player_indices:
			player_indices.append(player.player_index)
	return player_indices


func _on_body_entered(body: Node2D) -> void:
	if _accepts(body):
		_players_inside[body.get_instance_id()] = body
		_update_visual()
		readiness_changed.emit(body.player_index, true)


func _on_body_exited(body: Node2D) -> void:
	if _players_inside.erase(body.get_instance_id()):
		_update_visual()
		readiness_changed.emit(body.player_index, is_player_ready())


func _accepts(body: Node2D) -> bool:
	if body.get("player_index") == null:
		return false
	return allowed_player == AllowedPlayer.ANY or body.player_index == allowed_player


func _update_visual() -> void:
	frame.color = Color("8dff9a") if is_player_ready() else Color("e8efff")
	if is_player_ready():
		label.text = "PRONTO"
	elif allowed_player == AllowedPlayer.ANY:
		label.text = "P1 / P2"
	else:
		label.text = "P%d" % allowed_player
