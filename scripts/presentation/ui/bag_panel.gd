class_name BagPanel
extends GamePanel
## Inventario (Tab o E en una estantería): la mochila como celdas con dibujos, las herramientas
## con sus usos, el acopio en una tabla, comer y tomar, desmayos y la meta de la etapa.

var _content := VBoxContainer.new()
var _goal := VBoxContainer.new()
var _feedback: Label

const COLS := 6
const SLOT := Vector2(64, 64)


func _init() -> void:
	super()
	body.add_child(UIKit.title(Texts.t("BAG_TITLE")))
	_content.add_theme_constant_override("separation", 8)
	_goal.add_theme_constant_override("separation", 6)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	_content.custom_minimum_size = Vector2(460, 0)
	_goal.custom_minimum_size = Vector2(340, 0)
	cols.add_child(_content)
	cols.add_child(_goal)
	# Desplazable: en 720p el inventario completo no entra y "Cerrar" tiene que seguir a la vista.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(cols)
	body.add_child(scroll)
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
	var cap := PlayerActions.bag_capacity(s, Game.content)
	_content.add_child(UIKit.section(Texts.t("BAG_SECTION", {"n": pl.bag_count(), "cap": cap})))
	_content.add_child(_bag_grid(pl, cap))
	if pl.bag.is_empty():
		_content.add_child(UIKit.label(Texts.t("BAG_EMPTY"), 15, UIKit.COLOR_MUTED))
	_content.add_child(UIKit.section(Texts.t("BAG_STORAGE")))
	_content.add_child(_shelf_row(s))

	_content.add_child(UIKit.section(Texts.t("BAG_TOOLS")))
	_content.add_child(_tools_row(pl))

	_content.add_child(_consumables(pl))
	_content.add_child(UIKit.label(Texts.t("BAG_ROTS"), 14, UIKit.COLOR_MUTED, true))

	var next_bp := Simulation.faint_penalty_bp(pl.faint_count, Game.content.balance)
	_content.add_child(UIKit.label(Texts.t("BAG_FAINTS", {"n": pl.faint_count, "pct": Money.format_bp_percent(next_bp)}), 15, UIKit.COLOR_MUTED, true))
	if not StageGoal.is_founded(s):
		_add_goal(s)


## Celdas de la mochila: una por unidad, con el dibujo del objeto; lo que falta, celdas vacías.
func _bag_grid(pl: PlayerState, cap: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var ids := pl.bag.keys()
	ids.sort()
	var used := 0
	for id in ids:
		for i in pl.count(id):
			grid.add_child(_slot(id, true))
			used += 1
	for i in maxi(0, cap - used):
		grid.add_child(_slot("", false))
	return grid


func _slot(id: String, filled: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = SLOT
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.16, 0.13, 0.1) if filled else Color(0.09, 0.08, 0.07)
	st.border_color = Color(0.5, 0.4, 0.24) if filled else Color(0.25, 0.2, 0.14)
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", st)
	if filled:
		var icon := ItemIcon.new()
		icon.custom_minimum_size = Vector2(52, 52)
		icon.set_item(id)
		p.tooltip_text = Texts.t(Game.content.find_item(id).name_key)
		p.add_child(icon)
	return p


## Comer y tomar: un botón por cada objeto que se puede consumir.
func _consumables(pl: PlayerState) -> HFlowContainer:
	var box := HFlowContainer.new()
	box.add_theme_constant_override("h_separation", 6)
	box.add_theme_constant_override("v_separation", 6)
	var ids := pl.bag.keys()
	ids.sort()
	for id in ids:
		var def := Game.content.find_item(id)
		if def.food_bp > 0 or def.drink_bp > 0:
			var key := "BAG_DRINK" if def.drink_bp > def.food_bp else "BAG_EAT"
			var b := UIKit.button(Texts.t(key) + " · " + Texts.t(def.name_key), _consume.bind(id))
			b.custom_minimum_size = Vector2(0, 32)
			b.add_theme_font_size_override("font_size", 15)
			box.add_child(b)
	return box


func _tools_row(pl: PlayerState) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	for t in pl.tools:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(84, 0)
		var icon := ItemIcon.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.set_item(t)
		cell.add_child(icon)
		var text := Texts.t(Game.content.find_item(t).name_key)
		if pl.tool_wear.has(t):
			text += "\n" + Texts.t("BAG_USES", {"n": pl.tool_wear[t]})
		var l := UIKit.label(text, 13, UIKit.COLOR_TEXT, true)
		l.custom_minimum_size = Vector2(84, 0)
		cell.add_child(l)
		row.add_child(cell)
	return row


## El acopio va sobre una tabla: un dibujo por unidad, y el número cuando hay muchas.
func _shelf_row(s: GameState) -> PanelContainer:
	var board := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.36, 0.25, 0.16)
	st.border_color = Color(0.22, 0.15, 0.09)
	st.set_border_width_all(3)
	st.set_corner_radius_all(3)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	board.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ids := s.camp.storage.keys()
	ids.sort()
	if ids.is_empty():
		row.add_child(UIKit.label(Texts.t("BAG_STORAGE_EMPTY"), 15, Color(0.92, 0.86, 0.74)))
	for id in ids:
		var n := int(s.camp.storage[id])
		var cell := HBoxContainer.new()
		for i in mini(n, 4):
			var icon := ItemIcon.new()
			icon.custom_minimum_size = Vector2(40, 40)
			icon.set_item(id)
			cell.add_child(icon)
		var txt := "×%d" % n
		cell.add_child(UIKit.label(txt, 16, Color(0.98, 0.92, 0.8)))
		row.add_child(cell)
	board.add_child(row)
	return board


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
