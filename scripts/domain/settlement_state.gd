class_name SettlementState
extends RefCounted
## Población administrativa agregada y servicios base del asentamiento.
## No depende de actores 3D: los vecinos visibles solo la representan.

var population: int = 0
## Capacidad de agua sin mejoras (pozo deteriorado), en personas por jornada.
var base_water_capacity: int = 0


static func create(balance: BalanceConfig) -> SettlementState:
	var s := SettlementState.new()
	s.population = balance.population
	s.base_water_capacity = balance.base_water_capacity
	return s


func to_dict() -> Dictionary:
	return {"population": population, "base_water_capacity": base_water_capacity}


static func from_dict(d: Dictionary, r: DictReader) -> SettlementState:
	var s := SettlementState.new()
	s.population = r.get_small_int(d, "population", "settlement", 0, 10_000_000)
	s.base_water_capacity = r.get_small_int(d, "base_water_capacity", "settlement", 0, 10_000_000)
	return s
