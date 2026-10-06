class_name Interactable
extends StaticBody3D
## Objeto con el que el jugador puede interactuar (capa de física "interactable").
## La interacción abre un panel o arranca una actividad; nunca modifica estado por sí misma.
## El texto de la acción lo arma UIRoot según el estado actual.

enum Kind { DIALOGUE, FISH, SLEEP, BRANCHES, TREE, BUILD, LAKE_WATER }

@export var kind: Kind = Kind.FISH
## Id estable del contenido: lugar de pesca ("shore"/"dock"), árbol, montón de ramas, construcción.
@export var target_id: String = ""
@export var name_key: String = ""
@export var enabled: bool = true
