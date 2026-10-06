class_name TreasuryState
extends RefCounted
## Única autoridad sobre el fondo comunitario del asentamiento (no la billetera del jugador).
## Invariante: cash = opening + ingresos - pagos, verificable con el libro de movimientos.
## Por ahora: aportes a colectas (ingresos) y pagos de obra. Sin impuestos todavía.

const KIND_PAYMENT := "payment"
const KIND_INCOME := "income"
const KINDS := [KIND_PAYMENT, KIND_INCOME]
const MAX_CENTS := 1_000_000_000_000

var opening_cents: int = 0
var cash_cents: int = 0
## Cada movimiento: {id, day, tick, kind, origin, reason_key, amount_cents, operation_key}
var ledger: Array[Dictionary] = []
var next_entry_id: int = 1


static func create(opening: int) -> TreasuryState:
	var t := TreasuryState.new()
	t.opening_cents = opening
	t.cash_cents = opening
	return t


## Sin sobres presupuestarios todavía: todo el efectivo está disponible.
func available_cents() -> int:
	return cash_cents


func check_payment(amount_cents: int) -> CommandResult:
	if amount_cents <= 0:
		return CommandResult.failure("invalid_amount", Texts.t("ERR_INVALID_AMOUNT"))
	var available := available_cents()
	if amount_cents > available:
		return CommandResult.failure("insufficient_funds", Texts.t("ERR_INSUFFICIENT_FUNDS", {
			"missing": Money.format(amount_cents - available),
			"cost": Money.format(amount_cents),
			"available": Money.format(available),
		}), {"missing_cents": amount_cents - available})
	return CommandResult.success()


## Registra un pago ya validado. Devuelve false (sin mutar) si la validación no se cumple.
func post_payment(amount_cents: int, origin: String, reason_key: String, day: int, tick: int, operation_key: String) -> bool:
	if not check_payment(amount_cents).ok:
		return false
	cash_cents -= amount_cents
	ledger.append({
		"id": next_entry_id,
		"day": day,
		"tick": tick,
		"kind": KIND_PAYMENT,
		"origin": origin,
		"reason_key": reason_key,
		"amount_cents": amount_cents,
		"operation_key": operation_key,
	})
	next_entry_id += 1
	return true


func post_income(amount_cents: int, origin: String, reason_key: String, day: int, tick: int, operation_key: String) -> bool:
	if amount_cents <= 0:
		return false
	cash_cents += amount_cents
	ledger.append({
		"id": next_entry_id,
		"day": day,
		"tick": tick,
		"kind": KIND_INCOME,
		"origin": origin,
		"reason_key": reason_key,
		"amount_cents": amount_cents,
		"operation_key": operation_key,
	})
	next_entry_id += 1
	return true


func total_payments() -> int:
	var total := 0
	for e in ledger:
		if e["kind"] == KIND_PAYMENT:
			total += int(e["amount_cents"])
	return total


func total_income() -> int:
	var total := 0
	for e in ledger:
		if e["kind"] == KIND_INCOME:
			total += int(e["amount_cents"])
	return total


func is_consistent() -> bool:
	return cash_cents == opening_cents + total_income() - total_payments() and cash_cents >= 0


func entries_for_day(day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in ledger:
		if int(e["day"]) == day:
			out.append(e)
	return out


func recent_entries(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(ledger.size() - 1, maxi(-1, ledger.size() - 1 - count), -1):
		out.append(ledger[i])
	return out


func to_dict() -> Dictionary:
	var entries: Array = []
	for e in ledger:
		entries.append({
			"id": e["id"],
			"day": e["day"],
			"tick": str(e["tick"]),
			"kind": e["kind"],
			"origin": e["origin"],
			"reason_key": e["reason_key"],
			"amount_cents": str(e["amount_cents"]),
			"operation_key": e["operation_key"],
		})
	return {
		"opening_cents": str(opening_cents),
		"cash_cents": str(cash_cents),
		"next_entry_id": next_entry_id,
		"ledger": entries,
	}


static func from_dict(d: Dictionary, r: DictReader) -> TreasuryState:
	var t := TreasuryState.new()
	var w := "treasury"
	t.opening_cents = r.get_big_int(d, "opening_cents", w, 0, MAX_CENTS)
	t.cash_cents = r.get_big_int(d, "cash_cents", w, 0, MAX_CENTS)
	t.next_entry_id = r.get_small_int(d, "next_entry_id", w, 1, 100_000_000)
	var last_id := 0
	for item in r.get_array(d, "ledger", w):
		if not (item is Dictionary):
			r.fail(w + ".ledger", "movimiento inválido")
			continue
		var we := w + ".ledger[%d]" % t.ledger.size()
		var e := {
			"id": r.get_small_int(item, "id", we, 1, 100_000_000),
			"day": r.get_small_int(item, "day", we, 1, 1_000_000),
			"tick": r.get_big_int(item, "tick", we, 0, 1 << 62),
			"kind": r.get_string(item, "kind", we, KINDS),
			"origin": r.get_string(item, "origin", we),
			"reason_key": r.get_string(item, "reason_key", we),
			"amount_cents": r.get_big_int(item, "amount_cents", we, 1, MAX_CENTS),
			"operation_key": r.get_string(item, "operation_key", we),
		}
		if int(e["id"]) <= last_id:
			r.fail(we, "ids de movimientos fuera de orden")
		last_id = int(e["id"])
		t.ledger.append(e)
	if t.next_entry_id <= last_id:
		r.fail(w + ".next_entry_id", "menor o igual al último movimiento")
	if r.ok() and not t.is_consistent():
		r.fail(w, "la caja no coincide con fondo inicial + ingresos - pagos")
	return t
