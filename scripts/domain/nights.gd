class_name Nights
extends RefCounted
## Antes de dormir siempre pasa algo: un misterio, algo raro o un susto.
## Todo sale del generador de la partida, así una partida cargada repite lo mismo.
## Devuelve un evento {key, n} que el informe muestra arriba de todo.

## Capítulos del misterio de las luces del lago.
const LIGHTS_EPISODES := 6
## Rarezas sin efecto (EV_WEIRD_1..N en strings.csv).
const WEIRD_COUNT := 12


static func before_bed(state: GameState, content: GameContent) -> Dictionary:
	var b := content.balance
	var day := state.current_day()
	var options: Array[Dictionary] = []
	var fish := _fish_in_bag(state, content)
	if day >= b.fox_from_day and not fish.is_empty():
		options.append({"id": "fox", "w": 5})
	if day >= b.stranger_from_day and state.camp.wood >= 2:
		options.append({"id": "stranger", "w": 3})
	if state.camp.night_thread < LIGHTS_EPISODES and day >= 2:
		options.append({"id": "lights", "w": 4})
	options.append({"id": "bottle", "w": 2})
	if PlayerActions.bag_free(state, content) > 0:
		options.append({"id": "gift", "w": 2})
	options.append({"id": "weird", "w": 6})

	var total := 0
	for o in options:
		total += int(o["w"])
	var roll := state.rng.randi_range(0, total - 1)
	var pick := "weird"
	for o in options:
		if roll < int(o["w"]):
			pick = o["id"]
			break
		roll -= int(o["w"])

	match pick:
		"fox":
			return _fox(state, content, fish)
		"stranger":
			return _stranger(state, content)
		"lights":
			state.camp.night_thread += 1
			var ep := state.camp.night_thread
			if ep == LIGHTS_EPISODES:
				state.player.earn(Money.from_units(b.lights_reward_uc))
				state.facts["player"]["lights_solved"] = true
			return {"key": "EV_LIGHTS_%d" % ep, "n": b.lights_reward_uc}
		"bottle":
			var n := state.rng.randi_range(b.bottle_min_uc, b.bottle_max_uc)
			state.player.earn(Money.from_units(n))
			return {"key": "EV_BOTTLE", "n": n}
		"gift":
			state.player.add_item("fish_small_smoked", 1)
			return {"key": "EV_GIFT", "n": 1}
	return {"key": "EV_WEIRD_%d" % state.rng.randi_range(1, WEIRD_COUNT), "n": 0}


## El zorro viene por el olor. El fuego prendido lo espanta, y Polizón también.
static func _fox(state: GameState, content: GameContent, fish: Array) -> Dictionary:
	if Simulation.fire_lit(state):
		return {"key": "EV_FOX_FIRE", "n": 0}
	if state.has_fact("player", "has_dog"):
		return {"key": "EV_FOX_DOG", "n": 0}
	# Se lleva primero lo mejor: el ahumado.
	var stolen := 0
	for item_id in fish:
		while stolen < content.balance.fox_steals and state.player.remove_item(item_id, 1):
			stolen += 1
	return {"key": "EV_FOX_STOLE", "n": stolen}


## Un desconocido se lleva leña. Si Beto vive acá, a veces lo corre.
static func _stranger(state: GameState, content: GameContent) -> Dictionary:
	if Neighbors.is_living(state, "beto") and state.rng.randi_range(0, 1) == 0:
		return {"key": "EV_STRANGER_BETO", "n": 0}
	var n := mini(content.balance.stranger_wood_max, (state.camp.wood + 1) / 2)
	state.camp.wood -= n
	return {"key": "EV_STRANGER", "n": n}


## Pescado en la mochila, del más valioso al menos (ahumado primero).
static func _fish_in_bag(state: GameState, content: GameContent) -> Array:
	var out: Array = []
	for item_id in ["fish_big_smoked", "fish_small_smoked", "fish_big", "fish_small"]:
		if state.player.count(item_id) > 0 and content.find_item(item_id) != null:
			out.append(item_id)
	return out
