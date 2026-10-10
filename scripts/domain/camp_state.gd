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
## Visitas que tuvo cada comerciante (avanza su historia por entregas).
var merchant_visits: Dictionary = {}
## Ahumadero: item crudo -> cantidad cargada, y tick en que la tanda está lista (-1 = vacío).
var smoker_items: Dictionary = {}
var smoker_ready_tick: int = -1
## Clima del día (Weather.KINDS); si llueve, ventana [rain_start, rain_end) en ticks.
var weather: String = "sun"
var rain_start: int = -1
var rain_end: int = -1
var last_rain_day: int = 0
## El fogón arde hasta este tick (-1 = apagado).
var fire_until: int = -1
## Acopio: materiales comprados que no van en la mochila (chapas, cemento).
var storage: Dictionary = {}
## Espinel: pescado que quedó enganchado a la mañana (se pudre al cerrar).
var longline_items: Dictionary = {}
## Antojo del día: {merchant, item}; ese comerciante paga más por eso. Vacío = ninguno.
var craving: Dictionary = {}
## Capítulo del misterio de las luces del lago.
var night_thread: int = 0
## Vecinos: id -> {spot, since, talked_day, ep}.
var neighbors: Dictionary = {}


func has_building(id: String) -> bool:
	return buildings.has(id)


func smoker_count() -> int:
	var n := 0
	for k in smoker_items:
		n += int(smoker_items[k])
	return n


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
			"x": float(p.get("x", -Merchants.ROAD_HALF - 1.0)), "v": float(p.get("v", 0.0)),
			"visited": bool(p.get("visited", false)),
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
		"smoker_items": _items_to_list(smoker_items),
		"merchant_visits": _items_to_list(merchant_visits),
		"smoker_ready_tick": str(smoker_ready_tick),
		"weather": weather,
		"rain_start": str(rain_start),
		"rain_end": str(rain_end),
		"last_rain_day": last_rain_day,
		"fire_until": str(fire_until),
		"storage": _items_to_list(storage),
		"longline_items": _items_to_list(longline_items),
		"craving": craving.duplicate(),
		"night_thread": night_thread,
		"neighbors": _neighbors_to_list(),
	}


func _neighbors_to_list() -> Array:
	var out: Array = []
	var keys := neighbors.keys()
	keys.sort()
	for k in keys:
		var n: Dictionary = neighbors[k]
		out.append({"id": k, "spot": n["spot"], "since": n["since"], "talked_day": n["talked_day"], "ep": n["ep"]})
	return out


static func _items_to_list(d: Dictionary) -> Array:
	var out: Array = []
	var keys := d.keys()
	keys.sort()
	for k in keys:
		out.append({"id": k, "count": d[k]})
	return out


static func _read_items(d: Dictionary, key: String, r: DictReader, content: GameContent, kind: ItemDefinition.Kind) -> Dictionary:
	var out := {}
	for it in r.get_array(d, key, "camp"):
		if not (it is Dictionary):
			r.fail("camp." + key, "entrada inválida")
			continue
		var id := r.get_string(it, "id", "camp." + key)
		var def := content.find_item(id)
		if def == null or def.kind != kind:
			r.fail("camp." + key, "objeto inválido '%s'" % id)
		out[id] = r.get_small_int(it, "count", "camp." + key, 1, 100000)
	return out


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
			"x": r.get_finite_float([p.get("x")], 0, w + ".passes.x"),
			"v": r.get_finite_float([p.get("v")], 0, w + ".passes.v"),
			"visited": r.get_bool(p, "visited", w + ".passes"),
		})
	c.next_pass_id = r.get_small_int(d, "next_pass_id", w, 1, 100_000_000)
	for b in r.get_array(d, "branches_taken", w):
		if b is String:
			c.branches_taken.append(b)
	for t in r.get_array(d, "trees_cut", w):
		if t is Dictionary:
			c.trees_cut[r.get_string(t, "tree", w + ".trees_cut")] = r.get_small_int(t, "day", w + ".trees_cut", 1, 1_000_000)
	for it in r.get_array(d, "smoker_items", w):
		if it is Dictionary:
			var id := r.get_string(it, "id", w + ".smoker_items")
			var def := content.find_item(id)
			if def == null or def.smoked_into.is_empty():
				r.fail(w + ".smoker_items", "no se puede ahumar '%s'" % id)
			c.smoker_items[id] = r.get_small_int(it, "count", w + ".smoker_items", 1, 100000)
	c.smoker_ready_tick = r.get_big_int(d, "smoker_ready_tick", w, -1, 1 << 62)
	for it in r.get_array(d, "merchant_visits", w):
		if it is Dictionary:
			var mid := r.get_string(it, "id", w + ".merchant_visits")
			if content.find_merchant(mid) == null:
				r.fail(w + ".merchant_visits", "comerciante desconocido '%s'" % mid)
			c.merchant_visits[mid] = r.get_small_int(it, "count", w + ".merchant_visits", 0, 1_000_000)
	c.weather = r.get_string(d, "weather", w, Weather.KINDS)
	c.rain_start = r.get_big_int(d, "rain_start", w, -1, 1 << 62)
	c.rain_end = r.get_big_int(d, "rain_end", w, -1, 1 << 62)
	c.last_rain_day = r.get_small_int(d, "last_rain_day", w, 0, 1_000_000)
	c.fire_until = r.get_big_int(d, "fire_until", w, -1, 1 << 62)
	c.storage = _read_items(d, "storage", r, content, ItemDefinition.Kind.MATERIAL)
	c.longline_items = _read_items(d, "longline_items", r, content, ItemDefinition.Kind.CATCH)
	var cr := r.get_dict(d, "craving", w)
	if not cr.is_empty():
		var cm := r.get_string(cr, "merchant", w + ".craving")
		var ci := r.get_string(cr, "item", w + ".craving")
		if content.find_merchant(cm) == null or content.find_item(ci) == null:
			r.fail(w + ".craving", "antojo desconocido")
		c.craving = {"merchant": cm, "item": ci}
	c.night_thread = r.get_small_int(d, "night_thread", w, 0, Nights.LIGHTS_EPISODES)
	for it in r.get_array(d, "neighbors", w):
		if not (it is Dictionary):
			r.fail(w + ".neighbors", "vecino inválido")
			continue
		var nid := r.get_string(it, "id", w + ".neighbors", Neighbors.ATTRACTED_BY.keys())
		var spot := r.get_string(it, "spot", w + ".neighbors", [""] + Neighbors.SPOTS)
		c.neighbors[nid] = {
			"spot": spot,
			"since": r.get_small_int(it, "since", w + ".neighbors", 1, 1_000_000),
			"talked_day": r.get_small_int(it, "talked_day", w + ".neighbors", 0, 1_000_000),
			"ep": r.get_small_int(it, "ep", w + ".neighbors", 0, Neighbors.EPISODES),
		}
	if (c.rain_start < 0) != (c.rain_end < 0) or c.rain_end < c.rain_start:
		r.fail(w, "ventana de lluvia inconsistente")
	if c.smoker_items.is_empty() != (c.smoker_ready_tick < 0):
		r.fail(w, "ahumadero inconsistente (carga y hora de listo)")
	return c
