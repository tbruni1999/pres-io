class_name BuildingDefinition
extends Resource
## Construcción propia junto a la choza (fogón, cartel, muelle). Plantilla de solo lectura.

@export var id: String = ""
@export var name_key: String = ""
@export var wood: int = 0
@export var money_uc: int = 0
## Golpes de martillo (skillchecks) para levantarla.
@export var checks: int = 3
## Orden en que se sugiere al jugador.
@export var order: int = 0


func money_cents() -> int:
	return Money.from_units(money_uc)
