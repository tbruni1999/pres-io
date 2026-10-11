class_name Objectives
extends RefCounted
## Lo que sigue, derivado del estado (no se guarda aparte).
## Devuelve {"title": qué hacer, "why": por qué y con qué números}.


static func current(s: GameState, content: GameContent) -> Dictionary:
	var pl := s.player
	var t := content.balance.tired_threshold_bp
	if DayTime.is_night(s, content):
		return _step("OBJ_NIGHT", "WHY_NIGHT")
	if pl.thirst_bp < t:
		return _step("OBJ_DRINK", "WHY_DRINK", {"pct": Money.format_bp_percent(pl.thirst_bp)})
	if pl.hunger_bp < t:
		return _step("OBJ_EAT", "WHY_EAT", {"pct": Money.format_bp_percent(pl.hunger_bp)})
	if PlayerActions.best_rod(s, content) == null:
		return _step("OBJ_NO_ROD", "WHY_NO_ROD", {"wood": s.camp.wood, "need": content.balance.make_rod_wood})
	var waiting := s.camp.neighbors.keys()
	waiting.sort()
	for id in waiting:
		if not Neighbors.is_living(s, id):
			return _step("OBJ_PLACE_%s" % String(id).to_upper(), "WHY_PLACE")
	if pl.fish_caught_total == 0:
		return _step("OBJ_FIRST_FISH", "WHY_FIRST_FISH")
	if pl.earned_total_cents == 0:
		return _step("OBJ_HAIL", "WHY_HAIL")
	for b in content.sorted_buildings():
		if not s.camp.has_building(b.id):
			return _step("OBJ_" + b.id.to_upper(), "WHY_BUILD", {
				"wood": s.camp.wood, "need": b.wood,
				"money": Money.format(pl.wallet_cents), "cost": Money.format(b.money_cents())})
	if not StageGoal.is_founded(s):
		return _step("OBJ_GOAL", "WHY_GOAL", {"left": _goal_left(s, content)})
	return _step("OBJ_DONE", "WHY_DONE")


## Lo que le falta a la meta, con números: "Plata 40 UC / 500 UC · Chapa 2/5 · …".
static func _goal_left(s: GameState, content: GameContent) -> String:
	var parts: PackedStringArray = []
	for r in StageGoal.requirements(s, content):
		if r["ok"]:
			continue
		if r.get("money", false):
			parts.append("%s %s / %s" % [Texts.t("GOAL_MONEY"), Money.format(r["have"]), Money.format(r["need"])])
		elif r.has("item"):
			parts.append("%s %d/%d" % [Texts.t(content.find_item(r["item"]).name_key), r["have"], r["need"]])
		elif r["key"] == "GOAL_NEIGHBORS":
			parts.append("%s %d/%d" % [Texts.t("GOAL_NEIGHBORS"), r["have"], r["need"]])
		else:
			parts.append(Texts.t("GOAL_DEED"))
	return " · ".join(parts)


static func _step(title_key: String, why_key: String, params: Dictionary = {}) -> Dictionary:
	return {"title": Texts.t(title_key, params), "why": Texts.t(why_key, params)}
