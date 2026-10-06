extends SceneTree
## Pruebas de dominio y aplicación, sin renderizado.
## Uso: godot --headless --path . --script tests/run_tests.gd
## Sale con código 0 si todo pasa y 1 si alguna prueba falla.

const CONTENT := preload("res://data/game_content.tres")
const SESSION_SCRIPT := preload("res://scripts/application/game_session.gd")
const TEST_SAVE_DIR := "user://test_saves"
const FIXTURE_V1 := "res://tests/fixtures/save_v1_day2.json"

var _failures: PackedStringArray = PackedStringArray()
var _checks := 0
var _current := ""


func _initialize() -> void:
	var tests := [
		"test_money_format",
		"test_texts_loaded",
		"test_double_approval_charges_once",
		"test_insufficient_funds_no_mutation",
		"test_cash_balance_matches_ledger",
		"test_capacity_changes_from_next_day",
		"test_multi_day_project_timing",
		"test_advance_day_equals_stepping",
		"test_simulation_without_actors",
		"test_zero_values_no_invalid_division",
		"test_save_roundtrip_preserves_state_and_rng",
		"test_load_does_not_repeat_effects",
		"test_corrupt_and_future_saves_rejected",
		"test_tampered_save_rejected",
		"test_backup_used_when_main_save_corrupt",
		"test_session_load_failure_keeps_current_game",
		"test_pause_does_not_advance_economy",
		"test_clock_never_drops_steps",
		"test_dialogue_follows_state",
		"test_fixture_v1_loads",
	]
	for t in tests:
		_current = t
		var finished: Variant = call(t)
		# Un error de script interrumpe la prueba y devuelve null: cuenta como fallo.
		if finished != true and not _failures_for(t):
			_failures.append("%s: la prueba no terminó (error de script)" % t)
	_cleanup_dir(TEST_SAVE_DIR)
	print("")
	if _failures.is_empty():
		print("OK: %d pruebas, %d comprobaciones" % [tests.size(), _checks])
		quit(0)
	else:
		for f in _failures:
			printerr("FALLO ", f)
		print("FALLARON %d comprobaciones de %d" % [_failures.size(), _checks])
		quit(1)


func _failures_for(t: String) -> bool:
	for f in _failures:
		if f.begins_with(t + ":"):
			return true
	return false


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("%s: %s" % [_current, what])


func eq(a: Variant, b: Variant, what: String) -> void:
	check(a == b, "%s (obtenido %s, esperado %s)" % [what, a, b])


func new_state(seed_value: int = 1234) -> GameState:
	return GameState.create_new(CONTENT, seed_value)


func approve(s: GameState, content: GameContent = CONTENT, id: String = "well_repair") -> CommandResult:
	return Simulation.approve_project(s, content, id, "approve_project:%s" % id)


# ---------------------------------------------------------------------------

func test_money_format() -> bool:
	eq(Money.format(320000), "3.200 UC", "miles con punto")
	eq(Money.format(1000000), "10.000 UC", "diez mil")
	eq(Money.format(5), "0,05 UC", "centésimos")
	eq(Money.format(-123456789), "-1.234.567,89 UC", "negativo")
	eq(Money.format_bp_percent(3333), "33 %", "porcentaje desde puntos básicos")
	return true


func test_texts_loaded() -> bool:
	eq(Texts.t("HUD_DAY", {"day": 3}), "Día 3", "traducción CSV cargada con parámetros")
	return true


func test_double_approval_charges_once() -> bool:
	var s := new_state()
	var r1 := approve(s)
	check(r1.ok and not r1.is_duplicate(), "primera aprobación exitosa")
	var cash_after := s.treasury.cash_cents
	eq(cash_after, 1000000 - 320000, "se descontaron 3.200 UC")
	# Mismo comando repetido (doble clic / reintento): misma clave de operación.
	var r2 := approve(s)
	check(r2.ok and r2.is_duplicate(), "el duplicado se reconoce como ya aplicado")
	# Otro comando con otra clave sobre la misma obra: rechazado por estado.
	var r3 := Simulation.approve_project(s, CONTENT, "well_repair", "otra_clave")
	check(not r3.ok, "otra clave no puede aprobar una obra ya en curso")
	eq(r3.code, "project_not_available", "código de error")
	eq(s.treasury.cash_cents, cash_after, "la caja no cambió con los reintentos")
	eq(s.treasury.ledger.size(), 1, "un solo movimiento en el libro")
	return true


func test_insufficient_funds_no_mutation() -> bool:
	var s := new_state()
	s.treasury = TreasuryState.create(300000)  # 3.000 UC, la obra cuesta 3.200
	var before := JSON.stringify(s.to_dict("test"))
	var r := approve(s)
	check(not r.ok, "rechazada por fondos")
	eq(r.code, "insufficient_funds", "código de error")
	check(r.message.contains("200 UC"), "el mensaje indica cuánto falta: " + r.message)
	eq(JSON.stringify(s.to_dict("test")), before, "ningún cambio en caja, obra, libro ni operaciones")
	return true


func test_cash_balance_matches_ledger() -> bool:
	var s := new_state()
	approve(s)
	Simulation.advance_to_end_of_day(s, CONTENT)
	Simulation.advance_to_end_of_day(s, CONTENT)
	check(s.treasury.is_consistent(), "caja = inicial + ingresos - pagos")
	eq(s.treasury.cash_cents, s.treasury.opening_cents + s.treasury.total_income() - s.treasury.total_payments(), "igualdad exacta")
	for rep in s.reports:
		eq(rep.cash_end_cents, rep.cash_start_cents + rep.income_cents - rep.payments_cents, "informe del día %d cuadra" % rep.day)
	eq(s.reports[0].payments_cents, 320000, "el pago figura en el informe del día 1")
	eq(s.reports[1].payments_cents, 0, "el día 2 no repite el pago")
	return true


func test_capacity_changes_from_next_day() -> bool:
	var s := new_state()
	for i in 100:
		Simulation.step(s, CONTENT)
	approve(s)
	eq(Simulation.water_capacity(s, CONTENT, 1), 20, "en obra el día 1 sigue en 20")
	var rep1 := Simulation.advance_to_end_of_day(s, CONTENT)
	eq(rep1.day, 1, "cierre del día 1")
	eq(rep1.water_capacity, 20, "el día 1 se prestó con capacidad 20")
	eq(rep1.water_served, 20, "abastecidas 20")
	eq(rep1.completed_projects.size(), 1, "la obra vence al cierre del día 1")
	eq(rep1.next_water_capacity, 60, "capacidad 60 desde mañana")
	eq(s.get_project("well_repair").status, ProjectState.COMPLETED, "obra completada")
	eq(s.get_project("well_repair").operational_from_day, 2, "opera desde el día 2")
	eq(s.current_day(), 2, "la fecha avanzó")
	var rep2 := Simulation.advance_to_end_of_day(s, CONTENT)
	eq(rep2.water_capacity, 60, "el día 2 se prestó con capacidad 60")
	eq(rep2.water_coverage_bp, 10000, "cobertura total")
	eq(rep2.completed_projects.size(), 0, "no se completa dos veces")
	return true


func test_multi_day_project_timing() -> bool:
	var def := ProjectDefinition.new()
	def.id = "slow_well"
	def.site_id = "well_test"
	def.name_key = "PROJECT_WELL_REPAIR_NAME"
	def.cost_uc = 100
	def.duration_days = 2
	def.service_id = "water"
	def.capacity_after = 45
	var content := GameContent.new()
	content.balance = CONTENT.balance
	content.projects = [def]
	content.fact_subjects = CONTENT.fact_subjects
	var s := GameState.create_new(content, 1)
	check(approve(s, content, "slow_well").ok, "aprobada")
	var r1 := Simulation.advance_to_end_of_day(s, content)
	eq(r1.completed_projects.size(), 0, "plazo 2: no termina el día 1")
	eq(r1.next_water_capacity, 20, "sigue en 20")
	var r2 := Simulation.advance_to_end_of_day(s, content)
	eq(r2.completed_projects.size(), 1, "termina al cierre del día 2")
	eq(r2.water_capacity, 20, "el día 2 todavía rige 20")
	eq(Simulation.water_capacity(s, content, 3), 45, "desde el día 3 rige 45")
	return true


func test_advance_day_equals_stepping() -> bool:
	var a := new_state(99)
	var b := new_state(99)
	for s in [a, b]:
		for i in 50:
			Simulation.step(s, CONTENT)
		approve(s)
	Simulation.advance_to_end_of_day(a, CONTENT)
	var closed: DayReport = null
	while closed == null:
		closed = Simulation.step(b, CONTENT)
	eq(JSON.stringify(a.to_dict("t")), JSON.stringify(b.to_dict("t")), "mismo estado administrativo")
	return true


func test_simulation_without_actors() -> bool:
	# Todo el dominio corre sin escenas cargadas: este runner no instancia actores 3D.
	var s := new_state()
	approve(s)
	for d in 3:
		Simulation.advance_to_end_of_day(s, CONTENT)
	eq(s.current_day(), 4, "tres jornadas simuladas sin SceneTree de juego")
	eq(s.settlement.population, 60, "la población no depende de actores")
	return true


func test_zero_values_no_invalid_division() -> bool:
	eq(Simulation.coverage_bp(0, 0), 10000, "demanda cero = cobertura total")
	eq(Simulation.coverage_bp(5, 0), 10000, "capacidad sin demanda")
	eq(Simulation.coverage_bp(0, 10), 0, "sin capacidad")
	eq(Simulation.coverage_bp(200, 60), 10000, "el sobrante no supera 100 %")
	var s := new_state()
	s.settlement.population = 0
	s.settlement.base_water_capacity = 0
	var rep := Simulation.advance_to_end_of_day(s, CONTENT)
	eq(rep.water_served, 0, "población cero")
	eq(rep.water_coverage_bp, 10000, "sin NaN ni división por cero")
	s.treasury = TreasuryState.create(0)
	check(not approve(s).ok, "caja cero rechaza la obra")
	return true


func test_save_roundtrip_preserves_state_and_rng() -> bool:
	var svc := _service()
	var s := new_state(4242)
	for i in 30:
		Simulation.step(s, CONTENT)
	approve(s)
	Simulation.advance_to_end_of_day(s, CONTENT)
	for i in 77:
		Simulation.step(s, CONTENT)
	s.rng.randi()
	s.rng.randi()
	s.facts["neighbor_rosa"]["promised_well"] = true
	s.player_pose = {"position": Vector3(1.5, 0.05, -3.25), "yaw": 0.5, "pitch": -10.0}
	var w := svc.write_state(s, CONTENT, "test", "roundtrip")
	check(w.ok, "guardado: " + w.message)
	var loaded := svc.read_slot("roundtrip", CONTENT)
	check(loaded["ok"], "carga: %s" % loaded["message"])
	if not loaded["ok"]:
		return false
	var l: GameState = loaded["state"]
	eq(JSON.stringify(l.to_dict("test")), JSON.stringify(s.to_dict("test")), "estado idéntico tras guardar y cargar")
	eq(l.treasury.cash_cents, s.treasury.cash_cents, "tesorería")
	eq(l.tick, s.tick, "calendario")
	eq(l.get_project("well_repair").status, ProjectState.COMPLETED, "obra")
	eq(l.rng.randi(), s.rng.randi(), "el generador continúa igual")
	check(l.has_fact("neighbor_rosa", "promised_well"), "hechos narrativos")
	eq(l.player_pose["position"], Vector3(1.5, 0.05, -3.25), "pose del jugador")
	return true


func test_load_does_not_repeat_effects() -> bool:
	var svc := _service()
	var s := new_state()
	approve(s)
	svc.write_state(s, CONTENT, "test", "repeat")
	var l: GameState = svc.read_slot("repeat", CONTENT)["state"]
	var again := approve(l)
	check(again.is_duplicate(), "la aprobación cargada no se vuelve a cobrar")
	eq(l.treasury.cash_cents, 680000, "caja sin doble cobro tras cargar")
	Simulation.advance_to_end_of_day(l, CONTENT)
	eq(l.treasury.ledger.size(), 1, "terminar la obra tras cargar no crea pagos")
	return true


func test_corrupt_and_future_saves_rejected() -> bool:
	var svc := _service()
	var bad := svc.parse_text("{ esto no es json", CONTENT)
	check(not bad["ok"] and not String(bad["message"]).is_empty(), "JSON dañado con mensaje")
	var d := new_state().to_dict("test")
	d["schema_version"] = GameState.SCHEMA_VERSION + 1
	var future := svc.parse_text(JSON.stringify(d), CONTENT)
	check(not future["ok"] and future.get("future_version", false), "versión futura rechazada")
	check(String(future["message"]).contains("más nueva"), "mensaje de versión futura")
	var missing := new_state().to_dict("test")
	missing.erase("treasury")
	check(not svc.parse_text(JSON.stringify(missing), CONTENT)["ok"], "falta tesorería")
	var unknown := new_state().to_dict("test")
	unknown["projects"][0]["id"] = "proyecto_fantasma"
	check(not svc.parse_text(JSON.stringify(unknown), CONTENT)["ok"], "proyecto desconocido rechazado")
	return true


func test_tampered_save_rejected() -> bool:
	var svc := _service()
	var s := new_state()
	approve(s)
	var d := s.to_dict("test")
	d["treasury"]["cash_cents"] = "99999999"
	var r := svc.parse_text(JSON.stringify(d), CONTENT)
	check(not r["ok"], "caja que no coincide con el libro: rechazada")
	var d2 := s.to_dict("test")
	d2["projects"][0]["status"] = "completed"
	check(not svc.parse_text(JSON.stringify(d2), CONTENT)["ok"], "obra completada sin cierre: rechazada")
	var d3 := s.to_dict("test")
	d3["tick"] = 12.5
	check(not svc.parse_text(JSON.stringify(d3), CONTENT)["ok"], "tick no decimal en cadena: rechazado")
	return true


func test_backup_used_when_main_save_corrupt() -> bool:
	var svc := _service()
	var s := new_state()
	check(svc.write_state(s, CONTENT, "test", "bak").ok, "primer guardado")
	approve(s)
	check(svc.write_state(s, CONTENT, "test", "bak").ok, "segundo guardado (el primero pasa a .bak)")
	check(FileAccess.file_exists(svc.slot_path("bak") + ".bak"), "existe la copia anterior")
	check(not FileAccess.file_exists(svc.slot_path("bak") + ".tmp"), "no queda temporal")
	var f := FileAccess.open(svc.slot_path("bak"), FileAccess.WRITE)
	f.store_string("{roto")
	f.close()
	var r := svc.read_slot("bak", CONTENT)
	check(r["ok"] and r["from_backup"], "se recupera la copia anterior")
	if r["ok"]:
		eq((r["state"] as GameState).treasury.cash_cents, 1000000, "la copia anterior es el primer guardado")
	return true


func test_session_load_failure_keeps_current_game() -> bool:
	var session: Node = SESSION_SCRIPT.new()
	session._ready()
	session.autosave_enabled = false
	session.saves.save_dir = TEST_SAVE_DIR
	session.approve_project("well_repair")
	var before := JSON.stringify(session.state.to_dict("t"))
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var f := FileAccess.open(session.saves.slot_path("manual_1"), FileAccess.WRITE)
	f.store_string("{\"schema_version\": 99}")
	f.close()
	DirAccess.remove_absolute(session.saves.slot_path("manual_1") + ".bak")
	var r: CommandResult = session.load_game()
	check(not r.ok, "carga de versión futura falla")
	check(not r.message.is_empty(), "con mensaje: " + r.message)
	eq(JSON.stringify(session.state.to_dict("t")), before, "la partida actual quedó intacta")
	session.free()
	return true


func test_pause_does_not_advance_economy() -> bool:
	var session: Node = SESSION_SCRIPT.new()
	session._ready()
	session.autosave_enabled = false
	session.push_pause("ui")
	session._process(30.0)
	eq(session.state.tick, 0, "en pausa (diálogo/gestión) no avanza el reloj")
	session.pop_pause("ui")
	session._process(2.0)
	eq(session.state.tick, 2, "sin pausa avanza 1 paso por segundo")
	session.free()
	return true


func test_clock_never_drops_steps() -> bool:
	var c := SimClock.new()
	c.configure(CONTENT.balance)
	var total := c.consume(10.0)
	eq(total, 4, "como máximo 4 pasos por fotograma")
	check(c.lag_frames == 1, "se registra el atraso")
	for i in 5:
		total += c.consume(0.0)
	eq(total, 10, "los pasos pendientes se recuperan, no se descartan")
	return true


func test_dialogue_follows_state() -> bool:
	var dlg := DialogueService.load_file("res://data/dialogue/neighbor_rosa.json")
	var s := new_state()
	eq(dlg.start_entry(s).get("id"), "intro", "primera conversación")
	s.facts["neighbor_rosa"]["water_complaint_heard"] = true
	eq(dlg.start_entry(s).get("id"), "waiting", "ya escuchó el pedido")
	s.facts["neighbor_rosa"]["promised_well"] = true
	eq(dlg.start_entry(s).get("id"), "waiting_promised", "recuerda la promesa")
	eq(dlg.visible_options(dlg.get_entry("pump_detail"), s).size(), 1, "no ofrece prometer dos veces")
	approve(s)
	eq(dlg.start_entry(s).get("id"), "in_progress", "obra en curso")
	Simulation.advance_to_end_of_day(s, CONTENT)
	eq(dlg.start_entry(s).get("id"), "done_promised", "reconoce la promesa cumplida")
	return true


## Fixture generado con el código real de H1 (schema 1): pozo reparado, día 2.
## Se regenera solo si cambia el esquema, con tools/make_fixture.gd.
func test_fixture_v1_loads() -> bool:
	var f := FileAccess.open(FIXTURE_V1, FileAccess.READ)
	check(f != null, "existe el fixture")
	if f == null:
		return false
	var r := _service().parse_text(f.get_as_text(), CONTENT)
	check(r["ok"], "el fixture v1 carga: %s" % r.get("message", ""))
	if not r["ok"]:
		return false
	var s: GameState = r["state"]
	eq(s.current_day(), 2, "día 2")
	eq(s.treasury.cash_cents, 680000, "caja 6.800 UC")
	eq(s.get_project("well_repair").status, ProjectState.COMPLETED, "pozo reparado")
	eq(Simulation.water_capacity(s, CONTENT, s.current_day()), 60, "capacidad 60")
	return true


# ---------------------------------------------------------------------------

func _service() -> SaveService:
	var svc := SaveService.new()
	svc.save_dir = TEST_SAVE_DIR
	return svc


func _cleanup_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)
