extends Node
## Punto de acceso global (autoload "Game"): coordina la sesión de juego.
## Ejecuta comandos del dominio en orden, avanza el reloj administrativo,
## guarda/carga y notifica a la presentación mediante señales.
## No contiene reglas económicas: esas viven en scripts/domain.

signal treasury_changed
signal project_state_changed(project_id: String)
signal service_changed(service_id: String)
signal day_closed(report: DayReport)
signal facts_changed
## La partida activa fue reemplazada (nueva partida o carga): reconstruir visuales.
signal state_replaced
signal notice_posted(text: String)
## Cambió la billetera, la mochila o las herramientas del personaje.
signal player_changed
## La jornada terminó fuera de la cama (desmayo o dormir afuera): despierta en su choza.
## Se emite ANTES del autoguardado para que se guarde la pose de la choza.
signal woke_at_home(report: DayReport)
## Cambió el campamento: madera o construcciones.
signal camp_changed

const CONTENT_PATH := "res://data/game_content.tres"
const GAME_VERSION := "0.5.0-beto"
const DEFAULT_SEED := 20261005
const MANUAL_SLOT := "manual_1"
const AUTOSAVE_SLOT := "autosave"
const COMMAND_LOG_LIMIT := 50

var content: GameContent
var state: GameState
var clock := SimClock.new()
var saves := SaveService.new()
var settings := SettingsStore.new()
## Callable sin argumentos que devuelve la pose del jugador para guardarla.
var player_pose_provider: Callable
var autosave_enabled := true
## Resultado del último autoguardado al cerrar jornada (null si no hubo).
var last_autosave: CommandResult

## Diagnóstico (microsegundos).
var last_step_usec: int = 0
var last_close_usec: int = 0
var last_save_usec: int = 0
var command_log: Array[String] = []

var _pause_reasons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	content = load(CONTENT_PATH) as GameContent
	clock.configure(content.balance)
	settings.load_settings()
	settings.apply_audio()
	new_game()


func new_game(seed_value: int = DEFAULT_SEED) -> void:
	state = GameState.create_new(content, seed_value)
	clock.reset()
	_replaced()


# --- Reloj ----------------------------------------------------------------

func _process(delta: float) -> void:
	if is_paused():
		return
	var steps := clock.consume(delta)
	for i in steps:
		_run_step()


func _run_step() -> void:
	var t0 := Time.get_ticks_usec()
	var report := Simulation.step(state, content)
	last_step_usec = Time.get_ticks_usec() - t0
	_flush_notices()
	if state.player.faint_pending:
		_handle_faint(report)
	elif report != null:
		last_close_usec = last_step_usec
		if report.slept_outside:
			_wake_at_home(report)
		_after_day_closed(report)


## Desmayo: el resto de la jornada pasa sin conciencia (sin hambre ni sed) y despierta en casa.
func _handle_faint(report_if_closed: DayReport) -> void:
	state.player.faint_pending = false
	var report := report_if_closed
	if report == null:
		report = Simulation.advance_to_end_of_day(state, content, true)
	state.notices.clear()
	clock.reset()
	_log("faint day %d" % report.day)
	_wake_at_home(report)
	_after_day_closed(report)


func _wake_at_home(report: DayReport) -> void:
	state.player_pose = {}
	player_changed.emit()
	woke_at_home.emit(report)


func push_pause(reason: String) -> void:
	_pause_reasons[reason] = true


func pop_pause(reason: String) -> void:
	_pause_reasons.erase(reason)


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


# --- Comandos -------------------------------------------------------------

## Dormir: antes pasa algo raro (o un susto); después la jornada termina con los mismos
## pasos del reloj, sin hambre ni sed mientras dormís.
func sleep() -> DayReport:
	var t0 := Time.get_ticks_usec()
	var report := Simulation.go_to_bed(state, content)
	# Mientras dormís no hay avisos sueltos: lo importante va en el informe.
	state.notices.clear()
	last_close_usec = Time.get_ticks_usec() - t0
	clock.reset()
	_log("sleep -> close_day %d" % report.day)
	_after_day_closed(report)
	return report


# --- Comandos del personaje ---------------------------------------------------

func cast_line(spot: String = "shore") -> Dictionary:
	var r := PlayerActions.cast_line(state, content, spot)
	if r["ok"]:
		player_changed.emit()
	return r


func land_fish(fish_id: String, perfect: bool) -> CommandResult:
	return _player_command("land_fish", PlayerActions.land_fish(state, content, fish_id, perfect))


func consume(item_id: String) -> CommandResult:
	return _player_command("consume", PlayerActions.consume(state, content, item_id))


func drink_lake() -> CommandResult:
	return _player_command("drink_lake", PlayerActions.drink_lake(state, content))


func boil_water() -> CommandResult:
	return _player_command("boil_water", PlayerActions.boil_water(state, content))


func load_smoker() -> CommandResult:
	return _player_command("load_smoker", PlayerActions.load_smoker(state, content))


func collect_smoker() -> CommandResult:
	return _player_command("collect_smoker", PlayerActions.collect_smoker(state, content))


func cook_and_eat(fish_id: String) -> CommandResult:
	return _player_command("cook_and_eat", PlayerActions.cook_and_eat(state, content, fish_id))


func add_wood() -> CommandResult:
	return _player_command("add_wood", PlayerActions.add_wood(state, content))


func make_rod() -> CommandResult:
	return _player_command("make_rod", PlayerActions.make_rod(state, content))


func collect_longline() -> CommandResult:
	return _player_command("collect_longline", PlayerActions.collect_longline(state, content))


# --- Vecinos y meta -------------------------------------------------------------

func place_neighbor(id: String, spot: String) -> CommandResult:
	return _player_command("place_neighbor", Neighbors.place(state, id, spot))


## Clave del capítulo de hoy ("" si ya charlaron hoy).
func talk_neighbor(id: String) -> String:
	var key := Neighbors.talk(state, id)
	_log("talk %s -> %s" % [id, key])
	return key


func found_pueblo() -> CommandResult:
	var result := StageGoal.found(state, content)
	_player_command("found_pueblo", result)
	if result.ok:
		facts_changed.emit()
	return result


func gather_branches(spot_id: String) -> CommandResult:
	return _player_command("gather_branches", PlayerActions.gather_branches(state, content, spot_id))


func chop_tree(tree_id: String, success: bool) -> CommandResult:
	return _player_command("chop_tree", PlayerActions.chop_tree(state, content, tree_id, success))


func build(building_id: String) -> CommandResult:
	var result := PlayerActions.build(state, content, building_id)
	_player_command("build", result)
	if result.ok:
		camp_changed.emit()
	return result


# --- Comerciantes ---------------------------------------------------------------

func hail_merchant(pass_id: int) -> CommandResult:
	var result := Merchants.hail(state, content, pass_id)
	_log("hail %d -> %s" % [pass_id, result.code])
	return result


func sell_to_merchant(pass_id: int, item_id: String, qty: int) -> CommandResult:
	return _player_command("sell", Merchants.sell_to(state, content, pass_id, item_id, qty))


func buy_from_merchant(pass_id: int, item_id: String) -> CommandResult:
	return _player_command("buy", Merchants.buy_from(state, content, pass_id, item_id))


func begin_merchant_visit(pass_id: int) -> int:
	var had_dog := state.has_fact("player", "has_dog")
	var n := Merchants.begin_visit(state, content, pass_id)
	_log("visit %d -> %d" % [pass_id, n])
	if not had_dog and state.has_fact("player", "has_dog"):
		facts_changed.emit()
	return n


func dismiss_merchant(pass_id: int) -> void:
	Merchants.dismiss(state, pass_id)
	_log("dismiss %d" % pass_id)


func _flush_notices() -> void:
	if state.notices.is_empty():
		return
	var pending := state.notices
	state.notices = PackedStringArray()
	for n in pending:
		notice_posted.emit(n)
	camp_changed.emit()


func _player_command(command_name: String, result: CommandResult) -> CommandResult:
	_log("%s -> %s" % [command_name, result.code])
	if result.ok:
		player_changed.emit()
		camp_changed.emit()
	return result


func record_fact(subject: String, fact: String) -> void:
	if not state.facts.has(subject) or state.has_fact(subject, fact):
		return
	state.facts[subject][fact] = true
	facts_changed.emit()


func _after_day_closed(report: DayReport) -> void:
	for c in report.completed_projects:
		project_state_changed.emit(String(c["project_id"]))
	# Una colecta pudo llegar a la meta en el cierre: la obra arranca mañana.
	for id in content.project_ids():
		project_state_changed.emit(id)
	if report.next_water_capacity != report.water_capacity:
		service_changed.emit(Simulation.SERVICE_WATER)
	treasury_changed.emit()
	player_changed.emit()
	camp_changed.emit()
	if autosave_enabled:
		last_autosave = save_game(AUTOSAVE_SLOT)
		if not last_autosave.ok:
			notice_posted.emit(last_autosave.message)
	day_closed.emit(report)


# --- Guardado -------------------------------------------------------------

func save_game(slot: String = MANUAL_SLOT) -> CommandResult:
	if player_pose_provider.is_valid():
		state.player_pose = player_pose_provider.call()
	var t0 := Time.get_ticks_usec()
	var result := saves.write_state(state, content, GAME_VERSION, slot)
	last_save_usec = Time.get_ticks_usec() - t0
	_log("save %s -> %s" % [slot, result.code])
	return result


func load_game(slot: String = MANUAL_SLOT) -> CommandResult:
	var loaded := saves.read_slot(slot, content)
	_log("load %s -> %s" % [slot, "ok" if loaded["ok"] else "error"])
	if not loaded["ok"]:
		# La partida actual queda intacta.
		return CommandResult.failure("load_failed", "%s %s" % [loaded["message"], Texts.t("MSG_CURRENT_GAME_KEPT")])
	state = loaded["state"]
	clock.reset()
	_replaced()
	var msg := Texts.t("MSG_LOADED", {"day": state.current_day()})
	if loaded["from_backup"]:
		msg = loaded["message"]
	return CommandResult.success(msg)


func has_save(slot: String = MANUAL_SLOT) -> bool:
	return saves.slot_exists(slot)


func _replaced() -> void:
	state_replaced.emit()
	treasury_changed.emit()
	facts_changed.emit()
	player_changed.emit()
	camp_changed.emit()


func _log(line: String) -> void:
	command_log.append("[t%d] %s" % [state.tick if state else 0, line])
	if command_log.size() > COMMAND_LOG_LIMIT:
		command_log.pop_front()
