class_name SkillCheck
extends Control
## Skillcheck: una aguja va y viene sobre una barra; hay que apretar E dentro de la zona.
## El centro de la zona cuenta como "perfecto". Si no se aprieta en 3 pasadas, falla.
## Se reutiliza para pescar, talar y martillar.

signal resolved(result: String)

const HIT := "hit"
const PERFECT := "perfect"
const MISS := "miss"
const MAX_SWEEPS := 3.0
const PERFECT_FRACTION := 0.25

var active := false
var _zone_start := 0.0
var _zone_width := 0.2
var _speed := 1.0
var _t := 0.0
## Cosmético: dónde cae la zona no consume el generador de la partida.
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	custom_minimum_size = Vector2(440, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## zone_bp: ancho de la zona (10000 = toda la barra). speed: barras por segundo.
func start(zone_bp: int, speed: float) -> void:
	_zone_width = clampf(zone_bp / 10000.0, 0.05, 0.9)
	_zone_start = _rng.randf_range(0.15, 0.95 - _zone_width)
	_speed = maxf(0.2, speed)
	_t = _rng.randf_range(0.0, 0.1)
	active = true
	visible = true
	queue_redraw()


func stop() -> void:
	active = false
	visible = false


func needle() -> float:
	var phase := fposmod(_t, 2.0)
	return phase if phase <= 1.0 else 2.0 - phase


func press() -> String:
	if not active:
		return ""
	var n := needle()
	var result := MISS
	if n >= _zone_start and n <= _zone_start + _zone_width:
		var center := _zone_start + _zone_width * 0.5
		result = PERFECT if absf(n - center) <= _zone_width * PERFECT_FRACTION * 0.5 else HIT
	_finish(result)
	return result


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta * _speed
	if _t >= MAX_SWEEPS * 2.0:
		_finish(MISS)
	queue_redraw()


func _finish(result: String) -> void:
	stop()
	resolved.emit(result)


func _draw() -> void:
	if not active:
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(_zone_start * w, 2, _zone_width * w, h - 4), Color(0.35, 0.75, 0.4, 0.95))
	var pw := _zone_width * PERFECT_FRACTION
	var pc := _zone_start + _zone_width * 0.5
	draw_rect(Rect2((pc - pw * 0.5) * w, 2, pw * w, h - 4), Color(0.95, 0.85, 0.3, 1.0))
	var x := needle() * w
	draw_rect(Rect2(x - 2, -6, 4, h + 12), Color.WHITE)
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.5), false, 2.0)
