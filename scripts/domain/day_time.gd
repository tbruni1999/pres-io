class_name DayTime
extends RefCounted
## Hora del día derivada del tick. La jornada va de day_start_minute (06:00) a
## day_end_minute (24:00); la noche empieza en night_minute. Dormir salta a la mañana.
## No depende de la hora del equipo.


static func minute_of_day(state: GameState, content: GameContent, fraction: float = 0.0) -> float:
	var b := content.balance
	var span := float(b.day_end_minute - b.day_start_minute)
	var progress := (float(state.tick % state.ticks_per_day) + fraction) / float(state.ticks_per_day)
	return float(b.day_start_minute) + span * progress


static func is_night(state: GameState, content: GameContent) -> bool:
	return minute_of_day(state, content) >= float(content.balance.night_minute)


## Tick (dentro de la jornada) en que empieza la noche.
static func night_offset_ticks(state: GameState, content: GameContent) -> int:
	var b := content.balance
	return (b.night_minute - b.day_start_minute) * state.ticks_per_day / maxi(1, b.day_end_minute - b.day_start_minute)


## Convierte pasos administrativos a minutos de juego.
static func ticks_to_minutes(state: GameState, content: GameContent, ticks: int) -> int:
	var b := content.balance
	return ticks * (b.day_end_minute - b.day_start_minute) / state.ticks_per_day


static func format_clock(minute: float) -> String:
	var m := int(minute) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]
