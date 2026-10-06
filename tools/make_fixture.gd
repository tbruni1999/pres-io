extends SceneTree
## Genera el fixture del esquema de guardado actual con el código real.
## Uso (solo cuando cambia el esquema): godot --headless --path . --script tools/make_fixture.gd
## El fixture del esquema 1 (tests/fixtures/save_v1_day2.json) no se regenera: es histórico.

const CONTENT := preload("res://data/game_content.tres")
const OUT := "res://tests/fixtures/save_v2_day3.json"


func _initialize() -> void:
	var s := GameState.create_new(CONTENT, 20261006)
	var pl := s.player
	for i in 90:
		Simulation.step(s, CONTENT)
	PlayerActions.land_fish(s, CONTENT, "fish_small", false)
	PlayerActions.gather_branches(s, CONTENT, "branches_1")
	pl.earn(Money.from_units(1500))
	PlayerActions.purchase(s, CONTENT, CONTENT.find_item("cooler"), Money.from_units(250))
	s.facts["neighbor_rosa"]["collection_open"] = true
	PlayerActions.donate(s, CONTENT, "well_repair", Money.from_units(1000))
	pl.hunger_bp = PlayerState.FULL
	pl.thirst_bp = PlayerState.FULL
	Simulation.advance_to_end_of_day(s, CONTENT, true)
	Simulation.advance_to_end_of_day(s, CONTENT, true)
	for i in 40:
		Simulation.step(s, CONTENT)
	s.player_pose = {"position": Vector3(1.0, 0.05, 2.0), "yaw": 0.4, "pitch": -5.0}
	var text := JSON.stringify(s.to_dict("0.2.0-vecino"), "\t")
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
	print("fixture escrito: %s (%d bytes)" % [OUT, text.length()])
	quit(0)
