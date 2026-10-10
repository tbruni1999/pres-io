class_name NeighborPanel
extends GamePanel
## Charla con un loco: el capítulo de hoy (o una frase suelta) y lo suyo:
## la manta de Salim (al contado, precios que suben) o el pizarrón de Raúl.

var _id := ""
var _title: Label
var _line: Label
var _content := VBoxContainer.new()
var _feedback: Label


func _init() -> void:
	super()
	_title = UIKit.title("")
	body.add_child(_title)
	_line = UIKit.label("", 18, UIKit.COLOR_TEXT, true)
	_line.custom_minimum_size = Vector2(520, 0)
	body.add_child(_line)
	_content.add_theme_constant_override("separation", 8)
	body.add_child(_content)
	_feedback = UIKit.label("", 17, UIKit.COLOR_ACCENT, true)
	body.add_child(_feedback)
	body.add_child(UIKit.button(Texts.t("UI_CLOSE"), request_close))


func on_open(args: Dictionary) -> void:
	_id = String(args.get("id", ""))
	_title.text = Texts.t("NPC_" + _id.to_upper())
	var key := Game.talk_neighbor(_id)
	_line.text = "«%s»" % (Texts.t(key) if not key.is_empty() else ui.quip(_id.to_upper(), "QUIP"))
	_feedback.text = ""
	refresh()


func refresh() -> void:
	UIKit.clear(_content)
	match _id:
		"salim":
			_shop()
		"raul":
			_board()


func _shop() -> void:
	var s := Game.state
	_content.add_child(UIKit.label(Texts.t("SHOP_NO_CREDIT"), 14, UIKit.COLOR_MUTED, true))
	var ids := Neighbors.SALIM_STOCK.keys()
	ids.sort()
	for item_id in ids:
		var price := Neighbors.salim_price_cents(s, item_id)
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label(Texts.t("ITEM_" + String(item_id).to_upper()), 18))
		info.add_child(UIKit.label(Texts.t("SHOP_" + String(item_id).to_upper()), 14, UIKit.COLOR_MUTED, true))
		row.add_child(info)
		var b := UIKit.button(Texts.t("SHOP_BUY", {"price": Money.format(price)}), _buy.bind(item_id))
		b.disabled = price > s.player.wallet_cents or (item_id == "umbrella" and s.player.has_tool("umbrella"))
		row.add_child(b)
		_content.add_child(row)


func _board() -> void:
	_content.add_child(UIKit.section(Texts.t("RAUL_BOARD_TITLE")))
	var lines := Neighbors.raul_board(Game.state, Game.content)
	for line in lines:
		_content.add_child(UIKit.label("· " + Texts.t(line["key"], line["params"]), 17, UIKit.COLOR_TEXT, true))
	if lines.size() <= 1:
		_content.add_child(UIKit.label(Texts.t("RAUL_BOARD_EMPTY"), 15, UIKit.COLOR_MUTED, true))


func _buy(item_id: String) -> void:
	var r := Game.salim_buy(item_id)
	_feedback.text = r.message
	if r.ok:
		_line.text = "«%s»" % ui.quip("SALIM", "QUIP")
	ui.play_feedback(r.ok)
	refresh()
