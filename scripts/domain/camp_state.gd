class_name CampState
extends RefCounted
## Tu lugar: madera juntada, construcciones y comerciantes que pasan hoy por el camino.

var wood: int = 0
var buildings: PackedStringArray = PackedStringArray()
## Pasadas de comerciantes de la jornada:
## {id, merchant, start, status, stop_tick, leave_tick, bought}
var passes: Array[Dictionary] = []
var next_pass_id: int = 1
## Montones de ramas ya juntados hoy.
var branches_taken: PackedStringArray = PackedStringArray()
## tree_id -> jornada en que se taló.
var trees_cut: Dictionary = {}
## Pescado que se pudrió en el último cierre (para el informe).
var rotten_today: int = 0


func has_building(id: String) -> bool:
	return buildings.has(id)


func find_pass(pass_id: int) -> Dictionary:
	for p in passes:
		if int(p["id"]) == pass_id:
			return p
	return {}


func to_dict() -> Dictionary:
	var ps: Array = []
	for p in passes:
		ps.append({
			"id": p["id"], "merchant": p["merchant"], "start": str(p["start"]), "status": p["status"],
			"stop_tick": str(p["stop_tick"]), "leave_tick": str(p["leave_tick"]), "bought": p["bought"],
		})
	var cut: Array = []
	var keys := trees_cut.keys()
	keys.sort()
	for k in keys:
		cut.append({"tree": k, "day": trees_cut[k]})
	return {
		"wood": wood,
		"buildings": Array(buildings),
		"passes": ps,
		"next_pass_id": next_pass_id,
		"branches_taken": Array(branches_taken),
		"trees_cut": cut,
	}


static func from_dict(d: Dictionary, r: DictReader, content: GameContent) -> CampState:
	var c := CampState.new()
	var w := "camp"
	c.wood = r.get_small_int(d, "wood", w, 0, 1_000_000)
	for b in r.get_array(d, "buildings", w):
		if b is String and content.find_building(b) != null:
			c.buildings.append(b)
		else:
			r.fail(w + ".buildings", "construcción desconocida")
	for p in r.get_array(d, "passes", w):
		if not (p is Dictionary):
			r.fail(w + ".passes", "pasada inválida")
			continue
		var m := r.get_string(p, "merchant", w + ".passes")
		if content.find_merchant(m) == null:
			r.fail(w + ".passes", "comerciante desconocido '%s'" % m)
		c.passes.append({
			"id": r.get_small_int(p, "id", w + ".passes", 1, 100_000_000),
			"merchant": m,
			"start": r.get_big_int(p, "start", w + ".passes", 0, 1 << 62),
			"status": r.get_string(p, "status", w + ".passes", Merchants.STATUSES),
			"stop_tick": r.get_big_int(p, "stop_tick", w + ".passes", -1, 1 << 62),
			"leave_tick": r.get_big_int(p, "leave_tick", w + ".passes", -1, 1 << 62),
			"bought": r.get_small_int(p, "bought", w + ".passes", 0, 100000),
		})
	c.next_pass_id = r.get_small_int(d, "next_pass_id", w, 1, 100_000_000)
	for b in r.get_array(d, "branches_taken", w):
		if b is String:
			c.branches_taken.append(b)
	for t in r.get_array(d, "trees_cut", w):
		if t is Dictionary:
			c.trees_cut[r.get_string(t, "tree", w + ".trees_cut")] = r.get_small_int(t, "day", w + ".trees_cut", 1, 1_000_000)
	return c
