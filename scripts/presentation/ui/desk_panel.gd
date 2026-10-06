class_name DeskPanel
extends GamePanel
## Escritorio de la oficina comunitaria: caja, obra disponible y cierre de jornada.
## Los botones emiten comandos a Game; nunca restan dinero por su cuenta.

const PROJECT_ID := "well_repair"

var _day_label: Label
var _treasury_box := VBoxContainer.new()
var _project_box := VBoxContainer.new()
var _feedback: Label
var _approve_button: Button
var _confirm_pending := false


func _init() -> void:
	super()
	custom_minimum_size = Vector2(900, 0)
	var header := HBoxContainer.new()
	var t := UIKit.title(Texts.t("DESK_TITLE"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	_day_label = UIKit.label("", 18, UIKit.COLOR_MUTED)
	header.add_child(_day_label)
	body.add_child(header)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	_treasury_box.custom_minimum_size = Vector2(340, 0)
	_treasury_box.add_theme_constant_override("separation", 6)
	_project_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_project_box.add_theme_constant_override("separation", 6)
	columns.add_child(_treasury_box)
	columns.add_child(VSeparator.new())
	columns.add_child(_project_box)
	body.add_child(columns)

	_feedback = UIKit.label("", 18, UIKit.COLOR_ACCENT, true)
	_feedback.custom_minimum_size = Vector2(840, 0)
	body.add_child(_feedback)
	body.add_child(HSeparator.new())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	var close_day := UIKit.button(Texts.t("DESK_CLOSE_DAY"), _on_close_day)
	close_day.tooltip_text = Texts.t("DESK_CLOSE_DAY_TOOLTIP")
	footer.add_child(close_day)
	var hint := UIKit.label(Texts.t("DESK_CLOSE_DAY_HINT"), 15, UIKit.COLOR_MUTED, true)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	footer.add_child(UIKit.button(Texts.t("DESK_LEAVE"), request_close))
	body.add_child(footer)


func on_open(args: Dictionary) -> void:
	_confirm_pending = false
	_feedback.text = String(args.get("message", ""))
	if not Game.treasury_changed.is_connected(refresh):
		Game.treasury_changed.connect(refresh)
		Game.project_state_changed.connect(_on_project_changed)
	refresh()


func on_close() -> void:
	if Game.treasury_changed.is_connected(refresh):
		Game.treasury_changed.disconnect(refresh)
		Game.project_state_changed.disconnect(_on_project_changed)


func handle_back() -> bool:
	if _confirm_pending:
		_confirm_pending = false
		_feedback.text = Texts.t("DESK_CONFIRM_CANCELLED")
		refresh()
		return true
	return false


func _on_project_changed(_id: String) -> void:
	refresh()


func refresh() -> void:
	var s := Game.state
	_day_label.text = Texts.t("HUD_DAY", {"day": s.current_day()}) + " · " + Texts.t("HUD_DAY_PROGRESS", {"pct": s.day_progress_bp() / 100})
	_build_treasury(s)
	_build_project(s)


func _build_treasury(s: GameState) -> void:
	UIKit.clear(_treasury_box)
	_treasury_box.add_child(UIKit.section(Texts.t("DESK_TREASURY")))
	_treasury_box.add_child(UIKit.row(Texts.t("ROW_CASH"), Money.format(s.treasury.cash_cents)))
	_treasury_box.add_child(UIKit.row(Texts.t("ROW_AVAILABLE"), Money.format(s.treasury.available_cents()), UIKit.COLOR_GOOD))
	_treasury_box.add_child(UIKit.label(Texts.t("DESK_TREASURY_NOTE"), 14, UIKit.COLOR_MUTED, true))
	_treasury_box.add_child(HSeparator.new())
	_treasury_box.add_child(UIKit.section(Texts.t("DESK_LEDGER")))
	var entries := s.treasury.recent_entries(5)
	if entries.is_empty():
		_treasury_box.add_child(UIKit.label(Texts.t("DESK_LEDGER_EMPTY"), 16, UIKit.COLOR_MUTED))
	for e in entries:
		_treasury_box.add_child(UIKit.row(
			Texts.t("LEDGER_LINE", {"day": e["day"], "reason": Texts.t(e["reason_key"])}),
			"-" + Money.format(int(e["amount_cents"])), UIKit.COLOR_BAD))
	_treasury_box.add_child(UIKit.row(Texts.t("ROW_OPENING"), Money.format(s.treasury.opening_cents), UIKit.COLOR_MUTED))


func _build_project(s: GameState) -> void:
	UIKit.clear(_project_box)
	var def := Game.content.find_project(PROJECT_ID)
	var p := s.get_project(PROJECT_ID)
	var day := s.current_day()
	var cap_now := Simulation.water_capacity(s, Game.content, day)
	var pop := s.settlement.population
	_project_box.add_child(UIKit.section(Texts.t("DESK_PROJECTS")))
	_project_box.add_child(UIKit.label(Texts.t(def.name_key), 22, UIKit.COLOR_TEXT))
	_project_box.add_child(UIKit.label(Texts.t(def.description_key), 16, UIKit.COLOR_MUTED, true))
	_project_box.add_child(UIKit.row(Texts.t("ROW_COST"), Money.format(def.cost_cents())))
	_project_box.add_child(UIKit.row(Texts.t("ROW_DURATION"), Texts.t("VAL_DURATION", {"days": def.duration_days})))
	_project_box.add_child(UIKit.row(Texts.t("ROW_BENEFIT"), Texts.t("VAL_WATER_BENEFIT", {
		"before": s.settlement.base_water_capacity,
		"after": def.capacity_after,
		"cov_before": Money.format_bp_percent(Simulation.coverage_bp(s.settlement.base_water_capacity, pop)),
		"cov_after": Money.format_bp_percent(Simulation.coverage_bp(def.capacity_after, pop)),
	}), UIKit.COLOR_GOOD))
	_project_box.add_child(UIKit.label(Texts.t(def.benefit_key), 15, UIKit.COLOR_MUTED, true))

	_approve_button = null
	match p.status:
		ProjectState.AVAILABLE:
			var after := s.treasury.available_cents() - def.cost_cents()
			_project_box.add_child(UIKit.row(Texts.t("ROW_CASH_AFTER"), Money.format(maxi(after, 0)) if after >= 0 else Texts.t("VAL_NOT_ENOUGH"),
				UIKit.COLOR_TEXT if after >= 0 else UIKit.COLOR_BAD))
			_project_box.add_child(UIKit.row(Texts.t("ROW_STATUS"), Texts.t("STATUS_AVAILABLE")))
			var text := Texts.t("DESK_CONFIRM_APPROVE", {"cost": Money.format(def.cost_cents())}) if _confirm_pending else Texts.t("DESK_APPROVE")
			_approve_button = UIKit.button(text, _on_approve)
			_project_box.add_child(_approve_button)
		ProjectState.UNDER_CONSTRUCTION:
			_project_box.add_child(UIKit.row(Texts.t("ROW_STATUS"), Texts.t("STATUS_UNDER_CONSTRUCTION", {"day": p.completion_day}), UIKit.COLOR_ACCENT))
			_project_box.add_child(UIKit.label(Texts.t("DESK_WORKS_NOTE", {"day": p.completion_day, "next_day": p.completion_day + 1}), 15, UIKit.COLOR_MUTED, true))
		ProjectState.COMPLETED:
			_project_box.add_child(UIKit.row(Texts.t("ROW_STATUS"), Texts.t("STATUS_COMPLETED", {"day": p.completed_day}), UIKit.COLOR_GOOD))
	_project_box.add_child(UIKit.row(Texts.t("ROW_WATER_TODAY"), Texts.t("VAL_WATER_TODAY", {
		"capacity": cap_now, "population": pop,
		"coverage": Money.format_bp_percent(Simulation.coverage_bp(cap_now, pop)),
	})))


func _on_approve() -> void:
	# Primer clic: pedir confirmación mostrando el costo. Segundo clic: emitir el comando.
	if not _confirm_pending:
		_confirm_pending = true
		_feedback.text = Texts.t("DESK_CONFIRM_HINT")
		refresh()
		_approve_button.grab_focus()
		return
	_confirm_pending = false
	var result := Game.approve_project(PROJECT_ID)
	_feedback.text = result.message
	_feedback.add_theme_color_override("font_color", UIKit.COLOR_GOOD if result.ok else UIKit.COLOR_BAD)
	ui.play_feedback(result.ok)
	refresh()


func _on_close_day() -> void:
	_confirm_pending = false
	var report := Game.close_current_day()
	var autosave := ""
	if Game.last_autosave != null:
		autosave = Texts.t("MSG_AUTOSAVED") if Game.last_autosave.ok else Game.last_autosave.message
	ui.open_panel(ui.report, {"report": report, "return_to_desk": true, "autosave": autosave})
