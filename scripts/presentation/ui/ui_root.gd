class_name UIRoot
extends CanvasLayer
## Coordina HUD y paneles. Abrir un panel libera el cursor, detiene al jugador y
## pausa el reloj administrativo; cerrarlo recupera la captura del mouse.

const SFX_CONFIRM := preload("res://assets/audio/ui_confirm.wav")
const SFX_ERROR := preload("res://assets/audio/ui_error.wav")
const AMBIENT := preload("res://assets/audio/ambient_wind.wav")

var player: PlayerController
var hud := Hud.new()
var dialogue := DialoguePanel.new()
var inspect := InspectPanel.new()
var desk := DeskPanel.new()
var report := ReportPanel.new()
var notebook := NotebookPanel.new()
var pause_menu := PauseMenu.new()
var debug_overlay := DebugOverlay.new()

var _active: GamePanel = null
var _dim := ColorRect.new()
var _center := CenterContainer.new()
var _sfx := AudioStreamPlayer.new()
var _ambient := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	for p: GamePanel in [dialogue, inspect, desk, report, notebook, pause_menu]:
		p.ui = self
		p.close_requested.connect(close_panel)
		_center.add_child(p)
	add_child(debug_overlay)

	_sfx.bus = &"Efectos"
	add_child(_sfx)
	_ambient.bus = &"Ambiente"
	_ambient.stream = AMBIENT
	_ambient.volume_db = -6.0
	add_child(_ambient)
	# El WAV se importa en bucle (edit/loop_mode=2 en su .import).
	_ambient.play()

	Game.day_closed.connect(_on_day_closed)
	Game.notice_posted.connect(post_notice)
	if Game.has_save():
		post_notice.call_deferred(Texts.t("MSG_SAVE_AVAILABLE"))
	post_notice.call_deferred(Texts.t("MSG_WELCOME"))


func bind_player(p: PlayerController) -> void:
	player = p
	player.focus_changed.connect(_on_focus_changed)
	player.interaction_requested.connect(_on_interaction)
	_capture_mouse()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _active == null:
			open_panel(pause_menu)
		elif not _active.handle_back():
			close_panel()
	elif event.is_action_pressed("notebook"):
		get_viewport().set_input_as_handled()
		if _active == notebook:
			close_panel()
		elif _active == null:
			open_panel(notebook)
	elif event.is_action_pressed("debug_overlay") and OS.is_debug_build():
		get_viewport().set_input_as_handled()
		debug_overlay.visible = not debug_overlay.visible


func _unhandled_input(event: InputEvent) -> void:
	# Recuperar la captura si la ventana la perdió (p. ej. tras alt-tab).
	if _active == null and event is InputEventMouseButton and event.pressed:
		_capture_mouse()


func open_panel(panel: GamePanel, args: Dictionary = {}) -> void:
	if _active != null and _active != panel:
		_active.on_close()
		_active.visible = false
	var first_open := _active == null
	_active = panel
	panel.visible = true
	_dim.visible = true
	hud.set_crosshair_visible(false)
	if first_open:
		Game.push_pause("ui")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if player != null:
			player.set_input_enabled(false)
	panel.on_open(args)


func close_panel() -> void:
	if _active == null:
		return
	_active.on_close()
	_active.visible = false
	_active = null
	_dim.visible = false
	hud.set_crosshair_visible(true)
	Game.pop_pause("ui")
	if player != null:
		player.set_input_enabled(true)
	_capture_mouse()


func active_panel() -> GamePanel:
	return _active


func open_report(rep: DayReport, return_to_desk: bool) -> void:
	open_panel(report, {"report": rep, "return_to_desk": return_to_desk})


func post_notice(text: String) -> void:
	hud.post_notice(text)


func play_feedback(ok: bool) -> void:
	_sfx.stream = SFX_CONFIRM if ok else SFX_ERROR
	_sfx.play()


func _capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_focus_changed(target: Interactable) -> void:
	hud.set_prompt("" if target == null else "[E] " + target.prompt_text())


func _on_interaction(target: Interactable) -> void:
	match target.kind:
		Interactable.Kind.DIALOGUE:
			open_panel(dialogue, {"target_id": target.target_id})
		Interactable.Kind.INSPECT:
			open_panel(inspect, {"target_id": target.target_id})
		Interactable.Kind.DESK:
			open_panel(desk, {})


## Aviso informativo que no pausa: la jornada terminó mientras se recorría el mapa.
func _on_day_closed(rep: DayReport) -> void:
	if _active == null:
		post_notice(Texts.t("MSG_DAY_CLOSED", {"day": rep.day}))
