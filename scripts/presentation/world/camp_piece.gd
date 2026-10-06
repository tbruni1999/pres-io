class_name CampPiece
extends Node3D
## Pieza del campamento que cambia según el estado: lugar de construcción, árbol o ramas.
## Muestra $Before o $After y desactiva las colisiones de la variante oculta.

enum Mode { BUILDING, TREE, BRANCHES }

@export var mode: Mode = Mode.BUILDING
## Construcción (fire/sign/dock), árbol (tree_1...) o montón de ramas (branches_1...).
@export var target_id: String = ""

@onready var _before: Node3D = $Before
@onready var _after: Node3D = get_node_or_null("After")


func _ready() -> void:
	# Los interactuables de la pieza heredan su id (así una escena sirve para varios árboles).
	_assign_ids(self)
	Game.camp_changed.connect(refresh)
	Game.state_replaced.connect(refresh)
	Game.day_closed.connect(func(_r: DayReport) -> void: refresh())
	refresh()


func refresh() -> void:
	var s := Game.state
	var changed := false
	match mode:
		Mode.BUILDING:
			changed = s.camp.has_building(target_id)
		Mode.TREE:
			changed = not PlayerActions.tree_available(s, Game.content, target_id)
		Mode.BRANCHES:
			changed = s.camp.branches_taken.has(target_id)
	_show(_before, not changed)
	if _after != null:
		_show(_after, changed)


func _assign_ids(n: Node) -> void:
	for c in n.get_children():
		if c is Interactable and (c as Interactable).target_id.is_empty():
			(c as Interactable).target_id = target_id
		_assign_ids(c)


## Ocultar también saca del espacio físico sus cuerpos (disable_mode REMOVE por defecto).
static func _show(n: Node3D, on: bool) -> void:
	n.visible = on
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
