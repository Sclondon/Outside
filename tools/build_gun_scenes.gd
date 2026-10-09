extends SceneTree
## Not part of the game. Writes guns/<name>.tscn for each model in models/guns, from
## what tools/build_guns.py said of it in models/guns/guns.json (its collision, its
## markers, where its moving parts turn) and from the numbers below, which are the
## guns' own: how many rounds, how fast, how hard. Also the three pots and jars of
## props/ again as things that smash (guns/target_pot and so on): the same models,
## under scripts/breakable.gd, with the props' own scenes left alone.
## godot --headless --path . --script tools/build_gun_scenes.gd [-- name ...]

## Every exported property of scripts/gun.gd that is not left as it is.
const GUNS := {
	"revolver": {
		"mass": 1.1, "kind": &"revolver", "two_handed": false, "kick": 0.5,
		"rounds": 6, "capacity": 6, "reserve": 18, "ammo": &"pistol",
		"cycle_time": 0.45, "reload_time": 2.6, "damage": 35.0, "range": 60.0, "spread": 1.5, "pellets": 1, "force": 5.0,
		"flash": 0.7, "smoke": 0.8, "eject": Gun.Eject.ON_RELOAD, "shell_size": Vector2(0.006, 0.02), "break_angle": 70.0,
	},
	"rifle": {
		"mass": 3.9, "kind": &"rifle", "two_handed": true, "kick": 1.0,
		"rounds": 10, "capacity": 10, "reserve": 30, "ammo": &"rifle",
		"cycle_time": 1.1, "reload_time": 3.2, "damage": 80.0, "range": 300.0, "spread": 0.25, "pellets": 1, "force": 9.0,
		"flash": 1.0, "smoke": 1.0, "eject": Gun.Eject.ON_CYCLE, "shell_size": Vector2(0.0058, 0.056),
	},
	"shotgun": {
		"mass": 3.1, "kind": &"shotgun", "two_handed": true, "kick": 1.4,
		"rounds": 2, "capacity": 2, "reserve": 12, "ammo": &"shell",
		"cycle_time": 0.35, "reload_time": 2.4, "damage": 12.0, "range": 40.0, "spread": 4.0, "pellets": 8, "force": 2.2,
		"flash": 1.2, "smoke": 1.25, "eject": Gun.Eject.ON_RELOAD, "shell_size": Vector2(0.0102, 0.065), "shell_colour": Color(0.62, 0.16, 0.13),
		"break_angle": 32.0, "barrel_gap": 0.0256,
	},
	"flare_pistol": {
		"mass": 1.0, "kind": &"flare", "two_handed": false, "kick": 0.35,
		"rounds": 1, "capacity": 1, "reserve": 6, "ammo": &"flare",
		"cycle_time": 0.4, "reload_time": 1.8, "damage": 15.0, "range": 80.0, "spread": 1.0, "pellets": 1, "force": 3.0,
		"fires_flare": true, "tracer": false,
		"flash": 0.8, "smoke": 1.2, "eject": Gun.Eject.ON_RELOAD, "shell_size": Vector2(0.013, 0.07), "break_angle": 55.0,
	},
}
## Targets: the properties of scripts/shoot_target.gd.
const TARGETS := {
	"target_board": {"kind": ShootTarget.Kind.FALLS, "made_of": &"wood", "radius": 0.25},
	"target_gong": {"kind": ShootTarget.Kind.SWINGS, "made_of": &"metal", "radius": 0.2},
}
## Things that smash: the properties of scripts/breakable.gd, and whose model each wears.
const BREAKABLES := {
	"bottle": {"model": "res://models/guns/bottle.glb", "made_of": &"glass", "pieces": 5, "break_speed": 6.0},
	"tin_can": {"model": "res://models/guns/tin_can.glb", "made_of": &"metal", "unbreakable": true},
	"target_pot": {"model": "res://models/props/pot.glb", "like": "pot", "made_of": &"pot", "pieces": 6},
	"target_jar": {"model": "res://models/props/jar_canopic.glb", "like": "jar_canopic", "made_of": &"pot", "pieces": 6},
	"target_jackal": {"model": "res://models/props/jar_canopic_jackal.glb", "like": "jar_canopic_jackal", "made_of": &"pot", "pieces": 6},
}


func _initialize() -> void:
	var listing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/guns/guns.json"))
	var props: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/props/props.json"))
	DirAccess.make_dir_recursive_absolute("res://guns")
	var only := OS.get_cmdline_user_args()
	for name: String in GUNS:
		if only.is_empty() or name in only:
			save(name, gun(name, listing[name]))
	for name: String in TARGETS:
		if only.is_empty() or name in only:
			save(name, target(name, listing[name]))
	for name: String in BREAKABLES:
		if only.is_empty() or name in only:
			var about: Dictionary = BREAKABLES[name]
			save(name, breakable(name, about, props[about.like] if about.has("like") else listing[name]))
	if only.is_empty() or "ammo_box" in only:
		save("ammo_box", ammo_box(listing["ammo_box"]))
	quit()


func gun(name: String, about: Dictionary) -> Node3D:
	var root := RigidBody3D.new()
	root.name = name.to_pascal_case()
	root.set_script(load("res://scripts/gun.gd"))
	var numbers: Dictionary = GUNS[name]
	for property: String in numbers:
		root.set(property, numbers[property])
	root.gravity_scale = 2.0
	# (it lies where it is put down, and does not roll off)
	root.angular_damp = 6.0
	for group: StringName in [&"interest", &"throwable", &"guns"]:
		root.add_to_group(group, true)
	model(root, "res://models/guns/%s.glb" % name)
	solids(root, root, about.solids, "Body", Vector3.ZERO)
	markers(root, root, about.markers, Vector3.ZERO)
	return root


func target(name: String, about: Dictionary) -> Node3D:
	var root := StaticBody3D.new()
	root.name = name.to_pascal_case()
	root.set_script(load("res://scripts/shoot_target.gd"))
	var numbers: Dictionary = TARGETS[name]
	for property: String in numbers:
		root.set(property, numbers[property])
	model(root, "res://models/guns/%s.glb" % name)
	solids(root, root, about.solids, "Body", Vector3.ZERO)
	# What moves: a body of its own at the hinge, with the board's collision and the middle of the rings.
	var pivot := vector(about.pivots["Board"])
	var hinge := AnimatableBody3D.new()
	hinge.name = "Hinge"
	hinge.sync_to_physics = false
	hinge.position = pivot
	root.add_child(hinge)
	hinge.owner = root
	solids(root, hinge, about.solids, "Board", pivot)
	markers(root, hinge, about.markers, pivot)
	return root


func breakable(name: String, about: Dictionary, shape: Dictionary) -> Node3D:
	var root := RigidBody3D.new()
	root.name = name.to_pascal_case()
	root.set_script(load("res://scripts/breakable.gd"))
	for property: String in about:
		if property not in ["model", "like"]:
			root.set(property, about[property])
	root.mass = shape.get("mass", shape.get("about", {}).get("mass", 2.0))
	root.gravity_scale = 2.0
	root.angular_damp = 2.0
	for group: StringName in [&"interest", &"throwable"]:
		root.add_to_group(group, true)
	model(root, about.model)
	solids(root, root, shape.solids, "Body", Vector3.ZERO)
	return root


func ammo_box(about: Dictionary) -> Node3D:
	var root := Area3D.new()
	root.name = "AmmoBox"
	root.set_script(load("res://scripts/ammo_box.gd"))
	root.collision_layer = 0
	root.collision_mask = 3
	root.add_to_group(&"interest", true)
	model(root, "res://models/guns/ammo_box.glb")
	var zone := CollisionShape3D.new()
	zone.name = "Zone"
	var reach := SphereShape3D.new()
	reach.radius = 0.9
	zone.shape = reach
	zone.position.y = 0.4
	root.add_child(zone)
	zone.owner = root
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.set_meta(&"surface", &"wood")
	root.add_child(body)
	body.owner = root
	solids(root, body, about.solids, "Body", Vector3.ZERO)
	return root


func model(root: Node3D, path: String) -> void:
	var made: Node3D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	made.name = "Model"
	root.add_child(made)
	made.owner = root


## The collision shapes of one part of a model, under `parent`, which is at `pivot`.
func solids(root: Node3D, parent: Node3D, list: Array, part: String, pivot: Vector3) -> void:
	var count := 0
	for solid: Dictionary in list:
		if solid.get("part", "Body") != part:
			continue
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
		if solid.has("basis"):
			collider.transform = Transform3D(Basis(vector(solid.basis[0]), vector(solid.basis[1]), vector(solid.basis[2])).orthonormalized(), vector(solid.origin) - pivot)
		parent.add_child(collider)
		collider.owner = root


func markers(root: Node3D, parent: Node3D, list: Dictionary, pivot: Vector3) -> void:
	for label: String in list:
		var marker := Marker3D.new()
		marker.name = label
		marker.position = vector(list[label]) - pivot
		parent.add_child(marker)
		marker.owner = root


func save(name: String, root: Node3D) -> void:
	var scene := PackedScene.new()
	var result := scene.pack(root)
	if result == OK:
		result = ResourceSaver.save(scene, "res://guns/%s.tscn" % name)
	print("SCENE %s %s" % [name, "ok" if result == OK else "FAILED %d" % result])
	root.free()


func vector(from: Array) -> Vector3:
	return Vector3(from[0], from[1], from[2])
