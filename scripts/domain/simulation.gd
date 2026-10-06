class_name Simulation
extends RefCounted
## Reglas del dominio: comandos y paso administrativo.
## Funciones estáticas sobre GameState; no usan el SceneTree ni la hora del sistema.
##
## Cada comando sigue: validar -> preparar -> aplicar (sin puntos de falla) -> registrar.

const SERVICE_WATER := "water"


# --- Comando: aprobar proyecto -------------------------------------------

## approver: "" = el jugador con su cargo actual; "community" = la colecta de los vecinos.
static func approve_project(state: GameState, content: GameContent, project_id: String, operation_key: String, approver: String = "") -> CommandResult:
	if operation_key.is_empty():
		return CommandResult.failure("missing_operation_key", Texts.t("ERR_MISSING_OPERATION_KEY"))
	# Misma operación recibida otra vez (doble clic, reintento): no se vuelve a cobrar.
	if state.applied_operations.has(operation_key):
		return CommandResult.already_applied(Texts.t("MSG_OPERATION_ALREADY_APPLIED"))

	var def := content.find_project(project_id)
	var project := state.get_project(project_id)
	if def == null or project == null:
		return CommandResult.failure("unknown_project", Texts.t("ERR_UNKNOWN_PROJECT", {"id": project_id}))
	var who := state.office if approver.is_empty() else approver
	if def.required_office != who:
		return CommandResult.failure("no_authority", Texts.t("ERR_NO_AUTHORITY"))
	if project.status != ProjectState.AVAILABLE:
		var key := "ERR_PROJECT_UNDER_CONSTRUCTION" if project.status == ProjectState.UNDER_CONSTRUCTION else "ERR_PROJECT_COMPLETED"
		return CommandResult.failure("project_not_available", Texts.t(key, {"name": Texts.t(def.name_key)}))
	# Un solo proyecto activo por lugar: no se superponen obras.
	for other_id in state.projects:
		var other: ProjectState = state.projects[other_id]
		if other_id != project_id and other.site_id == def.site_id and other.status == ProjectState.UNDER_CONSTRUCTION:
			return CommandResult.failure("site_busy", Texts.t("ERR_SITE_BUSY"))

	var cost := def.cost_cents()
	var funds := state.treasury.check_payment(cost)
	if not funds.ok:
		return funds

	# Aplicar: todas las validaciones ya pasaron; ninguna de estas líneas puede fallar.
	var day := state.current_day()
	state.treasury.post_payment(cost, "project:" + project_id, def.name_key, day, state.tick, operation_key)
	project.status = ProjectState.UNDER_CONSTRUCTION
	project.paid_cents = cost
	project.approved_tick = state.tick
	project.approved_day = day
	project.completion_day = day + def.duration_days - 1
	project.operation_key = operation_key
	state.applied_operations[operation_key] = state.tick
	return CommandResult.success(Texts.t("MSG_PROJECT_APPROVED", {
		"name": Texts.t(def.name_key),
		"cost": Money.format(cost),
		"day": project.completion_day,
	}), {"project_id": project_id, "cost_cents": cost})


# --- Paso administrativo y cierre de jornada ------------------------------

## Avanza un paso administrativo. Devuelve el informe si ese paso cerró una jornada.
## resting: dormido o desmayado; hambre y sed no bajan.
static func step(state: GameState, content: GameContent, resting: bool = false) -> DayReport:
	state.tick += 1
	if not resting:
		_update_needs(state, content)
	Merchants.update(state, content)
	if state.tick % state.ticks_per_day == 0:
		return _close_day(state, content, state.tick / state.ticks_per_day)
	return null


## Ejecuta los pasos que faltan de la jornada actual con la misma función step().
## No es una segunda implementación de la economía.
static func advance_to_end_of_day(state: GameState, content: GameContent, resting: bool = false) -> DayReport:
	var remaining := state.ticks_left_in_day()
	for i in remaining:
		var report := step(state, content, resting)
		if report != null:
			return report
	push_error("advance_to_end_of_day: no se cerró la jornada tras %d pasos" % remaining)
	return null


static func _close_day(state: GameState, content: GameContent, day: int) -> DayReport:
	var report := DayReport.new()
	report.day = day

	# 1) Instantánea del estado operativo que rigió esta jornada.
	var capacity := water_capacity(state, content, day)
	var demand := state.settlement.population

	# 2) Ingresos: lo que suman los demás vecinos a las colectas abiertas.
	for id in content.project_ids():
		if collection_open(state, content, id):
			state.treasury.post_income(Money.from_units(content.balance.neighbors_daily_donation_uc),
				"donation:neighbors", "LEDGER_NEIGHBORS_DONATION", day, state.tick - 1, "neighbors_donation:%s:%d" % [id, day])

	# 3) Movimientos de caja de la jornada (aportes y pagos de obra).
	var payments := 0
	var income := 0
	for e in state.treasury.entries_for_day(day):
		if e["kind"] == TreasuryState.KIND_PAYMENT:
			payments += int(e["amount_cents"])
			report.payment_lines.append({"reason_key": e["reason_key"], "amount_cents": e["amount_cents"]})
		else:
			income += int(e["amount_cents"])
	report.income_cents = income
	report.payments_cents = payments
	report.cash_end_cents = state.treasury.cash_cents
	report.cash_start_cents = report.cash_end_cents + payments - report.income_cents

	# 4) Servicio efectivamente prestado.
	report.water_capacity = capacity
	report.water_demand = demand
	report.water_served = mini(capacity, demand)
	report.water_coverage_bp = coverage_bp(capacity, demand)

	# 5) Obras que vencen hoy: operan desde la jornada siguiente.
	for id in content.project_ids():
		var p := state.get_project(id)
		if p.status == ProjectState.UNDER_CONSTRUCTION and p.completion_day <= day:
			p.status = ProjectState.COMPLETED
			p.completed_day = day
			p.operational_from_day = day + 1
			report.completed_projects.append({"project_id": id, "operational_from_day": day + 1})

	# 6) Colectas que llegaron a la meta: la obra arranca en la jornada siguiente.
	fund_collections(state, content)

	# 6b) Lo perecedero que quedó en la mochila se echa a perder.
	var pl := state.player
	var rotten := 0
	for item_id in pl.bag.keys():
		var item := content.find_item(item_id)
		if item != null and item.perishable:
			rotten += pl.count(item_id)
			pl.remove_item(item_id, pl.count(item_id))
	report.rotten = rotten

	# 7) Informe: la jornada del personaje y la reacción del barrio (derivada del estado).
	report.earned_cents = pl.day_earned_cents
	report.spent_cents = pl.day_spent_cents
	report.fish_caught = pl.day_fish
	report.fainted = pl.day_fainted
	report.faint_penalty_cents = pl.day_faint_penalty_cents
	report.wallet_end_cents = pl.wallet_cents
	report.fund_cents = state.treasury.cash_cents
	pl.reset_day()
	report.next_water_capacity = water_capacity(state, content, day + 1)
	report.reaction_key = _reaction_key(state, report)
	state.reports.append(report)
	while state.reports.size() > content.balance.report_history_limit:
		state.reports.pop_front()

	# 8) La fecha avanza porque state.tick ya pertenece a la jornada siguiente:
	#    vuelven las ramas y se arma la agenda de comerciantes del día nuevo.
	state.camp.branches_taken.clear()
	Merchants.plan_day(state, content, day + 1)
	return report


# --- Personaje: hambre, sed y desmayo ------------------------------------

static func _update_needs(state: GameState, content: GameContent) -> void:
	var b := content.balance
	var pl := state.player
	pl.hunger_bp = maxi(0, pl.hunger_bp - b.hunger_decay_bp)
	pl.thirst_bp = maxi(0, pl.thirst_bp - b.thirst_decay_bp)
	if pl.hunger_bp == 0 or pl.thirst_bp == 0:
		_faint(state, content)


## Te desmayás: perdés una parte de tu plata que crece con cada desmayo.
static func _faint(state: GameState, content: GameContent) -> void:
	var b := content.balance
	var pl := state.player
	var bp := faint_penalty_bp(pl.faint_count, b)
	var penalty := pl.wallet_cents * bp / 10000
	if penalty > 0:
		pl.spend(penalty)
	pl.faint_count += 1
	pl.day_fainted = true
	pl.day_faint_penalty_cents += penalty
	pl.hunger_bp = maxi(pl.hunger_bp, b.faint_wake_bp)
	pl.thirst_bp = maxi(pl.thirst_bp, b.faint_wake_bp)
	pl.faint_pending = true


static func faint_penalty_bp(previous_faints: int, b: BalanceConfig) -> int:
	return mini(b.faint_penalty_max_bp, b.faint_penalty_step_bp * (previous_faints + 1))


static func is_tired(state: GameState, content: GameContent) -> bool:
	var t := content.balance.tired_threshold_bp
	return state.player.hunger_bp < t or state.player.thirst_bp < t


# --- Colectas comunitarias --------------------------------------------------

static func collection_open(state: GameState, content: GameContent, project_id: String) -> bool:
	var def := content.find_project(project_id)
	var p := state.get_project(project_id)
	return def != null and def.funded_by_collection and p.status == ProjectState.AVAILABLE \
		and state.has_fact("neighbor_rosa", "collection_open")


## Si el fondo alcanza la meta de una colecta abierta, los vecinos aprueban la obra.
static func fund_collections(state: GameState, content: GameContent) -> Array[String]:
	var started: Array[String] = []
	for id in content.project_ids():
		if not collection_open(state, content, id):
			continue
		if state.treasury.available_cents() >= content.find_project(id).cost_cents():
			var r := approve_project(state, content, id, "collection:%s" % id, "community")
			if r.ok:
				started.append(id)
	return started


# --- Servicios -------------------------------------------------------------

## Capacidad física de agua vigente en una jornada (personas por jornada).
static func water_capacity(state: GameState, content: GameContent, day: int) -> int:
	var cap := state.settlement.base_water_capacity
	for id in content.project_ids():
		var def := content.find_project(id)
		var p := state.get_project(id)
		if def.service_id == SERVICE_WATER and p.is_operational_on(day):
			cap = maxi(cap, def.capacity_after)
	return cap


## Cobertura en puntos básicos (10000 = 100 %). Demanda cero = cobertura total, sin dividir.
static func coverage_bp(capacity: int, demand: int) -> int:
	if demand <= 0:
		return 10000
	if capacity <= 0:
		return 0
	return mini(10000, capacity * 10000 / demand)


static func _reaction_key(state: GameState, report: DayReport) -> String:
	for c in report.completed_projects:
		if c["project_id"] == "well_repair":
			return "REACTION_WELL_DONE"
	var well := state.get_project("well_repair")
	if well != null and well.status == ProjectState.UNDER_CONSTRUCTION:
		return "REACTION_WELL_IN_PROGRESS"
	if report.water_coverage_bp >= 10000:
		return "REACTION_WATER_OK"
	if report.water_coverage_bp >= 5000:
		return "REACTION_WATER_PARTIAL"
	return "REACTION_WATER_CRITICAL"
