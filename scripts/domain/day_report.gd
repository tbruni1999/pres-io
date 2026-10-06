class_name DayReport
extends RefCounted
## Informe de cierre de una jornada. Conecta decisiones con resultados observables.

var day: int = 0
var cash_start_cents: int = 0
var income_cents: int = 0
var payments_cents: int = 0
var cash_end_cents: int = 0
## Pagos de la jornada: [{reason_key, amount_cents}]
var payment_lines: Array[Dictionary] = []
var water_capacity: int = 0
var water_demand: int = 0
var water_served: int = 0
var water_coverage_bp: int = 0
## Capacidad de agua vigente desde la jornada siguiente.
var next_water_capacity: int = 0
## Obras completadas en este cierre: [{project_id, operational_from_day}]
var completed_projects: Array[Dictionary] = []
var reaction_key: String = ""
## Jornada del personaje.
var earned_cents: int = 0
var spent_cents: int = 0
var fish_caught: int = 0
var fainted: bool = false
var faint_penalty_cents: int = 0
var wallet_end_cents: int = 0
## Fondo comunitario al cerrar.
var fund_cents: int = 0
## Pescado que se pudrió al cerrar.
var rotten: int = 0
## La jornada terminó sin que el jugador se fuera a dormir.
var slept_outside: bool = false


func to_dict() -> Dictionary:
	var lines: Array = []
	for l in payment_lines:
		lines.append({"reason_key": l["reason_key"], "amount_cents": str(l["amount_cents"])})
	var done: Array = []
	for c in completed_projects:
		done.append({"project_id": c["project_id"], "operational_from_day": c["operational_from_day"]})
	return {
		"day": day,
		"cash_start_cents": str(cash_start_cents),
		"income_cents": str(income_cents),
		"payments_cents": str(payments_cents),
		"cash_end_cents": str(cash_end_cents),
		"payment_lines": lines,
		"water_capacity": water_capacity,
		"water_demand": water_demand,
		"water_served": water_served,
		"water_coverage_bp": water_coverage_bp,
		"next_water_capacity": next_water_capacity,
		"completed_projects": done,
		"reaction_key": reaction_key,
		"earned_cents": str(earned_cents),
		"spent_cents": str(spent_cents),
		"fish_caught": fish_caught,
		"fainted": fainted,
		"faint_penalty_cents": str(faint_penalty_cents),
		"wallet_end_cents": str(wallet_end_cents),
		"fund_cents": str(fund_cents),
		"rotten": rotten,
		"slept_outside": slept_outside,
	}


static func from_dict(d: Dictionary, r: DictReader) -> DayReport:
	var rep := DayReport.new()
	var w := "reports[%s]" % d.get("day", "?")
	var big := TreasuryState.MAX_CENTS
	rep.day = r.get_small_int(d, "day", w, 1, 1_000_000)
	rep.cash_start_cents = r.get_big_int(d, "cash_start_cents", w, 0, big)
	rep.income_cents = r.get_big_int(d, "income_cents", w, 0, big)
	rep.payments_cents = r.get_big_int(d, "payments_cents", w, 0, big)
	rep.cash_end_cents = r.get_big_int(d, "cash_end_cents", w, 0, big)
	for l in r.get_array(d, "payment_lines", w):
		if l is Dictionary:
			rep.payment_lines.append({
				"reason_key": r.get_string(l, "reason_key", w),
				"amount_cents": r.get_big_int(l, "amount_cents", w, 0, big),
			})
		else:
			r.fail(w, "línea de pago inválida")
	rep.water_capacity = r.get_small_int(d, "water_capacity", w, 0, 10_000_000)
	rep.water_demand = r.get_small_int(d, "water_demand", w, 0, 10_000_000)
	rep.water_served = r.get_small_int(d, "water_served", w, 0, 10_000_000)
	rep.water_coverage_bp = r.get_small_int(d, "water_coverage_bp", w, 0, 10000)
	rep.next_water_capacity = r.get_small_int(d, "next_water_capacity", w, 0, 10_000_000)
	for c in r.get_array(d, "completed_projects", w):
		if c is Dictionary:
			rep.completed_projects.append({
				"project_id": r.get_string(c, "project_id", w),
				"operational_from_day": r.get_small_int(c, "operational_from_day", w, 1, 1_000_000),
			})
		else:
			r.fail(w, "obra completada inválida")
	rep.reaction_key = r.get_string(d, "reaction_key", w)
	rep.earned_cents = r.get_big_int(d, "earned_cents", w, 0, big)
	rep.spent_cents = r.get_big_int(d, "spent_cents", w, 0, big)
	rep.fish_caught = r.get_small_int(d, "fish_caught", w, 0, 1_000_000)
	rep.fainted = r.get_bool(d, "fainted", w)
	rep.faint_penalty_cents = r.get_big_int(d, "faint_penalty_cents", w, 0, big)
	rep.wallet_end_cents = r.get_big_int(d, "wallet_end_cents", w, 0, big)
	rep.fund_cents = r.get_big_int(d, "fund_cents", w, 0, big)
	rep.rotten = r.get_small_int(d, "rotten", w, 0, 1_000_000)
	rep.slept_outside = r.get_bool(d, "slept_outside", w)
	if r.ok() and rep.cash_end_cents != rep.cash_start_cents + rep.income_cents - rep.payments_cents:
		r.fail(w, "el informe no cuadra: caja final != inicial + ingresos - pagos")
	return rep
