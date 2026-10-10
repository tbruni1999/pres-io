class_name ReportPanel
extends GamePanel
## Fin del día (dormir o desmayo): cuatro números y un chiste.

var _content := VBoxContainer.new()


func _init() -> void:
	super()
	_content.add_theme_constant_override("separation", 6)
	body.add_child(_content)
	body.add_child(HSeparator.new())
	body.add_child(UIKit.button(Texts.t("UI_CONTINUE"), request_close))


func on_open(args: Dictionary) -> void:
	UIKit.clear(_content)
	var rep := args.get("report") as DayReport
	if rep == null:
		return
	var faint := rep.fainted
	var title := Texts.t("REPORT_DAY_END", {"day": rep.day})
	if faint:
		title = Texts.t("REPORT_FAINT_TITLE")
	elif rep.slept_outside:
		title = Texts.t("REPORT_SLEPT_OUT_TITLE")
	_content.add_child(UIKit.title(title))
	# Lo que pasó antes de dormir y al cerrar (misterio, zorro, vecinos, espinel).
	for e in rep.events:
		_content.add_child(UIKit.label(Texts.t(String(e["key"]), {"n": e["n"]}), 17, UIKit.COLOR_TEXT, true))
	if not rep.events.is_empty():
		_content.add_child(HSeparator.new())
	_content.add_child(UIKit.row(Texts.t("REPORT_EARNED"), "+" + Money.format(rep.earned_cents), UIKit.COLOR_GOOD))
	_content.add_child(UIKit.row(Texts.t("REPORT_SPENT"), "-" + Money.format(rep.spent_cents - rep.faint_penalty_cents), UIKit.COLOR_BAD))
	if faint:
		_content.add_child(UIKit.row(Texts.t("REPORT_FAINT_LOSS"), "-" + Money.format(rep.faint_penalty_cents), UIKit.COLOR_BAD))
	_content.add_child(UIKit.row(Texts.t("REPORT_FISH"), _fish(rep.fish_caught)))
	if rep.rotten > 0:
		_content.add_child(UIKit.row(Texts.t("REPORT_ROTTEN"), _fish(rep.rotten), UIKit.COLOR_BAD))
	_content.add_child(UIKit.row(Texts.t("REPORT_WALLET"), Money.format(rep.wallet_end_cents), UIKit.COLOR_ACCENT))
	if rep.slept_outside and not faint:
		_content.add_child(UIKit.label(Texts.t("REPORT_SLEPT_OUT_LINE"), 16, UIKit.COLOR_BAD, true))
	var quip := ui.quip("REPORT", "QUIP")
	if faint:
		quip = ui.quip("FAINT", "QUIP")
	elif rep.slept_outside:
		quip = ui.quip("SLEPT_OUT", "QUIP")
	elif rep.rotten > 0:
		quip = Texts.t("REPORT_QUIP_ROTTEN")
	_content.add_child(UIKit.label(quip, 18, UIKit.COLOR_TEXT, true))
	_content.add_child(HSeparator.new())
	_content.add_child(UIKit.label(tomorrow(Game.state, Game.content), 16, UIKit.COLOR_ACCENT, true))


## Qué trae el día nuevo: el clima y el antojo de algún comerciante.
static func tomorrow(s: GameState, c: GameContent) -> String:
	var text := Texts.t("MSG_WEATHER_" + s.camp.weather.to_upper())
	var cr := s.camp.craving
	if not cr.is_empty():
		var m := c.find_merchant(String(cr["merchant"]))
		text += " " + Texts.t("MSG_CRAVING", {"name": TradePanel._cap(Texts.t(m.name_key)), "item": Texts.t(c.find_item(String(cr["item"])).name_key)})
	return text


static func _fish(n: int) -> String:
	return Texts.t("VAL_FISH_ONE") if n == 1 else Texts.t("VAL_FISH", {"n": n})
