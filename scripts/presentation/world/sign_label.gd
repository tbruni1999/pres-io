@tool
class_name SignLabel
extends Label3D
## Cartel del mundo con texto centralizado (clave de data/text/strings.csv).

@export var text_key: String = "":
	set(v):
		text_key = v
		_refresh()


func _ready() -> void:
	_refresh()


func set_text_key(key: String, params: Dictionary = {}) -> void:
	text_key = key
	text = Texts.t(key, params)


func _refresh() -> void:
	if not text_key.is_empty():
		text = Texts.t(text_key)
