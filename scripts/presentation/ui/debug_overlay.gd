class_name DebugOverlay
extends Label
## Diagnóstico (F3, solo compilaciones de desarrollo). Se actualiza 4 veces por segundo
## y guarda los tiempos de fotograma en un buffer acotado (no escribe a disco).

const UPDATE_INTERVAL := 0.25
const BUFFER_SIZE := 240

var _frame_ms := PackedFloat32Array()
var _timer := 0.0


func _init() -> void:
	visible = false
	position = Vector2(16, 64)
	add_theme_font_size_override("font_size", 15)
	add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_frame_ms.append(delta * 1000.0)
	if _frame_ms.size() > BUFFER_SIZE:
		_frame_ms.remove_at(0)
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var median := sorted[sorted.size() / 2] if sorted.size() > 0 else 0.0
	var p95 := sorted[int(sorted.size() * 0.95)] if sorted.size() > 0 else 0.0
	var s := Game.state
	text = "\n".join([
		"FPS %d · frame mediana %.1f ms · p95 %.1f ms (%d muestras)" % [Engine.get_frames_per_second(), median, p95, sorted.size()],
		"draw calls %d · primitivas %d · objetos %d" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)],
		"nodos %d · memoria estática %.1f MB · VRAM %s" % [
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			_vram_text()],
		"tick %d · día %d · pausa %s · pendientes %d · atrasos %d" % [s.tick, s.current_day(), Game.is_paused(), Game.clock.pending_steps(), Game.clock.lag_frames],
		"paso %d µs · cierre %d µs · guardado %d µs" % [Game.last_step_usec, Game.last_close_usec, Game.last_save_usec],
		"actores vecinos %d · renderer %s" % [get_tree().get_node_count_in_group("neighbors"), ProjectSettings.get_setting("rendering/renderer/rendering_method")],
	])


func _vram_text() -> String:
	var v := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	return "N/D" if v <= 0.0 else "%.1f MB" % (v / 1048576.0)
