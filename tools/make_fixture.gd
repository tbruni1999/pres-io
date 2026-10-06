extends SceneTree
## Genera tests/fixtures/save_v1_day2.json con el código real de la versión actual.
## Uso (solo al crear un esquema nuevo): godot --headless --path . --script tools/make_fixture.gd

const CONTENT := preload("res://data/game_content.tres")


func _initialize() -> void:
	var s := GameState.create_new(CONTENT, 20261005)
	for i in 120:
		Simulation.step(s, CONTENT)
	s.facts["neighbor_rosa"]["water_complaint_heard"] = true
	s.facts["neighbor_rosa"]["promised_well"] = true
	s.facts["player"]["inspected_well"] = true
	Simulation.approve_project(s, CONTENT, "well_repair", "approve_project:well_repair")
	Simulation.advance_to_end_of_day(s, CONTENT)
	for i in 40:
		Simulation.step(s, CONTENT)
	s.player_pose = {"position": Vector3(-2.5, 0.05, -10.0), "yaw": 1.2, "pitch": -5.0}
	var text := JSON.stringify(s.to_dict("0.1.0-h1"), "\t")
	var f := FileAccess.open("res://tests/fixtures/save_v1_day2.json", FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
	print("fixture escrito (%d bytes)" % text.length())
	quit(0)
