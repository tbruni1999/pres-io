class_name PlayerState
extends RefCounted
## El personaje: billetera propia, hambre, sed, mochila y herramientas.
## La billetera es independiente del fondo comunitario (TreasuryState).
## Invariante: wallet = opening + ganado - gastado.

const FULL := 10000

var opening_cents: int = 0
var wallet_cents: int = 0
var earned_total_cents: int = 0
var spent_total_cents: int = 0
var hunger_bp: int = FULL
var thirst_bp: int = FULL
## item_id -> cantidad (solo objetos que se cargan en la mochila).
var bag: Dictionary = {}
var tools: PackedStringArray = PackedStringArray()
## Usos que le quedan a cada herramienta que se gasta (tool_id -> usos).
var tool_wear: Dictionary = {}
var faint_count: int = 0
var donated_total_cents: int = 0
var fish_caught_total: int = 0
## Contadores de la jornada en curso (se guardan en el informe y se reinician al cerrar).
var day_earned_cents: int = 0
var day_spent_cents: int = 0
var day_fish: int = 0
var day_faint_penalty_cents: int = 0
var day_fainted: bool = false
## Se desmayó en este paso; la sesión lo atiende enseguida (no se guarda).
var faint_pending: bool = false


static func create(balance: BalanceConfig) -> PlayerState:
	var p := PlayerState.new()
	p.opening_cents = Money.from_units(balance.start_wallet_uc)
	p.wallet_cents = p.opening_cents
	p.hunger_bp = balance.start_hunger_bp
	p.thirst_bp = balance.start_thirst_bp
	p.tools = PackedStringArray(balance.start_tools)
	return p


## Agrega una herramienta nueva con todos sus usos.
func add_tool(def: ItemDefinition) -> void:
	if not tools.has(def.id):
		tools.append(def.id)
	if def.durability > 0:
		tool_wear[def.id] = def.durability


## Gasta un uso. Devuelve true si con ese uso se rompió (y la saca).
func wear_tool(tool_id: String) -> bool:
	if not tool_wear.has(tool_id):
		return false
	var left := int(tool_wear[tool_id]) - 1
	if left > 0:
		tool_wear[tool_id] = left
		return false
	tool_wear.erase(tool_id)
	tools.remove_at(tools.find(tool_id))
	return true


func bag_count() -> int:
	var n := 0
	for id in bag:
		n += int(bag[id])
	return n


func count(item_id: String) -> int:
	return int(bag.get(item_id, 0))


func has_tool(item_id: String) -> bool:
	return tools.has(item_id)


func earn(cents: int) -> void:
	wallet_cents += cents
	earned_total_cents += cents
	day_earned_cents += cents


## Gasta solo si alcanza. Devuelve false sin cambiar nada si no alcanza.
func spend(cents: int) -> bool:
	if cents <= 0 or cents > wallet_cents:
		return false
	wallet_cents -= cents
	spent_total_cents += cents
	day_spent_cents += cents
	return true


func add_item(item_id: String, n: int) -> void:
	bag[item_id] = count(item_id) + n


func remove_item(item_id: String, n: int) -> bool:
	if n <= 0 or count(item_id) < n:
		return false
	var left := count(item_id) - n
	if left == 0:
		bag.erase(item_id)
	else:
		bag[item_id] = left
	return true


func reset_day() -> void:
	day_earned_cents = 0
	day_spent_cents = 0
	day_fish = 0
	day_faint_penalty_cents = 0
	day_fainted = false


func is_consistent() -> bool:
	return wallet_cents == opening_cents + earned_total_cents - spent_total_cents and wallet_cents >= 0


func to_dict() -> Dictionary:
	var items: Array = []
	var keys := bag.keys()
	keys.sort()
	for k in keys:
		items.append({"id": k, "count": bag[k]})
	return {
		"opening_cents": str(opening_cents),
		"wallet_cents": str(wallet_cents),
		"earned_total_cents": str(earned_total_cents),
		"spent_total_cents": str(spent_total_cents),
		"hunger_bp": hunger_bp,
		"thirst_bp": thirst_bp,
		"bag": items,
		"tools": Array(tools),
		"tool_wear": _wear_to_list(),
		"faint_count": faint_count,
		"donated_total_cents": str(donated_total_cents),
		"fish_caught_total": fish_caught_total,
		"day_earned_cents": str(day_earned_cents),
		"day_spent_cents": str(day_spent_cents),
		"day_fish": day_fish,
		"day_faint_penalty_cents": str(day_faint_penalty_cents),
		"day_fainted": day_fainted,
	}


func _wear_to_list() -> Array:
	var out: Array = []
	var keys := tool_wear.keys()
	keys.sort()
	for k in keys:
		out.append({"id": k, "uses": tool_wear[k]})
	return out


static func from_dict(d: Dictionary, r: DictReader, content: GameContent) -> PlayerState:
	var p := PlayerState.new()
	var w := "player_state"
	var big := TreasuryState.MAX_CENTS
	p.opening_cents = r.get_big_int(d, "opening_cents", w, 0, big)
	p.wallet_cents = r.get_big_int(d, "wallet_cents", w, 0, big)
	p.earned_total_cents = r.get_big_int(d, "earned_total_cents", w, 0, big)
	p.spent_total_cents = r.get_big_int(d, "spent_total_cents", w, 0, big)
	p.hunger_bp = r.get_small_int(d, "hunger_bp", w, 0, FULL)
	p.thirst_bp = r.get_small_int(d, "thirst_bp", w, 0, FULL)
	for item in r.get_array(d, "bag", w):
		if item is Dictionary:
			var id := r.get_string(item, "id", w + ".bag")
			if content.find_item(id) == null:
				r.fail(w + ".bag", "objeto desconocido '%s'" % id)
			p.bag[id] = r.get_small_int(item, "count", w + ".bag", 1, 100000)
		else:
			r.fail(w + ".bag", "entrada inválida")
	for t in r.get_array(d, "tools", w):
		if t is String and content.find_item(t) != null:
			p.tools.append(t)
		else:
			r.fail(w + ".tools", "herramienta desconocida")
	for t in r.get_array(d, "tool_wear", w):
		if not (t is Dictionary):
			r.fail(w + ".tool_wear", "entrada inválida")
			continue
		var tid := r.get_string(t, "id", w + ".tool_wear")
		if not p.tools.has(tid):
			r.fail(w + ".tool_wear", "desgaste de una herramienta que no tiene '%s'" % tid)
		p.tool_wear[tid] = r.get_small_int(t, "uses", w + ".tool_wear", 1, 1_000_000)
	for t in p.tools:
		var def := content.find_item(t)
		if def != null and def.durability > 0 and not p.tool_wear.has(t):
			r.fail(w + ".tool_wear", "falta el desgaste de '%s'" % t)
	p.faint_count = r.get_small_int(d, "faint_count", w, 0, 100000)
	p.donated_total_cents = r.get_big_int(d, "donated_total_cents", w, 0, big)
	p.fish_caught_total = r.get_small_int(d, "fish_caught_total", w, 0, 100_000_000)
	p.day_earned_cents = r.get_big_int(d, "day_earned_cents", w, 0, big)
	p.day_spent_cents = r.get_big_int(d, "day_spent_cents", w, 0, big)
	p.day_fish = r.get_small_int(d, "day_fish", w, 0, 100000)
	p.day_faint_penalty_cents = r.get_big_int(d, "day_faint_penalty_cents", w, 0, big)
	p.day_fainted = r.get_bool(d, "day_fainted", w)
	if r.ok() and not p.is_consistent():
		r.fail(w, "la billetera no coincide con lo ganado y gastado")
	return p
