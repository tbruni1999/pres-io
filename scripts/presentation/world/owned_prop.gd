extends Node3D
## Objeto del mundo que aparece cuando el personaje tiene esa herramienta (ej. la bici).

@export var item_id: String = ""


func _ready() -> void:
	Game.player_changed.connect(_refresh)
	Game.state_replaced.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = Game.state.player.has_tool(item_id)
