class_name Simulation
extends RefCounted
## Reglas del dominio: comandos y paso administrativo.
## Funciones estáticas sobre GameState; no usan el SceneTree ni la hora del sistema.
##
## Cada comando sigue: validar -> preparar -> aplicar (sin puntos de falla) -> registrar.

const SERVICE_WATER := "water"


# --- Comando: aprobar proyecto -------------------------------------------

static func approve_project(state: GameState, content: GameContent, project_id: String, operation_key: String) -> CommandResult:
	if operation_key.is_empty():
		return CommandResult.failure("missing_operation_key", Texts.t("ERR_MISSING_OPERATION_KEY"))
	# Misma operación recibida otra vez (doble clic, reintento): no se vuelve a cobrar.
	if state.applied_operations.has(operation_key):
		return CommandResult.already_applied(Texts.t("MSG_OPERATION_ALREADY_APPLIED"))

	var def := content.find_project(project_id)
	var project := state.get_project(project_id)
	if def == null or project == null:
		return CommandResult.failure("unknown_project", Texts.t("ERR_UNKNOWN_PROJECT", {"id": project_id}))
	if def.required_office != state.office:
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
static func step(state: GameState, content: GameContent) -> DayReport:
	state.tick += 1
	if state.tick % state.ticks_per_day == 0:
		return _close_day(state, content, state.tick / state.ticks_per_day)
	return null


## Ejecuta los pasos que faltan de la jornada actual con la misma función step().
## No es una segunda implementación de la economía.
static func advance_to_end_of_day(state: GameState, content: GameContent) -> DayReport:
	var remaining := state.ticks_left_in_day()
	for i in remaining:
		var report := step(state, content)
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

	# 2-3) Movimientos de caja de la jornada. En H1 solo hay pagos de obra;
	#      recaudación y funcionamiento se incorporan con la economía (H2).
	var payments := 0
	for e in state.treasury.entries_for_day(day):
		if e["kind"] == TreasuryState.KIND_PAYMENT:
			payments += int(e["amount_cents"])
			report.payment_lines.append({"reason_key": e["reason_key"], "amount_cents": e["amount_cents"]})
	report.income_cents = 0
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

	# 7) Informe y reacción de la comunidad derivada del estado (no inventada).
	report.next_water_capacity = water_capacity(state, content, day + 1)
	report.reaction_key = _reaction_key(state, report)
	state.reports.append(report)
	while state.reports.size() > content.balance.report_history_limit:
		state.reports.pop_front()

	# 8) La fecha avanza porque state.tick ya pertenece a la jornada siguiente.
	return report


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
