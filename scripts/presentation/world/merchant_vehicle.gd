extends Node3D
## Vehículo de un comerciante (carreta, auto, camión). Solo representación.

@export var bob_height: float = 0.0
@export var bob_speed: float = 6.0

@onready var _body: Node3D = $Body

var _moving := true
var _t := 0.0


func _ready() -> void:
	# Carrocería y personas: se funden por material (las ruedas giran aparte, no se tocan).
	MeshMerger.merge(_body, PackedStringArray(["Wheel"]))


func set_moving(moving: bool) -> void:
	_moving = moving


func _process(delta: float) -> void:
	if _moving and bob_height > 0.0:
		_t += delta * bob_speed
		_body.position.y = absf(sin(_t)) * bob_height
	else:
		_body.position.y = move_toward(_body.position.y, 0.0, delta)
