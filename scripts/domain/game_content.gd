class_name GameContent
extends Resource
## Contenido de definición: balance y catálogo de proyectos (plantillas de solo lectura).

@export var balance: BalanceConfig
## Lista de ProjectDefinition. Se declara como Array simple para que el .tres sea editable a mano.
@export var projects: Array = []
## Sujetos que pueden tener hechos narrativos guardados (jugador y vecinos con nombre).
@export var fact_subjects: PackedStringArray = PackedStringArray()


func find_project(project_id: String) -> ProjectDefinition:
	for p in projects:
		var def := p as ProjectDefinition
		if def != null and def.id == project_id:
			return def
	return null


## IDs ordenados de forma estable para procesar en orden determinista.
func project_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for p in projects:
		var def := p as ProjectDefinition
		if def != null:
			ids.append(def.id)
	ids.sort()
	return ids
