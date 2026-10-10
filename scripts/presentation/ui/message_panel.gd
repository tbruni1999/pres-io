class_name MessagePanel
extends GamePanel
## Cartel con título y texto (el fogón de fundación, avisos grandes).

var _title: Label
var _text: Label
var _extra: Label


func _init() -> void:
	super()
	_title = UIKit.title("")
	body.add_child(_title)
	_text = UIKit.label("", 18, UIKit.COLOR_TEXT, true)
	_text.custom_minimum_size = Vector2(500, 0)
	body.add_child(_text)
	_extra = UIKit.label("", 15, UIKit.COLOR_MUTED, true)
	body.add_child(_extra)
	body.add_child(UIKit.button(Texts.t("UI_CONTINUE"), request_close))


func on_open(args: Dictionary) -> void:
	_title.text = String(args.get("title", ""))
	_text.text = String(args.get("text", ""))
	_extra.text = String(args.get("extra", ""))
	_extra.visible = not _extra.text.is_empty()
