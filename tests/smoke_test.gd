extends Node
## Prueba de humo de la escena principal (sin renderizado): juega el comienzo
## con el rayo de interacción y las teclas reales (E, Esc, Tab).
## Uso: godot --headless --path . res://tests/smoke_test.tscn
## (Es una escena y no un --script para que el autoload "Game" esté disponible.)
## Termina sola (límite de fotogramas) y sale con código distinto de cero si falla.

const SMOKE_SAVE_DIR := "user://smoke_saves"
const FRAME_LIMIT := 6000

var _failures: PackedStringArray = PackedStringArray()
var _checks := 0
var _frames := 0
var game: Node
var main: Node3D
var player: PlayerController
var ui: UIRoot


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > FRAME_LIMIT:
		printerr("Límite de fotogramas alcanzado: la prueba no terminó")
		get_tree().quit(2)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(what)
		printerr("FALLO ", what)


func wait_physics(n: int = 3) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## Mantener E apretada un rato real (las acciones de "mantener" usan tiempo real).
func hold_interact(seconds: float) -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.action_press("interact")
	await get_tree().create_timer(seconds).timeout
	Input.action_release("interact")
	await wait_physics()


func look(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	player.apply_pose({"position": pos, "yaw": deg_to_rad(yaw_deg), "pitch": pitch_deg})
	await wait_physics()


func ctx_kind() -> String:
	return String(ui.context().get("kind", ""))


## Pone la aguja en el centro de la zona y aprieta E.
func hit_check() -> void:
	var sc := ui.skill_check
	sc._t = sc._zone_start + sc._zone_width * 0.5
	press("interact")
	await wait_physics(1)


func miss_check() -> void:
	var sc := ui.skill_check
	sc._t = 0.02 if sc._zone_start > 0.1 else 0.98
	press("interact")
	await wait_physics(1)


func piece(path: String) -> CampPiece:
	return main.get_node("World/" + path) as CampPiece


func _run() -> void:
	game = get_node("/root/Game")
	await get_tree().process_frame
	game.saves.save_dir = SMOKE_SAVE_DIR
	game.new_game()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	player = main.get_node("Player")
	ui = main.get_node("UI")
	await wait_physics(5)
	var s: GameState = game.state

	# 1) Despertar en la choza: se puede dormir mirando la cama.
	var spawn: Vector3 = main.get_node("World/PlayerSpawn").global_position
	check(player.global_position.distance_to(spawn) < 0.5, "aparece en la choza")
	await look(Vector3(0.3, 0.05, -0.6), 90, -32)
	check(ctx_kind() == "sleep", "mirando la cama se puede dormir (%s)" % ctx_kind())

	# 2) Pescar en la orilla con skillcheck (el tiempo sigue corriendo).
	await look(Vector3(-3.0, 0.05, -15.6), 6, -38)
	check(ctx_kind() == "fish", "en la orilla se puede pescar (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	var fishing := ui.current_activity() as Activities.Fishing
	check(fishing != null, "arranca la pesca")
	check(not game.is_paused(), "pescar no pausa el reloj")
	var tick0: int = s.tick
	fishing._timer = 0.0
	await wait_physics()
	check(ui.skill_check.active, "pica: aparece el skillcheck")
	var guard := 0
	while ui.skill_check.active and guard < 4:
		await hit_check()
		guard += 1
	check(s.player.bag_count() >= 1, "pescado en la mochila")
	fishing._timer = 0.0
	fishing._phase = "rest"
	await wait_physics()
	fishing._timer = 0.0
	await wait_physics()
	var bag_before := s.player.bag_count()
	await miss_check()
	check(s.player.bag_count() == bag_before, "si erra, el pescado se escapa")
	press("pause")
	await wait_physics()
	check(ui.current_activity() == null and ui.active_panel() == null, "Esc deja de pescar (sin abrir la pausa)")
	check(s.tick >= tick0, "el tiempo corrió mientras pescaba")

	# 3) Tomar agua del lago manteniendo E.
	s.player.thirst_bp = 2000
	await look(Vector3(0.0, 0.05, -15.3), 0, -40)
	check(ctx_kind() == "lake", "se puede tomar agua del lago (%s)" % ctx_kind())
	await hold_interact(1.8)
	check(s.player.thirst_bp > 2000, "tomó agua del lago")

	# 4) Juntar ramas.
	await look(Vector3(-10.0, 0.05, -3.9), 0, -50)
	check(ctx_kind() == "branches", "hay ramas (%s)" % ctx_kind())
	await hold_interact(2.4)
	check(s.camp.wood == 1, "junta una madera")
	check(not piece("Woods/Branches1").get_node("Before").visible, "el montón desaparece hasta mañana")

	# 5) Comerciante: hacerle señas a Don Ramiro y venderle.
	s.player.add_item("fish_small", 3)
	var p: Dictionary = s.camp.passes[0]
	var ramiro: MerchantDefinition = game.content.find_merchant("ramiro")
	while Merchants.position_x(p, ramiro, s.tick) < -20.0:
		Simulation.step(s, game.content)
	await look(Vector3(-6.0, 0.05, 9.5), 0, 0)
	check(ctx_kind() == "hail", "se le puede hacer señas (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	check(p["status"] == Merchants.STOPPED, "Ramiro frenó")
	var x: float = main.get_node("World/MerchantRoad").actor_x(int(p["id"]))
	await look(Vector3(x + 1.0, 0.05, 10.0), 0, 0)
	check(ctx_kind() == "trade", "cerca de la carreta se puede comerciar (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.trade and game.is_paused(), "panel de comercio (pausa)")
	var wallet: int = s.player.wallet_cents
	ui.trade._on_sell("fish_small", s.player.count("fish_small"))
	check(s.player.wallet_cents > wallet, "le vendió pescado")
	press("pause")
	await wait_physics()
	check(ui.active_panel() == null, "Esc cierra el comercio")
	check(p["status"] == Merchants.LEAVING, "Ramiro sigue viaje")

	# 6) Construir el fogón martillando.
	s.camp.wood = 3
	await look(Vector3(3.3, 0.05, 1.9), 180, -45)
	check(ctx_kind() == "build", "se puede construir el fogón (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	check(ui.current_activity() is Activities.Strikes, "arranca a martillar")
	await miss_check()
	check(not s.camp.has_building("fire"), "un martillazo errado no termina la obra")
	guard = 0
	while ui.current_activity() != null and guard < 6:
		await hit_check()
		guard += 1
	check(s.camp.has_building("fire") and s.camp.wood == 0, "fogón construido con la madera")
	check(piece("FirePlot").get_node("After").visible, "se ve el fogón")
	await wait_physics()
	s.camp.wood = 1
	s.player.thirst_bp = 1000
	check(ctx_kind() == "fire", "se puede usar el fogón (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.fire, "panel del fogón")
	game.boil_water()
	check(s.player.thirst_bp == PlayerState.FULL, "agua hervida")
	press("pause")
	await wait_physics()

	# 7) Guardar, empezar de cero y cargar.
	var saved := game.save_game() as CommandResult
	check(saved.ok, "guardado: " + saved.message)
	var wallet_saved: int = s.player.wallet_cents
	game.new_game()
	await wait_physics()
	check(not piece("FirePlot").get_node("After").visible, "partida nueva sin fogón")
	var loaded := game.load_game() as CommandResult
	check(loaded.ok, "carga: " + loaded.message)
	await wait_physics()
	s = game.state
	check(piece("FirePlot").get_node("After").visible, "tras cargar, el fogón vuelve")
	check(s.player.wallet_cents == wallet_saved, "tras cargar, la misma plata")
	check(not piece("Woods/Branches1").get_node("Before").visible, "tras cargar, las ramas siguen juntadas")

	# 8) Desmayo por sed: despierta en la choza al otro día.
	var day: int = s.current_day()
	player.apply_pose({"position": Vector3(10, 0.05, 5), "yaw": 0.0, "pitch": 0.0})
	s.player.thirst_bp = 1
	var t0 := Time.get_ticks_msec()
	while ui.active_panel() != ui.report and Time.get_ticks_msec() - t0 < 4000:
		await wait_physics()
	check(ui.active_panel() == ui.report, "informe del desmayo")
	check(game.state.current_day() == day + 1, "despierta al día siguiente")
	check(player.global_position.distance_to(spawn) < 0.5, "despierta en la choza")
	check(game.state.player.faint_count == 1, "se cuenta el desmayo")
	ui.report.request_close()
	await wait_physics()

	# 9) Dormir desde la cama.
	day = game.state.current_day()
	await look(Vector3(0.3, 0.05, -0.6), 90, -32)
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.report and game.state.current_day() == day + 1, "dormir termina el día")
	ui.report.request_close()
	await wait_physics()

	# 10) Mochila (Tab) y pausa (Esc).
	press("notebook")
	await wait_physics()
	check(ui.active_panel() == ui.bag, "Tab abre la mochila")
	press("notebook")
	await wait_physics()
	press("pause")
	await wait_physics()
	check(ui.active_panel() == ui.pause_menu, "Esc abre la pausa")
	press("pause")
	await wait_physics()
	check(ui.active_panel() == null, "Esc cierra la pausa")

	_cleanup()
	print("")
	if _failures.is_empty():
		print("SMOKE OK: %d comprobaciones en %d fotogramas" % [_checks, _frames])
		get_tree().quit(0)
	else:
		print("SMOKE FALLÓ: %d de %d" % [_failures.size(), _checks])
		get_tree().quit(1)


func _cleanup() -> void:
	var dir := DirAccess.open(SMOKE_SAVE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(SMOKE_SAVE_DIR)
