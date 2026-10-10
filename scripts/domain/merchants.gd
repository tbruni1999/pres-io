class_name Merchants
extends RefCounted
## Comerciantes que cruzan el camino frente a la choza.
## La agenda del día sale del generador de la partida; la posición se deriva del tick,
## así la escena se puede reconstruir en cualquier momento (también al cargar).

const SCHEDULED := "scheduled"
const PASSING := "passing"
const STOPPED := "stopped"
const LEAVING := "leaving"
const GONE := "gone"
## Esperando en la fila detrás de otro comerciante parado. También se le puede vender.
const QUEUED := "queued"
const STATUSES := [SCHEDULED, PASSING, STOPPED, QUEUED, LEAVING, GONE]

## El camino va de -ROAD_HALF a +ROAD_HALF en X; la choza está en X = 0.
const ROAD_HALF := 90.0
## Hasta dónde se le puede hacer señas (ya pasó la choza por poco).
const HAIL_MAX_X := 8.0
const HAIL_MIN_X := -50.0
const SIGN_BUILDING := "sign"


# --- Agenda ---------------------------------------------------------------------

## Arma las pasadas de una jornada. La primera del día 1 es siempre la de Don Ramiro.
static func plan_day(state: GameState, content: GameContent, day: int) -> void:
	var camp := state.camp
	camp.passes.clear()
	var b := content.balance
	var tpd := state.ticks_per_day
	var day_start := (day - 1) * tpd
	var slots := maxi(1, b.merchant_passes_per_day)
	# Todos tienen que terminar de cruzar antes de la noche (el más lento tarda slowest_crossing).
	var window_end := maxi(60, DayTime.night_offset_ticks(state, content) - _slowest_crossing(content) - b.merchant_stop_ticks)
	var spacing := maxi(1, (window_end - 30) / slots)
	if content.merchants.is_empty():
		return
	for i in slots:
		var offset := 30 + i * spacing + state.rng.randi_range(0, maxi(0, spacing / 3))
		offset = mini(offset, window_end)
		var merchant := _pick_merchant(state, content)
		if day == 1 and i == 0 and content.find_merchant(content.balance.first_merchant) != null:
			merchant = content.balance.first_merchant
		if merchant.is_empty():
			continue
		camp.passes.append({
			"id": camp.next_pass_id, "merchant": merchant, "start": day_start + offset,
			"status": SCHEDULED, "stop_tick": -1, "leave_tick": -1, "bought": 0,
			"x": -ROAD_HALF - 1.0, "v": 0.0, "visited": false,
		})
		camp.next_pass_id += 1


static func _slowest_crossing(content: GameContent) -> int:
	var slowest := 0
	for m in content.merchants:
		var def := m as MerchantDefinition
		if def != null:
			slowest = maxi(slowest, def.crossing_ticks)
	return slowest


static func _pick_merchant(state: GameState, content: GameContent) -> String:
	var pool: Array[MerchantDefinition] = []
	var total := 0
	for m in content.merchants:
		var def := m as MerchantDefinition
		if def != null and (def.requires_building.is_empty() or state.camp.has_building(def.requires_building)):
			pool.append(def)
			total += maxi(1, def.weight)
	var roll := state.rng.randi_range(0, maxi(0, total - 1))
	for def in pool:
		roll -= maxi(1, def.weight)
		if roll < 0:
			return def.id
	return "" if pool.is_empty() else pool[0].id


# --- Movimiento -----------------------------------------------------------------
# Cada pasada guarda su posición "x" y la velocidad "v" del último paso. Los vehículos
# parados (STOPPED) o esperando en fila (QUEUED) frenan a los que vienen atrás, que se
# ponen en fila a QUEUE_GAP metros. Los que van andando se pueden pasar entre sí.

static func speed(def: MerchantDefinition) -> float:
	return 2.0 * ROAD_HALF / maxf(1.0, float(def.crossing_ticks))


## Posición sobre el camino; fraction (0..1) interpola dentro del paso para animar suave.
static func position_x(p: Dictionary, fraction: float = 0.0) -> float:
	if p["status"] == SCHEDULED:
		return -ROAD_HALF - 1.0
	return float(p.get("x", -ROAD_HALF)) + float(p.get("v", 0.0)) * clampf(fraction, 0.0, 1.0)


static func is_waiting(p: Dictionary) -> bool:
	return p["status"] == STOPPED or p["status"] == QUEUED


static func is_on_road(p: Dictionary) -> bool:
	return p["status"] in [PASSING, STOPPED, QUEUED, LEAVING]


## Avanza el estado de las pasadas en un paso administrativo (de adelante hacia atrás).
static func update(state: GameState, content: GameContent) -> void:
	var t := state.tick
	var has_sign := state.camp.has_building(SIGN_BUILDING)
	var gap := content.balance.merchant_queue_gap
	var order: Array = state.camp.passes.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var xa := position_x(a)
		var xb := position_x(b)
		return xa > xb if xa != xb else int(a["id"]) < int(b["id"]))
	for p in order:
		var def := content.find_merchant(p["merchant"])
		var v := speed(def)
		match String(p["status"]):
			SCHEDULED:
				if t >= int(p["start"]):
					p["status"] = PASSING
					p["x"] = -ROAD_HALF
					p["v"] = 0.0
			PASSING, QUEUED:
				var x := float(p["x"])
				var limit := INF
				var blocker := _waiting_ahead(state, p)
				if not blocker.is_empty():
					limit = float(blocker["x"]) - gap
				var target := minf(x + v, limit)
				if has_sign and x < 0.0 and target >= 0.0 and limit >= 0.0:
					# Con el cartel, para justo frente a la choza.
					p["v"] = 0.0 - x
					p["x"] = 0.0
					_stop(p, t, content)
				elif target <= x + 0.001 and limit < INF:
					p["v"] = 0.0
					p["x"] = maxf(x, limit) if x > limit else x
					p["status"] = QUEUED
				else:
					p["v"] = target - x
					p["x"] = target
					p["status"] = PASSING
					if target >= ROAD_HALF:
						p["status"] = GONE
			STOPPED:
				p["v"] = 0.0
				if t >= int(p["leave_tick"]):
					p["status"] = LEAVING
			LEAVING:
				p["v"] = v
				p["x"] = float(p["x"]) + v
				if float(p["x"]) >= ROAD_HALF:
					p["status"] = GONE


## El vehículo parado o en fila más cercano adelante.
static func _waiting_ahead(state: GameState, p: Dictionary) -> Dictionary:
	var x := position_x(p)
	var best: Dictionary = {}
	for q in state.camp.passes:
		if q == p or not is_waiting(q):
			continue
		var qx := position_x(q)
		if qx > x or (qx == x and int(q["id"]) < int(p["id"])):
			if best.is_empty() or qx < position_x(best):
				best = q
	return best


static func _stop(p: Dictionary, t: int, content: GameContent) -> void:
	p["status"] = STOPPED
	p["stop_tick"] = t
	p["leave_tick"] = t + content.balance.merchant_stop_ticks


static func active_pass(state: GameState) -> Dictionary:
	for p in state.camp.passes:
		if p["status"] == STOPPED:
			return p
	return {}


## Posición del comerciante calculada como en el esquema 3 (para migrar partidas).
static func legacy_position_x(p: Dictionary, def: MerchantDefinition, t: float) -> float:
	var v := speed(def)
	var start := float(p["start"])
	match String(p["status"]):
		SCHEDULED:
			return -ROAD_HALF - 1.0
		STOPPED:
			return -ROAD_HALF + v * (float(p["stop_tick"]) - start)
		LEAVING, GONE:
			if int(p["stop_tick"]) >= 0:
				return -ROAD_HALF + v * (float(p["stop_tick"]) - start) + v * (t - float(p["leave_tick"]))
	return -ROAD_HALF + v * (t - start)


# --- Comandos -------------------------------------------------------------------

## Hacerle señas a un comerciante que viene por el camino.
static func hail(state: GameState, content: GameContent, pass_id: int) -> CommandResult:
	var p := state.camp.find_pass(pass_id)
	if p.is_empty():
		return CommandResult.failure("unknown_pass", Texts.t("ERR_NO_MERCHANT"))
	if is_waiting(p):
		return CommandResult.already_applied(Texts.t("MSG_ALREADY_STOPPED"))
	var def := content.find_merchant(p["merchant"])
	var x := position_x(p)
	if p["status"] != PASSING or x > HAIL_MAX_X or x < HAIL_MIN_X:
		return CommandResult.failure("too_far", Texts.t("ERR_MERCHANT_TOO_FAR"))
	p["v"] = 0.0
	_stop(p, state.tick, content)
	return CommandResult.success("", {"merchant": def.id})


## Capítulos de la historia por entregas de cada comerciante.
const EPISODES := 10


## Abre una visita (al empezar a comerciar). Cuenta una sola vez por pasada y devuelve
## el número de visita de ese comerciante (1, 2, 3...), que elige el capítulo de su historia.
static func begin_visit(state: GameState, content: GameContent, pass_id: int) -> int:
	var p := state.camp.find_pass(pass_id)
	if p.is_empty() or not is_waiting(p):
		return 0
	var m := String(p["merchant"])
	if not bool(p.get("visited", false)):
		p["visited"] = true
		state.camp.merchant_visits[m] = int(state.camp.merchant_visits.get(m, 0)) + 1
		var def := content.find_merchant(m)
		if int(state.camp.merchant_visits[m]) == EPISODES and def != null and not def.story_end_fact.is_empty():
			state.facts["player"][def.story_end_fact] = true
	return int(state.camp.merchant_visits.get(m, 0))


## El jugador terminó de comerciar: el comerciante sigue viaje.
static func dismiss(state: GameState, pass_id: int) -> void:
	var p := state.camp.find_pass(pass_id)
	if not p.is_empty() and is_waiting(p):
		p["status"] = LEAVING
		p["leave_tick"] = state.tick


static func sell_to(state: GameState, content: GameContent, pass_id: int, item_id: String, qty: int) -> CommandResult:
	var p := state.camp.find_pass(pass_id)
	if p.is_empty() or not is_waiting(p):
		return CommandResult.failure("no_merchant", Texts.t("ERR_NO_MERCHANT"))
	var def := content.find_merchant(p["merchant"])
	var price := def.buy_price_cents(item_id)
	if price <= 0:
		return CommandResult.failure("not_buyable", Texts.t("ERR_MERCHANT_DOESNT_BUY"))
	var room := def.max_buy - int(p["bought"])
	if room <= 0:
		return CommandResult.failure("merchant_full", Texts.t("ERR_MERCHANT_FULL"))
	qty = mini(qty, room)
	if qty <= 0 or state.player.count(item_id) < qty:
		return CommandResult.failure("not_enough_items", Texts.t("ERR_NOT_ENOUGH_ITEMS"))
	var total := price * qty
	state.player.remove_item(item_id, qty)
	state.player.earn(total)
	p["bought"] = int(p["bought"]) + qty
	return CommandResult.success(Texts.t("MSG_SOLD", {"n": qty, "name": Texts.t(content.find_item(item_id).name_key), "total": Money.format(total)}), {"total_cents": total, "qty": qty})


static func buy_from(state: GameState, content: GameContent, pass_id: int, item_id: String) -> CommandResult:
	var p := state.camp.find_pass(pass_id)
	if p.is_empty() or not is_waiting(p):
		return CommandResult.failure("no_merchant", Texts.t("ERR_NO_MERCHANT"))
	var def := content.find_merchant(p["merchant"])
	var price := def.sell_price_cents(item_id)
	var item := content.find_item(item_id)
	if price <= 0 or item == null:
		return CommandResult.failure("not_for_sale", Texts.t("ERR_NOT_FOR_SALE"))
	return PlayerActions.purchase(state, content, item, price)
