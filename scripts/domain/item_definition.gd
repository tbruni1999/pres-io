class_name ItemDefinition
extends Resource
## Plantilla de un objeto (pescado, comida, herramienta). Solo lectura por convención.

enum Kind { CATCH, FOOD, TOOL }

@export var id: String = ""
@export var name_key: String = ""
@export var kind: Kind = Kind.CATCH
## Precio de referencia (los comerciantes definen el suyo). 0 = no tiene precio fijo.
@export var buy_uc: int = 0
@export var sell_uc: int = 0
## Cuánto llena al comerlo o tomarlo, en puntos básicos (10000 = lleno).
@export var food_bp: int = 0
@export var drink_bp: int = 0
## Se echa a perder al cerrar la jornada si sigue en la mochila.
@export var perishable: bool = false

@export_group("Pesca (pescados)")
## Ancho de la zona del skillcheck, en puntos básicos de la barra.
@export var zone_bp: int = 0
## Velocidad de la aguja (barras completas por segundo).
@export var needle_speed: float = 0.0
## Skillchecks seguidos que hay que acertar.
@export var checks: int = 1

@export_group("Herramientas")
## Lugares extra en la mochila al tenerla (conservadora).
@export var bag_bonus: int = 0
## Caña: espera del pique (segundos) y probabilidad de pescado grande (puntos básicos).
@export var bite_min_s: float = 0.0
@export var bite_max_s: float = 0.0
@export var big_chance_bp: int = 0
## Caña: zona extra del skillcheck y multiplicador de velocidad de la aguja.
@export var zone_bonus_bp: int = 0
@export var needle_mult: float = 1.0
## Orden para elegir la mejor caña que tenés.
@export var tier: int = 0


func buy_cents() -> int:
	return Money.from_units(buy_uc)


func sell_cents() -> int:
	return Money.from_units(sell_uc)


func is_rod() -> bool:
	return kind == Kind.TOOL and bite_max_s > 0.0
