extends Node3D
## Un loco en el mundo (Beto, Salim, Raúl). Solo presentación: aparece cuando llegó
## (Neighbors), espera en su punto hasta que elegís dónde va su carpa y después se queda junto a ella.
## Mira al jugador si está cerca (decide 4 veces por segundo, gira suave).

@export var neighbor_id: String = "beto"
## Dónde espera recién llegado, antes de tener carpa.
@export var wait_point: Vector3 = Vector3(4.9, 0, 2.3)
@export var notice_radius: float = 6.0

var watch_target: Node3D
var _timer := 0.0
var _target_yaw := 0.0

@onready var _body: Node3D = $Body


func _ready() -> void:
	Game.camp_changed.connect(_refresh)
	Game.state_replaced.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var here := Neighbors.is_present(Game.state, neighbor_id)
	visible = here
	process_mode = Node.PROCESS_MODE_INHERIT if here else Node.PROCESS_MODE_DISABLED
	if here:
		global_position = _stand_point(Neighbors.spot_of(Game.state, neighbor_id))


## Al lado de su carpa (marcador "Stand" de la carpa de ese lugar) o esperando junto al fogón.
func _stand_point(spot: String) -> Vector3:
	for tent in get_tree().get_nodes_in_group("neighbor_tents"):
		if String(tent.get("spot")) == spot and not spot.is_empty():
			return (tent.get_node("Stand") as Node3D).global_position
	return wait_point


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		_target_yaw = _body.rotation.y
		if watch_target != null:
			var to := watch_target.global_position - global_position
			to.y = 0.0
			if to.length_squared() < notice_radius * notice_radius and to.length_squared() > 0.01:
				_target_yaw = atan2(to.x, to.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, _target_yaw, minf(1.0, 4.0 * delta))
