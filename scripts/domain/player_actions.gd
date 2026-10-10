class_name PlayerActions
extends RefCounted
## Comandos del personaje: pescar, comprar, juntar madera, construir, comer y tomar agua.
## Validan todo antes de cambiar algo; la plata pasa solo por PlayerState.earn/spend
## y por TreasuryState para el fondo comunitario. Vender: ver Merchants.

const WELL_PROJECT := "well_repair"


static func bag_capacity(state: GameState, content: GameContent) -> int:
	var cap := content.balance.bag_capacity
	for t in state.player.tools:
		var def := content.find_item(t)
		if def != null:
			cap += def.bag_bonus
	return cap


static func bag_free(state: GameState, content: GameContent) -> int:
	return maxi(0, bag_capacity(state, content) - state.player.bag_count())


static func best_rod(state: GameState, content: GameContent) -> ItemDefinition:
	var best: ItemDefinition = null
	for t in state.player.tools:
		var def := content.find_item(t)
		if def != null and def.is_rod() and (best == null or def.tier > best.tier):
			best = def
	return best


# --- Pesca --------------------------------------------------------------------

## Tira la línea desde la orilla ("shore") o el muelle ("dock").
## La espera del pique y qué pescado es salen del generador de la partida.
## Devuelve {ok, code, message, delay_s, fish_id, checks, zone_bp, speed}.
static func cast_line(state: GameState, content: GameContent, spot: String = "shore") -> Dictionary:
	var rod := best_rod(state, content)
	if rod == null:
		return {"ok": false, "code": "no_rod", "message": Texts.t("ERR_NO_ROD")}
	if DayTime.is_night(state, content):
		return {"ok": false, "code": "night", "message": Texts.t("ERR_NIGHT_NO_FISH")}
	if bag_free(state, content) <= 0:
		return {"ok": false, "code": "bag_full", "message": Texts.t("ERR_BAG_FULL")}
	var b := content.balance
	var on_dock := spot == "dock"
	if on_dock and not state.camp.has_building("dock"):
		return {"ok": false, "code": "no_dock", "message": Texts.t("ERR_NO_DOCK")}
	var rng := state.rng
	var delay := rng.randf_range(rod.bite_min_s, rod.bite_max_s) * Weather.bite_bp(state, content) / 10000.0
	var big_chance := rod.big_chance_bp + (b.dock_big_bonus_bp if on_dock else 0)
	var big := rng.randi_range(0, 9999) < big_chance
	var fish := content.find_item("fish_big" if big else "fish_small")
	# Cada tirada gasta la caña; si se rompe, este es su último pique.
	var broke := state.player.wear_tool(rod.id)
	return {
		"ok": true, "code": "ok", "message": Texts.t("MSG_TOOL_BROKE", {"name": Texts.t(rod.name_key)}) if broke else "",
		"broke": broke,
		"delay_s": delay,
		"fish_id": fish.id,
		"checks": maxi(1, fish.checks),
		"zone_bp": clampi(fish.zone_bp + rod.zone_bonus_bp + (b.dock_zone_bonus_bp if on_dock else 0), 500, 9000),
		"speed": fish.needle_speed * rod.needle_mult,
	}


## Resultado del skillcheck acertado: el pescado va a la mochila.
## perfect: todos los checks en el centro de la zona, suma uno más si hay lugar.
static func land_fish(state: GameState, content: GameContent, fish_id: String, perfect: bool) -> CommandResult:
	var def := content.find_item(fish_id)
	if def == null or def.kind != ItemDefinition.Kind.CATCH:
		return CommandResult.failure("unknown_item", Texts.t("ERR_UNKNOWN_ITEM"))
	var free := bag_free(state, content)
	if free <= 0:
		return CommandResult.failure("bag_full", Texts.t("ERR_BAG_FULL"))
	var n := 2 if perfect and free >= 2 else 1
	state.player.add_item(fish_id, n)
	state.player.day_fish += n
	state.player.fish_caught_total += n
	var key := "MSG_CATCH_PERFECT" if n == 2 else "MSG_CATCH"
	var msg := Texts.t(key, {"name": Texts.t(def.name_key)})
	# A veces sale algo más enganchado.
	var b := content.balance
	var found := 0
	if state.rng.randi_range(0, 9999) < b.find_chance_bp:
		found = state.rng.randi_range(b.find_min_uc, b.find_max_uc)
		state.player.earn(Money.from_units(found))
		msg += " " + Texts.t("MSG_FIND_%d" % state.rng.randi_range(1, FIND_LINES), {"money": Money.format(Money.from_units(found))})
	return CommandResult.success(msg, {"count": n, "found_uc": found})


## Frases de hallazgos (MSG_FIND_1..N).
const FIND_LINES := 6


# --- Compras ------------------------------------------------------------------

## Compra a un precio dado (lo fija cada comerciante). Herramientas una sola vez.
static func purchase(state: GameState, content: GameContent, def: ItemDefinition, price: int) -> CommandResult:
	var pl := state.player
	if def.kind == ItemDefinition.Kind.TOOL and pl.has_tool(def.id):
		return CommandResult.failure("already_owned", Texts.t("ERR_ALREADY_OWNED"))
	var in_bag := def.kind != ItemDefinition.Kind.TOOL and def.kind != ItemDefinition.Kind.MATERIAL
	if in_bag and bag_free(state, content) <= 0:
		return CommandResult.failure("bag_full", Texts.t("ERR_BAG_FULL"))
	if price > pl.wallet_cents:
		return CommandResult.failure("insufficient_funds", Texts.t("ERR_MISSING_MONEY", {"missing": Money.format(price - pl.wallet_cents)}))
	pl.spend(price)
	if def.kind == ItemDefinition.Kind.TOOL:
		pl.add_tool(def)
	elif def.kind == ItemDefinition.Kind.MATERIAL:
		state.camp.storage[def.id] = int(state.camp.storage.get(def.id, 0)) + 1
		return CommandResult.success(Texts.t("MSG_BOUGHT_STORAGE", {"name": Texts.t(def.name_key), "n": state.camp.storage[def.id]}))
	else:
		pl.add_item(def.id, 1)
	return CommandResult.success(Texts.t("MSG_BOUGHT", {"name": Texts.t(def.name_key)}))


# --- Madera y construcción ------------------------------------------------------

static func gather_branches(state: GameState, content: GameContent, spot_id: String) -> CommandResult:
	if state.camp.branches_taken.has(spot_id):
		return CommandResult.failure("already_gathered", Texts.t("ERR_BRANCHES_GONE"))
	state.camp.branches_taken.append(spot_id)
	state.camp.wood += content.balance.branch_wood
	return CommandResult.success(Texts.t("MSG_GOT_WOOD", {"n": content.balance.branch_wood}))


static func tree_available(state: GameState, content: GameContent, tree_id: String) -> bool:
	if not state.camp.trees_cut.has(tree_id):
		return true
	return state.current_day() >= int(state.camp.trees_cut[tree_id]) + content.balance.tree_regrow_days


## success: el jugador acertó los golpes de hacha del skillcheck.
static func chop_tree(state: GameState, content: GameContent, tree_id: String, success: bool) -> CommandResult:
	if not state.player.has_tool("axe"):
		return CommandResult.failure("no_axe", Texts.t("ERR_NO_AXE"))
	if not tree_available(state, content, tree_id):
		return CommandResult.failure("tree_cut", Texts.t("ERR_TREE_CUT"))
	if not success:
		return CommandResult.failure("missed", Texts.t("MSG_CHOP_MISSED"))
	state.camp.trees_cut[tree_id] = state.current_day()
	state.camp.wood += content.balance.tree_wood
	var msg := Texts.t("MSG_GOT_WOOD", {"n": content.balance.tree_wood})
	if state.player.wear_tool("axe"):
		msg += " " + Texts.t("MSG_TOOL_BROKE", {"name": Texts.t(content.find_item("axe").name_key)})
	return CommandResult.success(msg)


static func can_build(state: GameState, content: GameContent, building_id: String) -> CommandResult:
	var def := content.find_building(building_id)
	if def == null:
		return CommandResult.failure("unknown_building", Texts.t("ERR_UNKNOWN_ITEM"))
	if state.camp.has_building(building_id):
		return CommandResult.failure("already_built", Texts.t("ERR_ALREADY_BUILT"))
	if state.camp.wood < def.wood:
		return CommandResult.failure("missing_wood", Texts.t("ERR_MISSING_WOOD", {"missing": def.wood - state.camp.wood}))
	if state.player.wallet_cents < def.money_cents():
		return CommandResult.failure("insufficient_funds", Texts.t("ERR_MISSING_MONEY", {"missing": Money.format(def.money_cents() - state.player.wallet_cents)}))
	return CommandResult.success()


## Se cobra al terminar de martillar (los skillchecks los hace la presentación).
static func build(state: GameState, content: GameContent, building_id: String) -> CommandResult:
	var check := can_build(state, content, building_id)
	if not check.ok:
		return check
	var def := content.find_building(building_id)
	state.camp.wood -= def.wood
	if def.money_cents() > 0:
		state.player.spend(def.money_cents())
	state.camp.buildings.append(building_id)
	return CommandResult.success(Texts.t("MSG_BUILT", {"name": Texts.t(def.name_key)}))


# --- Ahumadero -----------------------------------------------------------------

const SMOKER_EMPTY := "empty"
const SMOKER_SMOKING := "smoking"
const SMOKER_READY := "ready"


static func smoker_status(state: GameState) -> String:
	if state.camp.smoker_items.is_empty():
		return SMOKER_EMPTY
	return SMOKER_READY if state.tick >= state.camp.smoker_ready_tick else SMOKER_SMOKING


## Carga el pescado crudo de la mochila (hasta la capacidad) y prende el fuego con una madera.
static func load_smoker(state: GameState, content: GameContent) -> CommandResult:
	if not state.camp.has_building("smokehouse"):
		return CommandResult.failure("no_smokehouse", Texts.t("ERR_NO_SMOKEHOUSE"))
	if smoker_status(state) != SMOKER_EMPTY:
		return CommandResult.failure("smoker_busy", Texts.t("ERR_SMOKER_BUSY"))
	if state.camp.wood < 1:
		return CommandResult.failure("missing_wood", Texts.t("ERR_MISSING_WOOD", {"missing": 1}))
	var room := content.balance.smoker_capacity
	var load := {}
	var pl := state.player
	for item_id in _sorted(pl.bag.keys()):
		var def := content.find_item(item_id)
		if def == null or def.smoked_into.is_empty() or room <= 0:
			continue
		var n := mini(room, pl.count(item_id))
		load[item_id] = n
		room -= n
	if load.is_empty():
		return CommandResult.failure("no_fish", Texts.t("ERR_NO_FISH"))
	var total := 0
	for item_id in load:
		pl.remove_item(item_id, load[item_id])
		total += int(load[item_id])
	state.camp.smoker_items = load
	state.camp.smoker_ready_tick = state.tick + content.balance.smoke_ticks
	state.camp.wood -= 1
	return CommandResult.success(Texts.t("MSG_SMOKER_LOADED", {"n": total}), {"count": total})


## Saca lo ahumado que entre en la mochila; lo que no entra queda en el ahumadero.
static func collect_smoker(state: GameState, content: GameContent) -> CommandResult:
	match smoker_status(state):
		SMOKER_EMPTY:
			return CommandResult.failure("smoker_empty", Texts.t("ERR_SMOKER_EMPTY"))
		SMOKER_SMOKING:
			return CommandResult.failure("smoker_not_ready", Texts.t("ERR_SMOKER_NOT_READY"))
	var free := bag_free(state, content)
	if free <= 0:
		return CommandResult.failure("bag_full", Texts.t("ERR_BAG_FULL"))
	var taken := 0
	for item_id in _sorted(state.camp.smoker_items.keys()):
		var n := mini(free, int(state.camp.smoker_items[item_id]))
		if n <= 0:
			continue
		state.player.add_item(content.find_item(item_id).smoked_into, n)
		var left := int(state.camp.smoker_items[item_id]) - n
		if left == 0:
			state.camp.smoker_items.erase(item_id)
		else:
			state.camp.smoker_items[item_id] = left
		free -= n
		taken += n
	if state.camp.smoker_items.is_empty():
		state.camp.smoker_ready_tick = -1
	# El olor del primer ahumado se siente lejos (atrae a Beto).
	state.facts["player"]["smoked_once"] = true
	var key := "MSG_SMOKER_COLLECTED" if state.camp.smoker_items.is_empty() else "MSG_SMOKER_COLLECTED_PARTIAL"
	return CommandResult.success(Texts.t(key, {"n": taken}), {"count": taken})


# --- Espinel ----------------------------------------------------------------------

## Saca del espinel lo que entre en la mochila.
static func collect_longline(state: GameState, content: GameContent) -> CommandResult:
	if not state.camp.has_building("longline"):
		return CommandResult.failure("no_longline", Texts.t("ERR_NO_LONGLINE"))
	var line := state.camp.longline_items
	if line.is_empty():
		return CommandResult.failure("longline_empty", Texts.t("ERR_LONGLINE_EMPTY"))
	var free := bag_free(state, content)
	if free <= 0:
		return CommandResult.failure("bag_full", Texts.t("ERR_BAG_FULL"))
	var taken := 0
	for item_id in _sorted(line.keys()):
		var n := mini(free, int(line[item_id]))
		state.player.add_item(item_id, n)
		state.player.day_fish += n
		state.player.fish_caught_total += n
		if n == int(line[item_id]):
			line.erase(item_id)
		else:
			line[item_id] = int(line[item_id]) - n
		free -= n
		taken += n
		if free <= 0:
			break
	return CommandResult.success(Texts.t("MSG_LONGLINE_COLLECTED", {"n": taken}), {"count": taken})


static func longline_count(state: GameState) -> int:
	var n := 0
	for k in state.camp.longline_items:
		n += int(state.camp.longline_items[k])
	return n


static func _sorted(keys: Array) -> Array:
	var k := keys.duplicate()
	k.sort()
	return k


# --- Comer y tomar ------------------------------------------------------------

## Agua del lago sin hervir: calma la sed, pero a veces cae mal.
static func drink_lake(state: GameState, content: GameContent) -> CommandResult:
	var b := content.balance
	var pl := state.player
	pl.thirst_bp = mini(PlayerState.FULL, pl.thirst_bp + b.raw_water_drink_bp)
	if state.rng.randi_range(0, 9999) < b.raw_water_sick_bp:
		pl.hunger_bp = maxi(0, pl.hunger_bp - b.raw_water_sick_hunger_bp)
		return CommandResult.success(Texts.t("MSG_LAKE_SICK"), {"sick": true})
	return CommandResult.success(Texts.t("MSG_LAKE_OK"), {"sick": false})


static func _use_fire(state: GameState) -> CommandResult:
	if not state.camp.has_building("fire"):
		return CommandResult.failure("no_fire", Texts.t("ERR_NO_FIRE"))
	if not Simulation.fire_lit(state):
		return CommandResult.failure("fire_out", Texts.t("ERR_FIRE_OUT"))
	return CommandResult.success()


## Echar una madera al fogón (lo prende si estaba apagado). Con lluvia y sin lona no prende.
static func add_wood(state: GameState, content: GameContent) -> CommandResult:
	var camp := state.camp
	if not camp.has_building("fire"):
		return CommandResult.failure("no_fire", Texts.t("ERR_NO_FIRE"))
	if camp.wood < 1:
		return CommandResult.failure("missing_wood", Texts.t("ERR_MISSING_WOOD", {"missing": 1}))
	if not Simulation.fire_sheltered_or_dry(state):
		return CommandResult.failure("raining", Texts.t("ERR_RAIN_NO_FIRE"))
	var b := content.balance
	var base := maxi(state.tick, camp.fire_until)
	if base - state.tick >= b.fire_max_ticks:
		return CommandResult.failure("fire_full", Texts.t("ERR_FIRE_FULL"))
	var was_lit := Simulation.fire_lit(state)
	camp.wood -= 1
	camp.fire_until = mini(base + Weather.fire_wood_ticks(state, content), state.tick + b.fire_max_ticks)
	return CommandResult.success(Texts.t("MSG_FIRE_FED" if was_lit else "MSG_FIRE_LIT"))


## Sin caña no hay plata: en el fogón se arma una de rama con un poco de madera.
static func make_rod(state: GameState, content: GameContent) -> CommandResult:
	if best_rod(state, content) != null:
		return CommandResult.failure("has_rod", Texts.t("ERR_HAS_ROD"))
	var need := content.balance.make_rod_wood
	if state.camp.wood < need:
		return CommandResult.failure("missing_wood", Texts.t("ERR_MISSING_WOOD", {"missing": need - state.camp.wood}))
	state.camp.wood -= need
	state.player.add_tool(content.find_item("rod_basic"))
	return CommandResult.success(Texts.t("MSG_ROD_MADE"))


## Fuego prendido hasta (tick), o -1.
static func fire_until(state: GameState) -> int:
	return state.camp.fire_until if Simulation.fire_lit(state) else -1


static func boil_water(state: GameState, _content: GameContent) -> CommandResult:
	var ok := _use_fire(state)
	if not ok.ok:
		return ok
	state.player.thirst_bp = PlayerState.FULL
	return CommandResult.success(Texts.t("MSG_BOILED"))


## Asar y comer un pescado en el fogón: llena el doble que crudo.
static func cook_and_eat(state: GameState, content: GameContent, fish_id: String) -> CommandResult:
	var ok := _use_fire(state)
	if not ok.ok:
		return ok
	var def := content.find_item(fish_id)
	if def == null or def.kind != ItemDefinition.Kind.CATCH or not state.player.remove_item(fish_id, 1):
		return CommandResult.failure("not_enough_items", Texts.t("ERR_NO_FISH"))
	var pl := state.player
	pl.hunger_bp = mini(PlayerState.FULL, pl.hunger_bp + def.food_bp * content.balance.cook_multiplier)
	return CommandResult.success(Texts.t("MSG_COOKED", {"name": Texts.t(def.name_key)}))


static func consume(state: GameState, content: GameContent, item_id: String) -> CommandResult:
	var def := content.find_item(item_id)
	if def == null or (def.food_bp <= 0 and def.drink_bp <= 0):
		return CommandResult.failure("not_edible", Texts.t("ERR_NOT_EDIBLE"))
	if not state.player.remove_item(item_id, 1):
		return CommandResult.failure("not_enough_items", Texts.t("ERR_NOT_ENOUGH_ITEMS"))
	var pl := state.player
	pl.hunger_bp = mini(PlayerState.FULL, pl.hunger_bp + def.food_bp)
	pl.thirst_bp = mini(PlayerState.FULL, pl.thirst_bp + def.drink_bp)
	var key := "MSG_DRANK" if def.drink_bp > def.food_bp else "MSG_ATE"
	return CommandResult.success(Texts.t(key, {"name": Texts.t(def.name_key)}))


## El pozo roto da poca agua (hay fila); arreglado, se llena la sed.
static func drink_well(state: GameState, content: GameContent) -> CommandResult:
	var fixed := well_fixed(state)
	var b := content.balance
	var pl := state.player
	pl.thirst_bp = mini(PlayerState.FULL, pl.thirst_bp + (b.well_drink_fixed_bp if fixed else b.well_drink_broken_bp))
	return CommandResult.success(Texts.t("MSG_DRANK_WELL_FIXED" if fixed else "MSG_DRANK_WELL_BROKEN"))


static func well_fixed(state: GameState) -> bool:
	var p := state.get_project(WELL_PROJECT)
	return p != null and p.is_operational_on(state.current_day())


# --- Colecta ------------------------------------------------------------------

## Aporte del jugador al fondo comunitario de una colecta abierta.
## Si con eso se llega a la meta, los vecinos aprueban la obra en el acto.
static func donate(state: GameState, content: GameContent, project_id: String, amount_cents: int) -> CommandResult:
	if not Simulation.collection_open(state, content, project_id):
		return CommandResult.failure("collection_closed", Texts.t("ERR_COLLECTION_CLOSED"))
	var pl := state.player
	if amount_cents <= 0:
		return CommandResult.failure("invalid_amount", Texts.t("ERR_INVALID_AMOUNT"))
	if amount_cents > pl.wallet_cents:
		return CommandResult.failure("insufficient_funds", Texts.t("ERR_MISSING_MONEY", {"missing": Money.format(amount_cents - pl.wallet_cents)}))
	var day := state.current_day()
	var op := "donation:player:%d" % state.treasury.next_entry_id
	pl.spend(amount_cents)
	pl.donated_total_cents += amount_cents
	state.treasury.post_income(amount_cents, "donation:player", "LEDGER_PLAYER_DONATION", day, state.tick, op)
	var started := Simulation.fund_collections(state, content)
	var key := "MSG_DONATED_GOAL" if started.has(project_id) else "MSG_DONATED"
	return CommandResult.success(Texts.t(key, {"amount": Money.format(amount_cents)}), {"started": started})
