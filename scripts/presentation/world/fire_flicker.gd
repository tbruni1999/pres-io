extends OmniLight3D
## Parpadeo cosmético de la luz del fuego (no consume el generador de la partida).
## DayNight fija la energía según la hora en la meta "night_energy"; acá se le suma el temblor.

@export var amount: float = 0.25
@export var speed: float = 9.0

var _t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.frequency = 0.8


func _process(delta: float) -> void:
	_t += delta * speed
	var target := float(get_meta("night_energy", light_energy))
	light_energy = maxf(0.0, target * (1.0 + _noise.get_noise_1d(_t) * amount))
