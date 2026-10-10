class_name TradePanel
extends GamePanel
## Comerciar con quien frenó frente a la choza. Cada comerciante tiene sus frases.

var _pass_id := -1
var _merchant: MerchantDefinition
var _title: Label
var _quip: Label
var _sell := VBoxContainer.new()
var _buy := VBoxContainer.new()
var _feedback: Label


func _init() -> void:
	super()
	custom_minimum_size = Vector2(720, 0)
	_title = UIKit.title("")
	body.add_child(_title)
	_quip = UIKit.label("", 20, UIKit.COLOR_TEXT, true)
	_quip.custom_minimum_size = Vector2(680, 0)
	body.add_child(_quip)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	for box: VBoxContainer in [_sell, _buy]:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 6)
		cols.add_child(box)
	body.add_child(cols)
	_feedback = UIKit.label("", 17, UIKit.COLOR_ACCENT, true)
	_feedback.custom_minimum_size = Vector2(680, 0)
	body.add_child(_feedback)
	body.add_child(UIKit.button(Texts.t("TRADE_DONE"), request_close))


func on_open(args: Dictionary) -> void:
	_pass_id = int(args.get("pass_id", -1))
	var p := Game.state.camp.find_pass(_pass_id)
	_merchant = Game.content.find_merchant(String(p.get("merchant", "")))
	if _merchant == null:
		request_close.call_deferred()
		return
	_title.text = _cap(Texts.t(_merchant.name_key))
	# Historia por entregas: un capítulo por visita; después, saludos sueltos.
	var visit := Game.begin_merchant_visit(_pass_id)
	if visit >= 1 and visit <= Merchants.EPISODES:
		_quip.text = "«%s»" % Texts.t("%s_EP_%d" % [_merchant.lines_prefix, visit])
		_title.text += "   ·   " + Texts.t("TRADE_EPISODE", {"n": visit, "total": Merchants.EPISODES})
		if visit == Merchants.EPISODES and not _merchant.story_end_fact.is_empty():
			ui.post_notice.call_deferred(Texts.t("MSG_STORY_END_" + _merchant.story_end_fact.to_upper()))
	else:
		_quip.text = "«%s»" % ui.quip(_merchant.lines_prefix, "GREET")
	_feedback.text = ""
	refresh()


func on_close() -> void:
	if _pass_id < 0:
		return
	var had_sale := int(Game.state.camp.find_pass(_pass_id).get("bought", 0)) > 0
	Game.dismiss_merchant(_pass_id)
	var kind := "BYE" if had_sale else "NOTHING"
	ui.post_notice("%s: «%s»" % [_cap(Texts.t(_merchant.name_key)), ui.quip(_merchant.lines_prefix, kind)])
	_pass_id = -1


func refresh() -> void:
	var s := Game.state
	var p := s.camp.find_pass(_pass_id)
	UIKit.clear(_sell)
	UIKit.clear(_buy)
	_sell.add_child(UIKit.section(Texts.t("TRADE_SELL")))
	var room := _merchant.max_buy - int(p.get("bought", 0))
	_sell.add_child(UIKit.label(Texts.t("TRADE_ROOM", {"n": room}) if room > 0 else Texts.t("TRADE_FULL"), 15, UIKit.COLOR_MUTED))
	var c := s.camp.craving
	if not c.is_empty() and c["merchant"] == _merchant.id:
		var cdef := Game.content.find_item(String(c["item"]))
		_sell.add_child(UIKit.label(Texts.t("MSG_CRAVING", {"name": _cap(Texts.t(_merchant.name_key)), "item": Texts.t(cdef.name_key)}), 15, UIKit.COLOR_ACCENT, true))
	var any := false
	for item_id in _sorted(_merchant.buys.keys()):
		var n := s.player.count(item_id)
		if n <= 0:
			continue
		any = true
		var def := Game.content.find_item(item_id)
		var price := Merchants.buy_price_today(s, Game.content, _merchant.id, item_id)
		var craving := Merchants.is_craving(s, _merchant.id, item_id)
		var row_text := Texts.t("TRADE_SELL_ROW", {"name": Texts.t(def.name_key), "n": n, "price": Money.format(price)})
		if craving:
			row_text += " · " + Texts.t("TRADE_CRAVING")
		_sell.add_child(UIKit.label(row_text, 18, UIKit.COLOR_ACCENT if craving else UIKit.COLOR_TEXT))
		var qty := mini(n, maxi(room, 0))
		var b := UIKit.button(Texts.t("TRADE_SELL_BUTTON", {"total": Money.format(price * qty)}), _on_sell.bind(item_id, qty))
		b.disabled = qty <= 0
		_sell.add_child(b)
	if not any:
		_sell.add_child(UIKit.label(Texts.t("TRADE_NOTHING"), 16, UIKit.COLOR_MUTED, true))
	_buy.add_child(UIKit.section(Texts.t("TRADE_BUY")))
	for item_id in _sorted(_merchant.sells.keys()):
		var def := Game.content.find_item(item_id)
		var price := _merchant.sell_price_cents(item_id)
		var owned := def.kind == ItemDefinition.Kind.TOOL and s.player.has_tool(item_id)
		var text := Texts.t("TRADE_BUY_ROW", {"name": Texts.t(def.name_key), "price": Money.format(price)})
		var b := UIKit.button(Texts.t("TRADE_OWNED") + " · " + Texts.t(def.name_key) if owned else text, _on_buy.bind(item_id))
		b.disabled = owned
		_buy.add_child(b)


func _on_sell(item_id: String, qty: int) -> void:
	var r := Game.sell_to_merchant(_pass_id, item_id, qty)
	_feedback.text = r.message
	if r.ok:
		_quip.text = "«%s»" % ui.quip(_merchant.lines_prefix, "SMOKED" if item_id.ends_with("_smoked") else "SOLD")
	ui.play_feedback(r.ok)
	refresh()


func _on_buy(item_id: String) -> void:
	var r := Game.buy_from_merchant(_pass_id, item_id)
	_feedback.text = r.message
	if r.ok:
		_quip.text = "«%s»" % ui.quip(_merchant.lines_prefix, "BUY")
	ui.play_feedback(r.ok)
	refresh()


static func _sorted(keys: Array) -> Array:
	var k := keys.duplicate()
	k.sort()
	return k


static func _cap(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)
