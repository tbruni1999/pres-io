class_name Neighbors
extends RefCounted
## Los locos que se van instalando en carpa, de a uno, atraídos por algo.
## No cobran: están porque quieren. Cada uno ayuda en algo y trae un problema (con vos).
##
## Beto: lo trae el olor del ahumadero. Mantiene el fogón prendido todo el día
## (con TU leña, lo necesites o no) y cobra el "impuesto Beto": un ahumado por día.

## Dónde puede armar la carpa (el jugador elige).
const SPOTS := ["lake", "back", "road"]
## Qué atrae a cada uno: un hecho del jugador.
const ATTRACTED_BY := {"beto": "smoked_once"}
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
		if not is_present(state, id) and state.has_fact("player", ATTRACTED_BY[id]):
			state.camp.neighbors[id] = {"spot": "", "since": day + 1, "talked_day": 0, "ep": 0}
			return id
	return ""


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
