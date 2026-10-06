class_name Hud
extends Control
## HUD discreto: jornada, mira, acción disponible y avisos breves.
## Se actualiza por señales y por un temporizador de 4 Hz, no reconstruye cada fotograma.

const NOTICE_SECONDS := 5.0

var _day_label: Label
var _day_bar: ProgressBar
var _crosshair: ColorRect
var _prompt: Label
var _notices := VBoxContainer.new()
var _timer := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var day_box := VBoxContainer.new()
	day_box.position = Vector2(16, 12)
	day_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_label = _outlined(UIKit.label("", 20))
	day_box.add_child(_day_label)
	_day_bar = ProgressBar.new()
	_day_bar.custom_minimum_size = Vector2(200, 8)
	_day_bar.show_percentage = false
	_day_bar.max_value = 10000
	_day_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_box.add_child(_day_bar)
	add_child(day_box)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.85)
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position -= Vector2(2, 2)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	_prompt = _outlined(UIKit.label("", 22))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y += 40
	add_child(_prompt)

	_notices.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notices.position = Vector2(-16, 12)
	_notices.alignment = BoxContainer.ALIGNMENT_BEGIN
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notices)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		refresh_day()


func refresh_day() -> void:
	var s := Game.state
	var label := Texts.t("HUD_DAY", {"day": s.current_day()})
	if Game.is_paused():
		label += "  " + Texts.t("HUD_PAUSED")
	_day_label.text = label
	_day_bar.value = s.day_progress_bp()


func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = not text.is_empty()


func set_crosshair_visible(v: bool) -> void:
	_crosshair.visible = v
	if not v:
		set_prompt("")


func post_notice(text: String) -> void:
	var l := _outlined(UIKit.label(text, 18, UIKit.COLOR_ACCENT, true))
	l.custom_minimum_size = Vector2(380, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notices.add_child(l)
	while _notices.get_child_count() > 4:
		_notices.get_child(0).queue_free()
		_notices.remove_child(_notices.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(NOTICE_SECONDS)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


static func _outlined(l: Label) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
