extends Node
## Prueba de humo de la escena principal (sin renderizado): recorre la primera
## experiencia completa usando el rayo de interacción real del jugador.
## Uso: godot --headless --path . res://tests/smoke_test.tscn
## (Es una escena y no un --script para que el autoload "Game" esté disponible.)
## Termina sola (límite de fotogramas) y sale con código distinto de cero si falla.

const SMOKE_SAVE_DIR := "user://smoke_saves"
const FRAME_LIMIT := 3000

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


func look_from(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	player.apply_pose({"position": pos, "yaw": deg_to_rad(yaw_deg), "pitch": pitch_deg})


func well_variant() -> String:
	return main.get_node("Settlement/WellSite").visible_variant()


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

	# 1) Aparezco cerca de la oficina.
	var spawn: Vector3 = main.get_node("Settlement/PlayerSpawn").global_position
	check(player.global_position.distance_to(spawn) < 0.5, "el jugador aparece en el punto inicial")
	check(well_variant() == ProjectState.AVAILABLE, "el pozo empieza deteriorado")

	# 2) Hablar con Rosa usando el rayo de interacción.
	look_from(Vector3(0.6, 0.05, -10.0), -90.0, -5.0)
	await wait_physics()
	var focus := player.current_focus()
	check(focus != null and focus.target_id == "neighbor_rosa", "el rayo enfoca a Rosa (%s)" % [focus.target_id if focus else "nada"])
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.dialogue, "se abre el diálogo")
	check(game.is_paused(), "el diálogo pausa la simulación")
	check(game.state.has_fact("neighbor_rosa", "water_complaint_heard"), "Rosa registró que explicó el problema")
	var tick_before: int = game.state.tick
	await wait_physics(30)
	check(game.state.tick == tick_before, "la jornada no avanza con el diálogo abierto")
	_press_option(ui.dialogue, "DLG_OPT_WHATS_WRONG")
	_press_option(ui.dialogue, "DLG_OPT_PROMISE")
	check(game.state.has_fact("neighbor_rosa", "promised_well"), "la promesa queda registrada")
	_press_option(ui.dialogue, "DLG_OPT_BYE")
	await wait_physics()
	check(ui.active_panel() == null and not game.is_paused(), "el diálogo se cierra y la simulación sigue")

	# 2b) El rayo respeta paredes: desde afuera de la oficina, el escritorio no se enfoca.
	look_from(Vector3(-20.3, 0.05, -13.0), -90.0, -30.0)
	await wait_physics()
	check(player.current_focus() == null, "la pared oeste bloquea el rayo hacia el escritorio")

	# 3) Inspeccionar el pozo.
	look_from(Vector3(0.0, 0.05, -10.6), 0.0, -25.0)
	await wait_physics()
	focus = player.current_focus()
	check(focus != null and focus.target_id == "well_main", "el rayo enfoca el pozo")
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.inspect, "se abre la inspección")
	check(game.state.has_fact("player", "inspected_well"), "inspección registrada")
	press("pause")
	await wait_physics()
	check(ui.active_panel() == null, "Escape cierra el panel activo")

	# 4-5) Escritorio: aprobar la reparación (dos clics: confirmar y pagar).
	look_from(Vector3(-16.0, 0.05, -13.0), 90.0, -30.0)
	await wait_physics()
	focus = player.current_focus()
	check(focus != null and focus.target_id == "office_desk", "el rayo enfoca el escritorio")
	press("interact")
	await wait_physics()
	check(ui.active_panel() == ui.desk, "se abre el escritorio")
	ui.desk._on_approve()
	check(game.state.treasury.cash_cents == 1000000, "el primer clic solo pide confirmación")
	ui.desk._on_approve()
	check(game.state.treasury.cash_cents == 680000, "se descuentan 3.200 UC una sola vez")
	check(game.state.get_project("well_repair").status == ProjectState.UNDER_CONSTRUCTION, "obra en curso")
	await wait_physics()
	check(well_variant() == ProjectState.UNDER_CONSTRUCTION, "aparece la obra en el mapa")
	var again: CommandResult = game.approve_project("well_repair")
	check(again.ok and again.is_duplicate() and game.state.treasury.cash_cents == 680000, "reintentar no vuelve a cobrar")

	# 6-7) Cerrar la jornada desde el escritorio: informe y obra terminada.
	ui.desk._on_close_day()
	await wait_physics()
	check(ui.active_panel() == ui.report, "se muestra el informe de cierre")
	var rep: DayReport = game.state.last_report()
	check(rep != null and rep.day == 1, "informe del día 1")
	check(rep != null and rep.payments_cents == 320000 and rep.water_capacity == 20 and rep.next_water_capacity == 60, "informe: pago, agua de hoy y de mañana")
	check(game.state.current_day() == 2, "empieza el día 2")
	check(well_variant() == ProjectState.COMPLETED, "el pozo cambia a reparado")
	check(main.get_node("Settlement/NeighborRosa/Body/BucketWater").visible, "el balde de Rosa ahora tiene agua")
	check(game.last_autosave != null and game.last_autosave.ok, "autoguardado al cerrar la jornada")
	ui.report._on_continue()
	check(ui.active_panel() == ui.desk, "continuar vuelve al escritorio")
	ui.desk.request_close()
	await wait_physics()
	check(ui.active_panel() == null and not game.is_paused(), "se sale del escritorio")

	# 8) Guardar, empezar de cero y cargar.
	look_from(Vector3(-3.0, 0.05, -9.0), 45.0, -10.0)
	await wait_physics()
	var saved := game.save_game() as CommandResult
	check(saved.ok, "guardado manual: " + saved.message)
	var saved_pos := player.global_position
	game.new_game()
	await wait_physics()
	check(well_variant() == ProjectState.AVAILABLE and game.state.treasury.cash_cents == 1000000, "nueva partida restablece el pozo")
	var loaded := game.load_game() as CommandResult
	check(loaded.ok, "carga: " + loaded.message)
	await wait_physics()
	check(well_variant() == ProjectState.COMPLETED, "tras cargar, el pozo se reconstruye reparado")
	check(game.state.treasury.cash_cents == 680000 and game.state.treasury.ledger.size() == 1, "tras cargar, saldo y libro sin cambios")
	check(game.state.current_day() == 2, "tras cargar, mismo día")
	check(player.global_position.distance_to(saved_pos) < 0.2, "tras cargar, el jugador vuelve a su lugar")

	# Ver el resultado.
	look_from(Vector3(0.0, 0.05, -10.6), 0.0, -25.0)
	await wait_physics()
	press("interact")
	await wait_physics()
	check(game.state.has_fact("player", "saw_well_repaired"), "inspeccionar el pozo reparado")
	press("pause")
	await wait_physics()
	var all_done := true
	for o in NotebookPanel.objectives(game.state):
		all_done = all_done and bool(o["done"])
	check(all_done, "todos los objetivos de la libreta completos")

	# Libreta y pausa con teclas.
	press("notebook")
	await wait_physics()
	check(ui.active_panel() == ui.notebook, "Tab abre la libreta")
	press("notebook")
	await wait_physics()
	press("pause")
	await wait_physics()
	check(ui.active_panel() == ui.pause_menu, "Escape abre la pausa")
	press("pause")
	await wait_physics()
	check(ui.active_panel() == null, "Escape cierra la pausa")

	_cleanup()
	print("")
	if _failures.is_empty():
		print("SMOKE OK: %d comprobaciones en %d fotogramas" % [_checks, _frames])
		get_tree().quit(0)
	else:
		print("SMOKE FALLÓ: %d de %d" % [_failures.size(), _checks])
		get_tree().quit(1)


func _press_option(panel: DialoguePanel, text_key: String) -> void:
	var wanted := "› " + Texts.t(text_key)
	for b in panel._options.get_children():
		if b is Button and (b as Button).text.begins_with(wanted.substr(0, 12)):
			(b as Button).pressed.emit()
			return
	check(false, "no se encontró la opción %s" % text_key)


func _cleanup() -> void:
	var dir := DirAccess.open(SMOKE_SAVE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(SMOKE_SAVE_DIR)
