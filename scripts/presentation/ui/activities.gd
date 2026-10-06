class_name Activities
extends RefCounted
## Actividades concretas. Cada una termina emitiendo un comando a Game.


## Pesca en loop: esperar pique -> skillcheck(s) -> resultado -> volver a tirar.
class Fishing extends Activity:
	var spot := "shore"
	var _phase := "wait"
	var _timer := 0.0
	var _cast: Dictionary = {}
	var _checks_left := 0
	var _all_perfect := true

	func begin() -> void:
		ui.skill_check.resolved.connect(_on_check)
		_cast_line()

	func _cast_line() -> void:
		_cast = Game.cast_line(spot)
		if not _cast["ok"]:
			ui.post_notice(_cast["message"])
			end()
			return
		_phase = "wait"
		_timer = float(_cast["delay_s"])
		title = Texts.t("FISH_WAITING")

	func process(delta: float) -> void:
		if _phase == "wait" or _phase == "rest":
			_timer -= delta
			if _timer <= 0.0:
				if _phase == "wait":
					_bite()
				else:
					_cast_line()

	func _bite() -> void:
		_phase = "check"
		_checks_left = int(_cast["checks"])
		_all_perfect = true
		_next_check()

	func _next_check() -> void:
		var total := int(_cast["checks"])
		title = Texts.t("FISH_BITE")
		if total > 1:
			title += "  " + Texts.t("FISH_CHECK_N", {"i": total - _checks_left + 1, "n": total})
		ui.skill_check.start(int(_cast["zone_bp"]), float(_cast["speed"]))
		ui.play_sfx("bite")

	func on_interact() -> bool:
		if _phase == "check":
			ui.skill_check.press()
		return true

	func _on_check(result: String) -> void:
		if done or _phase != "check":
			return
		if result == SkillCheck.MISS:
			ui.post_notice(Texts.t("FISH_ESCAPED"))
			ui.play_feedback(false)
			_rest()
			return
		_all_perfect = _all_perfect and result == SkillCheck.PERFECT
		_checks_left -= 1
		if _checks_left > 0:
			_next_check()
			return
		var r := Game.land_fish(String(_cast["fish_id"]), _all_perfect)
		ui.post_notice(r.message)
		ui.play_feedback(r.ok)
		_rest()

	func _rest() -> void:
		_phase = "rest"
		_timer = 1.2
		title = ""

	func status_text() -> String:
		return title + "\n" + Texts.t("FISH_STOP_HINT") if not title.is_empty() else Texts.t("FISH_STOP_HINT")

	func end() -> void:
		if ui.skill_check.resolved.is_connected(_on_check):
			ui.skill_check.resolved.disconnect(_on_check)
		super()


## Serie de golpes (martillo o hacha). on_done(success) recibe el resultado.
class Strikes extends Activity:
	var total := 3
	var zone_bp := 2400
	var speed := 1.0
	## Martillar: un error solo repite el golpe. Talar: un error termina.
	var retry_on_miss := true
	var label_key := "BUILD_HAMMER"
	var miss_key := "BUILD_MISSED"
	var on_done: Callable
	var _i := 0

	func begin() -> void:
		ui.skill_check.resolved.connect(_on_check)
		_next()

	func _next() -> void:
		title = Texts.t(label_key, {"i": _i + 1, "n": total})
		ui.skill_check.start(zone_bp, speed)

	func on_interact() -> bool:
		ui.skill_check.press()
		return true

	func _on_check(result: String) -> void:
		if done:
			return
		if result == SkillCheck.MISS:
			ui.play_feedback(false)
			if retry_on_miss:
				ui.post_notice(Texts.t(miss_key))
				_next()
			else:
				on_done.call(false)
				end()
			return
		ui.play_sfx("hit")
		_i += 1
		if _i >= total:
			on_done.call(true)
			end()
		else:
			_next()

	func status_text() -> String:
		return title + "\n" + Texts.t("ACTIVITY_CANCEL_HINT")

	func end() -> void:
		if ui.skill_check.resolved.is_connected(_on_check):
			ui.skill_check.resolved.disconnect(_on_check)
		super()


## Mantener E apretada un rato (juntar ramas, tomar agua del lago).
class Hold extends Activity:
	var seconds := 2.0
	var on_done: Callable
	var _t := 0.0

	func process(delta: float) -> void:
		if not Input.is_action_pressed("interact"):
			end()
			return
		_t += delta
		if _t >= seconds:
			on_done.call()
			end()

	func on_interact() -> bool:
		return true

	func progress() -> float:
		return clampf(_t / seconds, 0.0, 1.0)
