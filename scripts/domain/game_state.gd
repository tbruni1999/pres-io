class_name GameState
extends RefCounted
## Fuente de verdad de la partida. Los objetos 3D y la UI solo la representan.
## No depende del SceneTree: se puede crear, simular y validar en pruebas headless.

const SCHEMA_VERSION := 1
const PLAYER_BOUNDS := 75.0

var world_seed: int = 0
## Generador administrativo propio con estado guardado. Lo cosmético usa otro.
var rng := RandomNumberGenerator.new()
var tick: int = 0
var ticks_per_day: int = 360
var office: String = ""
var settlement: SettlementState
var treasury: TreasuryState
## project_id -> ProjectState
var projects: Dictionary = {}
## Claves de operación ya aplicadas -> tick en que se aplicaron (evita dobles cobros).
var applied_operations: Dictionary = {}
## sujeto -> {hecho: true}. Hechos narrativos (conversaciones, promesas, inspecciones).
var facts: Dictionary = {}
var reports: Array[DayReport] = []
## Pose del jugador: {"position": Vector3, "yaw": float, "pitch": float} o vacío.
var player_pose: Dictionary = {}


static func create_new(content: GameContent, seed_value: int) -> GameState:
	var s := GameState.new()
	var b := content.balance
	s.world_seed = seed_value
	s.rng.seed = seed_value
	s.ticks_per_day = b.ticks_per_day
	s.office = b.starting_office
	s.settlement = SettlementState.create(b)
	s.treasury = TreasuryState.create(b.starting_cash_cents())
	for id in content.project_ids():
		s.projects[id] = ProjectState.create(content.find_project(id))
	for subject in content.fact_subjects:
		s.facts[subject] = {}
	return s


func current_day() -> int:
	return tick / ticks_per_day + 1


## Progreso de la jornada actual en puntos básicos (0..9999).
func day_progress_bp() -> int:
	return (tick % ticks_per_day) * 10000 / ticks_per_day


func ticks_left_in_day() -> int:
	return ticks_per_day - (tick % ticks_per_day)


func get_project(project_id: String) -> ProjectState:
	return projects.get(project_id) as ProjectState


func has_fact(subject: String, fact: String) -> bool:
	return facts.has(subject) and bool(facts[subject].get(fact, false))


func last_report() -> DayReport:
	return null if reports.is_empty() else reports[-1]


func to_dict(game_version: String) -> Dictionary:
	var project_list: Array = []
	for id in _sorted_keys(projects):
		project_list.append((projects[id] as ProjectState).to_dict())
	var ops: Array = []
	for key in _sorted_keys(applied_operations):
		ops.append({"key": key, "tick": str(applied_operations[key])})
	var fact_list: Array = []
	for subject in _sorted_keys(facts):
		var names: Array = []
		for f in _sorted_keys(facts[subject]):
			if facts[subject][f]:
				names.append(f)
		fact_list.append({"subject": subject, "facts": names})
	var report_list: Array = []
	for rep in reports:
		report_list.append(rep.to_dict())
	var pose: Variant = null
	if not player_pose.is_empty():
		var p: Vector3 = player_pose["position"]
		pose = {"position": [p.x, p.y, p.z], "yaw": player_pose["yaw"], "pitch": player_pose["pitch"]}
	return {
		"schema_version": SCHEMA_VERSION,
		"game_version": game_version,
		"seed": str(world_seed),
		"rng_seed": str(rng.seed),
		"rng_state": str(rng.state),
		"tick": str(tick),
		"ticks_per_day": ticks_per_day,
		"office": office,
		"settlement": settlement.to_dict(),
		"treasury": treasury.to_dict(),
		"projects": project_list,
		"applied_operations": ops,
		"facts": fact_list,
		"reports": report_list,
		"player": pose,
	}


## Construye un estado nuevo desde datos sin tocar la sesión activa.
## Devuelve {"state": GameState o null, "errors": PackedStringArray, "future_version": bool}.
static func from_dict(d: Dictionary, content: GameContent) -> Dictionary:
	var r := DictReader.new()
	var version_v: Variant = d.get("schema_version")
	if not (version_v is float or version_v is int):
		return {"state": null, "errors": PackedStringArray(["schema_version ausente"]), "future_version": false}
	var version := int(version_v)
	if version > SCHEMA_VERSION:
		return {"state": null, "errors": PackedStringArray(["versión de esquema %d más nueva que %d" % [version, SCHEMA_VERSION]]), "future_version": true}
	if version < 1:
		return {"state": null, "errors": PackedStringArray(["versión de esquema inválida %d" % version]), "future_version": false}

	var s := GameState.new()
	var max_tick := 1 << 62
	s.world_seed = r.get_big_int(d, "seed", "root", DictReader.INT64_MIN, DictReader.INT64_MAX)
	s.rng.seed = r.get_big_int(d, "rng_seed", "root", DictReader.INT64_MIN, DictReader.INT64_MAX)
	var rng_state := r.get_big_int(d, "rng_state", "root", DictReader.INT64_MIN, DictReader.INT64_MAX)
	s.tick = r.get_big_int(d, "tick", "root", 0, max_tick)
	s.ticks_per_day = r.get_small_int(d, "ticks_per_day", "root", 1, 1_000_000)
	s.office = r.get_string(d, "office", "root")
	s.settlement = SettlementState.from_dict(r.get_dict(d, "settlement", "root"), r)
	s.treasury = TreasuryState.from_dict(r.get_dict(d, "treasury", "root"), r)

	for item in r.get_array(d, "projects", "root"):
		if not (item is Dictionary):
			r.fail("projects", "obra inválida")
			continue
		var def := content.find_project(String(item.get("id", "")))
		var p := ProjectState.from_dict(item, r, def)
		if s.projects.has(p.id):
			r.fail("projects", "obra duplicada %s" % p.id)
		s.projects[p.id] = p
	for id in content.project_ids():
		if not s.projects.has(id):
			r.fail("projects", "falta la obra %s" % id)

	for item in r.get_array(d, "applied_operations", "root"):
		if item is Dictionary:
			s.applied_operations[r.get_string(item, "key", "applied_operations")] = r.get_big_int(item, "tick", "applied_operations", 0, max_tick)
		else:
			r.fail("applied_operations", "operación inválida")

	for subject in content.fact_subjects:
		s.facts[subject] = {}
	for item in r.get_array(d, "facts", "root"):
		if not (item is Dictionary):
			r.fail("facts", "entrada inválida")
			continue
		var subject := r.get_string(item, "subject", "facts")
		if not content.fact_subjects.has(subject):
			r.fail("facts", "sujeto desconocido '%s'" % subject)
			continue
		for f in r.get_array(item, "facts", "facts"):
			if f is String:
				s.facts[subject][f] = true
			else:
				r.fail("facts", "hecho inválido")

	for item in r.get_array(d, "reports", "root"):
		if item is Dictionary:
			s.reports.append(DayReport.from_dict(item, r))
		else:
			r.fail("reports", "informe inválido")

	var pose_v: Variant = d.get("player")
	if pose_v is Dictionary:
		var pos_arr: Array = r.get_array(pose_v, "position", "player")
		var pos := Vector3(r.get_finite_float(pos_arr, 0, "player.position"), r.get_finite_float(pos_arr, 1, "player.position"), r.get_finite_float(pos_arr, 2, "player.position"))
		var yaw := r.get_finite_float([pose_v.get("yaw")], 0, "player.yaw")
		var pitch := r.get_finite_float([pose_v.get("pitch")], 0, "player.pitch")
		# Una ubicación fuera del mapa no invalida la partida: se usa el punto de aparición.
		if absf(pos.x) <= PLAYER_BOUNDS and absf(pos.z) <= PLAYER_BOUNDS and pos.y > -2.0 and pos.y < 20.0:
			s.player_pose = {"position": pos, "yaw": yaw, "pitch": clampf(pitch, -89.0, 89.0)}
	elif pose_v != null:
		r.fail("player", "se esperaba un objeto o null")

	if r.ok():
		_validate_relations(s, r)
	if not r.ok():
		return {"state": null, "errors": r.errors, "future_version": false}
	s.rng.state = rng_state
	return {"state": s, "errors": PackedStringArray(), "future_version": false}


## Relaciones entre partes: pagos de obras en el libro, claves de operación, fechas.
static func _validate_relations(s: GameState, r: DictReader) -> void:
	var day := s.current_day()
	for id in s.projects:
		var p: ProjectState = s.projects[id]
		if p.status == ProjectState.AVAILABLE:
			continue
		if not s.applied_operations.has(p.operation_key):
			r.fail("projects[%s]" % id, "la clave de operación no figura entre las aplicadas")
		var paid := 0
		for e in s.treasury.ledger:
			if e["operation_key"] == p.operation_key:
				paid += int(e["amount_cents"])
		if paid != p.paid_cents:
			r.fail("projects[%s]" % id, "el pago no coincide con el libro de movimientos")
		if p.approved_day > day:
			r.fail("projects[%s]" % id, "aprobada en una jornada futura")
		if p.status == ProjectState.UNDER_CONSTRUCTION and p.completion_day < day:
			r.fail("projects[%s]" % id, "obra vencida sin completar")
		if p.status == ProjectState.COMPLETED and p.completed_day >= day:
			r.fail("projects[%s]" % id, "completada en una jornada no cerrada")
	for rep in s.reports:
		if rep.day >= day:
			r.fail("reports", "informe de una jornada no cerrada (%d)" % rep.day)


static func _sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys
