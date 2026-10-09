extends SceneTree
## Not part of the game. Writes props/<name>.tscn for each model in models/train,
## from what tools/build_train.py said of it in models/train/train.json: the model
## (in pieces), its collision shapes, its markers, ladders and name boards. A vehicle
## is an AnimatableBody3D with scripts/train_vehicle.gd on it, so that a `Train` can
## run it; anything else is a prop like any other (tools/build_prop_scenes.gd).
## godot --headless --path . --script tools/build_train_scenes.gd [-- name ...]

func _initialize() -> void:
	var listing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/train/train.json"))
	DirAccess.make_dir_recursive_absolute("res://props")
	var only := OS.get_cmdline_user_args()
	for name: String in listing:
		if only.is_empty() or name in only:
			make(name, listing[name])
	quit()


func make(name: String, about: Dictionary) -> void:
	var root: Node3D
	var settings: Dictionary = about.get("settings", {})
	if about.body == "vehicle":
		var vehicle := AnimatableBody3D.new()
		vehicle.set_script(load("res://scripts/train_vehicle.gd"))
		vehicle.set(&"front", settings.get("front", 3.5))
		vehicle.set(&"rear", settings.get("rear", 3.5))
		vehicle.set(&"wheels", settings.get("wheels", {}))
		vehicle.set(&"crank", settings.get("crank", 0.0))
		vehicle.set(&"rod", settings.get("rod", 0.0))
		vehicle.set(&"roof_top", settings.get("roof_top", 0.0))
		if settings.has("inside"):
			vehicle.set(&"inside", box(settings["inside"]))
		root = vehicle
	else:
		root = StaticBody3D.new()
		var script: String = about.get("script", "")
		if script == "":
			script = "res://scripts/gear_prop.gd" if about.get("shiny", false) else "res://scripts/prop.gd"
		root.set_script(load(script))
		# (what knocks down anyone carried into it on a roof: see `TrainScenery`)
		if settings.has("strikes"):
			root.set_meta(&"strikes", box(settings["strikes"]))
	root.name = name.to_pascal_case()
	root.set(&"draw_distance", about.far)
	root.set(&"casts_shadow", about.get("shadow", true))
	var model: Node3D = (load("res://models/train/%s.glb" % name) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
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
				var shape := BoxShape3D.new()
				shape.size = vector(solid.size)
				collider.shape = shape
			"cylinder":
				var cylinder := CylinderShape3D.new()
				cylinder.radius = solid.radius
				cylinder.height = solid.height
				collider.shape = cylinder
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
		root.add_child(ladder, true)
		ladder.owner = root
	var boards := 0
	for words: Dictionary in about.get("labels", []):
		var board := Label3D.new()
		boards += 1
		board.name = "Name%d" % boards
		board.text = words.text
		board.font_size = 96
		board.pixel_size = float(words.size) / 96.0
		board.modulate = Color(words.colour[0], words.colour[1], words.colour[2])
		board.outline_size = 0
		board.shaded = true
		board.position = vector(words.at)
		board.rotation.y = words.yaw
		root.add_child(board)
		board.owner = root
	var scene := PackedScene.new()
	var result := scene.pack(root)
	if result == OK:
		result = ResourceSaver.save(scene, "res://props/%s.tscn" % name)
	print("SCENE %s %s (%d solids, %d triangles)" % [name, "ok" if result == OK else "FAILED %d" % result, count, about.triangles])
	root.free()


func vector(from: Array) -> Vector3:
	return Vector3(from[0], from[1], from[2])


func box(from: Array) -> AABB:
	return AABB(Vector3(from[0], from[1], from[2]), Vector3(from[3], from[4], from[5]))
