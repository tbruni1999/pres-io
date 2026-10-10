class_name Weather
extends RefCounted
## Clima del día: sale del generador de la partida al cerrar la jornada anterior.
## Cambia cosas (sed, piques, fuego), pero nunca traba el progreso:
## la lluvia dura unas horas, no hay tormentas y nunca llueve dos días seguidos.

const SUN := "sun"
const CLOUDY := "cloudy"
const WIND := "wind"
const RAIN := "rain"
const KINDS := [SUN, CLOUDY, WIND, RAIN]
## Peso de cada clima en el sorteo (en el mismo orden que KINDS).
const WEIGHTS := [4, 3, 2, 2]


static func plan_day(state: GameState, content: GameContent, day: int) -> void:
	var camp := state.camp
	var b := content.balance
	var kind := SUN
	if day > 1:
		var total := 0
		for i in KINDS.size():
			if _allowed(KINDS[i], camp, b, day):
				total += WEIGHTS[i]
		var roll := state.rng.randi_range(0, total - 1)
		for i in KINDS.size():
			if not _allowed(KINDS[i], camp, b, day):
				continue
			if roll < WEIGHTS[i]:
				kind = KINDS[i]
				break
			roll -= WEIGHTS[i]
	camp.weather = kind
	camp.rain_start = -1
	camp.rain_end = -1
	if kind == RAIN:
		var tpd := state.ticks_per_day
		var day_start := (day - 1) * tpd
		var length := state.rng.randi_range(b.rain_min_ticks, b.rain_max_ticks)
		var latest := maxi(tpd / 5, DayTime.night_offset_ticks(state, content) - length)
		camp.rain_start = day_start + state.rng.randi_range(tpd / 5, latest)
		camp.rain_end = camp.rain_start + length
		camp.last_rain_day = day


static func _allowed(kind: String, camp: CampState, b: BalanceConfig, day: int) -> bool:
	if kind != RAIN:
		return true
	return day >= b.first_rain_day and camp.last_rain_day != day - 1


static func is_raining(state: GameState) -> bool:
	return state.camp.rain_start >= 0 and state.tick >= state.camp.rain_start and state.tick < state.camp.rain_end


## Multiplicador (puntos básicos) de la sed: con sol pega el calor; con lluvia casi no.
static func thirst_bp(state: GameState, content: GameContent) -> int:
	if is_raining(state):
		return content.balance.rain_thirst_bp
	if state.camp.weather == SUN:
		return content.balance.sun_thirst_bp
	return 10000


## Multiplicador (puntos básicos) de la espera del pique: nublado y con lluvia pican más.
static func bite_bp(state: GameState, content: GameContent) -> int:
	if is_raining(state):
		return content.balance.rain_bite_bp
	if state.camp.weather == CLOUDY:
		return content.balance.cloudy_bite_bp
	return 10000


## Con viento la leña dura menos.
static func fire_wood_ticks(state: GameState, content: GameContent) -> int:
	var t := content.balance.fire_wood_ticks
	if state.camp.weather == WIND:
		t = t * 10000 / content.balance.wind_fire_bp
	return maxi(1, t)
