class_name BagPanel
extends GamePanel
## Mochila (Tab): lo que llevás, comer y tomar, herramientas (con sus usos), acopio,
## desmayos y la meta de la etapa (fundar el pueblito).

var _content := VBoxContainer.new()
var _goal := VBoxContainer.new()
var _feedback: Label


func _init() -> void:
	super()
	body.add_child(UIKit.title(Texts.t("BAG_TITLE")))
	_content.add_theme_constant_override("separation", 6)
	_goal.add_theme_constant_override("separation", 6)
	# Dos columnas: lo que llevás a la izquierda, la meta de la etapa a la derecha.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	_content.custom_minimum_size = Vector2(430, 0)
	_goal.custom_minimum_size = Vector2(360, 0)
	cols.add_child(_content)
	cols.add_child(_goal)
	body.add_child(cols)
	_feedback = UIKit.label("", 17, UIKit.COLOR_ACCENT, true)
	_feedback.custom_minimum_size = Vector2(500, 0)
	body.add_child(_feedback)
	body.add_child(UIKit.button(Texts.t("UI_CLOSE"), request_close))


func on_open(_args: Dictionary) -> void:
	_feedback.text = ""
	refresh()


func refresh() -> void:
	UIKit.clear(_content)
	UIKit.clear(_goal)
	var s := Game.state
	var pl := s.player
	_content.add_child(UIKit.label(Texts.t("HUD_BAG", {"n": pl.bag_count(), "cap": PlayerActions.bag_capacity(s, Game.content)}), 17, UIKit.COLOR_MUTED))
	if pl.bag.is_empty():
		_content.add_child(UIKit.label(Texts.t("BAG_EMPTY"), 17, UIKit.COLOR_MUTED))
	var keys := pl.bag.keys()
	keys.sort()
	for item_id in keys:
		var def := Game.content.find_item(item_id)
		var row := HBoxContainer.new()
		var l := UIKit.label(Texts.t("BAG_ROW", {"name": Texts.t(def.name_key), "n": pl.count(item_id)}), 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if def.food_bp > 0 or def.drink_bp > 0:
			var key := "BAG_DRINK" if def.drink_bp > def.food_bp else "BAG_EAT"
			row.add_child(UIKit.button(Texts.t(key), _consume.bind(item_id)))
		_content.add_child(row)
	_content.add_child(UIKit.label(Texts.t("BAG_ROTS"), 14, UIKit.COLOR_MUTED, true))
	_content.add_child(UIKit.section(Texts.t("BAG_TOOLS")))
	var names: PackedStringArray = []
	for t in pl.tools:
		var tname := Texts.t(Game.content.find_item(t).name_key)
		names.append(Texts.t("BAG_USES", {"name": tname, "n": pl.tool_wear[t]}) if pl.tool_wear.has(t) else tname)
	_content.add_child(UIKit.label(", ".join(names), 17, UIKit.COLOR_TEXT, true))
	_content.add_child(UIKit.section(Texts.t("BAG_STORAGE")))
	var stored: PackedStringArray = []
	var skeys := s.camp.storage.keys()
	skeys.sort()
	for id in skeys:
		stored.append(Texts.t("BAG_ROW", {"name": Texts.t(Game.content.find_item(id).name_key), "n": s.camp.storage[id]}))
	_content.add_child(UIKit.label(", ".join(stored) if not stored.is_empty() else Texts.t("BAG_STORAGE_EMPTY"), 17, UIKit.COLOR_TEXT if not stored.is_empty() else UIKit.COLOR_MUTED))
	var next_bp := Simulation.faint_penalty_bp(pl.faint_count, Game.content.balance)
	_content.add_child(UIKit.label(Texts.t("BAG_FAINTS", {"n": pl.faint_count, "pct": Money.format_bp_percent(next_bp)}), 15, UIKit.COLOR_MUTED, true))
	if not StageGoal.is_founded(s):
		_add_goal(s)


func _add_goal(s: GameState) -> void:
	_goal.add_child(UIKit.section(Texts.t("GOAL_TITLE")))
	for r in StageGoal.requirements(s, Game.content):
		var label_text := Texts.t(r["key"])
		if r.has("item"):
			label_text = Texts.t(Game.content.find_item(r["item"]).name_key)
		var value := Texts.t("GOAL_ROW", {"have": r["have"], "need": r["need"]})
		if r.get("money", false):
			value = "%s / %s" % [Money.format(r["have"]), Money.format(r["need"])]
		elif r["key"] == "GOAL_DEED":
			value = "✓" if r["ok"] else "—"
		_goal.add_child(UIKit.row(label_text, value, UIKit.COLOR_GOOD if r["ok"] else UIKit.COLOR_BAD))
	_goal.add_child(UIKit.label(Texts.t("GOAL_HINT"), 14, UIKit.COLOR_MUTED, true))
	if StageGoal.is_complete(s, Game.content):
		_goal.add_child(UIKit.button(Texts.t("GOAL_FOUND"), _found))


func _found() -> void:
	var r := Game.found_pueblo()
	ui.play_feedback(r.ok)
	if not r.ok:
		_feedback.text = r.message
		return
	ui.open_panel(ui.message, {"title": Texts.t("FOGON_TITLE"), "text": Texts.t("FOGON_BODY"), "extra": Texts.t("FOGON_NEXT")})


func _consume(item_id: String) -> void:
	var r := Game.consume(item_id)
	_feedback.text = r.message
	ui.play_feedback(r.ok)
	refresh()
