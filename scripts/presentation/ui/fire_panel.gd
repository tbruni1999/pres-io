class_name FirePanel
extends GamePanel
## Fogón: hervir agua y asar pescado. Cada uso gasta una madera.

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
	_content.add_child(UIKit.label(Texts.t("FIRE_WOOD", {"n": s.camp.wood}), 17, UIKit.COLOR_MUTED))
	var boil := UIKit.button(Texts.t("FIRE_BOIL"), _do.bind(func() -> CommandResult: return Game.boil_water()))
	boil.disabled = s.camp.wood < 1
	_content.add_child(boil)
	for fish_id in ["fish_small", "fish_big"]:
		if s.player.count(fish_id) <= 0:
			continue
		var def := Game.content.find_item(fish_id)
		var b := UIKit.button(Texts.t("FIRE_COOK", {"name": Texts.t(def.name_key)}), _do.bind(func() -> CommandResult: return Game.cook_and_eat(fish_id)))
		b.disabled = s.camp.wood < 1
		_content.add_child(b)


func _do(action: Callable) -> void:
	var r: CommandResult = action.call()
	_feedback.text = r.message
	ui.play_feedback(r.ok)
	refresh()
