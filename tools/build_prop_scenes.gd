extends SceneTree
## Not part of the game. Writes props/<name>.tscn for each model in models/props,
## from what tools/build_props.py said of it in models/props/props.json: the model,
## its collision shapes, its markers and ladders, and the kind of body it is.
## godot --headless --path . --script tools/build_prop_scenes.gd [-- name ...]

func _initialize() -> void:
	var listing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/props/props.json"))
	DirAccess.make_dir_recursive_absolute("res://props")
	var only := OS.get_cmdline_user_args()
	for name: String in listing:
		if only.is_empty() or name in only:
			make(name, listing[name])
	quit()


func make(name: String, about: Dictionary) -> void:
	var root: Node3D
	match about.body:
		"throw":
			# Something to pick up and throw, as the rocks in the test yard are.
			var loose := RigidBody3D.new()
			loose.mass = about.mass
			loose.gravity_scale = 2.0
			loose.angular_damp = 2.0
			loose.add_to_group(&"interest", true)
			loose.add_to_group(&"throwable", true)
			root = loose
		"swing":
			# Something to pick up and swing in both hands, as the bat in the test yard is:
			# its origin is the end he holds it by, and it lies along its own Y.
			var tool := RigidBody3D.new()
			tool.mass = about.mass
			tool.gravity_scale = 2.0
			tool.angular_damp = 2.0
			tool.add_to_group(&"interest", true)
			tool.add_to_group(&"throwable", true)
			tool.add_to_group(&"bats", true)
			root = tool
		"push":
			var block := RigidBody3D.new()
			block.mass = about.mass
			block.lock_rotation = true
			var surface := PhysicsMaterial.new()
			surface.friction = 0.6
			block.physics_material_override = surface
			block.add_to_group(&"interest", true)
			root = block
		_:
			root = StaticBody3D.new()
	root.name = name.to_pascal_case()
	# (one with gold, bronze or brass in it is a GearProp, which makes them shine)
	root.set_script(load("res://scripts/gear_prop.gd" if about.get("shiny", false) else "res://scripts/prop.gd"))
	root.set(&"draw_distance", about.far)
	root.set(&"casts_shadow", about.get("shadow", true))
	var model: Node3D = (load("res://models/props/%s.glb" % name) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	var count := 0
	for solid: Dictionary in about.solids:
		var collider := CollisionShape3D.new()
		count += 1
		collider.name = "Solid%d" % count
		match solid.type:
			"box":
				var box := BoxShape3D.new()
				box.size = vector(solid.size)
				collider.shape = box
			"cylinder":
				var cylinder := CylinderShape3D.new()
				cylinder.radius = solid.radius
				cylinder.height = solid.height
				collider.shape = cylinder
			"sphere":
				var sphere := SphereShape3D.new()
				sphere.radius = solid.radius
				collider.shape = sphere
			"hull":
				var hull := ConvexPolygonShape3D.new()
				var points := PackedVector3Array()
				for point: Array in solid.points:
					points.append(vector(point))
				hull.points = points
				collider.shape = hull
		if solid.has("basis"):
			collider.transform = Transform3D(Basis(vector(solid.basis[0]), vector(solid.basis[1]), vector(solid.basis[2])).orthonormalized(), vector(solid.origin))
		root.add_child(collider)
		collider.owner = root
	for label: String in about.markers:
		var marker := Marker3D.new()
		marker.name = label
		marker.position = vector(about.markers[label])
		root.add_child(marker)
		marker.owner = root
	for rungs: Dictionary in about.ladders:
		var ladder := Node3D.new()
		ladder.name = "Ladder"
		ladder.set_script(load("res://scripts/ladder.gd"))
		ladder.set(&"height", rungs.height)
		ladder.position = vector(rungs.at)
		ladder.rotation.y = rungs.yaw
		root.add_child(ladder)
		ladder.owner = root
	var scene := PackedScene.new()
	var result := scene.pack(root)
	if result == OK:
		result = ResourceSaver.save(scene, "res://props/%s.tscn" % name)
	print("SCENE %s %s (%d solids)" % [name, "ok" if result == OK else "FAILED %d" % result, count])
	root.free()


func vector(from: Array) -> Vector3:
	return Vector3(from[0], from[1], from[2])
