class_name ItemModel
extends RefCounted
## Modelos 3D chicos de los objetos (estanterías, red, leñero). Primitivas con color:
## barato de dibujar y legible de lejos. Los materiales se crean una sola vez.

static var _mats: Dictionary = {}


static func make(item_id: String) -> Node3D:
	var root := Node3D.new()
	match item_id:
		"fish_small":
			_fish(root, 0.22, 0.09, Color(0.72, 0.78, 0.84))
		"fish_big":
			_fish(root, 0.36, 0.13, Color(0.82, 0.6, 0.26))
		"fish_small_smoked":
			_fish(root, 0.22, 0.09, Color(0.55, 0.33, 0.16))
		"fish_big_smoked":
			_fish(root, 0.36, 0.13, Color(0.48, 0.26, 0.12))
		"bread":
			_part(root, _sphere(), Vector3(0.2, 0.1, 0.13), Vector3.ZERO, _mat("bread", Color(0.84, 0.64, 0.38), 0.8))
		"water_jug":
			_part(root, _cylinder(0.07, 0.22), Vector3.ONE, Vector3(0, 0.11, 0), _mat("jug", Color(0.22, 0.52, 0.9), 0.3))
			_part(root, _cylinder(0.03, 0.04), Vector3.ONE, Vector3(0, 0.24, 0), _mat("cap", Color(0.1, 0.1, 0.12), 0.6))
		"rod_basic":
			_rod(root, Color(0.5, 0.36, 0.2))
		"rod_good":
			_rod(root, Color(0.2, 0.5, 0.35))
		"axe":
			_part(root, _cylinder(0.012, 0.42), Vector3.ONE, Vector3(0, 0.21, 0), _mat("handle", Color(0.5, 0.36, 0.2), 0.8))
			_part(root, _box(Vector3(0.14, 0.06, 0.03)), Vector3.ONE, Vector3(0, 0.4, 0), _mat("steel", Color(0.55, 0.57, 0.6), 0.4, 0.6))
		"cooler":
			_part(root, _box(Vector3(0.3, 0.18, 0.2)), Vector3.ONE, Vector3(0, 0.09, 0), _mat("cooler", Color(0.9, 0.92, 0.94), 0.5))
			_part(root, _box(Vector3(0.3, 0.03, 0.2)), Vector3.ONE, Vector3(0, 0.19, 0), _mat("cooler_lid", Color(0.2, 0.45, 0.8), 0.5))
		"umbrella":
			_part(root, _cylinder(0.01, 0.5), Vector3.ONE, Vector3(0, 0.25, 0), _mat("steel", Color(0.4, 0.4, 0.42), 0.4, 0.5))
			_part(root, _cone(0.26, 0.12), Vector3.ONE, Vector3(0, 0.5, 0), _mat("canopy", Color(0.92, 0.5, 0.14), 0.9))
		"tape":
			_part(root, _cylinder(0.05, 0.03), Vector3.ONE, Vector3(0, 0.015, 0), _mat("tape", Color(0.95, 0.95, 0.93), 0.7))
		"sheet_metal":
			_part(root, _box(Vector3(0.5, 0.012, 0.26)), Vector3.ONE, Vector3(0, 0.006, 0), _mat("zinc", Color(0.62, 0.64, 0.66), 0.45, 0.4))
		"cement":
			_part(root, _box(Vector3(0.22, 0.12, 0.14)), Vector3.ONE, Vector3(0, 0.06, 0), _mat("sack", Color(0.7, 0.68, 0.62), 0.95))
		"salt":
			_part(root, _box(Vector3(0.12, 0.1, 0.1)), Vector3.ONE, Vector3(0, 0.05, 0), _mat("salt", Color(0.95, 0.94, 0.9), 0.9))
		"wood_log":
			_part(root, _cylinder(0.07, 0.6), Vector3.ONE, Vector3.ZERO, _mat("log", Color(0.42, 0.3, 0.2), 0.9))
		_:
			_part(root, _box(Vector3(0.2, 0.2, 0.2)), Vector3.ONE, Vector3(0, 0.1, 0), _mat("unknown", Color(0.5, 0.5, 0.5), 0.8))
	return root


static func _fish(root: Node3D, length: float, height: float, color: Color) -> void:
	# Cuerpo: esfera achatada a lo largo de Z; cola: cono con la punta hacia atrás.
	var body := _part(root, _sphere(), Vector3(height, height * 0.9, length), Vector3.ZERO, _mat("fish_%s" % color.to_html(), color, 0.4))
	body.name = "Body"
	var tail := _part(root, _cone(height * 0.9, height * 0.8), Vector3.ONE, Vector3(0, 0, -length * 0.5 - height * 0.3), _mat("fish_%s" % color.to_html(), color, 0.4))
	tail.rotation_degrees = Vector3(-90, 0, 0)


static func _rod(root: Node3D, color: Color) -> void:
	var cane := _part(root, _cylinder(0.012, 0.9), Vector3.ONE, Vector3(0, 0.45, 0), _mat("cane_%s" % color.to_html(), color, 0.6))
	cane.rotation_degrees = Vector3(0, 0, 70)
	_part(root, _cylinder(0.03, 0.03), Vector3.ONE, Vector3(-0.05, 0.1, 0), _mat("reel", Color(0.6, 0.6, 0.62), 0.4, 0.5))


static func _part(root: Node3D, mesh: Mesh, scl: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = scl
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## La clave incluye color y propiedades: dos materiales con el mismo nombre no se pisan.
static func _mat(key: String, color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var k := "%s|%s|%.2f|%.2f" % [key, color.to_html(), roughness, metallic]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic = metallic
		_mats[k] = m
	return _mats[k]


static func _sphere() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 8
	return c


static func _cone(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 8
	return c
