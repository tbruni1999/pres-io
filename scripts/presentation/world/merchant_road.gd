class_name MerchantRoad
extends Node3D
## Dibuja a los comerciantes del día sobre el camino. La posición sale de
## la posición guardada de cada pasada (Merchants.position_x), así que se reconstruye sola tras cargar.
## El nodo se ubica en el centro del camino, frente a la choza (X = 0).

signal merchant_arriving(def: MerchantDefinition)
signal merchant_passed(def: MerchantDefinition)

const VEHICLES := {
	"horse": preload("res://scenes/actors/merchant_horse.tscn"),
	"car": preload("res://scenes/actors/merchant_car.tscn"),
	"truck": preload("res://scenes/actors/merchant_truck.tscn"),
}
## Distancia al camino desde la que se le puede hacer señas, y para comerciar.
const HAIL_DISTANCE_Z := 7.0
const HAIL_DISTANCE_X := 32.0
const TRADE_DISTANCE := 4.5

## Carril de los que esperan (lado de la carpa) y carril de sobrepaso (metros desde el centro).
const LANE_IN := -0.9
const LANE_OUT := 1.4
const LANE_CHANGE_SPEED := 2.5

var _actors: Dictionary = {}
var _last_status: Dictionary = {}


func _ready() -> void:
	Game.state_replaced.connect(_reset)
	_reset()


func _reset() -> void:
	for a in _actors.values():
		a.queue_free()
	_actors.clear()
	_last_status.clear()
	# Al cargar no se anuncian pasadas viejas: se toma el estado actual como punto de partida.
	for p in Game.state.camp.passes:
		_last_status[int(p["id"])] = p["status"]


func _process(_delta: float) -> void:
	var s := Game.state
	var frac := 0.0 if Game.is_paused() else Game.clock.step_fraction()
	var seen := {}
	for p in s.camp.passes:
		var id := int(p["id"])
		var status := String(p["status"])
		var def := Game.content.find_merchant(p["merchant"])
		var prev := String(_last_status.get(id, Merchants.SCHEDULED))
		if prev != status:
			if status == Merchants.PASSING and prev == Merchants.SCHEDULED and not s.camp.has_building(Merchants.SIGN_BUILDING):
				merchant_arriving.emit(def)
			elif status == Merchants.GONE and prev == Merchants.PASSING:
				merchant_passed.emit(def)
			_last_status[id] = status
		if Merchants.is_on_road(p):
			seen[id] = true
			var actor: Node3D = _actors.get(id)
			if actor == null:
				actor = VEHICLES.get(def.vehicle, VEHICLES["horse"]).instantiate()
				add_child(actor)
				actor.position.z = LANE_OUT if p["status"] == Merchants.LEAVING else LANE_IN
				_actors[id] = actor
			# Los que se van sobrepasan por el otro carril para no atravesar a los que esperan.
			var lane := LANE_OUT if p["status"] == Merchants.LEAVING else LANE_IN
			var z := move_toward(actor.position.z, lane, LANE_CHANGE_SPEED * get_process_delta_time())
			actor.position = Vector3(clampf(Merchants.position_x(p, frac), -Merchants.ROAD_HALF - 5.0, Merchants.ROAD_HALF + 5.0), 0.0, z)
			actor.set_moving(not Merchants.is_waiting(p))
	for id in _actors.keys():
		if not seen.has(id):
			_actors[id].queue_free()
			_actors.erase(id)


## Qué se puede hacer con los comerciantes desde la posición del jugador.
func context_for(player_pos: Vector3) -> Dictionary:
	var local := to_local(player_pos)
	for p in Game.state.camp.passes:
		var id := int(p["id"])
		if not _actors.has(id):
			continue
		var def := Game.content.find_merchant(p["merchant"])
		var x: float = _actors[id].position.x
		var name := Texts.t(def.name_key)
		if p["status"] == Merchants.PASSING and x >= Merchants.HAIL_MIN_X and x <= Merchants.HAIL_MAX_X \
				and absf(local.z) < HAIL_DISTANCE_Z and absf(local.x - x) < HAIL_DISTANCE_X:
			return {"kind": "hail", "pass_id": id, "name": name, "prefix": def.lines_prefix, "text": Texts.t("ACTION_HAIL", {"name": name})}
		if Merchants.is_waiting(p) and Vector2(local.x - x, local.z).length() < TRADE_DISTANCE:
			return {"kind": "trade", "pass_id": id, "name": name, "prefix": def.lines_prefix, "text": Texts.t("ACTION_TRADE", {"name": name})}
	return {}


func actor_x(pass_id: int) -> float:
	return _actors[pass_id].position.x if _actors.has(pass_id) else NAN
