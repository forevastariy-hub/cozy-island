class_name WaterBuilder
extends RefCounted

const WaterShader = preload("res://scripts/water.gdshader")

var material: ShaderMaterial
var calm_material: StandardMaterial3D
var _parent: Node3D

func build(parent: Node3D, mask: ImageTexture, layout: PoiLayout, river: RiverBuilder, hf: HeightField) -> void:
	_parent = parent
	material = ShaderMaterial.new()
	material.shader = WaterShader
	material.set_shader_parameter("zone_mask", mask)
	material.set_shader_parameter("world_size", WorldConfig.SIZE)
	calm_material = StandardMaterial3D.new()
	calm_material.albedo_color = Color(0.40, 0.70, 0.72, 0.9)
	calm_material.roughness = 0.2
	calm_material.metallic = 0.05
	calm_material.emission_enabled = true
	calm_material.emission = Color(0.10, 0.26, 0.28)
	calm_material.emission_energy_multiplier = 0.8
	calm_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	calm_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_ocean()
	_build_lake(layout, hf)
	_build_river(river)
	for w in river.waterfalls:
		_build_waterfall(w)

func apply_mask(mask: ImageTexture) -> void:
	if material != null:
		material.set_shader_parameter("zone_mask", mask)

func _build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(WorldConfig.SIZE * 2.2, WorldConfig.SIZE * 2.2)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.material_override = material
	mi.position = Vector3(0.0, WorldConfig.SEA_LEVEL, 0.0)
	_parent.add_child(mi)

func _build_lake(layout: PoiLayout, hf: HeightField) -> void:
	if not layout.pois.has("lake"):
		return
	var lake: Dictionary = layout.pois["lake"]
	var c: Vector2 = lake["center"]
	var sz: Vector2 = lake["size"]
	var y := float(lake.get("y", WorldConfig.LAKE_Y))
	var phase := ShapeUtil.phase_for(c)
	var rx := maxf(1.0, sz.x * 0.5)
	var rz := maxf(1.0, sz.y * 0.5)
	var segs := 96
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.append(Vector3.ZERO)
	norms.append(Vector3.UP)
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		var dir := Vector2(cos(a), sin(a))
		var w := ShapeUtil.wobble(a, phase)
		var limit := w / sqrt(pow(dir.x / rx, 2.0) + pow(dir.y / rz, 2.0)) * 1.02
		var edge := 0.0
		for k in range(24):
			var r := limit * (1.0 - float(k) / 23.0)
			if hf.sample(c.x + dir.x * r, c.y + dir.y * r) < y - 0.05:
				edge = r
				break
		if edge < 1.0:
			edge = 1.0
		verts.append(Vector3(dir.x * edge, 0.0, dir.y * edge))
		norms.append(Vector3.UP)
	for i in range(segs):
		var i0 := 1 + i
		var i1 := 1 + (i + 1) % segs
		indices.append_array([0, i1, i0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "LakeWater"
	mi.mesh = mesh
	mi.material_override = calm_material
	mi.position = Vector3(c.x, y - 0.05, c.y)
	_parent.add_child(mi)

func _build_river(river: RiverBuilder) -> void:
	if river.polyline.size() < 2:
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()
	var count := river.polyline.size()
	var half_w := WorldConfig.RIVER.width * 0.5
	for i in range(count):
		var p := river.polyline[i]
		var dir: Vector2
		if i == 0:
			dir = (river.polyline[1] - p).normalized()
		elif i == count - 1:
			dir = (p - river.polyline[i - 1]).normalized()
		else:
			dir = (river.polyline[i + 1] - river.polyline[i - 1]).normalized()
		var perp := Vector2(-dir.y, dir.x) * half_w
		var y := river.water_levels[i] - 0.05
		verts.append(Vector3(p.x - perp.x, y, p.y - perp.y))
		verts.append(Vector3(p.x + perp.x, y, p.y + perp.y))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
	for i in range(count - 1):
		if _skip_river_quad(river, i):
			continue
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "RiverWater"
	mi.mesh = mesh
	mi.material_override = calm_material
	_parent.add_child(mi)

func _skip_river_quad(river: RiverBuilder, i: int) -> bool:
	for s in river.waterfall_spans:
		var span: Vector2i = s
		if i >= span.x - 1 and i + 1 <= span.y:
			return true
	return false

func _build_waterfall(w: Dictionary) -> void:
	var top: Vector3 = w["top"]
	var bottom: Vector3 = w["bottom"]
	var dir: Vector2 = w["dir"]
	var width: float = w["width"]
	var perp := Vector2(-dir.y, dir.x) * width * 0.5
	var drop_dir := dir * 1.4
	var tl := top + Vector3(-perp.x, 0.0, -perp.y)
	var tr := top + Vector3(perp.x, 0.0, perp.y)
	var bl := bottom + Vector3(-perp.x, 0.0, -perp.y) + Vector3(drop_dir.x, 0.0, drop_dir.y)
	var br := bottom + Vector3(perp.x, 0.0, perp.y) + Vector3(drop_dir.x, 0.0, drop_dir.y)
	var verts := PackedVector3Array([tl, tr, bl, br])
	var norms := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var indices := PackedInt32Array([0, 2, 1, 1, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.52, 0.70, 0.82, 0.5)
	var mi := MeshInstance3D.new()
	mi.name = "Waterfall"
	mi.mesh = mesh
	mi.material_override = mat
	_parent.add_child(mi)
