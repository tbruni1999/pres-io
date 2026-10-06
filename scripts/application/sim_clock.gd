class_name SimClock
extends RefCounted
## Reloj administrativo de pasos fijos, independiente de los fotogramas y de la hora del equipo.
## Si un fotograma trae más pasos que el máximo, el excedente queda pendiente para los
## siguientes fotogramas (nunca se descarta) y se registra el atraso.

var step_seconds: float = 1.0
var max_steps_per_frame: int = 4
var speed: float = 1.0
## Fotogramas que tuvieron que dejar pasos pendientes para después.
var lag_frames: int = 0
var _accumulator: float = 0.0


func configure(balance: BalanceConfig) -> void:
	step_seconds = maxf(balance.step_seconds, 0.001)
	max_steps_per_frame = maxi(balance.max_steps_per_frame, 1)


## Suma tiempo real y devuelve cuántos pasos ejecutar en este fotograma.
func consume(delta: float) -> int:
	_accumulator += maxf(delta, 0.0) * speed
	var due := int(floor(_accumulator / step_seconds))
	var steps := mini(due, max_steps_per_frame)
	if due > steps:
		lag_frames += 1
	_accumulator -= steps * step_seconds
	return steps


func pending_steps() -> int:
	return int(floor(_accumulator / step_seconds))


## Fracción del paso en curso (0..1), útil solo para presentación.
func step_fraction() -> float:
	return fposmod(_accumulator, step_seconds) / step_seconds


func reset() -> void:
	_accumulator = 0.0
	lag_frames = 0
