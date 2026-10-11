class_name ItemIcon
extends Control
## Dibujo de un objeto para el inventario: formas simples con color, sin imágenes.
## Todo se dibuja en relación al tamaño del control (sirve para cualquier celda).

var item_id := ""


func _init() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_item(id: String) -> void:
	item_id = id
	queue_redraw()


func _draw() -> void:
	var u := minf(size.x, size.y) / 56.0
	var c := size * 0.5
	match item_id:
		"fish_small":
			_fish(c, u, 0.34, Color(0.74, 0.8, 0.86))
		"fish_big":
			_fish(c, u, 0.42, Color(0.84, 0.62, 0.28))
		"fish_small_smoked":
			_fish(c, u, 0.34, Color(0.58, 0.36, 0.18))
			draw_line(c + Vector2(-6, -8) * u, c + Vector2(-2, 8) * u, Color(0.3, 0.18, 0.08), 2 * u)
		"fish_big_smoked":
			_fish(c, u, 0.42, Color(0.5, 0.28, 0.13))
			draw_line(c + Vector2(-8, -8) * u, c + Vector2(-2, 8) * u, Color(0.3, 0.16, 0.07), 2 * u)
		"bread":
			_ellipse(c, 19 * u, 12 * u, Color(0.86, 0.66, 0.4))
			draw_line(c + Vector2(-9, -2) * u, c + Vector2(9, -2) * u, Color(0.62, 0.42, 0.22), 2 * u)
		"water_jug":
			draw_rect(Rect2(c + Vector2(-9, -14) * u, Vector2(18, 28) * u), Color(0.22, 0.52, 0.9))
			draw_rect(Rect2(c + Vector2(-5, -19) * u, Vector2(10, 6) * u), Color(0.1, 0.1, 0.12))
			draw_rect(Rect2(c + Vector2(-5, -4) * u, Vector2(10, 8) * u), Color(0.9, 0.95, 1.0, 0.5))
		"rod_basic":
			_rod(c, u, Color(0.56, 0.4, 0.22))
		"rod_good":
			_rod(c, u, Color(0.2, 0.55, 0.38))
		"axe":
			draw_line(c + Vector2(-14, 20) * u, c + Vector2(10, -14) * u, Color(0.5, 0.36, 0.2), 3 * u)
			draw_colored_polygon(PackedVector2Array([c + Vector2(4, -18) * u, c + Vector2(20, -14) * u, c + Vector2(20, -5) * u, c + Vector2(8, -8) * u]), Color(0.55, 0.57, 0.6))
		"cooler":
			draw_rect(Rect2(c + Vector2(-18, -8) * u, Vector2(36, 24) * u), Color(0.92, 0.93, 0.95))
			draw_rect(Rect2(c + Vector2(-19, -13) * u, Vector2(38, 6) * u), Color(0.2, 0.45, 0.8))
		"umbrella":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				pts.append(c + Vector2(0, -6) * u + Vector2(cos(a) * 22, sin(a) * 12) * u)
			draw_colored_polygon(pts, Color(0.92, 0.5, 0.14))
			draw_line(c + Vector2(0, -6) * u, c + Vector2(0, 20) * u, Color(0.4, 0.4, 0.42), 2 * u)
		"tape":
			draw_arc(c, 14 * u, 0.0, TAU, 32, Color(0.95, 0.95, 0.93), 6 * u)
		"sheet_metal":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 6) * u, c + Vector2(16, 6) * u, c + Vector2(22, -6) * u, c + Vector2(-16, -6) * u]), Color(0.62, 0.64, 0.66))
			for i in 3:
				draw_line(c + Vector2(-16 + i * 12, 4) * u, c + Vector2(-10 + i * 12, -4) * u, Color(0.45, 0.47, 0.5), 1.5 * u)
		"cement":
			draw_rect(Rect2(c + Vector2(-16, -14) * u, Vector2(32, 28) * u), Color(0.7, 0.68, 0.62))
			draw_line(c + Vector2(-16, -6) * u, c + Vector2(16, -6) * u, Color(0.5, 0.48, 0.44), 2 * u)
		"salt":
			draw_rect(Rect2(c + Vector2(-12, -8) * u, Vector2(24, 20) * u), Color(0.97, 0.96, 0.92))
			for p in [Vector2(-5, -2), Vector2(3, 2), Vector2(-2, 5)]:
				draw_circle(c + p * u, 1.5 * u, Color(0.7, 0.7, 0.68))
		"bike":
			draw_arc(c + Vector2(-14, 12) * u, 12 * u, 0.0, TAU, 24, Color(0.15, 0.15, 0.15), 3 * u)
			draw_arc(c + Vector2(14, 12) * u, 12 * u, 0.0, TAU, 24, Color(0.15, 0.15, 0.15), 3 * u)
			draw_polyline(PackedVector2Array([c + Vector2(-14, 12) * u, c + Vector2(0, -6) * u, c + Vector2(14, 12) * u]), Color(0.2, 0.5, 0.45), 3 * u)
		_:
			draw_rect(Rect2(c + Vector2(-14, -14) * u, Vector2(28, 28) * u), Color(0.5, 0.5, 0.5))


func _fish(c: Vector2, u: float, rx_scale: float, col: Color) -> void:
	var rx := 26.0 * u * rx_scale / 0.4
	var ry := rx * 0.45
	_ellipse(c, rx, ry, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(rx * 0.8, 0), c + Vector2(rx * 1.35, -ry * 0.9), c + Vector2(rx * 1.35, ry * 0.9)]), col)
	draw_circle(c + Vector2(-rx * 0.5, -ry * 0.2), 2.2 * u, Color(0.08, 0.07, 0.07))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _rod(c: Vector2, u: float, col: Color) -> void:
	draw_line(c + Vector2(-22, 20) * u, c + Vector2(18, -20) * u, col, 2.5 * u)
	draw_circle(c + Vector2(-6, 8) * u, 5 * u, Color(0.6, 0.6, 0.62))
	draw_line(c + Vector2(18, -20) * u, c + Vector2(20, 14) * u, Color(0.9, 0.9, 0.9, 0.7), 1 * u)
