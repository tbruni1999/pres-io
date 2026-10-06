class_name UIRoot
extends CanvasLayer
## Coordina HUD, paneles y actividades.
## Paneles (comerciar, fogón, mochila, informe, pausa): liberan el cursor y pausan el reloj.
## Actividades (pescar, martillar, talar, mantener E): frenan al jugador pero el tiempo corre.

signal wake_at_home

const SFX := {
	"ok": preload("res://assets/audio/ui_confirm.wav"),
	"error": preload("res://assets/audio/ui_error.wav"),
	"bite": preload("res://assets/audio/ui_confirm.wav"),
	"hit": preload("res://assets/audio/footstep_dirt.wav"),
}
const AMBIENT := preload("res://assets/audio/ambient_wind.wav")

var player: PlayerController
var road: MerchantRoad
var hud := Hud.new()
var skill_check := SkillCheck.new()
var trade := TradePanel.new()
var fire := FirePanel.new()
var bag := BagPanel.new()
var report := ReportPanel.new()
var pause_menu := PauseMenu.new()
var debug_overlay := DebugOverlay.new()

var _active: GamePanel = null
var _activity: Activity = null
var _context: Dictionary = {}
var _dim := ColorRect.new()
var _center := CenterContainer.new()
var _sfx := AudioStreamPlayer.new()
var _ambient := AudioStreamPlayer.new()
## Cosmético: qué frase dice cada NPC no consume el generador de la partida.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var check_box := CenterContainer.new()
	check_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	check_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	check_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	check_box.position.y -= 110
	check_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check_box.add_child(skill_check)
	add_child(check_box)
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	for p: GamePanel in [trade, fire, bag, report, pause_menu]:
		p.ui = self
		p.close_requested.connect(close_panel)
		_center.add_child(p)
	add_child(debug_overlay)

	_sfx.bus = &"Efectos"
	add_child(_sfx)
	_ambient.bus = &"Ambiente"
	_ambient.stream = AMBIENT
	_ambient.volume_db = -8.0
	add_child(_ambient)
	# El WAV se importa en bucle (edit/loop_mode=2 en su .import).
	_ambient.play()

	Game.day_closed.connect(_on_day_closed)
	Game.fainted.connect(_on_fainted)
	Game.notice_posted.connect(post_notice)
	Game.state_replaced.connect(cancel_activity)
	if Game.has_save():
		post_notice.call_deferred(Texts.t("MSG_SAVE_AVAILABLE"))
	post_notice.call_deferred(Texts.t("MSG_WELCOME"))


func bind(p: PlayerController, merchant_road: MerchantRoad) -> void:
	player = p
	road = merchant_road
	road.merchant_arriving.connect(func(def: MerchantDefinition) -> void:
		post_notice(Texts.t("MSG_MERCHANT_COMING", {"name": Texts.t(def.name_key)})))
	road.merchant_passed.connect(func(def: MerchantDefinition) -> void:
		post_notice("%s %s" % [Texts.t("MSG_MERCHANT_PASSED", {"name": TradePanel._cap(Texts.t(def.name_key))}), quip(def.lines_prefix, "PASS")]))
	_capture_mouse()


# --- Entrada ----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _activity != null:
			cancel_activity()
		elif _active == null:
			open_panel(pause_menu)
		elif not _active.handle_back():
			close_panel()
	elif event.is_action_pressed("notebook"):
		get_viewport().set_input_as_handled()
		if _active == bag:
			close_panel()
		elif _active == null and _activity == null:
			open_panel(bag)
	elif event.is_action_pressed("interact") and _active == null:
		get_viewport().set_input_as_handled()
		if _activity != null:
			_activity.on_interact()
		else:
			_use_context()
	elif event.is_action_pressed("debug_overlay") and OS.is_debug_build():
		get_viewport().set_input_as_handled()
		debug_overlay.visible = not debug_overlay.visible


func _unhandled_input(event: InputEvent) -> void:
	if _active == null and event is InputEventMouseButton and event.pressed:
		_capture_mouse()


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	if _active != null or _activity != null:
		_context = {}
	else:
		_context = _find_context()
	hud.set_prompt("" if _context.is_empty() else "[E] " + String(_context["text"]))


func _process(delta: float) -> void:
	if _activity != null:
		_activity.process(delta)
		if _activity != null:
			hud.set_status(_activity.status_text(), _activity.progress())


# --- Contexto: qué se puede hacer ahora --------------------------------------------

## Comerciantes primero (pasan rápido), después lo que se mira con la mira.
func _find_context() -> Dictionary:
	var m := road.context_for(player.global_position) if road != null else {}
	if not m.is_empty():
		return m
	var target := player.current_focus()
	if target == null:
		return {}
	var s := Game.state
	var c := Game.content
	match target.kind:
		Interactable.Kind.FISH:
			return {"kind": "fish", "spot": target.target_id, "text": Texts.t("ACTION_FISH_DOCK" if target.target_id == "dock" else "ACTION_FISH")}
		Interactable.Kind.LAKE_WATER:
			return {"kind": "lake", "text": Texts.t("ACTION_DRINK_LAKE")}
		Interactable.Kind.SLEEP:
			return {"kind": "sleep", "text": Texts.t("ACTION_SLEEP")}
		Interactable.Kind.BRANCHES:
			if s.camp.branches_taken.has(target.target_id):
				return {"kind": "none", "text": Texts.t("ACTION_BRANCHES_GONE")}
			return {"kind": "branches", "id": target.target_id, "text": Texts.t("ACTION_BRANCHES")}
		Interactable.Kind.TREE:
			if not PlayerActions.tree_available(s, c, target.target_id):
				return {"kind": "none", "text": Texts.t("ACTION_TREE_GROWING")}
			if not s.player.has_tool("axe"):
				return {"kind": "none", "text": Texts.t("ACTION_CHOP_NEED_AXE")}
			return {"kind": "chop", "id": target.target_id, "text": Texts.t("ACTION_CHOP")}
		Interactable.Kind.BUILD:
			var b := c.find_building(target.target_id)
			if s.camp.has_building(b.id):
				return {"kind": "fire", "text": Texts.t("ACTION_FIRE")} if b.id == "fire" else {}
			var cost := Texts.t("COST_WOOD", {"n": b.wood}) if b.money_uc <= 0 else Texts.t("COST_WOOD_MONEY", {"n": b.wood, "money": Money.format(b.money_cents())})
			return {"kind": "build", "id": b.id, "text": Texts.t("ACTION_BUILD", {"name": Texts.t(b.name_key), "cost": cost})}
	return {}


func _use_context() -> void:
	var ctx := _context
	match String(ctx.get("kind", "")):
		"hail":
			var r := Game.hail_merchant(int(ctx["pass_id"]))
			if r.ok:
				post_notice("%s: «%s»" % [TradePanel._cap(String(ctx["name"])), quip(String(ctx["prefix"]), "GREET")])
			else:
				post_notice(r.message)
		"trade":
			open_panel(trade, {"pass_id": ctx["pass_id"]})
		"fish":
			var f := Activities.Fishing.new()
			f.spot = String(ctx["spot"])
			start_activity(f)
		"lake":
			_hold(1.5, func() -> void: post_notice(Game.drink_lake().message))
		"branches":
			var id := String(ctx["id"])
			_hold(2.0, func() -> void: post_notice(Game.gather_branches(id).message))
		"chop":
			var tree_id := String(ctx["id"])
			var chop := Activities.Strikes.new()
			chop.total = 3
			chop.zone_bp = 2200
			chop.speed = 1.1
			chop.retry_on_miss = false
			chop.label_key = "CHOP_SWING"
			chop.on_done = func(ok: bool) -> void:
				var r := Game.chop_tree(tree_id, ok)
				post_notice(r.message)
			start_activity(chop)
		"build":
			var bid := String(ctx["id"])
			var check := PlayerActions.can_build(Game.state, Game.content, bid)
			if not check.ok:
				post_notice(check.message)
				play_feedback(false)
				return
			var hammer := Activities.Strikes.new()
			hammer.total = Game.content.find_building(bid).checks
			hammer.zone_bp = 2600
			hammer.speed = 0.9
			hammer.on_done = func(_ok: bool) -> void:
				var r := Game.build(bid)
				post_notice(r.message)
				play_feedback(r.ok)
			start_activity(hammer)
		"fire":
			open_panel(fire)
		"sleep":
			cancel_activity()
			var rep := Game.sleep()
			open_panel(report, {"report": rep})


func _hold(seconds: float, on_done: Callable) -> void:
	var h := Activities.Hold.new()
	h.seconds = seconds
	h.on_done = on_done
	start_activity(h)


# --- Actividades --------------------------------------------------------------------

func start_activity(a: Activity) -> void:
	cancel_activity()
	_activity = a
	a.ui = self
	a.finished.connect(_on_activity_finished.bind(a))
	player.set_input_enabled(false)
	hud.set_crosshair_visible(false)
	a.begin()


func cancel_activity() -> void:
	if _activity != null:
		_activity.cancel()


func current_activity() -> Activity:
	return _activity


func _on_activity_finished(a: Activity) -> void:
	if a != _activity:
		return
	_activity = null
	skill_check.stop()
	hud.set_status("", -1.0)
	if _active == null:
		player.set_input_enabled(true)
		hud.set_crosshair_visible(true)


# --- Paneles --------------------------------------------------------------------------

func open_panel(panel: GamePanel, args: Dictionary = {}) -> void:
	cancel_activity()
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
	var closing := _active
	_active = null
	closing.on_close()
	closing.visible = false
	_dim.visible = false
	hud.set_crosshair_visible(true)
	Game.pop_pause("ui")
	if player != null:
		player.set_input_enabled(true)
	_capture_mouse()


func active_panel() -> GamePanel:
	return _active


func context() -> Dictionary:
	return _context


# --- Utilidades ----------------------------------------------------------------------

func post_notice(text: String) -> void:
	hud.post_notice(text)


func play_feedback(ok: bool) -> void:
	play_sfx("ok" if ok else "error")


func play_sfx(id: String) -> void:
	_sfx.stream = SFX.get(id, SFX["ok"])
	_sfx.pitch_scale = _rng.randf_range(0.95, 1.05) if id == "hit" else 1.0
	_sfx.play()


## Frase al azar de un NPC: PREFIJO_TIPO_1, _2, ... (las que existan en strings.csv).
func quip(prefix: String, kind: String) -> String:
	var options: PackedStringArray = []
	for i in range(1, 10):
		var key := "%s_%s_%d" % [prefix, kind, i]
		var text := Texts.t(key)
		if text == key:
			break
		options.append(text)
	return "" if options.is_empty() else options[_rng.randi_range(0, options.size() - 1)]


func _capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_day_closed(rep: DayReport) -> void:
	if _active == null and not rep.fainted and Game.is_paused() == false:
		post_notice(Texts.t("MSG_DAY_CLOSED", {"day": rep.day}))


func _on_fainted(rep: DayReport) -> void:
	cancel_activity()
	if _active != null:
		close_panel()
	wake_at_home.emit()
	open_panel(report, {"report": rep})
