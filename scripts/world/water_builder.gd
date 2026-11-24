class_name WaterBuilder
extends RefCounted

const WaterShader = preload("res://scripts/water.gdshader")

var material: ShaderMaterial
var calm_material: StandardMaterial3D
var _parent: Node3D

func build(parent: Node3D, mask: ImageTexture, layout: PoiLayout, river: RiverBuilder) -> void:
	_parent = parent
	material = ShaderMaterial.new()
	material.shader = WaterShader
	material.set_shader_parameter("zone_mask", mask)
	material.set_shader_parameter("world_size", WorldConfig.SIZE)
	calm_material = StandardMaterial3D.new()
	calm_material.albedo_color = Color(0.16, 0.42, 0.47)
	calm_material.roughness = 0.12
	calm_material.metallic = 0.15
	calm_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	calm_material.albedo_color.a = 0.82
	calm_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_ocean()
	_build_lake(layout)
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

func _build_lake(layout: PoiLayout) -> void:
	if not layout.pois.has("lake"):
		return
	var lake: Dictionary = layout.pois["lake"]
	var c: Vector2 = lake["center"]
	var sz: Vector2 = lake["size"]
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.08
	cyl.radial_segments = 48
	var mi := MeshInstance3D.new()
	mi.name = "LakeWater"
	mi.mesh = cyl
	mi.material_override = calm_material
	mi.position = Vector3(c.x, float(lake.get("y", WorldConfig.LAKE_Y)), c.y)
	mi.scale = Vector3(sz.x * 0.49, 1.0, sz.y * 0.49)
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

func _build_waterfall(w: Dictionary) -> void:
	var top: Vector3 = w["top"]
	var bottom: Vector3 = w["bottom"]
	var height := maxf(0.4, top.y - bottom.y)
	var width: float = w["width"]
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.82, 0.90, 0.95, 0.62)
	mat.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.name = "Waterfall"
	mi.mesh = quad
	mi.material_override = mat
	mi.position = (top + bottom) * 0.5
	var dir: Vector2 = w["dir"]
	mi.rotation.y = atan2(dir.x, dir.y)
	_parent.add_child(mi)
