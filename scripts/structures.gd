extends Node3D

func build_lookout_tower(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "LookoutTower"
	root.position = pos
	root.add_to_group("path_poi")

	var h: float = 14.0
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.52, 0.46)
	stone.roughness = 0.95
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.95

	for ix in range(3):
		for iz in range(3):
			var t := _box(Vector3(1.05, 0.18, 1.05), stone, Vector3((float(ix) - 1.0) * 1.1, 0.09, (float(iz) - 1.0) * 1.1))
			t.rotation.y = randf_range(-0.05, 0.05)
			root.add_child(t)

	var col := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.7
	cc.bottom_radius = 0.9
	cc.height = h
	cc.radial_segments = 10
	col.mesh = cc
	col.material_override = stone
	col.position.y = 0.09 + h * 0.5
	root.add_child(col)

	var deck := _box(Vector3(3.2, 0.12, 3.2), wood, Vector3(0, 0.09 + h + 0.06, 0))
	root.add_child(deck)

	for side in [-1.0, 1.0]:
		for zz in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.05
			pc.bottom_radius = 0.05
			pc.height = 0.6
			pc.radial_segments = 6
			post.mesh = pc
			post.material_override = wood
			post.position = Vector3(side * 1.45, 0.09 + h + 0.4, zz * 1.45)
			root.add_child(post)

	for s in [-1.0, 1.0]:
		var beam := _box(Vector3(3.0, 0.06, 0.07), wood, Vector3(0, 0.09 + h + 0.4, s * 1.5))
		root.add_child(beam)
		var beam2 := _box(Vector3(0.07, 0.06, 3.0), wood, Vector3(s * 1.5, 0.09 + h + 0.4, 0))
		root.add_child(beam2)

	var roof := MeshInstance3D.new()
	var rc: CylinderMesh = CylinderMesh.new()
	rc.top_radius = 0.0
	rc.bottom_radius = 1.7
	rc.height = 1.4
	rc.radial_segments = 8
	roof.mesh = rc
	roof.material_override = wood
	roof.position.y = 0.09 + h + 0.12 + 0.7
	root.add_child(roof)

	var body := StaticBody3D.new()
	var colshape := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = h
	colshape.shape = shape
	colshape.position = Vector3(0, 0.09 + h * 0.5, 0)
	body.add_child(colshape)

	root.add_child(body)

	parent.add_child(root)
	return root

func build_stone_tower(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "StoneTower"
	root.position = pos
	root.add_to_group("path_poi")

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.52, 0.46)
	stone.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.4, 0.38, 0.34)
	dark.roughness = 1.0
	var moss := StandardMaterial3D.new()
	moss.albedo_color = Color(0.32, 0.44, 0.23)
	moss.roughness = 1.0

	var h: float = randf_range(7.0, 11.0)
	var xoff: float = randf_range(-1.0, 1.0)
	var zoff: float = randf_range(-1.0, 1.0)

	for i in range(4):
		var a: float = TAU * float(i) / 4.0
		var fs := _box(Vector3(1.4, 0.3, 1.4), dark, Vector3(cos(a) * 1.5, 0.15, sin(a) * 1.5))
		root.add_child(fs)

	var tower := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.9
	tc.bottom_radius = 1.2
	tc.height = h
	tc.radial_segments = 10
	tower.mesh = tc
	tower.material_override = stone
	tower.position = Vector3(xoff, 0.15 + h * 0.5, zoff)
	tower.rotation.z = randf_range(-0.06, 0.06)
	root.add_child(tower)

	for i in range(6):
		var a: float = TAU * float(i) / 6.0
		var merlon := _box(Vector3(0.35, 0.5, 0.35), stone, Vector3(
			xoff + cos(a) * 1.25, 0.15 + h + 0.25, zoff + sin(a) * 1.25))
		merlon.rotation.z = randf_range(-0.1, 0.1)
		root.add_child(merlon)

	for _i in range(6):
		var a: float = randf_range(0.0, TAU)
		var rad: float = randf_range(0.3, 1.0)
		var mp := _box(Vector3(0.5, 0.06, 0.5), moss, Vector3(
			xoff + cos(a) * rad, 0.16 + randf_range(0.0, h * 0.5), zoff + sin(a) * rad))
		mp.rotation.x = randf_range(-0.3, 0.3)
		mp.rotation.z = randf_range(-0.3, 0.3)
		root.add_child(mp)

	var body := StaticBody3D.new()
	var colshape := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.1
	shape.height = h
	colshape.shape = shape
	colshape.position = Vector3(xoff, 0.15 + h * 0.5, zoff)
	body.add_child(colshape)
	root.add_child(body)

	parent.add_child(root)
	return root

func build_radio_tower(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "RadioTower"
	root.position = pos
	root.add_to_group("path_poi")

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.5, 0.52, 0.56)
	metal.roughness = 0.6
	metal.metallic = 0.5
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.95
	var dish_mat := StandardMaterial3D.new()
	dish_mat.albedo_color = Color(0.45, 0.48, 0.52)
	dish_mat.roughness = 0.4

	var h: float = 22.0
	var leg_w: float = 2.6

	for side_x in [-1.0, 1.0]:
		for side_z in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var lc := CylinderMesh.new()
			lc.top_radius = 0.14
			lc.bottom_radius = 0.22
			lc.height = h * 0.75
			lc.radial_segments = 6
			leg.mesh = lc
			leg.material_override = metal
			leg.position = Vector3(side_x * leg_w * 0.5, h * 0.75 * 0.5, side_z * leg_w * 0.5)
			leg.rotation.x = -0.25 * side_x
			leg.rotation.z = -0.25 * side_z
			root.add_child(leg)

	var col := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.2
	cc.bottom_radius = 0.3
	cc.height = h
	cc.radial_segments = 8
	col.mesh = cc
	col.material_override = metal
	col.position.y = h * 0.5
	root.add_child(col)

	for ph in [h * 0.4, h * 0.7]:
		var plat := _box(Vector3(3.4, 0.14, 3.4), wood, Vector3(0, ph, 0))
		root.add_child(plat)
		for side in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.08
			pc.bottom_radius = 0.08
			pc.height = 0.9
			pc.radial_segments = 5
			post.mesh = pc
			post.material_override = wood
			post.position = Vector3(side * 1.6, ph + 0.45, 1.6)
			root.add_child(post)
			var post2 := MeshInstance3D.new()
			post2.mesh = pc
			post2.material_override = wood
			post2.position = Vector3(side * 1.6, ph + 0.45, -1.6)
			root.add_child(post2)

	var dish := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.6
	sph.height = 0.7
	sph.radial_segments = 12
	sph.rings = 4
	dish.mesh = sph
	dish.material_override = dish_mat
	dish.position = Vector3(0, h + 0.3, 0)
	dish.rotation.x = -0.5
	dish.scale = Vector3(1.0, 0.4, 1.0)
	root.add_child(dish)

	var mast := MeshInstance3D.new()
	var mc := CylinderMesh.new()
	mc.top_radius = 0.06
	mc.bottom_radius = 0.06
	mc.height = 2.6
	mc.radial_segments = 6
	mast.mesh = mc
	mast.material_override = metal
	mast.position = Vector3(0, h + 0.3 + 1.3, 0)
	root.add_child(mast)

	var tip := MeshInstance3D.new()
	var tc2: CylinderMesh = CylinderMesh.new()
	tc2.top_radius = 0.0
	tc2.bottom_radius = 0.15
	tc2.height = 0.7
	tc2.radial_segments = 6
	tip.mesh = tc2
	tip.material_override = metal
	tip.position = Vector3(0, h + 0.3 + 2.6 + 0.35, 0)
	root.add_child(tip)

	var body := StaticBody3D.new()
	var colshape := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.6
	shape.height = h + 4.0
	colshape.shape = shape
	colshape.position = Vector3(0, (h + 4.0) * 0.5, 0)
	body.add_child(colshape)
	root.add_child(body)

	parent.add_child(root)
	return root

func build_camp(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Camp"
	root.position = pos
	root.add_to_group("path_poi")

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.95
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.38, 0.24, 0.13)
	log_mat.roughness = 1.0
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.52, 0.46)
	stone.roughness = 1.0
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.78, 0.66, 0.45)
	cloth.roughness = 1.0

	for i in range(10):
		var a: float = TAU * float(i) / 10.0
		var fs := MeshInstance3D.new()
		var fsphere := SphereMesh.new()
		fsphere.radius = 0.18
		fsphere.height = 0.24
		fsphere.radial_segments = 5
		fsphere.rings = 3
		fs.mesh = fsphere
		fs.material_override = stone
		fs.position = Vector3(cos(a) * 0.9, 0.12, sin(a) * 0.9)
		root.add_child(fs)

	var fbody := StaticBody3D.new()
	var fcol := CollisionShape3D.new()
	var fshape := CylinderShape3D.new()
	fshape.radius = 1.0
	fshape.height = 0.24
	fcol.shape = fshape
	fcol.position = Vector3(0, 0.12, 0)
	fbody.add_child(fcol)
	root.add_child(fbody)

	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + 0.4
		var log := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.12
		lc.bottom_radius = 0.15
		lc.height = 0.9
		lc.radial_segments = 6
		log.mesh = lc
		log.material_override = log_mat
		log.position = Vector3(cos(a) * 1.4, 0.18, sin(a) * 1.4)
		log.rotation = Vector3(PI * 0.5, a, 0.0)
		root.add_child(log)

	var bench := Node3D.new()
	bench.position = Vector3(0, 0, -2.6)
	var seat := _box(Vector3(1.8, 0.1, 0.5), wood, Vector3(0, 0.5, 0))
	var back := _box(Vector3(1.8, 0.45, 0.1), wood, Vector3(0, 0.78, 0.3))
	bench.add_child(seat)
	bench.add_child(back)
	for side in [-1.0, 1.0]:
		var leg := _box(Vector3(0.1, 0.45, 0.1), wood, Vector3(side * 0.75, 0.25, 0))
		bench.add_child(leg)
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(1.8, 0.9, 0.7)
	var bbody := StaticBody3D.new()
	var bcol := CollisionShape3D.new()
	bcol.shape = bshape
	bcol.position = Vector3(0, 0.45, 0)
	bbody.add_child(bcol)
	bench.add_child(bbody)
	root.add_child(bench)

	var tent := Node3D.new()
	tent.position = Vector3(2.4, 0, 1.2)
	var tent_cloth := StandardMaterial3D.new()
	tent_cloth.albedo_color = Color(0.8, 0.72, 0.55)
	tent_cloth.roughness = 1.0
	var tp: CylinderMesh = CylinderMesh.new()
	tp.top_radius = 0.0
	tp.bottom_radius = 1.0
	tp.height = 1.6
	tp.radial_segments = 6
	var tent_mesh := MeshInstance3D.new()
	tent_mesh.mesh = tp
	tent_mesh.material_override = tent_cloth
	tent_mesh.position.y = 0.8
	tent.add_child(tent_mesh)
	var ground := _box(Vector3(2.0, 0.04, 2.0), cloth, Vector3(0, 0.02, 0))
	tent.add_child(ground)
	var tent_body := StaticBody3D.new()
	var tent_col := CollisionShape3D.new()
	var tent_shape := CylinderShape3D.new()
	tent_shape.radius = 1.0
	tent_shape.height = 1.6
	tent_col.shape = tent_shape
	tent_col.position = Vector3(0, 0.8, 0)
	tent_body.add_child(tent_col)
	tent.add_child(tent_body)
	root.add_child(tent)

	parent.add_child(root)
	return root

func build_windmill(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Windmill"
	root.position = pos
	root.add_to_group("path_poi")

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.58, 0.55, 0.48)
	stone.roughness = 0.95
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.46, 0.32, 0.19)
	wood.roughness = 0.95
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.82, 0.76, 0.62)
	cloth.roughness = 1.0

	var h: float = 8.0
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 1.7
	bc.bottom_radius = 2.3
	bc.height = h
	bc.radial_segments = 10
	base.mesh = bc
	base.material_override = stone
	base.position.y = h * 0.5
	root.add_child(base)

	var roof := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.0
	rc.bottom_radius = 2.0
	rc.height = 1.8
	rc.radial_segments = 10
	roof.mesh = rc
	roof.material_override = wood
	roof.position.y = h + 0.9
	root.add_child(roof)

	var hub := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.4
	hs.height = 0.8
	hs.radial_segments = 8
	hs.rings = 4
	hub.mesh = hs
	hub.material_override = wood
	hub.position = Vector3(0, h - 1.2, 2.1)
	root.add_child(hub)

	var blades := Node3D.new()
	blades.position = Vector3(0, h - 1.2, 2.2)
	blades.rotation.z = 0.5
	for i in range(4):
		var a: float = TAU * float(i) / 4.0
		var arm := _box(Vector3(0.18, 3.4, 0.1), wood, Vector3(0, 0, 0))
		arm.position = Vector3(cos(a) * 1.7, sin(a) * 1.7, 0)
		arm.rotation.z = a - PI * 0.5
		blades.add_child(arm)
		var sail := _box(Vector3(0.75, 2.6, 0.05), cloth, Vector3(0, 0, 0))
		sail.position = Vector3(cos(a) * 1.9, sin(a) * 1.9, 0.08)
		sail.rotation.z = a - PI * 0.5
		blades.add_child(sail)
	root.add_child(blades)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.2
	shape.height = h
	col.shape = shape
	col.position.y = h * 0.5
	body.add_child(col)
	root.add_child(body)

	parent.add_child(root)
	return root

func build_farmhouse(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Farmhouse"
	root.position = pos
	root.add_to_group("path_poi")

	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.80, 0.72, 0.56)
	wall.roughness = 0.95
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.44, 0.30, 0.18)
	wood.roughness = 0.95
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.55, 0.28, 0.20)
	roof_mat.roughness = 0.9
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.48, 0.55)
	glass.roughness = 0.3
	glass.metallic = 0.2

	var w: float = 6.0
	var d: float = 4.4
	var wall_h: float = 3.2

	var walls := _box(Vector3(w, wall_h, d), wall, Vector3(0, wall_h * 0.5, 0))
	root.add_child(walls)

	var beam_l := _box(Vector3(0.16, wall_h, 0.16), wood, Vector3(-w * 0.5, wall_h * 0.5, d * 0.5))
	var beam_r := _box(Vector3(0.16, wall_h, 0.16), wood, Vector3(w * 0.5, wall_h * 0.5, d * 0.5))
	root.add_child(beam_l)
	root.add_child(beam_r)

	var roof_angle: float = 0.5
	var slab_w: float = w * 0.5 / cos(roof_angle) + 0.3
	for side in [-1.0, 1.0]:
		var slab := _box(Vector3(slab_w, 0.16, d + 0.8), roof_mat, Vector3(0, 0, 0))
		slab.position = Vector3(side * w * 0.25, wall_h + 0.55, 0)
		slab.rotation.z = -side * roof_angle
		root.add_child(slab)

	var door := _box(Vector3(1.0, 1.9, 0.12), wood, Vector3(0, 0.95, d * 0.5 + 0.02))
	root.add_child(door)
	var win := _box(Vector3(0.9, 0.8, 0.12), glass, Vector3(-1.7, 1.9, d * 0.5 + 0.02))
	root.add_child(win)
	var win2 := _box(Vector3(0.9, 0.8, 0.12), glass, Vector3(1.7, 1.9, d * 0.5 + 0.02))
	root.add_child(win2)

	var chimney := _box(Vector3(0.5, 1.4, 0.5), wood, Vector3(-w * 0.28, wall_h + 1.3, -d * 0.2))
	root.add_child(chimney)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, wall_h + 1.0, d)
	col.shape = shape
	col.position.y = (wall_h + 1.0) * 0.5
	body.add_child(col)
	root.add_child(body)

	parent.add_child(root)
	return root

func build_bridge(parent: Node3D, pos: Vector3, dir: Vector3, width: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Bridge"
	root.position = pos
	root.rotation.y = atan2(dir.x, dir.z)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.46, 0.31, 0.18)
	wood.roughness = 0.95
	var span := maxf(6.0, width)
	var planks := 10
	for i in range(planks):
		var x := -span * 0.5 + (float(i) + 0.5) * (span / float(planks))
		var plank := _box(Vector3(span / float(planks) * 0.92, 0.09, 2.4), wood, Vector3(x, 0.08, 0.0))
		plank.rotation.y = randf_range(-0.02, 0.02)
		root.add_child(plank)
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(span, 0.08, 0.08), wood, Vector3(0.0, 0.62, side * 1.15)))
		for xx in [-span * 0.42, 0.0, span * 0.42]:
			root.add_child(_box(Vector3(0.07, 0.54, 0.07), wood, Vector3(xx, 0.35, side * 1.15)))
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(span, 0.18, 2.4)
	col.shape = shape
	col.position.y = 0.08
	body.add_child(col)
	root.add_child(body)
	parent.add_child(root)
	return root

func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var m := MeshInstance3D.new()
	m.mesh = b
	m.material_override = mat
	m.position = pos
	return m

func rng_range(min_v: float, max_v: float) -> float:
	return randf_range(min_v, max_v)
