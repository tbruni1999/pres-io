class_name BagPanel
extends GamePanel
## Mochila (Tab): lo que llevás, comer y tomar, herramientas y desmayos.

var _content := VBoxContainer.new()
var _feedback: Label


func _init() -> void:
	super()
	body.add_child(UIKit.title(Texts.t("BAG_TITLE")))
	_content.add_theme_constant_override("separation", 6)
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
		names.append(Texts.t(Game.content.find_item(t).name_key))
	_content.add_child(UIKit.label(", ".join(names), 17))
	var next_bp := Simulation.faint_penalty_bp(pl.faint_count, Game.content.balance)
	_content.add_child(UIKit.label(Texts.t("BAG_FAINTS", {"n": pl.faint_count, "pct": Money.format_bp_percent(next_bp)}), 15, UIKit.COLOR_MUTED, true))


func _consume(item_id: String) -> void:
	var r := Game.consume(item_id)
	_feedback.text = r.message
	ui.play_feedback(r.ok)
	refresh()
