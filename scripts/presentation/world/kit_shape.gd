@tool
class_name KitShape
extends MeshInstance3D
## Pieza del kit de bloqueo: malla primitiva + colisión simple opcional.
## Editable desde el inspector (tamaño, material, colisión). Se construye una sola vez
## al entrar al árbol; reemplazable más adelante por modelos glTF sin tocar reglas.

## CAPSULE va al final para no cambiar el número de las formas que ya están en las escenas.
enum Shape { BOX, CYLINDER, CONE, SPHERE, CAPSULE }

## Caja: ancho, alto, fondo. Cilindro/cono/esfera: x = diámetro, y = altura.
## Esfera con x != y da un elipsoide (torsos, cabezas); cápsula: x = diámetro, y = largo total.
@export var shape: Shape = Shape.BOX:
	set(v):
		shape = v
		_rebuild()
@export var size: Vector3 = Vector3.ONE:
	set(v):
		size = v
		_rebuild()
@export var material: Material:
	set(v):
		material = v
		_rebuild()
## Lados de cilindros y conos (más lados = más redondo, más triángulos).
@export var segments: int = 12:
	set(v):
		segments = maxi(3, v)
		_rebuild()
## Crea un StaticBody3D con forma simple al ejecutar el juego.
@export var collide: bool = false
@export_flags_3d_physics var collision_layer_bits: int = 1
@export var casts_shadow: bool = true:
	set(v):
		casts_shadow = v
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if v else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
## Distancia a partir de la cual deja de dibujarse (0 = siempre visible).
@export var hide_beyond: float = 0.0:
	set(v):
		hide_beyond = v
		visibility_range_end = v
		visibility_range_end_margin = 2.0 if v > 0.0 else 0.0

## Mallas compartidas entre piezas iguales (misma forma, tamaño y material).
static var _mesh_cache: Dictionary = {}


func _ready() -> void:
	_rebuild()
	if collide and not Engine.is_editor_hint():
		_build_collision()


func _rebuild() -> void:
	# Durante la carga de la escena se espera a _ready para construir una sola vez.
	if not is_inside_tree():
		return
	var key := "%d|%s|%d|%d" % [shape, size, material.get_instance_id() if material else 0, segments]
	if not Engine.is_editor_hint() and _mesh_cache.has(key):
		mesh = _mesh_cache[key]
		return
	var m: PrimitiveMesh
	match shape:
		Shape.BOX:
			var b := BoxMesh.new()
			b.size = size
			m = b
		Shape.CYLINDER, Shape.CONE:
			var c := CylinderMesh.new()
			c.bottom_radius = size.x * 0.5
			c.top_radius = 0.0 if shape == Shape.CONE else size.x * 0.5
			c.height = size.y
			c.radial_segments = segments
			c.rings = 0
			m = c
		Shape.SPHERE:
			var s := SphereMesh.new()
			s.radius = size.x * 0.5
			s.height = size.y
			# Más anillos y lados que antes: sin facetas se lee como cuerpo y no como cajas.
			s.radial_segments = 18
			s.rings = 10
			m = s
		Shape.CAPSULE:
			var k := CapsuleMesh.new()
			k.radius = size.x * 0.5
			k.height = maxf(size.y, size.x)
			k.radial_segments = maxi(segments, 12)
			k.rings = 6
			m = k
	m.material = material
	mesh = m
	if not Engine.is_editor_hint():
		_mesh_cache[key] = m


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = collision_layer_bits
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	match shape:
		Shape.BOX:
			var b := BoxShape3D.new()
			b.size = size
			cs.shape = b
		Shape.CYLINDER, Shape.CONE:
			var c := CylinderShape3D.new()
			c.radius = size.x * (0.5 if shape == Shape.CYLINDER else 0.35)
			c.height = size.y
			cs.shape = c
		Shape.SPHERE:
			var s := SphereShape3D.new()
			s.radius = size.x * 0.5
			cs.shape = s
		Shape.CAPSULE:
			var k := CapsuleShape3D.new()
			k.radius = size.x * 0.5
			k.height = maxf(size.y, size.x)
			cs.shape = k
	body.add_child(cs)
	add_child(body)
