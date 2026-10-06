class_name ProjectState
extends RefCounted
## Estado de una obra concreta (separado de su ProjectDefinition).
## La operatividad del servicio se deriva de operational_from_day, no del estado visual.

const AVAILABLE := "available"
const UNDER_CONSTRUCTION := "under_construction"
const COMPLETED := "completed"
const STATUSES := [AVAILABLE, UNDER_CONSTRUCTION, COMPLETED]

var id: String = ""
var site_id: String = ""
var status: String = AVAILABLE
var paid_cents: int = 0
var approved_tick: int = -1
var approved_day: int = 0
## Jornada en cuyo cierre se completa la obra.
var completion_day: int = 0
var completed_day: int = 0
## Primera jornada en la que el servicio usa la nueva capacidad.
var operational_from_day: int = 0
var operation_key: String = ""


static func create(def: ProjectDefinition) -> ProjectState:
	var p := ProjectState.new()
	p.id = def.id
	p.site_id = def.site_id
	return p


func is_operational_on(day: int) -> bool:
	return status == COMPLETED and operational_from_day > 0 and day >= operational_from_day


func to_dict() -> Dictionary:
	return {
		"id": id,
		"site_id": site_id,
		"status": status,
		"paid_cents": str(paid_cents),
		"approved_tick": str(approved_tick),
		"approved_day": approved_day,
		"completion_day": completion_day,
		"completed_day": completed_day,
		"operational_from_day": operational_from_day,
		"operation_key": operation_key,
	}


static func from_dict(d: Dictionary, r: DictReader, def: ProjectDefinition) -> ProjectState:
	var p := ProjectState.new()
	var w := "projects[%s]" % d.get("id", "?")
	p.id = r.get_string(d, "id", w)
	p.site_id = r.get_string(d, "site_id", w)
	p.status = r.get_string(d, "status", w, STATUSES)
	p.paid_cents = r.get_big_int(d, "paid_cents", w, 0, TreasuryState.MAX_CENTS)
	p.approved_tick = r.get_big_int(d, "approved_tick", w, -1, 1 << 62)
	p.approved_day = r.get_small_int(d, "approved_day", w, 0, 1_000_000)
	p.completion_day = r.get_small_int(d, "completion_day", w, 0, 1_000_000)
	p.completed_day = r.get_small_int(d, "completed_day", w, 0, 1_000_000)
	p.operational_from_day = r.get_small_int(d, "operational_from_day", w, 0, 1_000_000)
	p.operation_key = r.get_string(d, "operation_key", w)
	if not r.ok():
		return p
	if def == null:
		r.fail(w, "proyecto desconocido")
		return p
	if p.site_id != def.site_id:
		r.fail(w, "lugar distinto al definido (%s)" % def.site_id)
	match p.status:
		AVAILABLE:
			if p.paid_cents != 0 or p.approved_day != 0:
				r.fail(w, "obra disponible con pagos o aprobación registrados")
		UNDER_CONSTRUCTION, COMPLETED:
			# El costo pagado se compara con el libro (no con el balance actual, que puede cambiar).
			if p.paid_cents <= 0 or p.approved_day < 1 or p.operation_key.is_empty():
				r.fail(w, "obra aprobada sin pago o clave de operación coherente")
			if p.completion_day < p.approved_day:
				r.fail(w, "plazo de obra inconsistente")
	if p.status == COMPLETED and (p.completed_day != p.completion_day or p.operational_from_day != p.completed_day + 1):
		r.fail(w, "fechas de finalización inconsistentes")
	return p
