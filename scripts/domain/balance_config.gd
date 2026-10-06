class_name BalanceConfig
extends Resource
## Valores de balance del prototipo (propuestas iniciales, ajustables con pruebas).
## Plantilla de solo lectura por convención: el progreso nunca se guarda acá.

## Pasos administrativos (1 s de simulación cada uno) por jornada.
@export var ticks_per_day: int = 360
## Segundos reales por paso administrativo a velocidad normal.
@export var step_seconds: float = 1.0
## Máximo de pasos administrativos que se procesan en un mismo fotograma.
@export var max_steps_per_frame: int = 4
@export var starting_cash_uc: int = 10000
@export var population: int = 60
## Capacidad de agua del pozo deteriorado, en personas abastecidas por jornada.
@export var base_water_capacity: int = 20
## Cargo inicial del jugador; los proyectos declaran qué cargo puede aprobarlos.
@export var starting_office: String = "community_organizer"
## Cantidad de informes de cierre que se conservan en la partida.
@export var report_history_limit: int = 30


func starting_cash_cents() -> int:
	return Money.from_units(starting_cash_uc)
