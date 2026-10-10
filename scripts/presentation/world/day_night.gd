class_name DayNight
extends Node
## Luz del día según la hora del juego (DayTime): sol que sale y se pone, atardecer
## cálido, noche con luna y faroles. Solo presentación: no cambia reglas.
## Se actualiza 10 veces por segundo (cambiar el cielo cada fotograma es caro).

const UPDATE_INTERVAL := 0.1
const SUNRISE := 300.0
const SUNSET := 1275.0
const MAX_ELEVATION := 62.0

@export var sun_path: NodePath = ^"../Sun"
@export var environment_path: NodePath = ^"../WorldEnvironment"
@export var day_energy: float = 0.95
@export var moon_energy: float = 0.14

## 0 = pleno día, 1 = noche cerrada. Lo usan los faroles y las pruebas.
var nightness: float = 0.0
## 0 = cielo limpio, 1 = cerrado de lluvia. Sigue al clima del día de a poco.
var overcast: float = 0.0
var _base_fog := 0.0
var _timer := 0.0
var _sky: ProceduralSkyMaterial
var _env: Environment
var sun: DirectionalLight3D


func _ready() -> void:
	sun = get_node(sun_path) as DirectionalLight3D
	_env = (get_node(environment_path) as WorldEnvironment).environment
	if _env.sky != null:
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_base_fog = _env.fog_density
	overcast = _overcast_target()
	Game.state_replaced.connect(func() -> void:
		overcast = _overcast_target()
		apply_now())
	apply_now()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		apply_now()


func _overcast_target() -> float:
	if Weather.is_raining(Game.state):
		return 0.8
	match Game.state.camp.weather:
		Weather.CLOUDY:
			return 0.45
		Weather.WIND:
			return 0.15
		Weather.RAIN:
			return 0.3
	return 0.0


func apply_now() -> void:
	overcast = move_toward(overcast, _overcast_target(), UPDATE_INTERVAL * 0.25)
	var frac := 0.0 if Game.is_paused() else Game.clock.step_fraction()
	apply_minute(DayTime.minute_of_day(Game.state, Game.content, frac))


func apply_minute(m: float) -> void:
	var day_t := clampf((m - SUNRISE) / (SUNSET - SUNRISE), 0.0, 1.0)
	var elevation := sin(PI * day_t) * MAX_ELEVATION
	var daylight := clampf(elevation / 12.0, 0.0, 1.0)
	var golden := 1.0 - clampf(elevation / 25.0, 0.0, 1.0)
	nightness = 1.0 - daylight
	if daylight > 0.0:
		sun.rotation_degrees = Vector3(-maxf(elevation, 4.0), lerpf(-80.0, 100.0, day_t), 0.0)
		sun.light_color = Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.62, 0.38), golden)
		sun.light_energy = lerpf(moon_energy, day_energy, daylight)
	else:
		sun.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
		sun.light_color = Color(0.55, 0.63, 0.88)
		sun.light_energy = moon_energy
	var day_ambient := Color(0.62, 0.66, 0.74)
	var night_ambient := Color(0.22, 0.27, 0.42)
	_env.ambient_light_color = night_ambient.lerp(day_ambient, daylight)
	_env.ambient_light_energy = lerpf(0.22, 0.55, daylight)
	var horizon_day := Color(0.78, 0.76, 0.7)
	var horizon := horizon_day.lerp(Color(0.92, 0.58, 0.36), golden * daylight).lerp(Color(0.07, 0.08, 0.14), nightness)
	var top := Color(0.36, 0.55, 0.78).lerp(Color(0.02, 0.03, 0.08), nightness)
	# Nublado: menos sol, cielo gris y más niebla.
	if overcast > 0.0:
		sun.light_energy *= 1.0 - 0.6 * overcast
		var gray := Color(0.52, 0.55, 0.58).lerp(Color(0.05, 0.06, 0.08), nightness)
		top = top.lerp(gray, overcast * 0.85)
		horizon = horizon.lerp(gray.lightened(0.1), overcast * 0.75)
	_env.fog_density = _base_fog + overcast * 0.01
	if _sky != null:
		_sky.sky_top_color = top
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon
		_sky.ground_bottom_color = Color(0.35, 0.3, 0.24).lerp(Color(0.03, 0.03, 0.04), nightness)
	_env.fog_light_color = horizon
	for light in get_tree().get_nodes_in_group("night_lights"):
		var l := light as Light3D
		if not l.has_meta("base_energy"):
			l.set_meta("base_energy", l.light_energy)
		var e := float(l.get_meta("base_energy")) * (0.25 + 0.75 * nightness)
		l.set_meta("night_energy", e)
		l.light_energy = e
