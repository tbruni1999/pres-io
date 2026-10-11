class_name MeshMerger
extends RefCounted
## Fusiona las mallas hijas de un nodo en una malla por material: menos llamadas de dibujo
## y la misma forma. Se usa al cargar personas y vehículos. Lo que se anima (ruedas) se deja
## afuera por prefijo de nombre. Solo presentación: el estado nunca lo ve.


## Devuelve cuántas mallas fusionó. Las mallas con hijos o con rango de visibilidad no se tocan.
## cast_shadows: las piezas chicas (personas, estanterías) no proyectan sombra: ahorra dibujos en el pase de sombras.
static func merge(root: Node3D, skip_prefixes: PackedStringArray = PackedStringArray(), cast_shadows: bool = true) -> int:
	var parts: Array[MeshInstance3D] = []
	_collect(root, root, parts, skip_prefixes)
	if parts.is_empty():
		return 0
	var tools := {}
	var order: Array = []
	var inv := root.global_transform.affine_inverse()
	for mi in parts:
		var xf := inv * mi.global_transform
		var m := mi.mesh
		for i in m.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			if mat == null:
				mat = m.surface_get_material(i)
			if not tools.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mat)
				tools[mat] = st
				order.append(mat)
			(tools[mat] as SurfaceTool).append_from(m, i, xf)
	for mi in parts:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for mat in order:
		var merged := MeshInstance3D.new()
		merged.name = "Merged_%s" % (mat.resource_path.get_file().get_basename() if mat.resource_path != "" else str(order.find(mat)))
		merged.mesh = (tools[mat] as SurfaceTool).commit()
		# Sombras transparentes (de contacto) no proyectan sombra.
		var transparent := mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		if transparent or not cast_shadows:
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(merged)
	return order.size()


static func _collect(node: Node, root: Node3D, out: Array[MeshInstance3D], skip: PackedStringArray) -> void:
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and c.get_child_count() == 0:
			var mi := c as MeshInstance3D
			var skipped := false
			for p in skip:
				if String(mi.name).begins_with(p):
					skipped = true
			if not skipped and mi.visibility_range_end == 0.0 and mi.mesh.get_surface_count() > 0:
				out.append(mi)
		_collect(c, root, out, skip)
