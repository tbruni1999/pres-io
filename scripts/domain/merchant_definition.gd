class_name MerchantDefinition
extends Resource
## Comerciante que pasa por el camino frente a la choza. Plantilla de solo lectura.

@export var id: String = ""
@export var name_key: String = ""
## Vehículo para la representación: horse, car, truck.
@export var vehicle: String = "horse"
## Pasos administrativos (segundos) que tarda en cruzar el camino entero.
@export var crossing_ticks: int = 60
## Lo que compra: item_id -> precio en UC por unidad.
@export var buys: Dictionary = {}
## Máximo de objetos que compra en una parada.
@export var max_buy: int = 6
## Lo que vende: item_id -> precio en UC.
@export var sells: Dictionary = {}
## Construcción necesaria para que empiece a pasar ("" = desde el principio).
@export var requires_building: String = ""
## Peso relativo al sortear quién pasa.
@export var weight: int = 1
## Prefijo de sus frases en strings.csv (p. ej. RAMIRO -> RAMIRO_GREET_1...).
@export var lines_prefix: String = ""


func buy_price_cents(item_id: String) -> int:
	return Money.from_units(int(buys.get(item_id, 0)))


func sell_price_cents(item_id: String) -> int:
	return Money.from_units(int(sells.get(item_id, 0)))
## Hecho que queda registrado en el jugador al terminar su historia por entregas
## (ej. Coco: "has_dog", el perro polizón baja del camión).
@export var story_end_fact: String = ""
