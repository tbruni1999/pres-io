extends Node3D
## Humo del ahumadero: se ve solo mientras hay una tanda ahumándose. Cosmético.

@export var rise_speed: float = 0.35
@export var height: float = 1.6

var _t := 0.0


func _process(delta: float) -> void:
	visible = PlayerActions.smoker_status(Game.state) == PlayerActions.SMOKER_SMOKING
	if not visible:
		return
	_t += delta * rise_speed
	var i := 0
	for puff: Node3D in get_children():
		var phase := fposmod(_t + i * 0.33, 1.0)
		puff.position = Vector3(sin((_t + i) * 2.0) * 0.12, phase * height, 0.0)
		puff.scale = Vector3.ONE * lerpf(0.6, 1.6, phase)
		i += 1
