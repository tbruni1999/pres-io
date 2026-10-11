class_name FirePanel
extends GamePanel
## Fogón: echar leña, hervir agua, asar pescado y, si te quedaste sin caña, armar una.
## Cada botón dice qué hace o, si está apagado, qué falta.

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
		# Hora absoluta: si pasa de las 24:00, el día siguiente arranca a las 06:00 sin hueco.
		var ft := s.camp.fire_until
		var tpd := s.ticks_per_day
		var b := c.balance
		var until_min := b.day_start_minute + float(ft % tpd) * (b.day_end_minute - b.day_start_minute) / tpd
		status = Texts.t("FIRE_STATUS_LIT", {"time": DayTime.format_clock(until_min)})
		if ft / tpd > s.tick / tpd:
			status += " " + Texts.t("FIRE_TOMORROW")
	_content.add_child(UIKit.label(status, 19, UIKit.COLOR_ACCENT if lit else UIKit.COLOR_BAD))
	_content.add_child(UIKit.label(Texts.t("FIRE_WOOD", {"n": s.camp.wood}), 17, UIKit.COLOR_MUTED))
	if Weather.is_raining(s) and not s.camp.has_building("tarp"):
		_content.add_child(UIKit.label(Texts.t("FIRE_RAIN_HINT"), 15, UIKit.COLOR_MUTED, true))

	var full := lit and s.camp.fire_until - s.tick >= c.balance.fire_max_ticks
	var wet := not Simulation.fire_sheltered_or_dry(s)
	var add := UIKit.button(_add_wood_text(s, full, wet), _do.bind(func() -> CommandResult: return Game.add_wood()))
	add.disabled = s.camp.wood < 1 or full or wet
	_content.add_child(add)

	var boil := UIKit.button(Texts.t("FIRE_BOIL_OK" if lit else "FIRE_BOIL_OUT"), _do.bind(func() -> CommandResult: return Game.boil_water()))
	boil.disabled = not lit
	_content.add_child(boil)

	for fish_id in ["fish_small", "fish_big"]:
		if s.player.count(fish_id) <= 0:
			continue
		var def := c.find_item(fish_id)
		var key := "FIRE_COOK" if lit else "FIRE_COOK_OUT"
		var b := UIKit.button(Texts.t(key, {"name": Texts.t(def.name_key)}), _do.bind(func() -> CommandResult: return Game.cook_and_eat(fish_id)))
		b.disabled = not lit
		_content.add_child(b)

	if PlayerActions.best_rod(s, c) == null:
		var need := c.balance.make_rod_wood
		var rod_text := Texts.t("FIRE_MAKE_ROD_OK", {"n": need}) if s.camp.wood >= need else Texts.t("FIRE_MAKE_ROD_NO", {"missing": need - s.camp.wood})
		var rod := UIKit.button(rod_text, _do.bind(func() -> CommandResult: return Game.make_rod()))
		rod.disabled = s.camp.wood < need
		_content.add_child(rod)


func _add_wood_text(s: GameState, full: bool, wet: bool) -> String:
	if s.camp.wood < 1:
		return Texts.t("FIRE_ADD_WOOD_NONE")
	if wet:
		return Texts.t("FIRE_ADD_WOOD_RAIN")
	if full:
		return Texts.t("FIRE_ADD_WOOD_FULL")
	return Texts.t("FIRE_ADD_WOOD_OK", {"n": s.camp.wood})


func _do(action: Callable) -> void:
	var r: CommandResult = action.call()
	_feedback.text = r.message
	ui.play_feedback(r.ok)
	refresh()
