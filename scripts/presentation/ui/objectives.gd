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
	if pl.fish_caught_total == 0:
		return Texts.t("OBJ_FIRST_FISH")
	if pl.earned_total_cents == 0:
		return Texts.t("OBJ_HAIL")
	for b in content.sorted_buildings():
		if not s.camp.has_building(b.id):
			return Texts.t("OBJ_" + b.id.to_upper())
	return Texts.t("OBJ_DONE")
