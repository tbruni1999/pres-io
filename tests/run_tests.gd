extends SceneTree
## Pruebas de dominio y aplicación, sin renderizado.
## Uso: godot --headless --path . --script tests/run_tests.gd
## Sale con código 0 si todo pasa y 1 si alguna prueba falla.
## Cada prueba devuelve true al terminar; si un error de script la corta, cuenta como fallo.

const CONTENT := preload("res://data/game_content.tres")
const SESSION_SCRIPT := preload("res://scripts/application/game_session.gd")
const TEST_SAVE_DIR := "user://test_saves"
const FIXTURE_V1 := "res://tests/fixtures/save_v1_day2.json"
const FIXTURE_V2 := "res://tests/fixtures/save_v2_day3.json"

var _failures: PackedStringArray = PackedStringArray()
var _checks := 0
var _current := ""


func _initialize() -> void:
	var tests := [
		"test_money_format",
		"test_texts_loaded",
		"test_double_approval_charges_once",
		"test_insufficient_funds_no_mutation",
		"test_fund_balance_matches_ledger",
		"test_capacity_changes_from_next_day",
		"test_multi_day_project_timing",
		"test_advance_day_equals_stepping",
		"test_simulation_without_actors",
		"test_zero_values_no_invalid_division",
		"test_needs_decay_and_tired",
		"test_faint_penalty_escalates",
		"test_sleep_freezes_needs",
		"test_fishing_deterministic_and_bag_limit",
		"test_merchant_day_plan",
		"test_hail_and_trade",
		"test_sign_makes_merchants_stop",
		"test_fish_rots_overnight",
		"test_lake_water_and_fire",
		"test_wood_and_building",
		"test_collection_funds_well",
		"test_save_roundtrip_preserves_state_and_rng",
		"test_load_does_not_repeat_effects",
		"test_corrupt_and_future_saves_rejected",
		"test_tampered_save_rejected",
		"test_backup_used_when_main_save_corrupt",
		"test_session_load_failure_keeps_current_game",
		"test_pause_does_not_advance_economy",
		"test_session_faint_wakes_next_day",
		"test_clock_never_drops_steps",
		"test_dialogue_follows_state",
		"test_fixture_v1_migrates",
		"test_fixture_v2_loads",
	]
	for t in tests:
		_current = t
		var finished: Variant = call(t)
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


## Estado con fondo comunitario de 10.000 UC, para probar la aprobación de obras.
func funded_state(seed_value: int = 1234) -> GameState:
	var s := new_state(seed_value)
	s.treasury = TreasuryState.create(1000000)
	return s


func approve(s: GameState, content: GameContent = CONTENT, id: String = "well_repair") -> CommandResult:
	return Simulation.approve_project(s, content, id, "approve_project:%s" % id, "community")


func well_cost() -> int:
	return CONTENT.find_project("well_repair").cost_cents()


## Sin hambre ni sed, para pruebas que no tratan de eso.
func fed(s: GameState) -> GameState:
	s.player.hunger_bp = PlayerState.FULL
	s.player.thirst_bp = PlayerState.FULL
	return s


## Mantiene lleno al personaje mientras avanza jornadas (evita desmayos en pruebas largas).
func advance_fed(s: GameState, content: GameContent = CONTENT) -> DayReport:
	return Simulation.advance_to_end_of_day(fed(s), content, true)


func give_money(s: GameState, units: int) -> void:
	s.player.earn(Money.from_units(units))


# --- Dinero y obras -----------------------------------------------------------

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
	var s := funded_state()
	var r1 := approve(s)
	check(r1.ok and not r1.is_duplicate(), "primera aprobación exitosa")
	var cash_after := s.treasury.cash_cents
	eq(cash_after, 1000000 - well_cost(), "se descontó el costo una vez")
	var r2 := approve(s)
	check(r2.ok and r2.is_duplicate(), "el duplicado se reconoce como ya aplicado")
	var r3 := Simulation.approve_project(s, CONTENT, "well_repair", "otra_clave", "community")
	eq(r3.code, "project_not_available", "otra clave no aprueba una obra ya en curso")
	eq(s.treasury.cash_cents, cash_after, "la caja no cambió con los reintentos")
	eq(s.treasury.ledger.size(), 1, "un solo movimiento en el libro")
	var r4 := Simulation.approve_project(funded_state(), CONTENT, "well_repair", "k")
	eq(r4.code, "no_authority", "un vecino solo no puede aprobar la obra del pozo")
	return true


func test_insufficient_funds_no_mutation() -> bool:
	var s := new_state()
	s.treasury = TreasuryState.create(well_cost() - 20000)
	var before := JSON.stringify(s.to_dict("test"))
	var r := approve(s)
	eq(r.code, "insufficient_funds", "rechazada por fondos")
	check(r.message.contains("200 UC"), "el mensaje indica cuánto falta: " + r.message)
	eq(JSON.stringify(s.to_dict("test")), before, "ningún cambio en caja, obra, libro ni operaciones")
	return true


func test_fund_balance_matches_ledger() -> bool:
	var s := new_state()
	s.facts["neighbor_rosa"]["collection_open"] = true
	give_money(s, 400)
	PlayerActions.donate(s, CONTENT, "well_repair", Money.from_units(300))
	advance_fed(s)
	advance_fed(s)
	check(s.treasury.is_consistent(), "fondo = inicial + ingresos - pagos")
	check(s.player.is_consistent(), "billetera = inicial + ganado - gastado")
	for rep in s.reports:
		eq(rep.cash_end_cents, rep.cash_start_cents + rep.income_cents - rep.payments_cents, "informe del día %d cuadra" % rep.day)
	eq(s.reports[0].income_cents, Money.from_units(330), "día 1: aporte propio + vecinos")
	return true


func test_capacity_changes_from_next_day() -> bool:
	var s := funded_state()
	for i in 100:
		Simulation.step(s, CONTENT)
	approve(s)
	eq(Simulation.water_capacity(s, CONTENT, 1), 20, "en obra el día 1 sigue en 20")
	var rep1 := advance_fed(s)
	eq(rep1.water_capacity, 20, "el día 1 se prestó con capacidad 20")
	eq(rep1.completed_projects.size(), 1, "la obra vence al cierre del día 1")
	eq(rep1.next_water_capacity, 60, "capacidad 60 desde mañana")
	eq(s.get_project("well_repair").operational_from_day, 2, "opera desde el día 2")
	var rep2 := advance_fed(s)
	eq(rep2.water_capacity, 60, "el día 2 se prestó con capacidad 60")
	eq(rep2.completed_projects.size(), 0, "no se completa dos veces")
	return true


func test_multi_day_project_timing() -> bool:
	var def := ProjectDefinition.new()
	def.id = "slow_well"
	def.site_id = "well_test"
	def.name_key = "PROJECT_WELL_REPAIR_NAME"
	def.cost_uc = 100
	def.duration_days = 2
	def.capacity_after = 45
	var content := GameContent.new()
	content.balance = CONTENT.balance
	content.items = CONTENT.items
	content.projects = [def]
	content.fact_subjects = CONTENT.fact_subjects
	var s := GameState.create_new(content, 1)
	s.treasury = TreasuryState.create(100000)
	check(approve(s, content, "slow_well").ok, "aprobada")
	eq(advance_fed(s, content).completed_projects.size(), 0, "plazo 2: no termina el día 1")
	var r2 := advance_fed(s, content)
	eq(r2.completed_projects.size(), 1, "termina al cierre del día 2")
	eq(Simulation.water_capacity(s, content, 3), 45, "desde el día 3 rige 45")
	return true


func test_advance_day_equals_stepping() -> bool:
	var a := new_state(99)
	var b := new_state(99)
	for s in [a, b]:
		s.facts["neighbor_rosa"]["collection_open"] = true
		for i in 50:
			Simulation.step(s, CONTENT)
	Simulation.advance_to_end_of_day(a, CONTENT)
	var closed: DayReport = null
	while closed == null:
		closed = Simulation.step(b, CONTENT)
	eq(JSON.stringify(a.to_dict("t")), JSON.stringify(b.to_dict("t")), "mismo estado administrativo")
	return true


func test_simulation_without_actors() -> bool:
	var s := new_state()
	for d in 3:
		advance_fed(s)
	eq(s.current_day(), 4, "tres jornadas simuladas sin escenas")
	eq(s.settlement.population, CONTENT.balance.population, "la población no depende de actores")
	return true


func test_zero_values_no_invalid_division() -> bool:
	eq(Simulation.coverage_bp(0, 0), 10000, "demanda cero = cobertura total")
	eq(Simulation.coverage_bp(0, 10), 0, "sin capacidad")
	eq(Simulation.coverage_bp(200, 60), 10000, "el sobrante no supera 100 %")
	var s := new_state()
	s.settlement.population = 0
	var rep := advance_fed(s)
	eq(rep.water_coverage_bp, 10000, "población cero sin división por cero")
	check(not approve(s).ok, "fondo cero rechaza la obra")
	s.player.wallet_cents = 0
	s.player.opening_cents = 0
	eq(Simulation.faint_penalty_bp(0, CONTENT.balance) * 0 / 10000, 0, "multa sobre billetera vacía")
	return true


# --- Personaje ----------------------------------------------------------------

func test_needs_decay_and_tired() -> bool:
	var s := fed(new_state())
	var b := CONTENT.balance
	for i in 100:
		Simulation.step(s, CONTENT)
	eq(s.player.hunger_bp, PlayerState.FULL - 100 * b.hunger_decay_bp, "el hambre baja por paso")
	eq(s.player.thirst_bp, PlayerState.FULL - 100 * b.thirst_decay_bp, "la sed baja más rápido")
	check(not Simulation.is_tired(s, CONTENT), "todavía no está cansado")
	s.player.thirst_bp = b.tired_threshold_bp - 1
	check(Simulation.is_tired(s, CONTENT), "con poca agua está cansado")
	return true


func test_faint_penalty_escalates() -> bool:
	var s := new_state()
	give_money(s, 980)  # 1.000 UC en total
	s.player.thirst_bp = 1
	Simulation.step(s, CONTENT)
	check(s.player.faint_pending, "se desmaya al quedarse sin agua")
	eq(s.player.wallet_cents, 90000, "primer desmayo: pierde 10 %")
	eq(s.player.thirst_bp, CONTENT.balance.faint_wake_bp, "despierta con algo de agua")
	s.player.faint_pending = false
	s.player.thirst_bp = 1
	Simulation.step(s, CONTENT)
	eq(s.player.wallet_cents, 72000, "segundo desmayo: pierde 20 % de lo que queda")
	eq(s.player.faint_count, 2, "se cuentan los desmayos")
	eq(Simulation.faint_penalty_bp(9, CONTENT.balance), 5000, "el castigo tiene tope de 50 %")
	check(s.player.is_consistent(), "la billetera sigue cuadrando")
	return true


func test_sleep_freezes_needs() -> bool:
	var s := new_state()
	var h := s.player.hunger_bp
	var rep := Simulation.advance_to_end_of_day(s, CONTENT, true)
	eq(rep.day, 1, "dormir cierra la jornada")
	eq(s.player.hunger_bp, h, "mientras dormís no da hambre")
	check(not rep.fainted, "dormir no desmaya")
	return true


func test_fishing_deterministic_and_bag_limit() -> bool:
	var a := new_state(7)
	var b := new_state(7)
	var ca := PlayerActions.cast_line(a, CONTENT)
	var cb := PlayerActions.cast_line(b, CONTENT)
	check(ca["ok"], "se puede pescar con la caña básica")
	eq(ca["delay_s"], cb["delay_s"], "misma semilla, misma espera")
	eq(ca["fish_id"], cb["fish_id"], "misma semilla, mismo pescado")
	var rod := CONTENT.find_item("rod_basic")
	check(ca["delay_s"] >= rod.bite_min_s and ca["delay_s"] <= rod.bite_max_s, "espera dentro del rango de la caña")
	var s := new_state()
	for i in CONTENT.balance.bag_capacity:
		check(PlayerActions.land_fish(s, CONTENT, "fish_small", false).ok, "entra el pescado %d" % (i + 1))
	eq(PlayerActions.land_fish(s, CONTENT, "fish_small", false).code, "bag_full", "mochila llena")
	eq(PlayerActions.cast_line(s, CONTENT)["code"], "bag_full", "no se tira la línea con la mochila llena")
	var p := new_state()
	eq(PlayerActions.land_fish(p, CONTENT, "fish_big", true).data["count"], 2, "perfecto: dos pescados")
	eq(p.player.day_fish, 2, "se cuentan en la jornada")
	return true


## Avanza pasos hasta que la pasada llegue a la posición x (o cambie de estado).
func run_until_x(s: GameState, p: Dictionary, x: float) -> void:
	var def := CONTENT.find_merchant(p["merchant"])
	var guard := 0
	while guard < 2000 and Merchants.position_x(p, def, s.tick) < x and (p["status"] == Merchants.SCHEDULED or p["status"] == Merchants.PASSING):
		Simulation.step(fed(s), CONTENT)
		guard += 1


func test_merchant_day_plan() -> bool:
	var a := new_state(5)
	var b := new_state(5)
	eq(a.camp.passes.size(), CONTENT.balance.merchant_passes_per_day, "pasadas planificadas para el día 1")
	eq(a.camp.passes[0]["merchant"], "ramiro", "el primero del día 1 es Don Ramiro")
	eq(JSON.stringify(a.camp.to_dict()), JSON.stringify(b.camp.to_dict()), "misma semilla, misma agenda")
	for p in a.camp.passes:
		check(p["merchant"] != "coco", "Coco no pasa sin cartel")
		check(int(p["start"]) < a.ticks_per_day, "todas dentro del día 1")
	advance_fed(a)
	check(int(a.camp.passes[0]["start"]) >= a.ticks_per_day, "al cerrar se planifica el día 2")
	return true


func test_hail_and_trade() -> bool:
	var s := new_state()
	var p: Dictionary = s.camp.passes[0]
	var id := int(p["id"])
	eq(Merchants.hail(s, CONTENT, id).code, "too_far", "antes de que aparezca no se le puede hacer señas")
	run_until_x(s, p, -20.0)
	eq(p["status"], Merchants.PASSING, "viene por el camino")
	check(Merchants.hail(s, CONTENT, id).ok, "frena con las señas")
	eq(p["status"], Merchants.STOPPED, "parado")
	s.player.add_item("fish_small", 6)
	s.player.add_item("fish_big", 2)
	var r := Merchants.sell_to(s, CONTENT, id, "fish_small", 6)
	check(r.ok, "le vende 6 chicos")
	eq(s.player.wallet_cents, Money.from_units(20 + 24), "Ramiro paga 4 UC por chico")
	eq(Merchants.sell_to(s, CONTENT, id, "fish_big", 1).code, "merchant_full", "Ramiro compra hasta 6 por parada")
	var before := s.player.wallet_cents
	eq(Merchants.buy_from(s, CONTENT, id, "axe").code, "not_for_sale", "Ramiro no vende hachas")
	check(Merchants.buy_from(s, CONTENT, id, "bread").ok, "le compra pan")
	eq(s.player.wallet_cents, before - Money.from_units(8), "pan a 8 UC")
	Merchants.dismiss(s, id)
	eq(p["status"], Merchants.LEAVING, "sigue viaje")
	eq(Merchants.sell_to(s, CONTENT, id, "fish_big", 1).code, "no_merchant", "ya no compra")
	check(s.player.is_consistent(), "la billetera cuadra")
	var s2 := new_state()
	var p2: Dictionary = s2.camp.passes[0]
	run_until_x(s2, p2, Merchants.HAIL_MAX_X + 2.0)
	eq(Merchants.hail(s2, CONTENT, int(p2["id"])).code, "too_far", "si ya pasó de largo, te lo perdiste")
	return true


func test_sign_makes_merchants_stop() -> bool:
	var s := new_state()
	s.camp.buildings.append("sign")
	var p: Dictionary = s.camp.passes[0]
	run_until_x(s, p, 0.5)
	eq(p["status"], Merchants.STOPPED, "con el cartel para solo frente a la choza")
	for i in CONTENT.balance.merchant_stop_ticks + 1:
		Simulation.step(fed(s), CONTENT)
	eq(p["status"], Merchants.LEAVING, "si nadie le compra, se va")
	var seen_coco := false
	for d in 6:
		advance_fed(s)
		for q in s.camp.passes:
			seen_coco = seen_coco or q["merchant"] == "coco"
	check(seen_coco, "con el cartel empieza a pasar Coco")
	return true


func test_fish_rots_overnight() -> bool:
	var s := new_state()
	s.player.add_item("fish_small", 3)
	s.player.add_item("bread", 1)
	var rep := advance_fed(s)
	eq(rep.rotten, 3, "el pescado se pudrió")
	eq(s.player.count("fish_small"), 0, "ya no está en la mochila")
	eq(s.player.count("bread"), 1, "el pan no se pudre")
	return true


func test_lake_water_and_fire() -> bool:
	var a := new_state(11)
	var b := new_state(11)
	a.player.thirst_bp = 1000
	b.player.thirst_bp = 1000
	var ra := PlayerActions.drink_lake(a, CONTENT)
	var rb := PlayerActions.drink_lake(b, CONTENT)
	eq(a.player.thirst_bp, 1000 + CONTENT.balance.raw_water_drink_bp, "el lago calma la sed")
	eq(ra.data["sick"], rb.data["sick"], "caer mal depende de la semilla, no del azar del motor")
	var sick := 0
	var s := new_state(3)
	for i in 200:
		fed(s)
		if PlayerActions.drink_lake(s, CONTENT).data["sick"]:
			sick += 1
	check(sick > 40 and sick < 110, "cae mal más o menos 1 de cada 3 veces (%d/200)" % sick)
	var f := new_state()
	eq(PlayerActions.boil_water(f, CONTENT).code, "no_fire", "sin fogón no se hierve")
	f.camp.buildings.append("fire")
	eq(PlayerActions.boil_water(f, CONTENT).code, "missing_wood", "el fogón gasta madera")
	f.camp.wood = 2
	f.player.thirst_bp = 100
	check(PlayerActions.boil_water(f, CONTENT).ok, "agua hervida")
	eq(f.player.thirst_bp, PlayerState.FULL, "el agua hervida llena la sed")
	f.player.hunger_bp = 1000
	f.player.add_item("fish_small", 1)
	check(PlayerActions.cook_and_eat(f, CONTENT, "fish_small").ok, "asa el pescado")
	eq(f.player.hunger_bp, 1000 + 2000 * CONTENT.balance.cook_multiplier, "asado llena el doble")
	eq(f.camp.wood, 0, "usó dos maderas")
	return true


func test_wood_and_building() -> bool:
	var s := new_state()
	check(PlayerActions.gather_branches(s, CONTENT, "branches_1").ok, "junta ramas")
	eq(PlayerActions.gather_branches(s, CONTENT, "branches_1").code, "already_gathered", "un montón por día")
	eq(s.camp.wood, 1, "una madera")
	eq(PlayerActions.chop_tree(s, CONTENT, "tree_1", true).code, "no_axe", "sin hacha no se tala")
	s.player.tools.append("axe")
	eq(PlayerActions.chop_tree(s, CONTENT, "tree_1", false).code, "missed", "si erra los golpes no saca madera")
	check(PlayerActions.chop_tree(s, CONTENT, "tree_1", true).ok, "tala el árbol")
	eq(s.camp.wood, 4, "tres maderas más")
	eq(PlayerActions.chop_tree(s, CONTENT, "tree_1", true).code, "tree_cut", "el árbol tiene que volver a crecer")
	advance_fed(s)
	check(PlayerActions.gather_branches(s, CONTENT, "branches_1").ok, "al otro día vuelven las ramas")
	advance_fed(s)
	check(PlayerActions.tree_available(s, CONTENT, "tree_1"), "el árbol volvió a crecer")
	s.camp.wood = 3
	var before := JSON.stringify(s.to_dict("t"))
	eq(PlayerActions.build(s, CONTENT, "sign").code, "missing_wood", "al cartel le falta madera")
	eq(JSON.stringify(s.to_dict("t")), before, "construir sin materiales no cambia nada")
	check(PlayerActions.build(s, CONTENT, "fire").ok, "levanta el fogón")
	eq(s.camp.wood, 0, "gastó la madera")
	eq(PlayerActions.build(s, CONTENT, "fire").code, "already_built", "no se construye dos veces")
	s.camp.wood = 4
	eq(PlayerActions.build(s, CONTENT, "sign").code, "insufficient_funds", "al cartel le falta plata")
	give_money(s, 40)
	check(PlayerActions.build(s, CONTENT, "sign").ok, "pone el cartel")
	check(s.player.is_consistent(), "la billetera cuadra")
	eq(PlayerActions.cast_line(s, CONTENT, "dock")["code"], "no_dock", "sin muelle no se pesca desde el muelle")
	return true


func test_collection_funds_well() -> bool:
	var s := new_state()
	give_money(s, 2000)
	eq(PlayerActions.donate(s, CONTENT, "well_repair", 1000).code, "collection_closed", "sin hablar con Rosa no hay colecta")
	s.facts["neighbor_rosa"]["collection_open"] = true
	var r := PlayerActions.donate(s, CONTENT, "well_repair", Money.from_units(500))
	check(r.ok, "aporta 500")
	eq(s.treasury.cash_cents, Money.from_units(500), "el aporte va al fondo comunitario")
	eq(s.player.donated_total_cents, Money.from_units(500), "queda registrado lo que aportaste")
	var rep := advance_fed(s)
	eq(rep.income_cents, Money.from_units(530), "los vecinos suman 30 por día")
	var goal := PlayerActions.donate(s, CONTENT, "well_repair", well_cost() - s.treasury.cash_cents)
	check(goal.ok and goal.data["started"].has("well_repair"), "al llegar a la meta arranca la obra")
	eq(s.get_project("well_repair").status, ProjectState.UNDER_CONSTRUCTION, "Don Aurelio trabaja")
	eq(s.treasury.cash_cents, 0, "el fondo pagó la obra")
	eq(PlayerActions.donate(s, CONTENT, "well_repair", 100).code, "collection_closed", "la colecta se cierra")
	advance_fed(s)
	check(PlayerActions.well_fixed(s), "al día siguiente el pozo anda")
	s.player.thirst_bp = 0
	PlayerActions.drink_well(s, CONTENT)
	eq(s.player.thirst_bp, PlayerState.FULL, "el pozo arreglado llena la sed")
	check(s.treasury.is_consistent() and s.player.is_consistent(), "fondo y billetera cuadran")
	return true


# --- Guardado -----------------------------------------------------------------

func test_save_roundtrip_preserves_state_and_rng() -> bool:
	var svc := _service()
	var s := new_state(4242)
	s.facts["neighbor_rosa"]["collection_open"] = true
	give_money(s, 120)
	s.player.add_item("fish_big", 2)
	s.camp.wood = 5
	s.camp.buildings.append("fire")
	PlayerActions.gather_branches(s, CONTENT, "branches_2")
	PlayerActions.donate(s, CONTENT, "well_repair", Money.from_units(50))
	PlayerActions.cast_line(s, CONTENT)
	for i in 60:
		Simulation.step(fed(s), CONTENT)
	advance_fed(s)
	for i in 77:
		Simulation.step(s, CONTENT)
	s.player_pose = {"position": Vector3(1.5, 0.05, -3.25), "yaw": 0.5, "pitch": -10.0}
	check(svc.write_state(s, CONTENT, "test", "roundtrip").ok, "guardado")
	var loaded := svc.read_slot("roundtrip", CONTENT)
	check(loaded["ok"], "carga: %s" % loaded["message"])
	if not loaded["ok"]:
		return false
	var l: GameState = loaded["state"]
	eq(JSON.stringify(l.to_dict("test")), JSON.stringify(s.to_dict("test")), "estado idéntico tras guardar y cargar")
	eq(l.rng.randi(), s.rng.randi(), "el generador continúa igual")
	eq(l.camp.wood, 6, "madera")
	check(l.camp.has_building("fire"), "construcciones")
	eq(l.player_pose["position"], Vector3(1.5, 0.05, -3.25), "pose del jugador")
	return true


func test_load_does_not_repeat_effects() -> bool:
	var svc := _service()
	var s := funded_state()
	approve(s)
	svc.write_state(s, CONTENT, "test", "repeat")
	var l: GameState = svc.read_slot("repeat", CONTENT)["state"]
	check(approve(l).is_duplicate(), "la aprobación cargada no se vuelve a cobrar")
	advance_fed(l)
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
	var missing := new_state().to_dict("test")
	missing.erase("player_state")
	check(not svc.parse_text(JSON.stringify(missing), CONTENT)["ok"], "falta el personaje")
	var unknown := new_state().to_dict("test")
	unknown["player_state"]["bag"] = [{"id": "objeto_fantasma", "count": 1}]
	check(not svc.parse_text(JSON.stringify(unknown), CONTENT)["ok"], "objeto desconocido rechazado")
	return true


func test_tampered_save_rejected() -> bool:
	var svc := _service()
	var s := funded_state()
	approve(s)
	var d := s.to_dict("test")
	d["treasury"]["cash_cents"] = "99999999"
	check(not svc.parse_text(JSON.stringify(d), CONTENT)["ok"], "fondo que no coincide con el libro")
	var d2 := new_state().to_dict("test")
	d2["player_state"]["wallet_cents"] = "500000"
	check(not svc.parse_text(JSON.stringify(d2), CONTENT)["ok"], "billetera inflada a mano")
	var d3 := s.to_dict("test")
	d3["tick"] = 12.5
	check(not svc.parse_text(JSON.stringify(d3), CONTENT)["ok"], "tick no decimal en cadena")
	return true


func test_backup_used_when_main_save_corrupt() -> bool:
	var svc := _service()
	var s := new_state()
	check(svc.write_state(s, CONTENT, "test", "bak").ok, "primer guardado")
	give_money(s, 50)
	check(svc.write_state(s, CONTENT, "test", "bak").ok, "segundo guardado (el primero pasa a .bak)")
	check(not FileAccess.file_exists(svc.slot_path("bak") + ".tmp"), "no queda temporal")
	var f := FileAccess.open(svc.slot_path("bak"), FileAccess.WRITE)
	f.store_string("{roto")
	f.close()
	var r := svc.read_slot("bak", CONTENT)
	check(r["ok"] and r["from_backup"], "se recupera la copia anterior")
	if r["ok"]:
		eq((r["state"] as GameState).player.wallet_cents, Money.from_units(20), "la copia anterior es el primer guardado")
	return true


func test_session_load_failure_keeps_current_game() -> bool:
	var session: Node = SESSION_SCRIPT.new()
	session._ready()
	session.autosave_enabled = false
	session.saves.save_dir = TEST_SAVE_DIR
	session.drink_lake()
	var before := JSON.stringify(session.state.to_dict("t"))
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var f := FileAccess.open(session.saves.slot_path("manual_1"), FileAccess.WRITE)
	f.store_string("{\"schema_version\": 99}")
	f.close()
	DirAccess.remove_absolute(session.saves.slot_path("manual_1") + ".bak")
	var r: CommandResult = session.load_game()
	check(not r.ok and not r.message.is_empty(), "carga de versión futura falla con mensaje")
	eq(JSON.stringify(session.state.to_dict("t")), before, "la partida actual quedó intacta")
	session.free()
	return true


func test_pause_does_not_advance_economy() -> bool:
	var session: Node = SESSION_SCRIPT.new()
	session._ready()
	session.autosave_enabled = false
	var thirst: int = session.state.player.thirst_bp
	session.push_pause("ui")
	session._process(30.0)
	eq(session.state.tick, 0, "en pausa no avanza el reloj")
	eq(session.state.player.thirst_bp, thirst, "en pausa no da sed")
	session.pop_pause("ui")
	session._process(2.0)
	eq(session.state.tick, 2, "sin pausa avanza 1 paso por segundo")
	session.free()
	return true


func test_session_faint_wakes_next_day() -> bool:
	var session: Node = SESSION_SCRIPT.new()
	session._ready()
	session.autosave_enabled = false
	var got: Array = []
	session.fainted.connect(func(rep: DayReport) -> void: got.append(rep))
	session.state.player.thirst_bp = 1
	session._process(1.0)
	eq(got.size(), 1, "la sesión avisa del desmayo")
	eq(session.state.current_day(), 2, "despierta al día siguiente")
	check(got.size() == 1 and (got[0] as DayReport).fainted, "el informe marca el desmayo")
	check(session.state.player_pose.is_empty(), "despierta en su casa")
	session.free()
	return true


func test_clock_never_drops_steps() -> bool:
	var c := SimClock.new()
	c.configure(CONTENT.balance)
	var total := c.consume(10.0)
	eq(total, 4, "como máximo 4 pasos por fotograma")
	eq(c.lag_frames, 1, "se registra el atraso")
	for i in 5:
		total += c.consume(0.0)
	eq(total, 10, "los pasos pendientes se recuperan, no se descartan")
	return true


func test_dialogue_follows_state() -> bool:
	var dlg := DialogueService.load_file("res://data/dialogue/neighbor_rosa.json")
	var s := funded_state()
	eq(dlg.start_entry(s).get("id"), "intro", "primera conversación")
	s.facts["neighbor_rosa"]["water_complaint_heard"] = true
	s.facts["neighbor_rosa"]["collection_open"] = true
	eq(dlg.start_entry(s).get("id"), "collecting", "durante la colecta")
	approve(s)
	eq(dlg.start_entry(s).get("id"), "in_progress", "obra en curso")
	advance_fed(s)
	eq(dlg.start_entry(s).get("id"), "done", "pozo arreglado")
	return true


## Fixture generado con el código de H1 (schema 1, escritorio y caja). Debe migrar a v2.
func test_fixture_v1_migrates() -> bool:
	var r := _load_fixture(FIXTURE_V1)
	check(r["ok"], "el fixture v1 carga migrado: %s" % r.get("message", ""))
	if not r["ok"]:
		return false
	var s: GameState = r["state"]
	eq(s.ticks_per_day, 360, "conserva la duración de jornada con la que se jugó")
	eq(s.current_day(), 2, "día 2")
	eq(s.treasury.cash_cents, 680000, "conserva el fondo")
	eq(s.get_project("well_repair").status, ProjectState.COMPLETED, "pozo reparado")
	eq(s.player.wallet_cents, Money.from_units(CONTENT.balance.start_wallet_uc), "se agrega un personaje inicial")
	return true


## Fixture generado con el código actual (schema 2). Se regenera con tools/make_fixture.gd.
func test_fixture_v2_loads() -> bool:
	var r := _load_fixture(FIXTURE_V2)
	check(r["ok"], "el fixture v2 carga: %s" % r.get("message", ""))
	if not r["ok"]:
		return false
	var s: GameState = r["state"]
	eq(s.current_day(), 3, "día 3")
	eq(s.get_project("well_repair").status, ProjectState.COMPLETED, "pozo arreglado por la colecta")
	check(s.player.has_tool("cooler"), "tiene la conservadora")
	return true


# ---------------------------------------------------------------------------

func _load_fixture(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "message": "no existe %s" % path}
	return _service().parse_text(f.get_as_text(), CONTENT)


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
