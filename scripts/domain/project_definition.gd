class_name ProjectDefinition
extends Resource
## Plantilla de un proyecto de obra. Solo lectura por convención:
## el estado de cada obra vive en ProjectState, nunca en este Resource.

@export var id: String = ""
## Lugar predeterminado del mapa donde se construye (id estable de contenido).
@export var site_id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var benefit_key: String = ""
@export var cost_uc: int = 0
## Plazo en jornadas. La obra se completa al cierre de la jornada
## (aprobación + plazo - 1) y opera desde la jornada siguiente.
@export var duration_days: int = 1
## Servicio que modifica al completarse.
@export var service_id: String = "water"
@export var capacity_after: int = 0
## Cargo con autoridad para aprobarlo.
@export var required_office: String = "community_organizer"


func cost_cents() -> int:
	return Money.from_units(cost_uc)
