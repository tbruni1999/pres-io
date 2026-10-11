class_name MeshMerger
extends RefCounted
## Fusiona las mallas hijas de un nodo en pocas mallas (una por material y tipo de sombra):
## menos llamadas de dibujo y la misma forma. Las normales se transforman con la inversa-traspuesta,
## así la iluminación no cambia con escalas no uniformes. Las mallas con textura triplanar no se
## fusionan: el patrón se calcula desde la posición de cada pieza y fundirlas lo correría.
## Solo presentación: el estado nunca lo ve.


## Grupo de geometría que se va armando: vértices, normales, UV e índices de un mismo material.
class Acc:
	var mat: Material
	var casts := true
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()


## Devuelve cuántas mallas fundidas quedaron. Las mallas con hijos, con rango de visibilidad
## o con textura triplanar no se tocan.
## cast_shadows: false apaga la sombra de todo el resultado (personas y estanterías).
static func merge(root: Node3D, skip_prefixes: PackedStringArray = PackedStringArray(), cast_shadows: bool = true) -> int:
	var parts: Array[MeshInstance3D] = []
	_collect(root, parts, skip_prefixes)
	if parts.is_empty():
		return 0
	var groups := {}
	var order: Array = []
	var inv := root.global_transform.affine_inverse()
	for mi in parts:
		var xf := inv * mi.global_transform
		var nb := xf.basis.inverse().transposed()
		# Si el resultado no proyecta sombra, las piezas no se separan por su marca: un grupo por material.
		var casts := cast_shadows and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := mi.mesh
		for i in m.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			if mat == null:
				mat = m.surface_get_material(i)
			var key := "%d|%s" % [mat.get_instance_id() if mat else 0, "s" if casts else "n"]
			if not groups.has(key):
				var g := Acc.new()
				g.mat = mat
				g.casts = casts
				groups[key] = g
				order.append(key)
			var acc: Acc = groups[key]
			var arrays := m.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms = arrays[Mesh.ARRAY_NORMAL]
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			var idx = arrays[Mesh.ARRAY_INDEX]
			var base := acc.v.size()
			for k in verts.size():
				acc.v.append(xf * verts[k])
				acc.n.append((nb * norms[k]).normalized() if norms is PackedVector3Array and k < norms.size() else Vector3.UP)
				acc.uv.append(uvs[k] if uvs is PackedVector2Array and k < uvs.size() else Vector2.ZERO)
			if idx is PackedInt32Array:
				for k in idx:
					acc.idx.append(base + k)
			else:
				for k in verts.size():
					acc.idx.append(base + k)
	for mi in parts:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	var out := 0
	for key in order:
		var acc: Acc = groups[key]
		var arrs := []
		arrs.resize(Mesh.ARRAY_MAX)
		arrs[Mesh.ARRAY_VERTEX] = acc.v
		arrs[Mesh.ARRAY_NORMAL] = acc.n
		arrs[Mesh.ARRAY_TEX_UV] = acc.uv
		arrs[Mesh.ARRAY_INDEX] = acc.idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
		am.surface_set_material(0, acc.mat)
		var merged := MeshInstance3D.new()
		var label := acc.mat.resource_path.get_file().get_basename() if acc.mat and acc.mat.resource_path != "" else "sin_material"
		merged.name = "Merged%d_%s" % [out, label]
		merged.mesh = am
		# Sombras transparentes (de contacto) nunca proyectan; el resto sigue la marca de sus piezas.
		var transparent := acc.mat is BaseMaterial3D and (acc.mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		if transparent or not cast_shadows or not acc.casts:
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(merged)
		out += 1
	return out


static func _collect(node: Node, out: Array[MeshInstance3D], skip: PackedStringArray) -> void:
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and c.get_child_count() == 0:
			var mi := c as MeshInstance3D
			var skipped := false
			for p in skip:
				if String(mi.name).begins_with(p):
					skipped = true
			if not skipped and mi.visibility_range_end == 0.0 and mi.mesh.get_surface_count() > 0 and not _has_textured_triplanar(mi):
				out.append(mi)
		_collect(c, out, skip)


static func _has_textured_triplanar(mi: MeshInstance3D) -> bool:
	for i in mi.mesh.get_surface_count():
		var mat: Material = mi.get_active_material(i)
		if mat == null:
			mat = mi.mesh.surface_get_material(i)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).uv1_triplanar and (mat as BaseMaterial3D).albedo_texture != null:
			return true
	return false
