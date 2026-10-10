class_name BalanceConfig
extends Resource
## Valores de balance del prototipo (propuestas iniciales, ajustables con pruebas).
## Plantilla de solo lectura por convención: el progreso nunca se guarda acá.

## Pasos administrativos (1 s de simulación cada uno) por jornada.
@export var ticks_per_day: int = 480
## Reloj del juego (minutos desde las 00:00): la jornada va de 06:00 a 24:00.
@export var day_start_minute: int = 360
@export var day_end_minute: int = 1440
## Desde el atardecer baja la luz; desde la noche no pica nada ni pasan comerciantes.
@export var dusk_minute: int = 1170
@export var night_minute: int = 1260
## Si la jornada termina y no estás en la cama, dormís a la intemperie:
## hambre y sed bajan esto (sin bajar de slept_outside_floor_bp).
@export var slept_outside_loss_bp: int = 1500
@export var slept_outside_floor_bp: int = 1000
## Segundos reales por paso administrativo a velocidad normal.
@export var step_seconds: float = 1.0
## Máximo de pasos administrativos que se procesan en un mismo fotograma.
@export var max_steps_per_frame: int = 4
## Fondo comunitario inicial: arranca vacío y se llena con colectas.
@export var starting_cash_uc: int = 0
## Población administrativa del lugar (al principio, solo vos: los vecinos llegan después).
@export var population: int = 0
## Capacidad de agua del pozo deteriorado, en personas abastecidas por jornada.
@export var base_water_capacity: int = 20
## Cargo inicial del jugador; los proyectos declaran qué cargo puede aprobarlos.
@export var starting_office: String = "neighbor"
## Cantidad de informes de cierre que se conservan en la partida.
@export var report_history_limit: int = 30

@export_group("Personaje")
@export var start_wallet_uc: int = 20
@export var start_hunger_bp: int = 7000
@export var start_thirst_bp: int = 7000
@export var start_tools: PackedStringArray = PackedStringArray(["rod_basic"])
## Lo que ya hay al empezar: una fogatita al lado de la carpa.
@export var start_buildings: PackedStringArray = PackedStringArray(["fire"])
## Lo que bajan hambre y sed por paso administrativo (1 s), en puntos básicos.
@export var hunger_decay_bp: int = 14
@export var thirst_decay_bp: int = 21
## Por debajo de este nivel el personaje está cansado: camina lento y no corre.
@export var tired_threshold_bp: int = 2000
@export var bag_capacity: int = 6
## Desmayo: pierde (paso x desmayos previos+1) de su plata, con tope.
@export var faint_penalty_step_bp: int = 1000
@export var faint_penalty_max_bp: int = 5000
@export var faint_wake_bp: int = 3500

@export_group("Lago, fogón y madera")
## Agua del lago cruda: cuánto calma la sed y la probabilidad de que caiga mal.
@export var raw_water_drink_bp: int = 4000
@export var raw_water_sick_bp: int = 3500
@export var raw_water_sick_hunger_bp: int = 3000
## Asado en el fogón: el pescado llena este múltiplo de lo que llena crudo.
@export var cook_multiplier: int = 2
@export var branch_wood: int = 1
@export var tree_wood: int = 3
@export var tree_regrow_days: int = 2
## Muelle: más pescado grande y zona de skillcheck más ancha.
@export var dock_big_bonus_bp: int = 2000
@export var dock_zone_bonus_bp: int = 500

@export_group("Ahumadero")
## Pescados por tanda y pasos que tarda una tanda (90 pasos = 3 h y 22 min de juego).
@export var smoker_capacity: int = 8
@export var smoke_ticks: int = 90

@export_group("Comerciantes")
@export var merchant_passes_per_day: int = 4
## Cuánto espera parado si nadie le compra (pasos de 1 s).
@export var merchant_stop_ticks: int = 45
## Distancia entre vehículos cuando hacen fila frente a la choza (metros).
@export var merchant_queue_gap: float = 7.5
## El primero en pasar el día 1 (para conocer el juego).
@export var first_merchant: String = "ramiro"

@export_group("Agua y colecta")
## Agua que da el pozo roto después de hacer la fila, y el pozo arreglado.
@export var well_drink_broken_bp: int = 2500
@export var well_drink_fixed_bp: int = 10000
## Lo que suman los demás vecinos a la colecta en cada cierre mientras está abierta.
@export var neighbors_daily_donation_uc: int = 30


func starting_cash_cents() -> int:
	return Money.from_units(starting_cash_uc)
