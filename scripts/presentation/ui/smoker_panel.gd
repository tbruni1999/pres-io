class_name SmokerPanel
extends GamePanel
## Ahumadero: cargar pescado crudo (1 madera) y sacar lo ahumado cuando está listo.

var _content := VBoxContainer.new()
var _feedback: Label


func _init() -> void:
	super()
	body.add_child(UIKit.title(Texts.t("SMOKER_TITLE")))
	_content.add_theme_constant_override("separation", 8)
	body.add_child(_content)
	_feedback = UIKit.label("", 17, UIKit.COLOR_ACCENT, true)
	_feedback.custom_minimum_size = Vector2(500, 0)
	body.add_child(_feedback)
	body.add_child(UIKit.button(Texts.t("UI_CLOSE"), request_close))


func on_open(_args: Dictionary) -> void:
	_feedback.text = ""
	refresh()


func refresh() -> void:
	UIKit.clear(_content)
	var s := Game.state
	var c := Game.content
	match PlayerActions.smoker_status(s):
		PlayerActions.SMOKER_EMPTY:
			_content.add_child(UIKit.label(Texts.t("SMOKER_EMPTY", {"cap": c.balance.smoker_capacity}), 18, UIKit.COLOR_TEXT, true))
			var b := UIKit.button(Texts.t("SMOKER_LOAD"), _do.bind(func() -> CommandResult: return Game.load_smoker()))
			_content.add_child(b)
		PlayerActions.SMOKER_SMOKING:
			_content.add_child(UIKit.label(Texts.t("SMOKER_SMOKING", {"n": s.camp.smoker_count(), "time": ready_time(s, c)}), 18, UIKit.COLOR_TEXT, true))
		PlayerActions.SMOKER_READY:
			_content.add_child(UIKit.label(Texts.t("SMOKER_READY", {"n": s.camp.smoker_count()}), 18, UIKit.COLOR_GOOD, true))
			_content.add_child(UIKit.button(Texts.t("SMOKER_COLLECT"), _do.bind(func() -> CommandResult: return Game.collect_smoker())))
	_content.add_child(UIKit.label(Texts.t("FIRE_WOOD", {"n": s.camp.wood}), 15, UIKit.COLOR_MUTED))
	_content.add_child(UIKit.label(Texts.t("SMOKER_HINT"), 15, UIKit.COLOR_MUTED, true))


## Hora de juego a la que estará lista la tanda (si cae al día siguiente, igual se muestra la hora).
static func ready_time(s: GameState, c: GameContent) -> String:
	var left := maxi(0, s.camp.smoker_ready_tick - s.tick)
	var m := DayTime.minute_of_day(s, c) + DayTime.ticks_to_minutes(s, c, left)
	if m >= c.balance.day_end_minute:
		m = c.balance.day_start_minute + (m - c.balance.day_end_minute)
	return DayTime.format_clock(m)


func _do(action: Callable) -> void:
	var r: CommandResult = action.call()
	_feedback.text = r.message
	ui.play_feedback(r.ok)
	refresh()
