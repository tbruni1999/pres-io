class_name Neighbors
extends RefCounted
## Los locos que se van instalando en carpa, de a uno, atraídos por algo.
## No cobran: están porque quieren. Cada uno ayuda en algo y trae un problema (con vos).
##
## Beto: lo trae el olor del ahumadero. Mantiene el fogón prendido todo el día
## (con TU leña, lo necesites o no) y cobra el "impuesto Beto": un ahumado por día.
## Salim: lo trae el movimiento del camino (cartel + tres paradas con venta en un día).
## Vende lo que el camino no trae (sal, cinta, sombrilla), con "inflación" por capítulo.
## Problema: megáfono de 6 a 9. Con su carpa en el lago espanta los peces; en otro lado te despierta.
## Raúl "Antena": lo traen las luces del lago (dos capítulos vistos). Cada día anota en su
## pizarrón el clima, la lluvia, quién pasa y a qué hora, y el antojo. Problema: sale a
## "escanear" a los comerciantes y se van antes (más seguido cuanto más cerca del camino).

## Dónde puede armar la carpa (el jugador elige).
const SPOTS := ["lake", "back", "road"]
## Qué atrae a cada uno: un hecho del jugador.
const ATTRACTED_BY := {"beto": "smoked_once", "salim": "busy_road", "raul": "lake_lights_2"}
## Probabilidad (puntos básicos) de que Raúl salga a escanear según dónde está su carpa.
const RAUL_SCAN_BP := {"road": 10000, "lake": 5000, "back": 1500}
## Lo que vende Salim: precio base en UC (sube 1 cada 2 capítulos, hasta +5).
const SALIM_STOCK := {"salt": 10, "tape": 20, "umbrella": 80}
## Megáfono de Salim: de 06:00 a 09:00 (80 pasos de la jornada).
const MEGAPHONE_TICKS := 80
const EPISODES := 10


static func is_present(state: GameState, id: String) -> bool:
	return state.camp.neighbors.has(id)


## Llegó y ya eligió lugar para la carpa.
static func is_living(state: GameState, id: String) -> bool:
	return is_present(state, id) and not String(state.camp.neighbors[id]["spot"]).is_empty()


static func living_count(state: GameState) -> int:
	var n := 0
	for id in state.camp.neighbors:
		if is_living(state, id):
			n += 1
	return n


## Al cerrar la jornada: llega a lo sumo uno por día, si ya lo atrajo algo.
static func check_arrivals(state: GameState, day: int) -> String:
	var ids := ATTRACTED_BY.keys()
	ids.sort()
	for id in ids:
		if not is_present(state, id) and _attracted(state, id):
			state.camp.neighbors[id] = {"spot": "", "since": day + 1, "talked_day": 0, "ep": 0}
			return id
	return ""


static func _attracted(state: GameState, id: String) -> bool:
	# Las luces ya vistas antes de que existiera Raúl también cuentan.
	if id == "raul" and state.camp.night_thread >= 2:
		return true
	return state.has_fact("player", ATTRACTED_BY[id])


static func place(state: GameState, id: String, spot: String) -> CommandResult:
	if not is_present(state, id):
		return CommandResult.failure("unknown_neighbor", Texts.t("ERR_NO_NEIGHBOR"))
	if not SPOTS.has(spot):
		return CommandResult.failure("bad_spot", Texts.t("ERR_BAD_SPOT"))
	if is_living(state, id):
		return CommandResult.failure("already_placed", Texts.t("ERR_ALREADY_PLACED"))
	for other in state.camp.neighbors:
		if String(state.camp.neighbors[other]["spot"]) == spot:
			return CommandResult.failure("spot_taken", Texts.t("ERR_SPOT_TAKEN"))
	state.camp.neighbors[id]["spot"] = spot
	return CommandResult.success(Texts.t("MSG_%s_PLACED" % id.to_upper()))


## Charla: un capítulo nuevo por día; si ya charlaron hoy, una frase suelta.
## Devuelve la clave del texto ("" si no está).
static func talk(state: GameState, id: String) -> String:
	if not is_present(state, id):
		return ""
	var n: Dictionary = state.camp.neighbors[id]
	var day := state.current_day()
	if int(n["talked_day"]) == day or int(n["ep"]) >= EPISODES:
		return ""
	n["talked_day"] = day
	n["ep"] = int(n["ep"]) + 1
	return "%s_EP_%d" % [id.to_upper(), int(n["ep"])]


static func spot_of(state: GameState, id: String) -> String:
	return String(state.camp.neighbors[id]["spot"]) if is_present(state, id) else ""


## Beto prende el fogón con tu leña cada vez que se apaga (de día y si no llueve encima).
static func tend_fire(state: GameState, content: GameContent) -> bool:
	if not is_living(state, "beto") or not state.camp.has_building("fire") or Simulation.fire_lit(state):
		return false
	if state.camp.wood < 1 or DayTime.is_night(state, content) or not Simulation.fire_sheltered_or_dry(state):
		return false
	state.camp.wood -= 1
	state.camp.fire_until = state.tick + Weather.fire_wood_ticks(state, content)
	return true


## El impuesto Beto: al cerrar se come un ahumado de tu mochila, si hay.
static func beto_tax(state: GameState) -> int:
	if not is_living(state, "beto"):
		return 0
	for item_id in ["fish_small_smoked", "fish_big_smoked"]:
		if state.player.remove_item(item_id, 1):
			return 1
	return 0


# --- Salim ---------------------------------------------------------------------

static func salim_price_cents(state: GameState, item_id: String) -> int:
	var ep := int(state.camp.neighbors["salim"]["ep"]) if is_present(state, "salim") else 0
	return Money.from_units(int(SALIM_STOCK[item_id]) + mini(5, ep / 2))


## Comprarle a Salim, al contado. La cinta arregla la caña al toque (no va a la mochila).
static func salim_buy(state: GameState, content: GameContent, item_id: String) -> CommandResult:
	if not is_living(state, "salim"):
		return CommandResult.failure("unknown_neighbor", Texts.t("ERR_NO_NEIGHBOR"))
	if not SALIM_STOCK.has(item_id):
		return CommandResult.failure("not_for_sale", Texts.t("ERR_NOT_FOR_SALE"))
	var price := salim_price_cents(state, item_id)
	var pl := state.player
	if item_id == "tape":
		var rod := PlayerActions.best_rod(state, content)
		if rod == null or rod.durability <= 0:
			return CommandResult.failure("no_rod", Texts.t("ERR_NO_ROD"))
		var uses := int(pl.tool_wear.get(rod.id, rod.durability))
		if uses >= rod.durability:
			return CommandResult.failure("rod_fine", Texts.t("ERR_ROD_FINE"))
		if price > pl.wallet_cents:
			return CommandResult.failure("insufficient_funds", Texts.t("ERR_MISSING_MONEY", {"missing": Money.format(price - pl.wallet_cents)}))
		pl.spend(price)
		pl.tool_wear[rod.id] = mini(rod.durability, uses + content.balance.tape_uses)
		return CommandResult.success(Texts.t("MSG_TAPE_FIXED", {"name": Texts.t(rod.name_key), "n": pl.tool_wear[rod.id]}))
	return PlayerActions.purchase(state, content, content.find_item(item_id), price)


## Megáfono de la mañana: con la carpa en el lago, pican menos de 6 a 9.
static func megaphone_scares_fish(state: GameState) -> bool:
	return spot_of(state, "salim") == "lake" and state.tick % state.ticks_per_day < MEGAPHONE_TICKS


## Al cerrar: si su carpa no está en el lago, el megáfono te despierta (arrancás con hambre).
static func megaphone_wakes(state: GameState, content: GameContent) -> bool:
	if not is_living(state, "salim") or spot_of(state, "salim") == "lake":
		return false
	state.player.hunger_bp = maxi(0, state.player.hunger_bp - content.balance.megaphone_hunger_bp)
	return true


# --- Raúl -------------------------------------------------------------------------

## ¿Sale a escanear al comerciante que acaba de parar? (generador de la partida)
static func raul_scans(state: GameState) -> bool:
	if not is_living(state, "raul"):
		return false
	return state.rng.randi_range(0, 9999) < int(RAUL_SCAN_BP.get(spot_of(state, "raul"), 0))


## Pizarrón de Raúl: lo que va a pasar hoy (clima, lluvia, comerciantes y antojo).
## [{key, params}] para que la presentación lo traduzca.
static func raul_board(state: GameState, content: GameContent) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c := state.camp
	out.append({"key": "RAUL_BOARD_WEATHER", "params": {"weather": Texts.t("WEATHER_" + c.weather.to_upper())}})
	if c.rain_start >= 0:
		out.append({"key": "RAUL_BOARD_RAIN", "params": {
			"from": _clock(state, content, c.rain_start), "to": _clock(state, content, c.rain_end)}})
	for p in c.passes:
		if p["status"] == Merchants.SCHEDULED:
			out.append({"key": "RAUL_BOARD_PASS", "params": {
				"name": Texts.t(content.find_merchant(p["merchant"]).name_key), "time": _clock(state, content, int(p["start"]))}})
	if not c.craving.is_empty():
		out.append({"key": "RAUL_BOARD_CRAVING", "params": {
			"name": Texts.t(content.find_merchant(c.craving["merchant"]).name_key),
			"item": Texts.t(content.find_item(c.craving["item"]).name_key)}})
	return out


static func _clock(state: GameState, content: GameContent, tick: int) -> String:
	var b := content.balance
	var m := b.day_start_minute + float(tick % state.ticks_per_day) * (b.day_end_minute - b.day_start_minute) / state.ticks_per_day
	return DayTime.format_clock(m)
