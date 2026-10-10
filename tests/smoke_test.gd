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
	await look(Vector3(0.3, 0.05, 1.3), 0, -35)
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
	while Merchants.position_x(p) < -20.0:
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

	# 6) Arranca con fogatita; construir el cartel martillando.
	check(s.camp.has_building("fire") and piece("FirePlot").get_node("After").visible, "arranca con la fogatita prendida")
	s.camp.wood = 4
	s.player.earn(Money.from_units(40))
	await look(Vector3(-3.4, 0.05, 7.6), 180, -45)
	check(ctx_kind() == "build", "se puede construir el cartel (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	check(ui.current_activity() is Activities.Strikes, "arranca a martillar")
	await miss_check()
	check(not s.camp.has_building("sign"), "un martillazo errado no termina la obra")
	guard = 0
	while ui.current_activity() != null and guard < 6:
		await hit_check()
		guard += 1
	check(s.camp.has_building("sign") and s.camp.wood == 0, "cartel construido con la madera")
	check(piece("SignPlot").get_node("After").visible, "se ve el cartel")
	s.camp.wood = 2
	s.player.thirst_bp = 1000
	var flame: Node3D = piece("FirePlot").get_node("After/Flame")
	s.camp.fire_until = -1
	await get_tree().create_timer(0.3).timeout
	check(not flame.visible, "fogón apagado: no hay llama")
	check(game.add_wood().ok, "echa leña")
	await get_tree().create_timer(0.3).timeout
	check(flame.visible, "con leña vuelve la llama")
	await look(Vector3(3.3, 0.05, 1.9), 180, -45)
	check(ctx_kind() == "fire", "se puede usar la fogata (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.fire, "panel del fogón")
	game.boil_water()
	check(s.player.thirst_bp == PlayerState.FULL, "agua hervida")
	press("pause")
	await wait_physics()

	# 6b) Ahumadero: construir, cargar y sacar ahumados.
	s.camp.wood = 10
	s.player.earn(Money.from_units(120))
	await look(Vector3(-2.9, 0.05, -0.6), 90, -45)
	check(ctx_kind() == "build", "se puede construir el ahumadero (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	guard = 0
	while ui.current_activity() != null and guard < 10:
		await hit_check()
		guard += 1
	check(s.camp.has_building("smokehouse"), "ahumadero construido")
	await look(Vector3(-2.9, 0.05, -0.6), 90, -25)
	check(ctx_kind() == "smoker", "se puede usar el ahumadero (%s)" % ctx_kind())
	s.camp.wood = 1
	s.player.add_item("fish_big", 2)
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.smoker, "panel del ahumadero")
	game.load_smoker()
	check(PlayerActions.smoker_status(s) == PlayerActions.SMOKER_SMOKING, "ahumando")
	press("pause")
	await wait_physics()
	var smoke: Node3D = piece("SmokehousePlot").get_node("After/Smoke")
	await wait_physics(2)
	check(smoke.visible, "sale humo de la chimenea")
	for i in game.content.balance.smoke_ticks:
		Simulation.step(s, game.content)
	s.player.hunger_bp = PlayerState.FULL
	s.player.thirst_bp = PlayerState.FULL
	check(game.collect_smoker().ok and s.player.count("fish_big_smoked") == 2, "saca dos tarariras ahumadas")

	# 6d) Lluvia: se ve y apaga el fogón (sin lona).
	var rain: RainFx = main.get_node("Rain")
	s.camp.weather = Weather.RAIN
	s.camp.rain_start = s.tick
	s.camp.rain_end = s.tick + 40
	s.camp.wood = 3
	game.add_wood()
	Simulation.step(s, game.content)
	await get_tree().create_timer(0.35).timeout
	check(rain.is_raining_visible(), "llueve en pantalla")
	check(not Simulation.fire_lit(s), "la lluvia apagó el fogón")
	s.camp.weather = Weather.SUN
	s.camp.rain_start = -1
	s.camp.rain_end = -1
	await get_tree().create_timer(0.35).timeout
	check(not rain.is_raining_visible(), "paró de llover")

	# 6e) El olor del ahumado trae a Beto: elegir dónde va su carpa y charlar.
	s.player.hunger_bp = PlayerState.FULL
	s.player.thirst_bp = PlayerState.FULL
	var rep_beto: DayReport = game.sleep()
	check(rep_beto.events.any(func(e: Dictionary) -> bool: return e["key"] == "EV_BETO_ARRIVES"), "el informe avisa que llega Beto")
	await wait_physics()
	var beto: Node3D = main.get_node("World/Neighbors/Beto")
	check(beto.visible, "Beto está en el campamento")
	await look(beto.global_position + Vector3(0, 0.05, 2.0), 0, -12)
	check(ctx_kind() == "place", "a Beto se le dice dónde va la carpa (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.place, "panel para elegir el lugar")
	ui.place._choose("lake")
	await wait_physics()
	check(ui.active_panel() == null, "eligió y se cerró")
	check(main.get_node("World/Neighbors/Tent_lake").visible and not main.get_node("World/Neighbors/Tent_road").visible, "aparece su carpa en el lago")
	await look(beto.global_position + Vector3(0, 0.05, 2.0), 0, -12)
	check(ctx_kind() == "talk", "se puede charlar con Beto (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.neighbor, "se abre la charla con Beto")
	check(int(s.camp.neighbors["beto"]["ep"]) == 1, "primer capítulo de Beto")
	press("pause")
	await wait_physics()
	check(ui.active_panel() == null, "Esc cierra la charla")

	# 6e') Salim (lo trae el camino con movimiento) y su manta; Raúl y su pizarrón.
	s.facts["player"]["busy_road"] = true
	s.player.hunger_bp = PlayerState.FULL
	s.player.thirst_bp = PlayerState.FULL
	game.sleep()
	await wait_physics()
	var salim: Node3D = main.get_node("World/Neighbors/Salim")
	check(salim.visible, "llegó Salim")
	game.place_neighbor("salim", "road")
	await wait_physics()
	await look(salim.global_position + Vector3(0, 0.05, -2.0), 180, -12)
	check(ctx_kind() == "talk", "se puede ir a la manta de Salim (%s)" % ctx_kind())
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.neighbor, "panel de Salim")
	s.player.earn(Money.from_units(20))
	var salt_before: int = s.player.count("salt")
	ui.neighbor._buy("salt")
	check(s.player.count("salt") == salt_before + 1, "le compró sal a Salim")
	press("pause")
	await wait_physics()
	s.camp.night_thread = 2
	s.player.hunger_bp = PlayerState.FULL
	s.player.thirst_bp = PlayerState.FULL
	game.sleep()
	await wait_physics()
	check(main.get_node("World/Neighbors/Raul").visible, "llegó Raúl")
	game.place_neighbor("raul", "back")
	ui.open_panel(ui.neighbor, {"id": "raul"})
	await wait_physics()
	check(ui.neighbor._content.get_child_count() >= 2, "el pizarrón de Raúl muestra el día")
	ui.close_panel()
	await wait_physics()

	# 6f) Espinel: amanece con pescado y se saca manteniendo E.
	s.camp.buildings.append("longline")
	s.camp.longline_items = {"fish_small": 2}
	game.camp_changed.emit()
	s.player.bag.clear()
	await look(Vector3(-15.27, 0.05, -20.73), -45, -30)
	check(ctx_kind() == "longline", "se puede sacar el espinel (%s)" % ctx_kind())
	await hold_interact(1.8)
	check(s.player.count("fish_small") == 2 and s.camp.longline_items.is_empty(), "sacó el pescado del espinel")

	# 6c) La noche: oscurece, no pica y hay faroles.
	var day_night: DayNight = main.get_node("DayNight")
	var porch: OmniLight3D = main.get_node("World/Home/Before/TentLight")
	day_night.apply_now()
	var porch_day := porch.light_energy
	var day_tick: int = s.tick
	s.tick = (s.current_day() - 1) * s.ticks_per_day + DayTime.night_offset_ticks(s, game.content) + 20
	day_night.apply_now()
	check(day_night.nightness > 0.9, "de noche está oscuro (%.2f)" % day_night.nightness)
	check(porch.light_energy > porch_day, "el farol de la carpa brilla más de noche")
	await look(Vector3(-3.0, 0.05, -15.6), 6, -38)
	check(ctx_kind() == "none" and String(ui.context().get("text", "")).contains("noche"), "de noche no se puede pescar")
	s.tick = day_tick
	day_night.apply_now()
	await wait_physics()

	# 7) Guardar, empezar de cero y cargar.
	var saved := game.save_game() as CommandResult
	check(saved.ok, "guardado: " + saved.message)
	var wallet_saved: int = s.player.wallet_cents
	game.new_game()
	await wait_physics()
	check(not piece("SignPlot").get_node("After").visible, "partida nueva sin cartel")
	var loaded := game.load_game() as CommandResult
	check(loaded.ok, "carga: " + loaded.message)
	await wait_physics()
	s = game.state
	check(piece("SignPlot").get_node("After").visible, "tras cargar, el cartel vuelve")
	check(s.player.wallet_cents == wallet_saved, "tras cargar, la misma plata")
	check(main.get_node("World/Neighbors/Tent_lake").visible and main.get_node("World/Neighbors/Beto").visible, "tras cargar, Beto sigue en su carpa")

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

	# 8b) Si termina la jornada y no estás en la cama, dormís afuera y amanecés en la choza.
	player.apply_pose({"position": Vector3(8, 0.05, 6), "yaw": 0.0, "pitch": 0.0})
	game.state.player.hunger_bp = PlayerState.FULL
	game.state.player.thirst_bp = PlayerState.FULL
	day = game.state.current_day()
	game.state.tick = day * game.state.ticks_per_day - 2
	t0 = Time.get_ticks_msec()
	while ui.active_panel() != ui.report and Time.get_ticks_msec() - t0 < 4000:
		await wait_physics()
	check(ui.active_panel() == ui.report and game.state.reports[-1].slept_outside, "informe: dormiste afuera")
	check(player.global_position.distance_to(spawn) < 0.5, "amanece en la choza")
	check(game.state.player.hunger_bp < PlayerState.FULL, "dormir afuera da hambre")
	ui.report.request_close()
	await wait_physics()

	# 9) Dormir desde la cama.
	day = game.state.current_day()
	await look(Vector3(0.3, 0.05, 1.3), 0, -35)
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.report and game.state.current_day() == day + 1, "dormir termina el día")
	check(not game.state.reports[-1].events.is_empty(), "antes de dormir pasó algo")
	ui.report.request_close()
	await wait_physics()

	# 10) Mochila (Tab) y pausa (Esc).
	press("notebook")
	await wait_physics()
	check(ui.active_panel() == ui.bag, "Tab abre la mochila")
	check(ui.bag._goal.get_child_count() > 3, "la mochila muestra la meta del pueblito")
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
