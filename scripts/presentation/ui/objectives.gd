class_name Objectives
extends RefCounted
## Un único objetivo a la vista, derivado del estado (no se guarda aparte).


static func current(s: GameState, content: GameContent) -> String:
	var pl := s.player
	var t := content.balance.tired_threshold_bp
	if DayTime.is_night(s, content):
		return Texts.t("OBJ_NIGHT")
	if pl.thirst_bp < t:
		return Texts.t("OBJ_DRINK")
	if pl.hunger_bp < t:
		return Texts.t("OBJ_EAT")
	if PlayerActions.best_rod(s, content) == null:
		return Texts.t("OBJ_NO_ROD")
	for id in s.camp.neighbors:
		if not Neighbors.is_living(s, id):
			return Texts.t("OBJ_PLACE_%s" % id.to_upper())
	if pl.fish_caught_total == 0:
		return Texts.t("OBJ_FIRST_FISH")
	if pl.earned_total_cents == 0:
		return Texts.t("OBJ_HAIL")
	for b in content.sorted_buildings():
		if not s.camp.has_building(b.id):
			return Texts.t("OBJ_" + b.id.to_upper())
	if not StageGoal.is_founded(s):
		return Texts.t("OBJ_GOAL")
	return Texts.t("OBJ_DONE")
