class_name Money
extends RefCounted
## Dinero del dominio: siempre enteros de centésimos de UC (nunca float).
## La UI muestra unidades con formato local (punto de miles, coma decimal).

const CENTS_PER_UNIT := 100


static func from_units(units: int) -> int:
	return units * CENTS_PER_UNIT


static func format(cents: int) -> String:
	var negative := cents < 0
	var abs_cents := absi(cents)
	var units := abs_cents / CENTS_PER_UNIT
	var rest := abs_cents % CENTS_PER_UNIT
	var digits := str(units)
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "." + grouped
	if rest != 0:
		grouped += ",%02d" % rest
	return ("-" if negative else "") + grouped + " UC"


## Formatea puntos básicos (10000 = 100 %) como porcentaje entero redondeado hacia abajo.
static func format_bp_percent(basis_points: int) -> String:
	return "%d %%" % (basis_points / 100)
