extends SceneTree
## Genera las texturas procedurales del proyecto (tileables, 512 px) en assets/textures.
## Uso: godot --headless --path . --script tools/generate_textures.gd
## Son originales (ruido + rampas de color): sin licencias externas. Volver a correr
## este script las regenera iguales (semillas fijas).

const OUT := "res://assets/textures/"
const SIZE := 512


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_noise_tex("ground_dirt", 11, 0.012, 5, [Color(0.31, 0.25, 0.17), Color(0.42, 0.34, 0.23), Color(0.47, 0.4, 0.27), Color(0.36, 0.3, 0.2)])
	_noise_tex("ground_grass", 12, 0.018, 5, [Color(0.25, 0.3, 0.13), Color(0.34, 0.38, 0.17), Color(0.42, 0.44, 0.2), Color(0.3, 0.33, 0.15)])
	_noise_tex("sand", 13, 0.03, 4, [Color(0.55, 0.48, 0.35), Color(0.63, 0.56, 0.41), Color(0.6, 0.52, 0.38)])
	_noise_tex("road", 14, 0.02, 4, [Color(0.4, 0.33, 0.24), Color(0.5, 0.42, 0.31), Color(0.45, 0.37, 0.27)])
	_noise_tex("rock", 15, 0.05, 6, [Color(0.3, 0.29, 0.27), Color(0.45, 0.44, 0.41), Color(0.38, 0.37, 0.34)])
	_noise_tex("leaves", 16, 0.09, 3, [Color(0.15, 0.24, 0.1), Color(0.27, 0.38, 0.16), Color(0.36, 0.46, 0.2), Color(0.22, 0.32, 0.13)])
	_wood("wood_planks", 21, Color(0.42, 0.31, 0.2), Color(0.3, 0.21, 0.13), 8)
	_wood("bark", 22, Color(0.31, 0.24, 0.17), Color(0.18, 0.13, 0.09), 24)
	_canvas("canvas", 31, Color(0.55, 0.5, 0.36))
	_corrugated("zinc", 41, Color(0.6, 0.62, 0.63), Color(0.47, 0.32, 0.2))
	_water_normal("water_normal", 51)
	_grass_blades("grass_blades", 61)
	_mask("noise_mask", 71)
	print("texturas generadas en ", OUT)
	quit(0)


func _noise(seed_value: int, freq: float, octaves: int, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


func _ramp(colors: Array, t: float) -> Color:
	t = clampf(t, 0.0, 0.9999) * (colors.size() - 1)
	var i := int(t)
	return (colors[i] as Color).lerp(colors[i + 1], t - i)


## Ruido tileable mapeado a una rampa de colores, con grano fino.
func _noise_tex(name: String, seed_value: int, freq: float, octaves: int, colors: Array) -> void:
	var base := _noise(seed_value, freq, octaves).get_seamless_image(SIZE, SIZE, false, false, 0.2)
	var grain := _noise(seed_value + 100, 0.35, 1).get_seamless_image(SIZE, SIZE, false, false, 0.1)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var v := base.get_pixel(x, y).r
			var g := grain.get_pixel(x, y).r - 0.5
			img.set_pixel(x, y, _ramp(colors, v).lightened(g * 0.12) if g > 0 else _ramp(colors, v).darkened(-g * 0.12))
	_save(img, name)


## Tablas: vetas alargadas en X con separación entre tablas.
func _wood(name: String, seed_value: int, light: Color, dark: Color, boards: int) -> void:
	var n := _noise(seed_value, 0.02, 4)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var board_h := SIZE / boards
	for y in SIZE:
		for x in SIZE:
			var grain := n.get_noise_2d(x * 0.15, y * 3.0) * 0.5 + 0.5
			var c := dark.lerp(light, grain)
			var edge := y % board_h
			if edge < 2:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	_save(img, name)


func _canvas(name: String, seed_value: int, base: Color) -> void:
	var n := _noise(seed_value, 0.01, 3)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var weave := 0.04 if (x / 2 + y / 2) % 2 == 0 else -0.04
			var stain := n.get_noise_2d(x, y) * 0.18
			img.set_pixel(x, y, base.lightened(weave + stain) if weave + stain > 0 else base.darkened(-(weave + stain)))
	_save(img, name)


## Chapa acanalada con manchas de óxido + su mapa de normales.
func _corrugated(name: String, seed_value: int, metal: Color, rust: Color) -> void:
	var n := _noise(seed_value, 0.008, 5)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var nrm := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var waves := 16.0
	for y in SIZE:
		for x in SIZE:
			var phase := float(x) / SIZE * waves * TAU
			var shade := sin(phase) * 0.08
			var r := clampf(n.get_noise_2d(x, y) * 1.6 + 0.1, 0.0, 1.0)
			var c := metal.lerp(rust, r)
			img.set_pixel(x, y, c.lightened(shade) if shade > 0 else c.darkened(-shade))
			var dx := cos(phase) * 0.6
			nrm.set_pixel(x, y, Color(0.5 + dx * 0.5, 0.5, 1.0))
	_save(img, name)
	_save(nrm, name + "_normal")


func _water_normal(name: String, seed_value: int) -> void:
	var h := _noise(seed_value, 0.02, 3).get_seamless_image(SIZE, SIZE, false, false, 0.2)
	var nrm := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var l := h.get_pixel((x - 1 + SIZE) % SIZE, y).r
			var r := h.get_pixel((x + 1) % SIZE, y).r
			var u := h.get_pixel(x, (y - 1 + SIZE) % SIZE).r
			var d := h.get_pixel(x, (y + 1) % SIZE).r
			var v := Vector3((l - r) * 3.0, (u - d) * 3.0, 1.0).normalized()
			nrm.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5))
	_save(nrm, name)


## Pastos para el MultiMesh: hojas verticales con transparencia recortada (alpha scissor).
func _grass_blades(name: String, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var w := 256
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for b in 26:
		var x0 := rng.randf_range(10, w - 10)
		var height := rng.randf_range(w * 0.45, w * 0.98)
		var bend := rng.randf_range(-30, 30)
		var width := rng.randf_range(3.0, 6.0)
		var col := Color(0.28, 0.36, 0.14).lerp(Color(0.55, 0.55, 0.25), rng.randf())
		for i in int(height):
			var t := float(i) / height
			var cx := x0 + bend * t * t
			var half := width * (1.0 - t)
			for dx in range(int(-half) - 1, int(half) + 2):
				var px := int(cx) + dx
				var py := w - 1 - i
				if px >= 0 and px < w and py >= 0:
					img.set_pixel(px, py, col.darkened((1.0 - t) * 0.35))
	_save(img, name)


## Máscara en escala de grises (baja frecuencia) para mezclar texturas en el suelo.
func _mask(name: String, seed_value: int) -> void:
	var img := _noise(seed_value, 0.006, 4).get_seamless_image(SIZE, SIZE, false, false, 0.3)
	img.convert(Image.FORMAT_L8)
	_save(img, name)


func _save(img: Image, name: String) -> void:
	img.save_png(OUT + name + ".png")
