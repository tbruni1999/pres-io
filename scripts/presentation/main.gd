extends Node3D
## Escena principal: conecta jugador, mundo e interfaz. No contiene reglas de juego.

@onready var player: PlayerController = $Player
@onready var ui: UIRoot = $UI
@onready var spawn: Marker3D = $World/PlayerSpawn
@onready var road: MerchantRoad = $World/MerchantRoad


func _ready() -> void:
	ui.bind(player, road)
	Game.player_pose_provider = player.get_pose
	Game.state_replaced.connect(_place_player)
	ui.wake_at_home.connect(go_home)
	$World/Dog.player = player
	$World/Neighbors/Beto.watch_target = player
	var rain := RainFx.new()
	rain.name = "Rain"
	rain.target = player
	add_child(rain)
	_place_player()


func _place_player() -> void:
	if Game.state.player_pose.is_empty():
		go_home()
	else:
		player.apply_pose(Game.state.player_pose)


## Despertar en la choza (inicio, desmayo).
func go_home() -> void:
	player.apply_pose({"position": spawn.global_position, "yaw": spawn.global_rotation.y, "pitch": 0.0})
