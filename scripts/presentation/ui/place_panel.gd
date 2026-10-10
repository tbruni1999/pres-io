class_name PlacePanel
extends GamePanel
## Elegir dónde arma la carpa un vecino recién llegado (da igual para el futuro:
## al fundar el pueblito se rearman las casas).

var _id := ""
var _content := VBoxContainer.new()
var _feedback: Label


func _init() -> void:
	super()
	body.add_child(UIKit.title(Texts.t("PLACE_TITLE")))
	body.add_child(UIKit.label(Texts.t("PLACE_BODY"), 17, UIKit.COLOR_TEXT, true))
	_content.add_theme_constant_override("separation", 8)
	body.add_child(_content)
	_feedback = UIKit.label("", 17, UIKit.COLOR_ACCENT, true)
	body.add_child(_feedback)
	body.add_child(UIKit.button(Texts.t("UI_CLOSE"), request_close))


func on_open(args: Dictionary) -> void:
	_id = String(args.get("id", "beto"))
	_feedback.text = ""
	UIKit.clear(_content)
	for spot in Neighbors.SPOTS:
		var b := UIKit.button(Texts.t("PLACE_" + String(spot).to_upper()), _choose.bind(spot))
		for other in Game.state.camp.neighbors:
			if Neighbors.spot_of(Game.state, other) == spot:
				b.disabled = true
		_content.add_child(b)


func _choose(spot: String) -> void:
	var r := Game.place_neighbor(_id, spot)
	ui.play_feedback(r.ok)
	if r.ok:
		ui.post_notice(r.message)
		request_close()
	else:
		_feedback.text = r.message
