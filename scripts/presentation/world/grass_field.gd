class_name GrassField
extends Node3D
## Pasto y juncos con MultiMesh: miles de matas en pocas llamadas de dibujo.
## Se divide en zonas (chunks) para que la cámara descarte las que no ve y cada zona
## deja de dibujarse a cierta distancia. Sin sombras ni colisión. Se genera una sola vez
## al cargar, con semilla fija (no consume el generador de la partida).

@export var area_size: float = 150.0
@export var chunk_size: float = 25.0
@export var per_chunk: int = 260
@export var blade_size: Vector2 = Vector2(0.55, 0.42)
@export var material: Material
@export var visible_distance: float = 55.0
@export var seed_value: int = 7
## Zonas sin pasto: Vector3(x, z, radio).
@export var exclude_circles: PackedVector3Array = PackedVector3Array()
## Franjas sin pasto: Vector4(min_x, min_z, max_x, max_z).
@export var exclude_rects: PackedVector4Array = PackedVector4Array()
## Si radio interior y exterior > 0, solo crece en un anillo (juncos alrededor del lago).
@export var ring_center: Vector2 = Vector2.ZERO
@export var ring_inner: float = 0.0
@export var ring_outer: float = 0.0


func _ready() -> void:
	var mesh := _blade_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half := area_size * 0.5
	var chunks := int(ceil(area_size / chunk_size))
	for cx in chunks:
		for cz in chunks:
			var origin := Vector2(-half + cx * chunk_size, -half + cz * chunk_size)
			var xforms: Array[Transform3D] = []
			for i in per_chunk:
				var p := origin + Vector2(rng.randf() * chunk_size, rng.randf() * chunk_size)
				if not _allowed(p):
					continue
				var s := rng.randf_range(0.7, 1.35)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
				xforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
			if xforms.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xforms.size()
			for i in xforms.size():
				mm.set_instance_transform(i, xforms[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = visible_distance
			mmi.visibility_range_end_margin = 8.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			add_child(mmi)


func _allowed(p: Vector2) -> bool:
	if ring_outer > 0.0:
		var d := p.distance_to(ring_center)
		if d < ring_inner or d > ring_outer:
			return false
	for c in exclude_circles:
		if p.distance_squared_to(Vector2(c.x, c.y)) < c.z * c.z:
			return false
	for r in exclude_rects:
		if p.x >= r.x and p.y >= r.y and p.x <= r.z and p.y <= r.w:
			return false
	return true


## Dos planos cruzados con la textura de pasto (alpha scissor, sin ordenar transparencias).
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := blade_size.x * 0.5
	var h := blade_size.y
	for angle in [0.0, PI * 0.5]:
		var dir := Vector3(cos(angle), 0, sin(angle)) * w
		var a := -dir
		var b := dir
		var quad := [[a, Vector2(0, 1)], [b, Vector2(1, 1)], [b + Vector3.UP * h, Vector2(1, 0)],
			[a, Vector2(0, 1)], [b + Vector3.UP * h, Vector2(1, 0)], [a + Vector3.UP * h, Vector2(0, 0)]]
		for v in quad:
			# Normal hacia arriba: el pasto se ilumina como el suelo y no se ve negro de espaldas.
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	st.set_material(material)
	return st.commit()
