@tool
class_name CableLine
extends MeshInstance3D
## Cable colgante entre postes: una polilínea con caída, dibujada como líneas.
## Barato (sin colisión ni sombras); se reconstruye solo cuando cambian los puntos.

@export var points: PackedVector3Array = PackedVector3Array():
	set(v):
		points = v
		_rebuild()
@export var sag: float = 0.5:
	set(v):
		sag = v
		_rebuild()
@export var color: Color = Color(0.08, 0.08, 0.08):
	set(v):
		color = v
		_rebuild()

const SEGMENTS := 10


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rebuild()


func _rebuild() -> void:
	if points.size() < 2:
		mesh = null
		return
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		for s in SEGMENTS:
			var t0 := float(s) / SEGMENTS
			var t1 := float(s + 1) / SEGMENTS
			im.surface_add_vertex(_sample(a, b, t0))
			im.surface_add_vertex(_sample(a, b, t1))
	im.surface_end()
	mesh = im


func _sample(a: Vector3, b: Vector3, t: float) -> Vector3:
	var p := a.lerp(b, t)
	p.y -= sag * 4.0 * t * (1.0 - t)
	return p
