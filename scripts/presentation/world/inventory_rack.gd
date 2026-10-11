class_name InventoryRack
extends Node3D
## Estanterías, red de pescados y leñero del campamento: muestran lo que tenés.
## Se rearman cuando cambia la mochila, el acopio o la leña. Solo presentación.
## E sobre cualquiera de ellos abre la mochila (ver inventario en detalle).

enum Mode { SHELF, NET, WOOD }

const SHELF_LEVELS := [0.42, 0.86, 1.3]
const SHELF_COLUMNS := [-0.66, -0.22, 0.22, 0.66]
const NET_MAX := 12
const WOOD_MAX := 14
const FISH_IDS := ["fish_big", "fish_small", "fish_big_smoked", "fish_small_smoked"]

@export var mode: Mode = Mode.SHELF

## Objetos visibles: se funden en pocas mallas (una por material) cada vez que cambian.
var _items := Node3D.new()
## Etiquetas de cantidad (texto, sin fundir).
var _shown := Node3D.new()
var _visible := 0
## Estructura fija (tablas, postes): se funde una vez al cargar.
var _frame := Node3D.new()
var _logs: MultiMeshInstance3D


func _ready() -> void:
	add_child(_frame)
	add_child(_items)
	add_child(_shown)
	match mode:
		Mode.SHELF:
			_build_shelf()
		Mode.NET:
			_build_net()
		Mode.WOOD:
			_build_wood()
	MeshMerger.merge(_frame, PackedStringArray(), false)
	Game.player_changed.connect(_refresh)
	Game.camp_changed.connect(_refresh)
	Game.state_replaced.connect(_refresh)
	_refresh()


## Objetos visibles ahora (sin contar etiquetas), para pruebas.
func shown_count() -> int:
	return _visible


func _refresh() -> void:
	_visible = 0
	for holder in [_items, _shown]:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
	var s := Game.state
	match mode:
		Mode.SHELF:
			_refresh_shelf(s)
		Mode.NET:
			_refresh_net(s)
		Mode.WOOD:
			_refresh_wood(s)
	MeshMerger.merge(_items, PackedStringArray(), false)


# --- Estantería ----------------------------------------------------------------

func _build_shelf() -> void:
	var wood := load("res://assets/materials/wood_old.tres") as Material
	_box(_frame, Vector3(1.8, 1.62, 0.03), Vector3(0, 0.81, -0.19), wood)
	for x in [-0.9, 0.9]:
		_box(_frame, Vector3(0.05, 1.66, 0.42), Vector3(x, 0.83, 0.0), wood)
	for y in SHELF_LEVELS:
		_box(_frame, Vector3(1.8, 0.035, 0.42), Vector3(0, y - 0.02, 0.0), wood)
	_box(_frame, Vector3(1.8, 0.05, 0.42), Vector3(0, 1.64, 0.0), wood)


func _refresh_shelf(s: GameState) -> void:
	var entries := _shelf_entries(s)
	var slot := 0
	for e in entries:
		if slot >= SHELF_LEVELS.size() * SHELF_COLUMNS.size():
			break
		var level: float = SHELF_LEVELS[slot / SHELF_COLUMNS.size()]
		var x: float = SHELF_COLUMNS[slot % SHELF_COLUMNS.size()]
		var m := ItemModel.make(String(e[0]))
		m.position = Vector3(x, level + 0.02, 0.06)
		_items.add_child(m)
		_visible += 1
		var n: int = int(e[1])
		if n > 1:
			_count_at(Vector3(x, level + 0.2, 0.12), "×%d" % n)
		slot += 1


func _shelf_entries(s: GameState) -> Array:
	var out: Array = []
	var pl := s.player
	var ids := pl.bag.keys()
	for id in s.camp.storage.keys():
		ids.append(id)
	ids.sort()
	for id in ids:
		var n := pl.count(id) if pl.bag.has(id) else int(s.camp.storage[id])
		if n > 0:
			out.append([id, n])
	for t in pl.tools:
		if t != "bike":
			out.append([t, 1])
	return out


# --- Red de pescados -----------------------------------------------------------

func _build_net() -> void:
	var wood := load("res://assets/materials/wood_old.tres") as Material
	for x in [-1.0, 1.0]:
		_box(_frame, Vector3(0.06, 1.95, 0.06), Vector3(x, 0.975, 0.0), wood)
	_box(_frame, Vector3(2.12, 0.06, 0.06), Vector3(0, 1.95, 0.0), wood)
	var net := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.9, 1.7)
	net.mesh = plane
	net.rotation_degrees = Vector3(90, 0, 0)
	net.position = Vector3(0, 1.1, 0.03)
	net.material_override = load("res://assets/materials/net.tres")
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)


func _refresh_net(s: GameState) -> void:
	var fish := _fish_units(s)
	var shown := mini(fish.size(), NET_MAX)
	for i in shown:
		var m := ItemModel.make(String(fish[i]))
		var col := i % 6
		var row := i / 6
		m.position = Vector3(-0.8 + col * 0.32, 1.72 - row * 0.5, 0.07)
		m.rotation_degrees = Vector3(0, 90, 8 * (1 if i % 2 == 0 else -1))
		_items.add_child(m)
		_visible += 1
	if fish.size() > shown:
		_count_at(Vector3(0, 0.25, 0.12), "+%d" % (fish.size() - shown))


## Pescado de la mochila y del espinel, uno por unidad (crudo y ahumado).
func _fish_units(s: GameState) -> Array:
	var out: Array = []
	for id in FISH_IDS:
		for i in s.player.count(id):
			out.append(id)
		for i in int(s.camp.longline_items.get(id, 0)):
			out.append(id)
	return out


# --- Leñero ----------------------------------------------------------------------

func _build_wood() -> void:
	_box(_frame, Vector3(1.4, 0.06, 0.62), Vector3(0, 0.03, 0.0), load("res://assets/materials/wood_old.tres") as Material)
	_logs = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = 0.6
	cyl.radial_segments = 8
	cyl.material = load("res://assets/materials/bark.tres")
	mm.mesh = cyl
	_logs.multimesh = mm
	add_child(_logs)


func _refresh_wood(s: GameState) -> void:
	var n := mini(s.camp.wood, WOOD_MAX)
	var mm := _logs.multimesh
	mm.instance_count = n
	var basis := Basis.from_euler(Vector3(0, 0, PI / 2.0))
	for i in n:
		var layer := i / 4
		var idx := i % 4
		var pos := Vector3(0.0, 0.1 + layer * 0.13, (idx - 1.5) * 0.14)
		mm.set_instance_transform(i, Transform3D(basis, pos))
	if s.camp.wood > n:
		_count_at(Vector3(0, 0.1 + 3 * 0.13, 0.0), "+%d" % (s.camp.wood - n))
	elif s.camp.wood > 0:
		_count_at(Vector3(0, 0.1 + ((n - 1) / 4) * 0.13 + 0.14, 0.0), "×%d" % s.camp.wood)


# --- Utilidades ------------------------------------------------------------------

func _count_at(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = 0.003
	l.font_size = 30
	l.outline_size = 8
	l.modulate = Color(1, 0.95, 0.85)
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	_shown.add_child(l)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
