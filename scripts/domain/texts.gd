class_name Texts
extends RefCounted
## Acceso único a los textos centralizados (data/text/strings.csv).
## Las claves se traducen con TranslationServer y admiten parámetros {nombre}.


static func t(key: String, params: Dictionary = {}) -> String:
	var text := String(TranslationServer.translate(key))
	if params.is_empty():
		return text
	return text.format(params)
