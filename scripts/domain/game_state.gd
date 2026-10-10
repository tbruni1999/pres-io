class_name GameState
extends RefCounted
## Fuente de verdad de la partida. Los objetos 3D y la UI solo la representan.
## No depende del SceneTree: se puede crear, simular y validar en pruebas headless.

const SCHEMA_VERSION := 5
const PLAYER_BOUNDS := 75.0

var world_seed: int = 0
## Generador administrativo propio con estado guardado. Lo cosmético usa otro.
var rng := RandomNumberGenerator.new()
var tick: int = 0
var ticks_per_day: int = 360
var office: String = ""
var settlement: SettlementState
var treasury: TreasuryState
var player: PlayerState
var camp: CampState
## project_id -> ProjectState
var projects: Dictionary = {}
## Claves de operación ya aplicadas -> tick en que se aplicaron (evita dobles cobros).
var applied_operations: Dictionary = {}
## sujeto -> {hecho: true}. Hechos narrativos (conversaciones, promesas, inspecciones).
var facts: Dictionary = {}
var reports: Array[DayReport] = []
## Pose del jugador: {"position": Vector3, "yaw": float, "pitch": float} o vacío.
var player_pose: Dictionary = {}
## Avisos que produjo el paso (lluvia, fuego apagado). No se guardan: la sesión los muestra y vacía.
var notices: PackedStringArray = PackedStringArray()


static func create_new(content: GameContent, seed_value: int) -> GameState:
	var s := GameState.new()
	var b := content.balance
	s.world_seed = seed_value
	s.rng.seed = seed_value
	s.ticks_per_day = b.ticks_per_day
	s.office = b.starting_office
	s.settlement = SettlementState.create(b)
	s.treasury = TreasuryState.create(b.starting_cash_cents())
	s.player = PlayerState.create(b)
	s.camp = CampState.new()
	s.camp.buildings = PackedStringArray(b.start_buildings)
	s.camp.fire_until = b.fire_start_ticks if s.camp.has_building("fire") else -1
	for t in b.start_tools:
		var def := content.find_item(t)
		if def != null:
			s.player.add_tool(def)
	for id in content.project_ids():
		s.projects[id] = ProjectState.create(content.find_project(id))
	for subject in content.fact_subjects:
		s.facts[subject] = {}
	Weather.plan_day(s, content, 1)
	Merchants.plan_day(s, content, 1)
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
		"player_state": player.to_dict(),
		"camp": camp.to_dict(),
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

	# Migraciones en cadena desde versiones que existieron de verdad.
	if version == 1:
		d = migrate_v1_to_v2(d, content)
		version = 2
	var migrated_v2 := version == 2
	if version == 2:
		d = migrate_v2_to_v3(d)
		version = 3
	if version == 3:
		d = migrate_v3_to_v4(d, content)
		version = 4
	if version == 4:
		d = migrate_v4_to_v5(d, content)

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
	s.player = PlayerState.from_dict(r.get_dict(d, "player_state", "root"), r, content)
	s.camp = CampState.from_dict(r.get_dict(d, "camp", "root"), r, content)

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
	if migrated_v2:
		_drop_night_passes(s, content)
	return {"state": s, "errors": PackedStringArray(), "future_version": false}


## v1 (H1, escritorio y caja comunitaria) -> v2 (vecino con billetera, hambre y sed).
## Conserva calendario, fondo, obras, hechos e informes; agrega un personaje inicial.
static func migrate_v1_to_v2(d: Dictionary, content: GameContent) -> Dictionary:
	var out := d.duplicate(true)
	out["schema_version"] = 2
	out["player_state"] = PlayerState.create(content.balance).to_dict()
	# Sin agenda de comerciantes: se arma vacía y desde el próximo cierre se planifica.
	out["camp"] = CampState.new().to_dict()
	# Los informes v1 no tenían la jornada del personaje: se completan en cero.
	for rep in out.get("reports", []):
		if rep is Dictionary:
			for key in ["earned_cents", "spent_cents", "faint_penalty_cents", "wallet_end_cents", "fund_cents"]:
				if not rep.has(key):
					rep[key] = "0"
			if not rep.has("fish_caught"):
				rep["fish_caught"] = 0
			if not rep.has("fainted"):
				rep["fainted"] = false
			if not rep.has("rotten"):
				rep["rotten"] = 0
	return out


## Las agendas de v2 no conocían la noche: quien pasaría de noche ya no pasa.
static func _drop_night_passes(s: GameState, content: GameContent) -> void:
	var night_tick := (s.current_day() - 1) * s.ticks_per_day + DayTime.night_offset_ticks(s, content)
	for p in s.camp.passes:
		var def := content.find_merchant(p["merchant"])
		if p["status"] == Merchants.SCHEDULED and int(p["start"]) + def.crossing_ticks >= night_tick:
			p["status"] = Merchants.GONE


## v3 -> v4: los comerciantes guardan su posición (para formar fila) y el refugio
## inicial pasó a ser una carpa: quien venía jugando ya tenía la choza, se la conserva.
static func migrate_v3_to_v4(d: Dictionary, content: GameContent) -> Dictionary:
	var out := d.duplicate(true)
	out["schema_version"] = 4
	var camp: Variant = out.get("camp")
	if not (camp is Dictionary):
		return out
	var tick_v: Variant = out.get("tick")
	var t := float(String(tick_v).to_int()) if tick_v is String else 0.0
	var passes: Variant = camp.get("passes", [])
	for p in (passes if passes is Array else []):
		if not (p is Dictionary):
			continue
		var def := content.find_merchant(String(p.get("merchant", "")))
		if def == null:
			continue
		var legacy := {"status": p.get("status", Merchants.SCHEDULED), "start": String(p.get("start", "0")).to_int(),
			"stop_tick": String(p.get("stop_tick", "-1")).to_int(), "leave_tick": String(p.get("leave_tick", "-1")).to_int()}
		p["x"] = Merchants.legacy_position_x(legacy, def, t)
		p["v"] = Merchants.speed(def) if legacy["status"] in [Merchants.PASSING, Merchants.LEAVING] else 0.0
		p["visited"] = false
	camp["merchant_visits"] = []
	var b: Variant = camp.get("buildings", [])
	if b is Array and not b.has("shack"):
		b.append("shack")
	return out


## v4 -> v5: clima, fogón con leña, desgaste de herramientas, acopio, espinel,
## antojos, misterios de noche y vecinos. Se arranca con sol, fogón apagado y
## herramientas con todos sus usos.
static func migrate_v4_to_v5(d: Dictionary, content: GameContent) -> Dictionary:
	var out := d.duplicate(true)
	out["schema_version"] = 5
	var camp: Variant = out.get("camp")
	if camp is Dictionary:
		camp["weather"] = Weather.SUN
		camp["rain_start"] = "-1"
		camp["rain_end"] = "-1"
		camp["last_rain_day"] = 0
		camp["fire_until"] = "-1"
		camp["storage"] = []
		camp["longline_items"] = []
		camp["craving"] = {}
		camp["night_thread"] = 0
		camp["neighbors"] = []
	# Quien ya ahumaba antes de v5 cuenta como "ya ahumó" (atrae a Beto).
	var smoked := false
	if camp is Dictionary:
		var bl: Variant = camp.get("buildings", [])
		smoked = bl is Array and bl.has("smokehouse")
	if smoked:
		var fl: Variant = out.get("facts", [])
		for f in (fl if fl is Array else []):
			if f is Dictionary and f.get("subject") == "player" and f.get("facts") is Array and not f["facts"].has("smoked_once"):
				f["facts"].append("smoked_once")
	var pl: Variant = out.get("player_state")
	if pl is Dictionary:
		var wear: Array = []
		var tools: Variant = pl.get("tools", [])
		for t in (tools if tools is Array else []):
			var def := content.find_item(String(t)) if t is String else null
			if def != null and def.durability > 0:
				wear.append({"id": t, "uses": def.durability})
		pl["tool_wear"] = wear
	var reps: Variant = out.get("reports", [])
	for rep in (reps if reps is Array else []):
		if rep is Dictionary and not rep.has("events"):
			rep["events"] = []
	return out


## v2 (choza y lago) -> v3 (noche y ahumadero): ahumadero vacío y marca de "dormiste afuera".
static func migrate_v2_to_v3(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out["schema_version"] = 3
	var camp: Variant = out.get("camp")
	if camp is Dictionary:
		if not camp.has("smoker_items"):
			camp["smoker_items"] = []
		if not camp.has("smoker_ready_tick"):
			camp["smoker_ready_tick"] = "-1"
	var reps: Variant = out.get("reports", [])
	for rep in (reps if reps is Array else []):
		if rep is Dictionary and not rep.has("slept_outside"):
			rep["slept_outside"] = false
	return out


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
