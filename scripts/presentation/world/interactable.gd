class_name Interactable
extends StaticBody3D
## Objeto con el que el jugador puede interactuar (capa de física "interactable").
## La interacción solo abre un diálogo, una inspección o el escritorio:
## nunca modifica dinero ni estado por sí misma.

enum Kind { DIALOGUE, INSPECT, DESK }

@export var kind: Kind = Kind.INSPECT
## Id estable del contenido (vecino, lugar u objeto): neighbor_rosa, well_main, office_desk.
@export var target_id: String = ""
@export var action_key: String = "ACTION_INSPECT"
@export var name_key: String = ""
@export var enabled: bool = true


func prompt_text() -> String:
	return Texts.t(action_key, {"name": Texts.t(name_key)})
