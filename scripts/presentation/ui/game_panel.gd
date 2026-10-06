class_name GamePanel
extends PanelContainer
## Base de los paneles modales. UIRoot se ocupa de cursor, pausa y foco;
## cada panel solo arma su contenido y pide cerrarse.

signal close_requested

var ui: UIRoot
var body := VBoxContainer.new()


func _init() -> void:
	custom_minimum_size = Vector2(560, 0)
	body.add_theme_constant_override("separation", 10)
	add_child(body)
	visible = false


## Se llama cada vez que el panel se abre.
func on_open(_args: Dictionary) -> void:
	pass


func on_close() -> void:
	pass


## Escape cierra el panel activo; un panel puede interceptarlo devolviendo true.
func handle_back() -> bool:
	return false


func request_close() -> void:
	close_requested.emit()
