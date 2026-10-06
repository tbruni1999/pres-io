class_name DialogueService
extends RefCounted
## Diálogos definidos por datos (data/dialogue/*.json), elegidos según el estado.
## El diálogo solo lee el estado y registra hechos narrativos: nunca toca dinero.

var resident_id: String = ""
var name_key: String = ""
var role_key: String = ""
var _entries: Array = []
var _by_id: Dictionary = {}


static func load_file(path: String) -> DialogueService:
	var svc := DialogueService.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir el diálogo %s" % path)
		return svc
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		push_error("Diálogo inválido %s" % path)
		return svc
	svc.resident_id = String(data.get("resident_id", ""))
	svc.name_key = String(data.get("name_key", ""))
	svc.role_key = String(data.get("role_key", ""))
	svc._entries = data.get("entries", [])
	for e in svc._entries:
		svc._by_id[e["id"]] = e
	return svc


## Primera entrada cuyo contexto coincide con el estado actual.
func start_entry(state: GameState) -> Dictionary:
	for e in _entries:
		if e.get("only_via_next", false):
			continue
		if matches(e.get("when", {}), state):
			return e
	return {}


func get_entry(entry_id: String) -> Dictionary:
	return _by_id.get(entry_id, {})


func visible_options(entry: Dictionary, state: GameState) -> Array:
	var out: Array = []
	for o in entry.get("options", []):
		if matches(o.get("when", {}), state):
			out.append(o)
	return out


func matches(when: Dictionary, state: GameState) -> bool:
	var projects: Dictionary = when.get("projects", {})
	for pid in projects:
		var p := state.get_project(pid)
		if p == null or p.status != projects[pid]:
			return false
	for f in when.get("facts", []):
		if not state.has_fact(resident_id, f):
			return false
	for f in when.get("missing_facts", []):
		if state.has_fact(resident_id, f):
			return false
	return true
