class_name Activity
extends RefCounted
## Una tarea en curso del jugador (pescar, martillar, talar, mantener E).
## Mientras dura, el jugador no camina, pero el tiempo del juego SIGUE corriendo.
## UIRoot la crea, le reenvía E y Esc, y la cancela si hace falta.

signal finished

var ui: UIRoot
var title: String = ""
var done := false


func begin() -> void:
	pass


func process(_delta: float) -> void:
	pass


## E apretada. Devuelve true si la usó.
func on_interact() -> bool:
	return false


func cancel() -> void:
	end()


func end() -> void:
	if done:
		return
	done = true
	ui.skill_check.stop()
	finished.emit()


## Texto de estado bajo la mira (vacío = nada).
func status_text() -> String:
	return title


## Progreso 0..1 para la barra de "mantener E" (negativo = no se muestra).
func progress() -> float:
	return -1.0
