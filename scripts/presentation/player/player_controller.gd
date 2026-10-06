class_name PlayerController
extends CharacterBody3D
## Jugador en primera persona: caminar, mirar e interactuar.
## La interacción usa una única consulta de rayo desde la cámara (alcance 2,5 m)
## que respeta paredes: si lo primero que toca es un muro, no hay objetivo.

signal focus_changed(target: Interactable)
signal interaction_requested(target: Interactable)

const LAYER_WORLD := 1
const LAYER_INTERACTABLE := 4
const REFERENCE_ASPECT := 16.0 / 9.0

@export var walk_speed: float = 4.0
@export var run_speed: float = 6.0
@export var acceleration: float = 30.0
@export var interact_range: float = 2.5
@export var step_distance: float = 0.75

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _steps: AudioStreamPlayer = $Footsteps

var input_enabled: bool = true
var _pitch: float = 0.0
var _focus: Interactable = null
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _step_accum: float = 0.0
## Aleatoriedad cosmética: no consume el generador administrativo de la partida.
var _cosmetic_rng := RandomNumberGenerator.new()


func _ready() -> void:
	Game.settings.changed.connect(_apply_settings)
	_apply_settings()


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_focus(null)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := Game.settings.mouse_sensitivity
		rotate_y(deg_to_rad(-motion.relative.x * sens))
		var invert := -1.0 if Game.settings.invert_y else 1.0
		_pitch = clampf(_pitch - motion.relative.y * sens * invert, -85.0, 85.0)
		_head.rotation_degrees.x = _pitch
	elif event.is_action_pressed("interact") and _focus != null:
		get_viewport().set_input_as_handled()
		interaction_requested.emit(_focus)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var target := Vector3.ZERO
	var speed := walk_speed
	if input_enabled:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var dir := global_basis * Vector3(iv.x, 0.0, iv.y)
		dir.y = 0.0
		if dir.length_squared() > 1.0:
			dir = dir.normalized()
		if Input.is_action_pressed("sprint"):
			speed = run_speed
		target = dir * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()
	_update_footsteps(delta)
	_update_focus()


func _update_focus() -> void:
	if not input_enabled:
		_set_focus(null)
		return
	var from := _camera.global_position
	var to := from - _camera.global_basis.z * interact_range
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD | LAYER_INTERACTABLE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Interactable = null
	if not hit.is_empty():
		var collider := hit["collider"] as Interactable
		if collider != null and collider.enabled:
			target = collider
	_set_focus(target)


func _set_focus(target: Interactable) -> void:
	if target == _focus:
		return
	_focus = target
	focus_changed.emit(target)


func current_focus() -> Interactable:
	return _focus


func _update_footsteps(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or horizontal < 0.5:
		_step_accum = 0.0
		return
	_step_accum += horizontal * delta
	if _step_accum >= step_distance:
		_step_accum = 0.0
		_steps.pitch_scale = _cosmetic_rng.randf_range(0.9, 1.1)
		_steps.play()


## Pose para guardar: posición y orientación de cámara.
func get_pose() -> Dictionary:
	return {"position": global_position, "yaw": rotation.y, "pitch": _pitch}


func apply_pose(pose: Dictionary) -> void:
	global_position = pose["position"]
	rotation = Vector3(0.0, float(pose["yaw"]), 0.0)
	_pitch = float(pose["pitch"])
	_head.rotation_degrees.x = _pitch
	velocity = Vector3.ZERO


## El ajuste es un FOV HORIZONTAL referido a 16:9. Camera3D.fov, con keep_aspect
## KEEP_HEIGHT (por defecto), es el FOV VERTICAL: se convierte para que 80° horizontales
## en 16:9 equivalgan a ~49,4° verticales. En pantallas más anchas se ve más a los costados.
func _apply_settings() -> void:
	var h := deg_to_rad(Game.settings.fov_horizontal)
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = rad_to_deg(2.0 * atan(tan(h * 0.5) / REFERENCE_ASPECT))
