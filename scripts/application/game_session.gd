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

const CONTENT_PATH := "res://data/game_content.tres"
const GAME_VERSION := "0.1.0-h1"
const DEFAULT_SEED := 20261005
const MANUAL_SLOT := "manual_1"
const AUTOSAVE_SLOT := "autosave"
const COMMAND_LOG_LIMIT := 50

var content: GameContent
var state: GameState
var clock := SimClock.new()
var saves := SaveService.new()
var settings := SettingsStore.new()
var dialogues: Dictionary = {}
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
	dialogues["neighbor_rosa"] = DialogueService.load_file("res://data/dialogue/neighbor_rosa.json")
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
	if report != null:
		last_close_usec = last_step_usec
		_after_day_closed(report)


func push_pause(reason: String) -> void:
	_pause_reasons[reason] = true


func pop_pause(reason: String) -> void:
	_pause_reasons.erase(reason)


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


# --- Comandos -------------------------------------------------------------

func approve_project(project_id: String) -> CommandResult:
	# Clave estable: aprobar la misma obra dos veces es la misma operación.
	var op_key := "approve_project:%s" % project_id
	var result := Simulation.approve_project(state, content, project_id, op_key)
	_log("approve_project %s -> %s" % [project_id, result.code])
	if result.ok and not result.is_duplicate():
		treasury_changed.emit()
		project_state_changed.emit(project_id)
	return result


## Cierra la jornada actual ejecutando los pasos pendientes con la misma lógica del reloj.
func close_current_day() -> DayReport:
	var t0 := Time.get_ticks_usec()
	var report := Simulation.advance_to_end_of_day(state, content)
	last_close_usec = Time.get_ticks_usec() - t0
	clock.reset()
	_log("close_day %d" % report.day)
	_after_day_closed(report)
	return report


func record_fact(subject: String, fact: String) -> void:
	if not state.facts.has(subject) or state.has_fact(subject, fact):
		return
	state.facts[subject][fact] = true
	facts_changed.emit()


func _after_day_closed(report: DayReport) -> void:
	for c in report.completed_projects:
		project_state_changed.emit(String(c["project_id"]))
	if report.next_water_capacity != report.water_capacity:
		service_changed.emit(Simulation.SERVICE_WATER)
	if not report.payment_lines.is_empty():
		treasury_changed.emit()
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


func _log(line: String) -> void:
	command_log.append("[t%d] %s" % [state.tick if state else 0, line])
	if command_log.size() > COMMAND_LOG_LIMIT:
		command_log.pop_front()
