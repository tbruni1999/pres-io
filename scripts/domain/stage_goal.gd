class_name StageGoal
extends RefCounted
## Meta de la etapa "carpa": juntar plata, materiales (casi todos comprados),
## la escritura del campo y tres vecinos. Al cumplirla se funda el pueblito con un fogón.

const FOUNDED_FACT := "pueblo_founded"


## [{key, have, need, ok}] en el orden en que se muestran.
static func requirements(state: GameState, content: GameContent) -> Array[Dictionary]:
	var b := content.balance
	var out: Array[Dictionary] = []
	var money := Money.from_units(b.goal_money_uc)
	out.append({"key": "GOAL_MONEY", "have": state.player.wallet_cents, "need": money, "money": true,
		"ok": state.player.wallet_cents >= money})
	var ids := b.goal_materials.keys()
	ids.sort()
	for id in ids:
		var have := int(state.camp.storage.get(id, 0))
		var need := int(b.goal_materials[id])
		out.append({"key": "GOAL_ITEM", "item": id, "have": have, "need": need, "ok": have >= need})
	var deed := state.has_fact("player", b.goal_fact)
	out.append({"key": "GOAL_DEED", "have": 1 if deed else 0, "need": 1, "ok": deed})
	var n := Neighbors.living_count(state)
	out.append({"key": "GOAL_NEIGHBORS", "have": n, "need": b.goal_neighbors, "ok": n >= b.goal_neighbors})
	return out


static func is_complete(state: GameState, content: GameContent) -> bool:
	for r in requirements(state, content):
		if not r["ok"]:
			return false
	return true


static func is_founded(state: GameState) -> bool:
	return state.has_fact("player", FOUNDED_FACT)


## Se paga la plata, se usan los materiales y se arma el fogón con los vecinos.
static func found(state: GameState, content: GameContent) -> CommandResult:
	if is_founded(state):
		return CommandResult.already_applied(Texts.t("MSG_ALREADY_FOUNDED"))
	if not is_complete(state, content):
		return CommandResult.failure("goal_incomplete", Texts.t("ERR_GOAL_INCOMPLETE"))
	var b := content.balance
	state.player.spend(Money.from_units(b.goal_money_uc))
	for id in b.goal_materials:
		var left := int(state.camp.storage[id]) - int(b.goal_materials[id])
		if left == 0:
			state.camp.storage.erase(id)
		else:
			state.camp.storage[id] = left
	state.facts["player"][FOUNDED_FACT] = true
	return CommandResult.success(Texts.t("MSG_FOUNDED"))
