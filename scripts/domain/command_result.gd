class_name CommandResult
extends RefCounted
## Resultado de un comando del dominio: éxito o código de error con explicación legible.
## Un comando rechazado nunca deja mutaciones parciales.

const OK := "ok"
const DUPLICATE := "duplicate"

var ok: bool = false
var code: String = ""
var message: String = ""
var data: Dictionary = {}


static func success(message_text: String = "", payload: Dictionary = {}) -> CommandResult:
	var r := CommandResult.new()
	r.ok = true
	r.code = OK
	r.message = message_text
	r.data = payload
	return r


## Operación ya procesada antes con la misma clave: éxito sin efectos nuevos.
static func already_applied(message_text: String) -> CommandResult:
	var r := success(message_text)
	r.code = DUPLICATE
	return r


static func failure(error_code: String, message_text: String, payload: Dictionary = {}) -> CommandResult:
	var r := CommandResult.new()
	r.ok = false
	r.code = error_code
	r.message = message_text
	r.data = payload
	return r


func is_duplicate() -> bool:
	return code == DUPLICATE
