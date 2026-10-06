class_name InspectPanel
extends GamePanel
## Inspección de un lugar del mapa. Muestra datos reales del estado del servicio.

var _content := VBoxContainer.new()


func _init() -> void:
	super()
	_content.add_theme_constant_override("separation", 8)
	body.add_child(_content)
	body.add_child(HSeparator.new())
	body.add_child(UIKit.button(Texts.t("UI_CLOSE"), request_close))


func on_open(args: Dictionary) -> void:
	UIKit.clear(_content)
	match String(args.get("target_id", "")):
		"well_main":
			_build_well()
		_:
			_content.add_child(UIKit.label(Texts.t("INSPECT_NOTHING")))


func _build_well() -> void:
	var s := Game.state
	var def := Game.content.find_project("well_repair")
	var p := s.get_project("well_repair")
	var day := s.current_day()
	var capacity := Simulation.water_capacity(s, Game.content, day)
	var demand := s.settlement.population
	var coverage := Simulation.coverage_bp(capacity, demand)
	Game.record_fact("player", "inspected_well")
	if p.status == ProjectState.COMPLETED:
		Game.record_fact("player", "saw_well_repaired")

	_content.add_child(UIKit.title(Texts.t("INSPECT_WELL_TITLE")))
	var status_key := {
		ProjectState.AVAILABLE: "INSPECT_WELL_STATUS_BROKEN",
		ProjectState.UNDER_CONSTRUCTION: "INSPECT_WELL_STATUS_WORKS",
		ProjectState.COMPLETED: "INSPECT_WELL_STATUS_DONE",
	}[p.status] as String
	_content.add_child(UIKit.label(Texts.t(status_key, {"day": p.completed_day}), 19, UIKit.COLOR_TEXT, true))
	_content.add_child(UIKit.section(Texts.t("INSPECT_WELL_SERVICE_TODAY", {"day": day})))
	_content.add_child(UIKit.row(Texts.t("ROW_WATER_CAPACITY"), Texts.t("VAL_PEOPLE_PER_DAY", {"n": capacity})))
	_content.add_child(UIKit.row(Texts.t("ROW_WATER_DEMAND"), Texts.t("VAL_PEOPLE", {"n": demand})))
	var cov_color := UIKit.COLOR_GOOD if coverage >= 10000 else UIKit.COLOR_BAD
	_content.add_child(UIKit.row(Texts.t("ROW_WATER_COVERAGE"), Money.format_bp_percent(coverage), cov_color))
	match p.status:
		ProjectState.AVAILABLE:
			_content.add_child(UIKit.label(Texts.t("INSPECT_WELL_HINT", {
				"cost": Money.format(def.cost_cents()),
				"days": def.duration_days,
				"capacity_after": def.capacity_after,
			}), 17, UIKit.COLOR_ACCENT, true))
		ProjectState.UNDER_CONSTRUCTION:
			_content.add_child(UIKit.label(Texts.t("INSPECT_WELL_WORKS_HINT", {
				"day": p.completion_day,
				"next_day": p.completion_day + 1,
				"capacity_after": def.capacity_after,
			}), 17, UIKit.COLOR_ACCENT, true))
