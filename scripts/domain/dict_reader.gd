class_name DictReader
extends RefCounted
## Lectura validada de diccionarios provenientes de JSON (partidas guardadas).
## Acumula errores legibles en lugar de fallar en el primer problema.
## Los enteros grandes (dinero, ticks, estado RNG) se leen desde cadenas decimales.

const MAX_INT_DIGITS := 19
const INT64_MAX := 9223372036854775807
const INT64_MIN := -9223372036854775807 - 1

var errors: PackedStringArray = PackedStringArray()


func ok() -> bool:
	return errors.is_empty()


func fail(where: String, what: String) -> void:
	errors.append("%s: %s" % [where, what])


func get_dict(d: Dictionary, key: String, where: String) -> Dictionary:
	var v: Variant = d.get(key)
	if v is Dictionary:
		return v
	fail(where + "." + key, "se esperaba un objeto")
	return {}


func get_array(d: Dictionary, key: String, where: String) -> Array:
	var v: Variant = d.get(key)
	if v is Array:
		return v
	fail(where + "." + key, "se esperaba una lista")
	return []


func get_string(d: Dictionary, key: String, where: String, allowed: Array = []) -> String:
	var v: Variant = d.get(key)
	if not (v is String):
		fail(where + "." + key, "se esperaba texto")
		return ""
	if not allowed.is_empty() and not allowed.has(v):
		fail(where + "." + key, "valor no permitido '%s'" % v)
	return v


func get_bool(d: Dictionary, key: String, where: String) -> bool:
	var v: Variant = d.get(key)
	if v is bool:
		return v
	fail(where + "." + key, "se esperaba verdadero/falso")
	return false


## Entero pequeño guardado como número JSON (JSON no distingue int de float).
func get_small_int(d: Dictionary, key: String, where: String, min_v: int, max_v: int) -> int:
	var v: Variant = d.get(key)
	if v is int:
		return _check_range(int(v), where + "." + key, min_v, max_v)
	if v is float and is_finite(v) and float(v) == floorf(v) and absf(v) < 1.0e9:
		return _check_range(int(v), where + "." + key, min_v, max_v)
	fail(where + "." + key, "se esperaba un número entero")
	return min_v


## Entero de 64 bits guardado como cadena decimal para no perder precisión.
func get_big_int(d: Dictionary, key: String, where: String, min_v: int, max_v: int) -> int:
	var v: Variant = d.get(key)
	if not (v is String) or not _is_decimal(v):
		fail(where + "." + key, "se esperaba un entero en cadena decimal")
		return min_v
	return _check_range(String(v).to_int(), where + "." + key, min_v, max_v)


func get_finite_float(arr: Array, index: int, where: String) -> float:
	if index >= arr.size():
		fail(where, "faltan componentes")
		return 0.0
	var v: Variant = arr[index]
	if (v is float or v is int) and is_finite(float(v)):
		return float(v)
	fail(where, "se esperaba un número finito")
	return 0.0


func _check_range(value: int, where: String, min_v: int, max_v: int) -> int:
	if value < min_v or value > max_v:
		fail(where, "fuera de rango [%d, %d]: %d" % [min_v, max_v, value])
		return min_v
	return value


static func _is_decimal(s: String) -> bool:
	var body := s.substr(1) if s.begins_with("-") else s
	if body.is_empty() or body.length() > MAX_INT_DIGITS:
		return false
	for c in body:
		if c < "0" or c > "9":
			return false
	# 19 dígitos puede superar int64: se compara como texto contra el máximo.
	if body.length() == MAX_INT_DIGITS:
		var limit := "9223372036854775808" if s.begins_with("-") else "9223372036854775807"
		return body <= limit
	return true
