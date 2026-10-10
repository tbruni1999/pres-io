extends Node
## Muestra la llama y la luz del fogón solo mientras arde (Simulation.fire_lit).
## El fuego se apaga con el paso del tiempo, así que se revisa 4 veces por segundo.

@onready var _flame: Node3D = $"../Flame"
@onready var _light: Light3D = $"../FireLight"
var _timer := 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	var lit := Simulation.fire_lit(Game.state)
	_flame.visible = lit
	_light.visible = lit
