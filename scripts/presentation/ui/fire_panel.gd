class_name FirePanel
extends GamePanel
## Fogón: echar leña, hervir agua, asar pescado y, si te quedaste sin caña, armar una.
## El fuego arde con leña y se apaga solo (o con la lluvia, si no tiene lona).

var _content := VBoxContainer.new()
var _feedback: Label


func _init() -> void:
	super()
	body.add_child(UIKit.title(Texts.t("FIRE_TITLE")))
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
	var lit := Simulation.fire_lit(s)
	var status := Texts.t("FIRE_STATUS_OUT")
	if lit:
		var until_min := DayTime.minute_of_day(s, c) + DayTime.ticks_to_minutes(s, c, s.camp.fire_until - s.tick)
		status = Texts.t("FIRE_STATUS_LIT", {"time": DayTime.format_clock(fmod(until_min, 1440.0))})
	_content.add_child(UIKit.label(status, 19, UIKit.COLOR_ACCENT if lit else UIKit.COLOR_BAD))
	_content.add_child(UIKit.label(Texts.t("FIRE_WOOD", {"n": s.camp.wood}), 17, UIKit.COLOR_MUTED))
	if Weather.is_raining(s) and not s.camp.has_building("tarp"):
		_content.add_child(UIKit.label(Texts.t("FIRE_RAIN_HINT"), 15, UIKit.COLOR_MUTED, true))
	var add := UIKit.button(Texts.t("FIRE_ADD_WOOD"), _do.bind(func() -> CommandResult: return Game.add_wood()))
	add.disabled = s.camp.wood < 1
	_content.add_child(add)
	var boil := UIKit.button(Texts.t("FIRE_BOIL"), _do.bind(func() -> CommandResult: return Game.boil_water()))
	boil.disabled = not lit
	_content.add_child(boil)
	for fish_id in ["fish_small", "fish_big"]:
		if s.player.count(fish_id) <= 0:
			continue
		var def := c.find_item(fish_id)
		var b := UIKit.button(Texts.t("FIRE_COOK", {"name": Texts.t(def.name_key)}), _do.bind(func() -> CommandResult: return Game.cook_and_eat(fish_id)))
		b.disabled = not lit
		_content.add_child(b)
	if PlayerActions.best_rod(s, c) == null:
		var rod := UIKit.button(Texts.t("FIRE_MAKE_ROD", {"n": c.balance.make_rod_wood}), _do.bind(func() -> CommandResult: return Game.make_rod()))
		rod.disabled = s.camp.wood < c.balance.make_rod_wood
		_content.add_child(rod)


func _do(action: Callable) -> void:
	var r: CommandResult = action.call()
	_feedback.text = r.message
	ui.play_feedback(r.ok)
	refresh()
