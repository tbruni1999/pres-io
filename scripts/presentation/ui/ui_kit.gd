class_name UIKit
extends RefCounted
## Constructores pequeños de controles con el estilo del tema del proyecto.

const COLOR_TEXT := Color(0.95, 0.92, 0.85)
const COLOR_MUTED := Color(0.72, 0.68, 0.6)
const COLOR_ACCENT := Color(0.93, 0.7, 0.32)
const COLOR_GOOD := Color(0.55, 0.85, 0.55)
const COLOR_BAD := Color(1.0, 0.55, 0.45)


static func label(text: String, font_size: int = 18, color: Color = COLOR_TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 200
	return l


static func title(text: String) -> Label:
	return label(text, 26, COLOR_ACCENT)


static func section(text: String) -> Label:
	return label(text.to_upper(), 15, COLOR_MUTED)


static func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(callback)
	return b


## Fila "concepto ........ valor" alineada.
static func row(key: String, value: String, value_color: Color = COLOR_TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	var k := label(key, 18, COLOR_MUTED)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var v := label(value, 18, value_color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	return h


static func clear(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()
