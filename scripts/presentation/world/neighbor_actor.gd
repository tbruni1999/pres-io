extends Node3D
## Vecino visible. Es solo representación: sus datos y hechos viven en GameState.
## Decide hacia dónde mirar ~4 veces por segundo (con desfase propio) y gira suave
## cada fotograma. Descargarlo no afecta la población administrativa.

@export var resident_id: String = "neighbor_rosa"
@export var notice_radius: float = 6.0
@export var decision_interval: float = 0.25
@export var turn_speed: float = 4.0

## Lo asigna la escena principal; sin objetivo la vecina mantiene su orientación.
var watch_target: Node3D

@onready var _body: Node3D = $Body
@onready var _bucket_water: Node3D = $Body/BucketWater

var _rest_yaw: float = 0.0
var _target_yaw: float = 0.0
var _decision_timer: float = 0.0


func _ready() -> void:
	_rest_yaw = _body.rotation.y
	_target_yaw = _rest_yaw
	# Desfase cosmético para que varios actores no decidan en el mismo fotograma.
	_decision_timer = randf() * decision_interval
	Game.service_changed.connect(func(_id: String) -> void: _refresh_props())
	Game.state_replaced.connect(_refresh_props)
	_refresh_props()


func _process(delta: float) -> void:
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer += decision_interval
		_decide()
	_body.rotation.y = lerp_angle(_body.rotation.y, _target_yaw, minf(1.0, turn_speed * delta))


func _decide() -> void:
	_target_yaw = _rest_yaw
	if watch_target == null:
		return
	var to := watch_target.global_position - global_position
	to.y = 0.0
	if to.length_squared() <= notice_radius * notice_radius and to.length_squared() > 0.01:
		# El cuerpo mira hacia +Z local; atan2 da el giro que apunta ese eje al jugador.
		_target_yaw = atan2(to.x, to.z) - rotation.y


## El balde lleno aparece cuando el agua efectivamente alcanza (derivado del estado).
func _refresh_props() -> void:
	var day := Game.state.current_day()
	var capacity := Simulation.water_capacity(Game.state, Game.content, day)
	var coverage := Simulation.coverage_bp(capacity, Game.state.settlement.population)
	_bucket_water.visible = coverage >= 10000
