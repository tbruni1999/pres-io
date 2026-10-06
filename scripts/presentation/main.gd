extends Node3D
## Escena principal: conecta jugador, mundo e interfaz. No contiene reglas de juego.

@onready var player: PlayerController = $Player
@onready var ui: UIRoot = $UI
@onready var spawn: Marker3D = $Settlement/PlayerSpawn


func _ready() -> void:
	ui.bind_player(player)
	Game.player_pose_provider = player.get_pose
	Game.state_replaced.connect(_place_player)
	for actor in get_tree().get_nodes_in_group("neighbors"):
		actor.watch_target = player
	_place_player()


func _place_player() -> void:
	if Game.state.player_pose.is_empty():
		player.apply_pose({"position": spawn.global_position, "yaw": spawn.global_rotation.y, "pitch": 0.0})
	else:
		player.apply_pose(Game.state.player_pose)
