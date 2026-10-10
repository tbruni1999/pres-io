class_name Hud
extends Control
## HUD mínimo: día, plata, madera, mochila, hambre y sed, un objetivo, la acción y avisos.
## Se refresca 4 veces por segundo, no cada fotograma.

const NOTICE_SECONDS := 4.5

var _day_label: Label
var _day_bar: ProgressBar
var _money: Label
var _wood_bag: Label
var _hunger: ProgressBar
var _thirst: ProgressBar
var _objective: Label
var _crosshair: ColorRect
var _prompt: Label
var _status: Label
var _hold: ProgressBar
var _notices := VBoxContainer.new()
var _timer := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(16, 10)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_label = _outlined(UIKit.label("", 19))
	top_left.add_child(_day_label)
	_day_bar = _bar(Vector2(180, 6), Color(0.93, 0.7, 0.32))
	_day_bar.max_value = 10000
	top_left.add_child(_day_bar)
	_money = _outlined(UIKit.label("", 26, UIKit.COLOR_ACCENT))
	top_left.add_child(_money)
	_wood_bag = _outlined(UIKit.label("", 17))
	top_left.add_child(_wood_bag)
	add_child(top_left)

	var needs := VBoxContainer.new()
	needs.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	needs.position = Vector2(16, -70)
	needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hunger = _need_row(needs, Texts.t("HUD_HUNGER"), Color(0.9, 0.6, 0.3))
	_thirst = _need_row(needs, Texts.t("HUD_THIRST"), Color(0.35, 0.65, 0.95))
	add_child(needs)

	_objective = _outlined(UIKit.label("", 18, UIKit.COLOR_TEXT))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_objective.position.y = 12
	add_child(_objective)

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
	_prompt.position.y += 36
	add_child(_prompt)

	_hold = _bar(Vector2(220, 10), Color(0.95, 0.95, 0.95))
	_hold.max_value = 1.0
	_hold.set_anchors_preset(Control.PRESET_CENTER)
	_hold.position += Vector2(-110, 70)
	_hold.visible = false
	add_child(_hold)

	_status = _outlined(UIKit.label("", 20, UIKit.COLOR_ACCENT))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status.position.y -= 150
	add_child(_status)

	_notices.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notices.position = Vector2(-16, 12)
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notices)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		refresh()


func refresh() -> void:
	var s := Game.state
	var pl := s.player
	var clock := DayTime.format_clock(DayTime.minute_of_day(s, Game.content))
	var weather := Texts.t("WEATHER_" + s.camp.weather.to_upper())
	if Weather.is_raining(s):
		weather = Texts.t("HUD_RAINING")
	_day_label.text = Texts.t("HUD_DAY", {"day": s.current_day()}) + " · " + clock + " · " + weather + ("  " + Texts.t("HUD_PAUSED") if Game.is_paused() else "")
	_day_bar.value = s.day_progress_bp()
	_money.text = Money.format(pl.wallet_cents)
	_wood_bag.text = "%s   ·   %s" % [Texts.t("HUD_WOOD", {"n": s.camp.wood}), Texts.t("HUD_BAG", {"n": pl.bag_count(), "cap": PlayerActions.bag_capacity(s, Game.content)})]
	_hunger.value = pl.hunger_bp
	_thirst.value = pl.thirst_bp
	_objective.text = Objectives.current(s, Game.content)


func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = not text.is_empty()


func set_status(text: String, hold_progress: float) -> void:
	_status.text = text
	_hold.visible = hold_progress >= 0.0
	_hold.value = maxf(hold_progress, 0.0)


func set_crosshair_visible(v: bool) -> void:
	_crosshair.visible = v
	if not v:
		set_prompt("")


func post_notice(text: String) -> void:
	if text.is_empty():
		return
	var l := _outlined(UIKit.label(text, 18, UIKit.COLOR_ACCENT, true))
	l.custom_minimum_size = Vector2(420, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notices.add_child(l)
	while _notices.get_child_count() > 4:
		var old := _notices.get_child(0)
		_notices.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(NOTICE_SECONDS)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _need_row(parent: Control, text: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _outlined(UIKit.label(text, 16))
	l.custom_minimum_size = Vector2(70, 0)
	row.add_child(l)
	var bar := _bar(Vector2(170, 12), color)
	bar.max_value = PlayerState.FULL
	row.add_child(bar)
	parent.add_child(row)
	return bar


static func _bar(min_size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = min_size
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


static func _outlined(l: Label) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
