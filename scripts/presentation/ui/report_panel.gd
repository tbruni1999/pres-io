class_name ReportPanel
extends GamePanel
## Informe de cierre de jornada: dinero, agua y reacción de la comunidad.

var _content := VBoxContainer.new()
var _return_to_desk := false


func _init() -> void:
	super()
	custom_minimum_size = Vector2(620, 0)
	_content.add_theme_constant_override("separation", 6)
	body.add_child(_content)
	body.add_child(HSeparator.new())
	body.add_child(UIKit.button(Texts.t("UI_CONTINUE"), _on_continue))


func on_open(args: Dictionary) -> void:
	_return_to_desk = bool(args.get("return_to_desk", false))
	UIKit.clear(_content)
	var rep := args.get("report") as DayReport
	if rep == null:
		_content.add_child(UIKit.label(Texts.t("REPORT_NONE")))
		return
	build_report(_content, rep, true)
	var autosave := String(args.get("autosave", ""))
	if not autosave.is_empty():
		_content.add_child(UIKit.label(autosave, 14, UIKit.COLOR_MUTED, true))


## También lo usa la libreta para el resumen del último cierre.
static func build_report(box: VBoxContainer, rep: DayReport, full: bool) -> void:
	box.add_child(UIKit.title(Texts.t("REPORT_TITLE", {"day": rep.day})))
	box.add_child(UIKit.section(Texts.t("REPORT_MONEY")))
	if full:
		box.add_child(UIKit.row(Texts.t("ROW_CASH_START"), Money.format(rep.cash_start_cents)))
	box.add_child(UIKit.row(Texts.t("ROW_INCOME"), Money.format(rep.income_cents)))
	if rep.payment_lines.is_empty():
		box.add_child(UIKit.row(Texts.t("ROW_PAYMENTS"), Money.format(0)))
	for l in rep.payment_lines:
		box.add_child(UIKit.row(Texts.t("ROW_PAYMENT_LINE", {"reason": Texts.t(l["reason_key"])}), "-" + Money.format(int(l["amount_cents"])), UIKit.COLOR_BAD))
	box.add_child(UIKit.row(Texts.t("ROW_CASH_END"), Money.format(rep.cash_end_cents), UIKit.COLOR_ACCENT))
	box.add_child(UIKit.section(Texts.t("REPORT_WATER")))
	var cov_color := UIKit.COLOR_GOOD if rep.water_coverage_bp >= 10000 else UIKit.COLOR_BAD
	box.add_child(UIKit.row(Texts.t("ROW_WATER_SERVED"), Texts.t("VAL_WATER_SERVED", {
		"served": rep.water_served, "demand": rep.water_demand,
		"coverage": Money.format_bp_percent(rep.water_coverage_bp),
	}), cov_color))
	for c in rep.completed_projects:
		var def := Game.content.find_project(String(c["project_id"]))
		box.add_child(UIKit.label(Texts.t("REPORT_PROJECT_DONE", {
			"name": Texts.t(def.name_key), "day": c["operational_from_day"], "capacity": rep.next_water_capacity,
		}), 17, UIKit.COLOR_GOOD, true))
	if rep.next_water_capacity != rep.water_capacity:
		box.add_child(UIKit.row(Texts.t("ROW_WATER_TOMORROW"), Texts.t("VAL_PEOPLE_PER_DAY", {"n": rep.next_water_capacity}), UIKit.COLOR_GOOD))
	box.add_child(UIKit.section(Texts.t("REPORT_COMMUNITY")))
	box.add_child(UIKit.label(Texts.t(rep.reaction_key), 17, UIKit.COLOR_TEXT, true))


func _on_continue() -> void:
	if _return_to_desk:
		ui.open_panel(ui.desk, {})
	else:
		request_close()
