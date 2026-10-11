class_name ConfirmPanel
extends GamePanel
## Pregunta antes de algo que cuesta tiempo o no se puede deshacer (dormir de día).
## Un solo botón de acción y otro para seguir; Esc también sigue.

var _title: Label
var _text: Label
var _ok: Button
var _on_ok: Callable = Callable()


func _init() -> void:
	super()
	custom_minimum_size = Vector2(540, 0)
	_title = UIKit.title("")
	body.add_child(_title)
	_text = UIKit.label("", 18, UIKit.COLOR_TEXT, true)
	_text.custom_minimum_size = Vector2(500, 0)
	body.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_ok = UIKit.button("", _confirm)
	_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_ok)
	var back := UIKit.button(Texts.t("CONFIRM_BACK"), request_close)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	body.add_child(row)


## args: title, text, ok (texto del botón de acción), on_ok (Callable sin argumentos).
func on_open(args: Dictionary) -> void:
	_title.text = String(args.get("title", ""))
	_text.text = String(args.get("text", ""))
	_ok.text = String(args.get("ok", Texts.t("CONFIRM_OK")))
	_on_ok = args.get("on_ok", Callable())


func on_close() -> void:
	_on_ok = Callable()


func _confirm() -> void:
	var action := _on_ok
	request_close()
	if action.is_valid():
		action.call()
