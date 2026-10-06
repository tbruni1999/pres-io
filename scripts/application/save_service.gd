class_name SaveService
extends RefCounted
## Guardado y carga de partidas en JSON versionado dentro de user://saves.
##
## Escritura: instantánea -> archivo temporal -> verificación -> el guardado anterior
## pasa a .bak -> el temporal reemplaza al guardado. Si algo falla se intenta
## restaurar el anterior. No se afirma atomicidad absoluta: ver docs/SAVE_SCHEMA.md.
##
## Carga: se valida completa en un GameState temporal; la sesión activa solo se
## reemplaza si todo es válido.

const DEFAULT_DIR := "user://saves"

var save_dir: String = DEFAULT_DIR


func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


func slot_exists(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")


func write_state(state: GameState, content: GameContent, game_version: String, slot: String) -> CommandResult:
	var dir_err := DirAccess.make_dir_recursive_absolute(save_dir)
	if dir_err != OK and not DirAccess.dir_exists_absolute(save_dir):
		return CommandResult.failure("save_dir", Texts.t("ERR_SAVE_DIR", {"error": error_string(dir_err)}))

	var final_path := slot_path(slot)
	var tmp_path := final_path + ".tmp"
	var bak_path := final_path + ".bak"
	var text := JSON.stringify(state.to_dict(game_version), "\t")

	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return CommandResult.failure("save_open", Texts.t("ERR_SAVE_WRITE", {"error": error_string(FileAccess.get_open_error())}))
	var stored := f.store_string(text)
	var write_err := f.get_error()
	f.close()
	if not stored or write_err != OK:
		DirAccess.remove_absolute(tmp_path)
		return CommandResult.failure("save_write", Texts.t("ERR_SAVE_WRITE", {"error": error_string(write_err)}))

	# Verificar que el temporal se puede volver a leer y validar antes de reemplazar nada.
	var check := read_file(tmp_path, content)
	if not check["ok"]:
		DirAccess.remove_absolute(tmp_path)
		return CommandResult.failure("save_verify", Texts.t("ERR_SAVE_VERIFY", {"error": check["message"]}))

	if FileAccess.file_exists(final_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var bak_err := DirAccess.rename_absolute(final_path, bak_path)
		if bak_err != OK:
			DirAccess.remove_absolute(tmp_path)
			return CommandResult.failure("save_backup", Texts.t("ERR_SAVE_WRITE", {"error": error_string(bak_err)}))
	var move_err := DirAccess.rename_absolute(tmp_path, final_path)
	if move_err != OK:
		if FileAccess.file_exists(bak_path) and not FileAccess.file_exists(final_path):
			DirAccess.rename_absolute(bak_path, final_path)
		return CommandResult.failure("save_replace", Texts.t("ERR_SAVE_WRITE", {"error": error_string(move_err)}))
	return CommandResult.success(Texts.t("MSG_SAVED", {"day": state.current_day()}), {"path": final_path, "bytes": text.length()})


## Lee un slot. Si el principal falta o es inválido, prueba la copia anterior (.bak).
## Devuelve {"ok", "state", "message", "from_backup"}.
func read_slot(slot: String, content: GameContent) -> Dictionary:
	var main_path := slot_path(slot)
	var bak_path := main_path + ".bak"
	if not FileAccess.file_exists(main_path) and not FileAccess.file_exists(bak_path):
		return {"ok": false, "state": null, "message": Texts.t("ERR_NO_SAVE"), "from_backup": false}
	var result := {"ok": false, "state": null, "message": "", "from_backup": false}
	if FileAccess.file_exists(main_path):
		result = read_file(main_path, content)
		result["from_backup"] = false
		# Una versión futura no se reemplaza por una copia vieja en silencio.
		if result["ok"] or result.get("future_version", false):
			return result
	if FileAccess.file_exists(bak_path):
		var bak := read_file(bak_path, content)
		if bak["ok"]:
			bak["from_backup"] = true
			bak["message"] = Texts.t("MSG_LOADED_FROM_BACKUP", {"error": result["message"]})
			return bak
	return result


func read_file(path: String, content: GameContent) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "state": null, "message": Texts.t("ERR_LOAD_OPEN", {"error": error_string(FileAccess.get_open_error())})}
	var text := f.get_as_text()
	f.close()
	return parse_text(text, content)


func parse_text(text: String, content: GameContent) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "state": null, "message": Texts.t("ERR_LOAD_CORRUPT", {"error": "línea %d: %s" % [json.get_error_line(), json.get_error_message()]})}
	if not (json.data is Dictionary):
		return {"ok": false, "state": null, "message": Texts.t("ERR_LOAD_CORRUPT", {"error": "la raíz no es un objeto"})}
	var parsed := GameState.from_dict(json.data, content)
	if parsed["future_version"]:
		return {"ok": false, "state": null, "future_version": true, "message": Texts.t("ERR_LOAD_FUTURE", {"error": "; ".join(parsed["errors"])})}
	if parsed["state"] == null:
		var errors: PackedStringArray = parsed["errors"]
		var shown := errors.slice(0, 3)
		return {"ok": false, "state": null, "message": Texts.t("ERR_LOAD_INVALID", {"error": "; ".join(shown), "count": errors.size()})}
	return {"ok": true, "state": parsed["state"], "message": ""}
