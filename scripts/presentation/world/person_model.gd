extends Node3D
## Persona del juego (locos). Al cargar funde sus piezas por material y las mueve
## apenas, como si cambiara el peso de un pie al otro. Solo presentación.

@export var sway_deg: float = 0.7
@export var sway_speed: float = 0.8

var _t := 0.0


func _ready() -> void:
	MeshMerger.merge(self, PackedStringArray(), false)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta * sway_speed
	rotation_degrees.z = sin(_t) * sway_deg
