extends SceneTree
## Genera el fixture del esquema de guardado actual con el código real.
## Uso (solo cuando cambia el esquema): godot --headless --path . --script tools/make_fixture.gd
## Los fixtures de esquemas anteriores (v1 a v4) no se regeneran: son históricos.

const CONTENT := preload("res://data/game_content.tres")
const OUT := "res://tests/fixtures/save_v5_day3.json"


func _initialize() -> void:
	var s := GameState.create_new(CONTENT, 20261007)
	var pl := s.player
	for i in 60:
		Simulation.step(s, CONTENT)
	PlayerActions.land_fish(s, CONTENT, "fish_small", false)
	PlayerActions.gather_branches(s, CONTENT, "branches_2")
	pl.hunger_bp = PlayerState.FULL
	pl.thirst_bp = PlayerState.FULL
	# Termina el día 1 sin ir a la cama: durmió afuera.
	while Simulation.step(s, CONTENT) == null:
		pl.hunger_bp = PlayerState.FULL
		pl.thirst_bp = PlayerState.FULL
	s.camp.wood = 12
	pl.earn(Money.from_units(150))
	PlayerActions.build(s, CONTENT, "smokehouse")
	s.camp.wood = 1
	PlayerActions.land_fish(s, CONTENT, "fish_big", false)
	PlayerActions.load_smoker(s, CONTENT)
	for i in 30:
		Simulation.step(s, CONTENT)
	# Dos comerciantes: uno frena con señas y el otro hace fila detrás.
	s.camp.passes.clear()
	s.camp.passes.append({"id": 50, "merchant": "ramiro", "start": s.tick, "status": Merchants.PASSING, "stop_tick": -1, "leave_tick": -1, "bought": 0, "visited": false, "x": -20.0, "v": 0.0})
	s.camp.passes.append({"id": 51, "merchant": "chola", "start": s.tick, "status": Merchants.PASSING, "stop_tick": -1, "leave_tick": -1, "bought": 0, "visited": false, "x": -40.0, "v": 0.0})
	s.camp.next_pass_id = 52
	Merchants.hail(s, CONTENT, 50)
	for i in 12:
		pl.hunger_bp = PlayerState.FULL
		pl.thirst_bp = PlayerState.FULL
		Simulation.step(s, CONTENT)
	# Esquema 5: sacar el primer ahumado trae a Beto; dormir (con misterio) y elegirle lugar.
	for i in 90:
		pl.hunger_bp = PlayerState.FULL
		pl.thirst_bp = PlayerState.FULL
		Simulation.step(s, CONTENT)
	PlayerActions.collect_smoker(s, CONTENT)
	s.camp.buildings.append("longline")
	Simulation.go_to_bed(s, CONTENT)
	Neighbors.place(s, "beto", "back")
	Neighbors.talk(s, "beto")
	s.camp.storage = {"cement": 1}
	for i in 40:
		pl.hunger_bp = PlayerState.FULL
		pl.thirst_bp = PlayerState.FULL
		Simulation.step(s, CONTENT)
	s.player_pose = {"position": Vector3(-3.0, 0.05, 1.0), "yaw": 0.4, "pitch": -5.0}
	var text := JSON.stringify(s.to_dict("0.5.0-beto"), "\t", true, true)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
	print("fixture escrito: %s (%d bytes)" % [OUT, text.length()])
	quit(0)
