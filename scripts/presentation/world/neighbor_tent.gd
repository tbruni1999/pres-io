extends Node3D
## Carpa de un vecino: se ve si alguno eligió este lugar (Neighbors.SPOTS).
## Ocultarla también saca su colisión.

@export var spot: String = ""


func _ready() -> void:
	Game.camp_changed.connect(_refresh)
	Game.state_replaced.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var used := false
	for id in Game.state.camp.neighbors:
		if Neighbors.spot_of(Game.state, id) == spot:
			used = true
	visible = used
	process_mode = Node.PROCESS_MODE_INHERIT if used else Node.PROCESS_MODE_DISABLED
