class_name TerrainMeshBuilder
extends RefCounted

const TerrainShader = preload("res://scripts/terrain.gdshader")

var mesh_instance: MeshInstance3D
var body: StaticBody3D
var shape: ConcavePolygonShape3D
var material: ShaderMaterial

func build(parent: Node3D, hf: HeightField, painter: TerrainPainter) -> void:
	material = ShaderMaterial.new()
	material.shader = TerrainShader
	material.set_shader_parameter("zone_mask", painter.mask_texture)
	material.set_shader_parameter("world_size", WorldConfig.SIZE)
	_apply(parent, hf, painter)

func apply_mask(mask: ImageTexture) -> void:
	if material != null:
		material.set_shader_parameter("zone_mask", mask)

func _apply(parent: Node3D, hf: HeightField, painter: TerrainPainter) -> void:
	var n := HeightField.N
	var cell := hf.cell
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(n * n)
	norms.resize(n * n)
	for zi in range(n):
		var z := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(n):
			var x := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var idx := zi * n + xi
			verts[idx] = Vector3(x, hf.grid[idx], z)
			norms[idx] = hf.sample_normal(x, z)
	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	for zi in range(n - 1):
		for xi in range(n - 1):
			var i0 := zi * n + xi
			var i1 := i0 + 1
			var i2 := i0 + n
			var i3 := i2 + 1
			indices.append_array([i0, i1, i2])
			faces.append_array([verts[i0], verts[i1], verts[i2]])
			indices.append_array([i1, i3, i2])
			faces.append_array([verts[i1], verts[i3], verts[i2]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = painter.colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Ground"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

	shape = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	body = StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
