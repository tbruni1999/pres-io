class_name PauseMenu
extends GamePanel
## Pausa: continuar, guardar, cargar, ajustes, nueva partida y salir.

var _main := VBoxContainer.new()
var _settings := VBoxContainer.new()
var _status: Label
var _confirm_new := false
var _new_button: Button


func _init() -> void:
	super()
	custom_minimum_size = Vector2(480, 0)
	body.add_child(UIKit.title(Texts.t("PAUSE_TITLE")))
	_main.add_theme_constant_override("separation", 8)
	body.add_child(_main)
	_main.add_child(UIKit.button(Texts.t("PAUSE_RESUME"), request_close))
	_main.add_child(UIKit.button(Texts.t("PAUSE_SAVE"), _on_save))
	_main.add_child(UIKit.button(Texts.t("PAUSE_LOAD"), _on_load))
	_main.add_child(UIKit.button(Texts.t("PAUSE_SETTINGS"), _show_settings.bind(true)))
	_new_button = UIKit.button(Texts.t("PAUSE_NEW_GAME"), _on_new_game)
	_main.add_child(_new_button)
	_main.add_child(UIKit.button(Texts.t("PAUSE_QUIT"), func() -> void: get_tree().quit()))
	_build_settings()
	body.add_child(_settings)
	_status = UIKit.label("", 16, UIKit.COLOR_ACCENT, true)
	_status.custom_minimum_size = Vector2(440, 0)
	body.add_child(_status)


func on_open(_args: Dictionary) -> void:
	_status.text = Texts.t("PAUSE_SAVE_LOCATION", {"path": ProjectSettings.globalize_path(Game.saves.save_dir)})
	_reset_new_game()
	_show_settings(false)


func on_close() -> void:
	Game.settings.save_settings()


func handle_back() -> bool:
	if _settings.visible:
		_show_settings(false)
		return true
	return false


func _on_save() -> void:
	var r := Game.save_game()
	_status.text = r.message
	ui.play_feedback(r.ok)


func _on_load() -> void:
	var r := Game.load_game()
	ui.play_feedback(r.ok)
	if r.ok:
		ui.post_notice(r.message)
		request_close()
	else:
		_status.text = r.message


func _on_new_game() -> void:
	if not _confirm_new:
		_confirm_new = true
		_new_button.text = Texts.t("PAUSE_NEW_GAME_CONFIRM")
		return
	Game.new_game()
	ui.post_notice(Texts.t("MSG_NEW_GAME"))
	request_close()


func _reset_new_game() -> void:
	_confirm_new = false
	_new_button.text = Texts.t("PAUSE_NEW_GAME")


func _show_settings(show_it: bool) -> void:
	_settings.visible = show_it
	_main.visible = not show_it


func _build_settings() -> void:
	var st := Game.settings
	_settings.add_theme_constant_override("separation", 8)
	_settings.add_child(UIKit.section(Texts.t("SETTINGS_TITLE")))
	_add_slider("SETTINGS_SENSITIVITY", 0.02, 0.6, 0.01, st.mouse_sensitivity, func(v: float) -> void: st.mouse_sensitivity = v, "%.2f")
	_add_slider("SETTINGS_FOV", SettingsStore.FOV_MIN, SettingsStore.FOV_MAX, 1.0, st.fov_horizontal, func(v: float) -> void: st.fov_horizontal = v, "%d°")
	var invert := CheckBox.new()
	invert.text = Texts.t("SETTINGS_INVERT_Y")
	invert.button_pressed = st.invert_y
	invert.toggled.connect(func(on: bool) -> void:
		st.invert_y = on
		st.notify_changed())
	_settings.add_child(invert)
	_add_slider("SETTINGS_VOLUME_MASTER", 0.0, 1.0, 0.05, st.volume_master, func(v: float) -> void: st.volume_master = v, "%.2f")
	_add_slider("SETTINGS_VOLUME_AMBIENT", 0.0, 1.0, 0.05, st.volume_ambient, func(v: float) -> void: st.volume_ambient = v, "%.2f")
	_add_slider("SETTINGS_VOLUME_EFFECTS", 0.0, 1.0, 0.05, st.volume_effects, func(v: float) -> void: st.volume_effects = v, "%.2f")
	_settings.add_child(UIKit.label(Texts.t("SETTINGS_FOV_NOTE"), 14, UIKit.COLOR_MUTED, true))
	_settings.add_child(UIKit.button(Texts.t("UI_BACK"), _show_settings.bind(false)))


func _add_slider(key: String, min_v: float, max_v: float, step: float, value: float, setter: Callable, fmt: String) -> void:
	var row := HBoxContainer.new()
	var name_label := UIKit.label(Texts.t(key), 17, UIKit.COLOR_MUTED)
	name_label.custom_minimum_size = Vector2(220, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(160, 28)
	row.add_child(slider)
	var value_label := UIKit.label(fmt % value, 17)
	value_label.custom_minimum_size = Vector2(56, 0)
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		value_label.text = fmt % v
		Game.settings.notify_changed())
	_settings.add_child(row)
