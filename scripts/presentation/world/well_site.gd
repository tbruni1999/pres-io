extends Node3D
## Representación del pozo (lugar well_main). Muestra la variante que corresponde
## al estado de la obra; se puede reconstruir en cualquier momento (p. ej. tras cargar).
## No otorga agua ni cobra nada: solo refleja el estado del dominio.

@export var project_id: String = "well_repair"

@onready var _deteriorated: Node3D = $Deteriorated
@onready var _construction: Node3D = $Construction
@onready var _completed: Node3D = $Completed
@onready var _sign: SignLabel = $SignBoard/Text


func _ready() -> void:
	Game.project_state_changed.connect(_on_project_changed)
	Game.state_replaced.connect(refresh)
	refresh()


func _on_project_changed(changed_id: String) -> void:
	if changed_id == project_id:
		refresh()


func refresh() -> void:
	var p := Game.state.get_project(project_id)
	var status := p.status if p != null else ProjectState.AVAILABLE
	_deteriorated.visible = status == ProjectState.AVAILABLE
	_construction.visible = status == ProjectState.UNDER_CONSTRUCTION
	_completed.visible = status == ProjectState.COMPLETED
	match status:
		ProjectState.UNDER_CONSTRUCTION:
			_sign.set_text_key("SIGN_WELL_WORKS", {"day": p.completion_day})
		ProjectState.COMPLETED:
			var def := Game.content.find_project(project_id)
			_sign.set_text_key("SIGN_WELL_DONE", {"day": p.completed_day, "capacity": def.capacity_after})
		_:
			_sign.set_text_key("SIGN_WELL_BROKEN", {"capacity": Game.state.settlement.base_water_capacity})


## Variante visible actualmente (para pruebas de humo).
func visible_variant() -> String:
	if _completed.visible:
		return ProjectState.COMPLETED
	if _construction.visible:
		return ProjectState.UNDER_CONSTRUCTION
	return ProjectState.AVAILABLE
