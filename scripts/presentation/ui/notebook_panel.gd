class_name NotebookPanel
extends GamePanel
## Libreta (Tab): objetivos derivados del estado y resultados recientes.

var _content := VBoxContainer.new()


func _init() -> void:
	super()
	custom_minimum_size = Vector2(620, 0)
	_content.add_theme_constant_override("separation", 6)
	body.add_child(_content)
	body.add_child(HSeparator.new())
	body.add_child(UIKit.button(Texts.t("UI_CLOSE"), request_close))


func on_open(_args: Dictionary) -> void:
	UIKit.clear(_content)
	var s := Game.state
	_content.add_child(UIKit.title(Texts.t("NOTEBOOK_TITLE", {"day": s.current_day()})))
	_content.add_child(UIKit.section(Texts.t("NOTEBOOK_OBJECTIVES")))
	for o in objectives(s):
		var done: bool = o["done"]
		var mark := "[x] " if done else "[ ] "
		_content.add_child(UIKit.label(mark + Texts.t(o["key"]), 18, UIKit.COLOR_MUTED if done else UIKit.COLOR_TEXT, true))
	_content.add_child(HSeparator.new())
	var rep := s.last_report()
	if rep == null:
		_content.add_child(UIKit.label(Texts.t("NOTEBOOK_NO_REPORT"), 16, UIKit.COLOR_MUTED, true))
	else:
		ReportPanel.build_report(_content, rep, false)
	_content.add_child(UIKit.label(Texts.t("NOTEBOOK_CONTROLS"), 14, UIKit.COLOR_MUTED, true))


## Objetivos de la primera sesión, calculados a partir del estado (no se guardan aparte).
static func objectives(s: GameState) -> Array:
	var well := s.get_project("well_repair")
	return [
		{"key": "OBJ_TALK_ROSA", "done": s.has_fact("neighbor_rosa", "water_complaint_heard")},
		{"key": "OBJ_INSPECT_WELL", "done": s.has_fact("player", "inspected_well")},
		{"key": "OBJ_APPROVE_REPAIR", "done": well.status != ProjectState.AVAILABLE},
		{"key": "OBJ_CLOSE_DAY", "done": well.status == ProjectState.COMPLETED},
		{"key": "OBJ_SEE_RESULT", "done": s.has_fact("player", "saw_well_repaired")},
	]
