class_name GameContent
extends Resource
## Contenido de definición: balance y catálogo de proyectos (plantillas de solo lectura).

@export var balance: BalanceConfig
## Lista de ProjectDefinition. Se declara como Array simple para que el .tres sea editable a mano.
@export var projects: Array = []
## Lista de ItemDefinition (pescados, comida, herramientas).
@export var items: Array = []
## Lista de MerchantDefinition.
@export var merchants: Array = []
## Lista de BuildingDefinition.
@export var buildings: Array = []
## Sujetos que pueden tener hechos narrativos guardados (jugador y vecinos con nombre).
@export var fact_subjects: PackedStringArray = PackedStringArray()


func find_project(project_id: String) -> ProjectDefinition:
	for p in projects:
		var def := p as ProjectDefinition
		if def != null and def.id == project_id:
			return def
	return null


func find_item(item_id: String) -> ItemDefinition:
	for i in items:
		var def := i as ItemDefinition
		if def != null and def.id == item_id:
			return def
	return null


func find_merchant(merchant_id: String) -> MerchantDefinition:
	for m in merchants:
		var def := m as MerchantDefinition
		if def != null and def.id == merchant_id:
			return def
	return null


func find_building(building_id: String) -> BuildingDefinition:
	for b in buildings:
		var def := b as BuildingDefinition
		if def != null and def.id == building_id:
			return def
	return null


func sorted_buildings() -> Array[BuildingDefinition]:
	var out: Array[BuildingDefinition] = []
	for b in buildings:
		if b is BuildingDefinition:
			out.append(b)
	out.sort_custom(func(a: BuildingDefinition, c: BuildingDefinition) -> bool: return a.order < c.order)
	return out


func items_of_kind(kind: ItemDefinition.Kind) -> Array[ItemDefinition]:
	var out: Array[ItemDefinition] = []
	for i in items:
		var def := i as ItemDefinition
		if def != null and def.kind == kind:
			out.append(def)
	return out


## IDs ordenados de forma estable para procesar en orden determinista.
func project_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for p in projects:
		var def := p as ProjectDefinition
		if def != null:
			ids.append(def.id)
	ids.sort()
	return ids
