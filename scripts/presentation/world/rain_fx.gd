class_name RainFx
extends Node3D
## Lluvia cosmética alrededor del jugador: CPUParticles3D (funciona en Compatibility),
## sin sombras, con gotas finas. Se prende/apaga según Weather.is_raining (4 veces por segundo).

const AREA := Vector3(26, 1, 26)

var target: Node3D
var _particles := CPUParticles3D.new()
var _timer := 0.0


func _ready() -> void:
	var drop := QuadMesh.new()
	drop.size = Vector2(0.015, 0.45)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.82, 0.92, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	drop.material = mat
	_particles.mesh = drop
	_particles.amount = 900
	_particles.lifetime = 0.9
	_particles.preprocess = 0.9
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = AREA * 0.5
	_particles.direction = Vector3(0.08, -1, 0)
	_particles.spread = 2.0
	_particles.initial_velocity_min = 13.0
	_particles.initial_velocity_max = 16.0
	_particles.gravity = Vector3.ZERO
	_particles.position.y = 11.0
	_particles.local_coords = false
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.emitting = false
	add_child(_particles)
	Game.state_replaced.connect(func() -> void: _timer = 0.0)


func _process(delta: float) -> void:
	if target != null:
		global_position = Vector3(target.global_position.x, 0.0, target.global_position.z)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		var raining := Weather.is_raining(Game.state)
		if raining != _particles.emitting:
			_particles.emitting = raining


func is_raining_visible() -> bool:
	return _particles.emitting
