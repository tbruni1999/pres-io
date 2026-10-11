extends SceneTree
## Genera una partida de muestra (docs/partida_demo.json): sexto día por la tarde, con los tres
## locos en carpa, estantería, espinel y cosas en la mochila para ver el inventario.
## Uso: godot --headless --path . --script tools/make_demo.gd
## Se avanza con los mismos pasos del juego (descansando, así no baja hambre ni sed) y se ajusta
## solo con las operaciones del dominio, para que la partida valide al cargarse.

const CONTENT := preload("res://data/game_content.tres")
const OUT := "res://docs/partida_demo.json"


func _initialize() -> void:
	var s := GameState.create_new(CONTENT, 20261010)
	# Cinco jornadas completas (sin hambre ni sed) y un poco de la sexta.
	for d in 5:
		Simulation.advance_to_end_of_day(s, CONTENT, true)
	for i in 200:
		Simulation.step(s, CONTENT, true)
	var pl := s.player
	pl.hunger_bp = 8200
	pl.thirst_bp = 7600
	pl.earn(Money.from_units(330))
	pl.add_tool(CONTENT.find_item("axe"))
	pl.add_tool(CONTENT.find_item("bike"))
	pl.tool_wear["rod_basic"] = 31
	pl.tool_wear["axe"] = 14
	pl.add_item("fish_big", 2)
	pl.add_item("fish_small", 3)
	pl.add_item("fish_big_smoked", 1)
	pl.add_item("bread", 1)
	pl.add_item("water_jug", 1)
	s.camp.buildings.append("sign")
	s.camp.buildings.append("smokehouse")
	s.camp.buildings.append("dock")
	s.camp.buildings.append("tarp")
	s.camp.buildings.append("longline")
	s.camp.buildings.append("shack")
	s.camp.wood = 9
	s.camp.storage = {"sheet_metal": 3, "cement": 2}
	s.camp.longline_items = {"fish_small": 2}
	s.camp.fire_until = s.tick + 120
	s.camp.night_thread = 2
	s.camp.neighbors = {
		"beto": {"spot": "back", "since": 3, "talked_day": 5, "ep": 4},
		"salim": {"spot": "road", "since": 5, "talked_day": 5, "ep": 2},
		"raul": {"spot": "lake", "since": 6, "talked_day": 5, "ep": 1},
	}
	s.facts["player"]["smoked_once"] = true
	s.facts["player"]["busy_road"] = true
	s.facts["player"]["lake_lights_2"] = true
	var text := JSON.stringify(s.to_dict("0.5.0-beto"), "\t", true, true)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
	print("partida de muestra escrita: %s (%d bytes), día %d" % [OUT, text.length(), s.current_day()])
	quit(0)
