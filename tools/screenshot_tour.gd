extends Node
## Recorrido de capturas para revisión visual (requiere ventana/GPU; no sirve headless).
## Uso: godot --path . res://tools/screenshot_tour.tscn -- --out=/ruta/carpeta
## Guarda PNG de vistas fijas y paneles en cada estado del pozo. No mide rendimiento.

var out_dir := "user://screenshots"
var main: Node3D
var player: PlayerController
var ui: UIRoot
var game: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	game = get_node("/root/Game")
	game.autosave_enabled = false
	game.new_game()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	player = main.get_node("Player")
	ui = main.get_node("UI")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(20)

	var spawn: Marker3D = main.get_node("Settlement/PlayerSpawn")
	await _shot("01_inicio", spawn.global_position, rad_to_deg(spawn.global_rotation.y), -2)
	await _shot_at("02_plaza_rosa", Vector3(-4.0, 0.05, -6.5), Vector3(2.4, 1.2, -10.0))
	await _shot_at("03_pozo_deteriorado", Vector3(-3.0, 0.05, -8.0), Vector3(0.5, 0.8, -13.0))
	await _shot_at("04_oficina_interior", Vector3(-11.6, 0.05, -11.8), Vector3(-17.4, 0.9, -13.0))
	await _shot_at("05_oficina_exterior", Vector3(-5.0, 0.05, -6.0), Vector3(-12.0, 1.8, -13.0))
	await _shot_at("06_calle", Vector3(-30.0, 0.05, 2.0), Vector3(0.0, 1.5, -2.0))
	await _shot_at("06b_acceso_sur", Vector3(0.5, 0.05, 18.0), Vector3(0.0, 1.0, 56.0))

	# Paneles
	await _panel("07_dialogo", Vector3(0.6, 0.05, -10.0), -90, -5, func() -> void: ui.open_panel(ui.dialogue, {"target_id": "neighbor_rosa"}))
	await _panel("08_inspeccion", Vector3(0.0, 0.05, -10.6), 0, -25, func() -> void: ui.open_panel(ui.inspect, {"target_id": "well_main"}))
	await _panel("09_escritorio", Vector3(-16.0, 0.05, -13.0), 90, -30, func() -> void: ui.open_panel(ui.desk, {}))
	ui.open_panel(ui.desk, {})
	ui.desk._on_approve()
	await _frames(4)
	await _capture("10_escritorio_confirmar")
	ui.desk._on_approve()
	await _frames(4)
	await _capture("11_escritorio_aprobado")
	ui.close_panel()

	await _shot_at("12_pozo_en_obra", Vector3(-3.0, 0.05, -8.0), Vector3(0.5, 0.8, -13.0))
	ui.open_panel(ui.desk, {})
	ui.desk._on_close_day()
	await _frames(4)
	await _capture("13_informe")
	ui.close_panel()
	await _shot_at("14_pozo_reparado", Vector3(-3.0, 0.05, -8.0), Vector3(0.5, 0.8, -13.0))
	await _shot_at("15_pozo_reparado_tanque", Vector3(5.5, 0.05, -9.0), Vector3(2.0, 1.0, -14.0))
	await _panel("16_libreta", Vector3(-3.0, 0.05, -9.0), -110, -6, func() -> void: ui.open_panel(ui.notebook, {}))
	await _panel("17_pausa", Vector3(-3.0, 0.05, -9.0), -110, -6, func() -> void: ui.open_panel(ui.pause_menu, {}))
	ui.open_panel(ui.pause_menu, {})
	ui.pause_menu._show_settings(true)
	await _frames(4)
	await _capture("17b_ajustes")
	ui.close_panel()
	ui.debug_overlay.visible = true
	await _shot("18_diagnostico", Vector3(-8.5, 0.05, -12.2), -90, -2, 90)
	print("capturas en ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Ubica la cámara en pos mirando hacia target (alto de ojos ~1,7 m).
func _look(pos: Vector3, target: Vector3) -> Dictionary:
	var to := target - (pos + Vector3(0, 1.7, 0))
	var yaw := rad_to_deg(atan2(-to.x, -to.z))
	var pitch := rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
	return {"yaw": yaw, "pitch": pitch}


func _shot_at(shot_name: String, pos: Vector3, target: Vector3) -> void:
	var l := _look(pos, target)
	await _shot(shot_name, pos, l["yaw"], l["pitch"])


func _shot(shot_name: String, pos: Vector3, yaw: float, pitch: float, settle: int = 12) -> void:
	player.apply_pose({"position": pos, "yaw": deg_to_rad(yaw), "pitch": pitch})
	await get_tree().physics_frame
	await _frames(settle)
	await _capture(shot_name)


func _panel(shot_name: String, pos: Vector3, yaw: float, pitch: float, open: Callable) -> void:
	player.apply_pose({"position": pos, "yaw": deg_to_rad(yaw), "pitch": pitch})
	await _frames(6)
	open.call()
	await _frames(6)
	await _capture(shot_name)
	ui.close_panel()


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
