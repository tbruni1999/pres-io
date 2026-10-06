extends Node
## Recorrido de capturas para revisión visual (requiere ventana/GPU; no sirve headless).
## Uso: godot --path . res://tools/screenshot_tour.tscn -- --out=/ruta/carpeta
## Guarda PNG de vistas fijas, actividades y paneles. No mide rendimiento.

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
	var s: GameState = game.state

	var spawn: Marker3D = main.get_node("World/PlayerSpawn")
	await _shot("01_despertar", spawn.global_position, rad_to_deg(spawn.global_rotation.y), -4)
	await _shot_at("02_frente_choza", Vector3(-6.0, 0.05, 7.5), Vector3(0.0, 1.2, 0.0))
	await _shot_at("03_camino", Vector3(0.5, 0.05, 4.0), Vector3(-25.0, 1.0, 12.6))
	await _shot_at("04_lago", Vector3(-3.0, 0.05, -12.0), Vector3(2.0, 0.0, -36.0))

	# Pescando: forzar el pique para ver el skillcheck.
	_pose_at(Vector3(-1.5, 0.05, -16.0), Vector3(-1.2, 0.3, -18.0))
	await _frames(4)
	var f := Activities.Fishing.new()
	ui.start_activity(f)
	f._timer = 0.0
	await _frames(8)
	await _capture("05_pique_skillcheck")
	ui.cancel_activity()

	# Comerciante: Don Ramiro llegando.
	var p: Dictionary = s.camp.passes[0]
	while s.tick < int(p["start"]) + 14:
		Simulation.step(s, game.content)
	await _shot_at("06_ramiro_llega", Vector3(-6.0, 0.05, 9.0), Vector3(-20.0, 1.3, 12.6))
	while Merchants.position_x(p, game.content.find_merchant("ramiro"), s.tick) < -8.0:
		Simulation.step(s, game.content)
	await _frames(2)
	player.apply_pose({"position": Vector3(-6.0, 0.05, 9.0), "yaw": 0.0, "pitch": 0.0})
	await _frames(3)
	await _capture("07_prompt_senas")
	game.hail_merchant(int(p["id"]))
	s.player.add_item("fish_small", 4)
	s.player.add_item("fish_big", 1)
	await _frames(4)
	await _shot_at("08_ramiro_parado", Vector3(-5.0, 0.05, 9.2), Vector3(-8.0, 1.4, 12.6))
	ui.open_panel(ui.trade, {"pass_id": int(p["id"])})
	await _frames(4)
	await _capture("09_comerciar")
	ui.trade._on_sell("fish_small", 4)
	await _frames(3)
	await _capture("10_comerciar_vendido")
	ui.close_panel()

	# Construir el fogón (con madera regalada para la captura).
	s.camp.wood = 30
	s.player.earn(Money.from_units(400))
	_pose_at(Vector3(3.3, 0.05, 1.6), Vector3(3.3, 0.2, 3.6))
	await _frames(4)
	await _capture("11_plot_fogon")
	var hammer := Activities.Strikes.new()
	hammer.total = 3
	hammer.on_done = func(_ok: bool) -> void: pass
	ui.start_activity(hammer)
	await _frames(6)
	await _capture("12_martillando")
	ui.cancel_activity()
	for b in ["fire", "sign", "dock"]:
		game.build(b)
	await _frames(4)
	await _shot_at("13_fogon_cartel", Vector3(-1.0, 0.05, 6.5), Vector3(1.0, 0.8, 4.0))
	await _shot_at("14_cartel", Vector3(-3.4, 0.05, 13.5), Vector3(-3.4, 1.7, 9.4))
	await _shot_at("15_muelle", Vector3(14.0, 0.05, -14.0), Vector3(6.0, 0.3, -27.0))
	await _shot_at("16_desde_muelle", Vector3(5.5, 0.05, -26.5), Vector3(0.0, 0.0, -36.0))
	await _shot_at("17_arbol_ramas", Vector3(-8.0, 0.05, -2.0), Vector3(-11.0, 0.8, -7.0))

	# Ahumadero con humo, atardecer y noche.
	s.camp.wood += 11
	game.build("smokehouse")
	s.player.add_item("fish_small", 3)
	game.load_smoker()
	await _frames(4)
	await _shot_at("17b_ahumadero", Vector3(-8.5, 0.05, 4.0), Vector3(-4.8, 1.3, -0.6))
	var dn: DayNight = main.get_node("DayNight")
	var keep_tick: int = s.tick
	var day0: int = (s.current_day() - 1) * s.ticks_per_day
	s.tick = day0 + int(380.0 / 1080.0 * s.ticks_per_day * (1170.0 - 360.0) / 380.0)
	dn.apply_now()
	await _shot_at("17c_atardecer", Vector3(-6.0, 0.05, -12.0), Vector3(4.0, 0.5, -36.0))
	s.tick = day0 + DayTime.night_offset_ticks(s, game.content) + 40
	dn.apply_now()
	await _shot_at("17d_noche_choza", Vector3(-3.0, 0.05, 8.0), Vector3(0.5, 1.0, 0.0))
	await _shot_at("17e_noche_lago", Vector3(-3.0, 0.05, -15.0), Vector3(0.0, 0.5, -36.0))
	s.tick = keep_tick
	dn.apply_now()

	# Otros comerciantes.
	for q in s.camp.passes:
		q["status"] = Merchants.GONE
	s.camp.passes.append({"id": 900, "merchant": "chola", "start": s.tick - 12, "status": Merchants.PASSING, "stop_tick": -1, "leave_tick": -1, "bought": 0})
	s.camp.passes.append({"id": 901, "merchant": "coco", "start": s.tick - 20, "status": Merchants.PASSING, "stop_tick": -1, "leave_tick": -1, "bought": 0})
	await _frames(4)
	await _shot_at("18_chola_y_coco", Vector3(-1.0, 0.05, 6.5), Vector3(-16.0, 1.2, 12.6))

	ui.open_panel(ui.bag, {})
	await _frames(4)
	await _capture("19_mochila")
	ui.close_panel()
	s.player.thirst_bp = 1200
	await _shot_at("20_hud_sed", Vector3(-3.0, 0.05, -12.0), Vector3(2.0, 0.0, -36.0))
	var rep: DayReport = game.sleep()
	ui.open_panel(ui.report, {"report": rep})
	await _frames(4)
	await _capture("21_informe")
	ui.close_panel()
	print("capturas en ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _look(pos: Vector3, target: Vector3) -> Dictionary:
	var to := target - (pos + Vector3(0, 1.7, 0))
	return {"yaw": rad_to_deg(atan2(-to.x, -to.z)), "pitch": rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))}


func _pose_at(pos: Vector3, target: Vector3) -> void:
	var l := _look(pos, target)
	player.apply_pose({"position": pos, "yaw": deg_to_rad(l["yaw"]), "pitch": l["pitch"]})


func _shot_at(shot_name: String, pos: Vector3, target: Vector3) -> void:
	var l := _look(pos, target)
	await _shot(shot_name, pos, l["yaw"], l["pitch"])


func _shot(shot_name: String, pos: Vector3, yaw: float, pitch: float, settle: int = 12) -> void:
	player.apply_pose({"position": pos, "yaw": deg_to_rad(yaw), "pitch": pitch})
	await get_tree().physics_frame
	await _frames(settle)
	await _capture(shot_name)


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
