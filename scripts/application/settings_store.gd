class_name SettingsStore
extends RefCounted
## Ajustes del jugador, separados de las partidas (user://settings.cfg).

signal changed

const PATH := "user://settings.cfg"
const FOV_MIN := 65.0
const FOV_MAX := 100.0

## Grados de giro por píxel de movimiento del mouse.
var mouse_sensitivity: float = 0.12
var invert_y: bool = false
## Campo de visión HORIZONTAL en grados, referido a una pantalla 16:9.
## Se convierte al FOV vertical que usa Camera3D (ver PlayerController).
var fov_horizontal: float = 80.0
var volume_master: float = 0.8
var volume_ambient: float = 0.7
var volume_effects: float = 0.8


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = clampf(float(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)), 0.02, 0.6)
	invert_y = bool(cfg.get_value("controls", "invert_y", invert_y))
	fov_horizontal = clampf(float(cfg.get_value("video", "fov_horizontal", fov_horizontal)), FOV_MIN, FOV_MAX)
	volume_master = clampf(float(cfg.get_value("audio", "master", volume_master)), 0.0, 1.0)
	volume_ambient = clampf(float(cfg.get_value("audio", "ambient", volume_ambient)), 0.0, 1.0)
	volume_effects = clampf(float(cfg.get_value("audio", "effects", volume_effects)), 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("video", "fov_horizontal", fov_horizontal)
	cfg.set_value("audio", "master", volume_master)
	cfg.set_value("audio", "ambient", volume_ambient)
	cfg.set_value("audio", "effects", volume_effects)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("No se pudieron guardar los ajustes: %s" % error_string(err))


func apply_audio() -> void:
	_set_bus("Master", volume_master)
	_set_bus("Ambiente", volume_ambient)
	_set_bus("Efectos", volume_effects)


## Aplica un cambio en vivo. El archivo se escribe al cerrar el menú (save_settings).
func notify_changed() -> void:
	apply_audio()
	changed.emit()


static func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.0001)
