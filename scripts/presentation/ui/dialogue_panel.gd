class_name DialoguePanel
extends GamePanel
## Conversación con un vecino. Elige la entrada según el estado y registra hechos
## narrativos (pedido escuchado, promesa). No modifica dinero ni servicios.

var _service: DialogueService
var _name_label: Label
var _text_label: Label
var _options: VBoxContainer


func _init() -> void:
	super()
	custom_minimum_size = Vector2(640, 0)
	_name_label = UIKit.title("")
	body.add_child(_name_label)
	_text_label = UIKit.label("", 20, UIKit.COLOR_TEXT, true)
	_text_label.custom_minimum_size = Vector2(600, 0)
	body.add_child(_text_label)
	body.add_child(HSeparator.new())
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 6)
	body.add_child(_options)


func on_open(args: Dictionary) -> void:
	_service = Game.dialogues.get(args.get("target_id", "")) as DialogueService
	if _service == null:
		request_close.call_deferred()
		return
	_name_label.text = "%s — %s" % [Texts.t(_service.name_key), Texts.t(_service.role_key)]
	_show_entry(_service.start_entry(Game.state))


func _show_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		request_close()
		return
	for f in entry.get("set_facts", []):
		Game.record_fact(_service.resident_id, f)
	_text_label.text = Texts.t(entry["text"], _params())
	UIKit.clear(_options)
	var first: Button = null
	for o in _service.visible_options(entry, Game.state):
		var option: Dictionary = o
		var b := UIKit.button("› " + Texts.t(option["text"], _params()), func() -> void: _choose(option))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_options.add_child(b)
		if first == null:
			first = b
	if first != null:
		_focus_later.call_deferred(first)


func _focus_later(b: Button) -> void:
	if is_instance_valid(b) and b.is_inside_tree() and visible:
		b.grab_focus()


func _choose(option: Dictionary) -> void:
	for f in option.get("set_facts", []):
		Game.record_fact(_service.resident_id, f)
	if option.has("next"):
		_show_entry(_service.get_entry(option["next"]))
	else:
		request_close()


func _params() -> Dictionary:
	var def := Game.content.find_project("well_repair")
	return {
		"well_cost": Money.format(def.cost_cents()),
		"capacity": Game.state.settlement.base_water_capacity,
		"population": Game.state.settlement.population,
		"capacity_after": def.capacity_after,
	}
