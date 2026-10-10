extends Node3D
## Polizón, el perro que bajó del camión de Coco. Solo presentación: aparece cuando el
## jugador tiene el hecho "has_dog", lo sigue a unos metros y de noche se echa al lado del fuego.
## Decide adónde ir 5 veces por segundo y se mueve suave cada fotograma.

@export var follow_distance: float = 2.2
@export var speed: float = 4.5
@export var rest_point: Vector3 = Vector3(2.4, 0, 2.8)

var player: Node3D
var _target := Vector3.ZERO
var _timer := 0.0
var _t := 0.0

@onready var _body: Node3D = $Body


func _ready() -> void:
	Game.facts_changed.connect(_refresh)
	Game.state_replaced.connect(_refresh)
	_refresh()
	global_position = rest_point


func _refresh() -> void:
	visible = Game.state.has_fact("player", "has_dog")
	set_process(visible)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.2
		_decide()
	var to := _target - global_position
	to.y = 0.0
	var moving := to.length() > 0.15
	if moving:
		var step := minf(to.length(), speed * delta)
		global_position += to.normalized() * step
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, 8.0 * delta))
		_t += delta * 14.0
		_body.position.y = absf(sin(_t)) * 0.05
	else:
		_body.position.y = move_toward(_body.position.y, 0.0, delta)


func _decide() -> void:
	if player == null or DayTime.is_night(Game.state, Game.content):
		_target = rest_point
		return
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() > follow_distance:
		_target = player.global_position - to.normalized() * follow_distance
		_target.y = 0.0
