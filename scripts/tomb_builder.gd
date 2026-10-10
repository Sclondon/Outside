class_name TombBuilder
extends RefCounted
## Makes a tomb's layout (`TombLayout`) into stone and working parts under a
## node, and keeps hold of everything a level needs to run it (`TombLevel`).
## Each room on the axis is a node of its own (`room_nodes`), with one solid
## body for all its stone, so that rooms far from him can be put away.

const WALL_STONE := Color(0.5, 0.42, 0.3)
const FLOOR_STONE := Color(0.4, 0.34, 0.25)
const CUT_ROCK := Color(0.2, 0.17, 0.13)
const LOFT_STONE := Color(0.46, 0.39, 0.29)
const KERB_STONE := Color(0.3, 0.26, 0.2)
const SAND := Color(0.5, 0.43, 0.3)
const BLOCK_STONE := Color(0.56, 0.47, 0.32)
const DOOR_STONE := Color(0.24, 0.21, 0.17)
const BEAM_WOOD := Color(0.2, 0.14, 0.09)

var layout: TombLayout
var root: Node3D
## By the plan's room (a loft or a crypt has its parent's node).
var room_nodes: Array[Node3D] = []
## By link: the door, where there is one.
var doors := {}
## By link: the sand that pours in to make a way up (a SandFall), where there is one.
var sands := {}
## The ropes that hang down shafts.
var ropes: Array[Rope] = []
## By switch: the Plate (a plate, a seal stone, an offering table), or for a
## brazier the prop it is.
var switches := {}
## Each block: `body`, `home` (where it started), `thing` (the plan's, or -1 for
## one that belongs to the plate of its own room).
var blocks: Array[Dictionary] = []
## By thing: what he carries. And where each goes back to.
var items := {}
var item_homes := {}
## Each mummy: `node`, `room`, `guardian`, `safe` (how far along he is out of its reach) and `east` (whether that is the far side).
var mummies: Array[Dictionary] = []
var treasure: Area3D
## Pits: he dies in these.
var deaths: Array[Area3D] = []
## Where he starts again: `room` and `at`.
var checks: Array[Dictionary] = []
## Inscriptions: `at`, `hint`, `room`.
var writings: Array[Dictionary] = []
## What the hooks made (swarms and the rest), to be reset with the room.
var hooked: Array[Node3D] = []

var _materials := {}
var _bodies := {}


static func build(from: TombLayout, under: Node3D) -> TombBuilder:
	var builder := TombBuilder.new()
	builder.layout = from
	builder.root = under
	builder._build()
	return builder


func _build() -> void:
	var plan := layout.plan
	room_nodes.resize(plan.rooms.size())
	for room in plan.spine():
		var node := Node3D.new()
		node.name = "Room%d_%s" % [room.id, TombPlan.ROLE_NAMES[room.role]]
		root.add_child(node)
		room_nodes[room.id] = node
		var body := StaticBody3D.new()
		body.name = "Stone"
		node.add_child(body)
		_bodies[room.id] = body
	for room in plan.rooms:
		if room.spine < 0:
			room_nodes[room.id] = room_nodes[room.parent]
			_bodies[room.id] = _bodies[room.parent]
	for box: Array in layout.boxes:
		_stone(box[0], box[1], box[2], box[3], box[4])
	for part in layout.parts:
		_part(part)


func _stone(at: Vector3, size: Vector3, made_of: String, solid: bool, room: int) -> void:
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = at
		(_bodies[room] as StaticBody3D).add_child(collider)
	if made_of == "":
		return
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(made_of)
	visual.position = at
	room_nodes[room].add_child(visual)


func _material(made_of: String) -> Material:
	if _materials.has(made_of):
		return _materials[made_of]
	var material: Material
	match made_of:
		"wall":
			material = Sandstone.surface(WALL_STONE, 0.7, 1.4, 0.45, 0.35)
		"floor":
			material = Sandstone.surface(FLOOR_STONE, 1.2, 1.2, 0.6, 0.5)
		"rock":
			material = Sandstone.surface(CUT_ROCK, 3.0, 5.0, 0.8, 0.7)
		"loft":
			material = Sandstone.surface(LOFT_STONE, 0.3, 1.0, 0.4, 0.3)
		"kerb":
			material = Toon.surface(KERB_STONE)
		"block":
			material = Sandstone.surface(BLOCK_STONE, 0.9, 0.9, 0.3, 0.6)
		"gold":
			material = Toon.gold()
		"sand":
			material = Toon.surface(SAND)
		"wood":
			material = Toon.surface(BEAM_WOOD)
		_:
			material = Toon.surface(WALL_STONE)
	_materials[made_of] = material
	return material


func _part(part: Dictionary) -> void:
	var room: int = part["room"]
	var node := room_nodes[room]
	var at: Vector3 = part["at"]
	match part["kind"]:
		"torch":
			var torch := TombParts.Torch.new()
			torch.position = at
			node.add_child(torch)
		"bowl":
			var bowl := _scene("brazier", at, 0.0, node)
			var flame := bowl.find_child("Flame*", true, false) as Node3D
			(flame if flame else bowl).add_child(Fire.brazier())
		"pillar":
			var high: float = part["high"]
			for piece: Array in [[high * 0.5, Vector3(0.6, high, 0.6)], [high - 0.2, Vector3(0.85, 0.4, 0.85)], [0.15, Vector3(0.85, 0.3, 0.85)]]:
				_show(node, at + Vector3.UP * float(piece[0]), piece[1], "loft")
		"glyphs":
			node.add_child(_signs(at, part["long"]))
		"prop":
			_scene(part["scene"], at, part["yaw"], node)
		"door":
			var size: Vector3 = part["size"]
			var door := TombParts.Door.new(size, DOOR_STONE)
			door.position = at
			if part["sinks"]:
				# (it goes down into the floor: there is a loft over it)
				door.height = -size.y - 0.05
			node.add_child(door)
			doors[part["link"]] = door
		"plate":
			var plate := _plate(node, at, Vector3(1.5, 0.5, TombLayout.FRONT - TombLayout.BACK - 0.3), false, 1)
			switches[part["trigger"]] = plate
		"lever":
			var stone := _plate(node, at, Vector3(1.1, 0.5, 1.6), true, 2)
			_show(stone, Vector3(0.0, 0.02, 0.0), Vector3(0.5, 0.03, 0.5), "gold")
			switches[part["trigger"]] = stone
		"offering":
			var table := _plate(node, at, Vector3(TombLayout.TABLE_LONG - 0.2, 0.6, 2.0), false, 1)
			switches[part["trigger"]] = table
		"brazier":
			switches[part["trigger"]] = _scene("brazier", at, 0.0, node)
		"block":
			var block := RigidBody3D.new()
			block.add_to_group(&"interest")
			block.add_to_group(&"tomb_blocks")
			block.mass = 20.0
			block.lock_rotation = true
			# (it keeps to his line, so that it cannot be lost against the back wall)
			block.axis_lock_linear_z = true
			var surface := PhysicsMaterial.new()
			surface.friction = 0.6
			block.physics_material_override = surface
			var shape := BoxShape3D.new()
			shape.size = Vector3.ONE * TombLayout.BLOCK
			var collider := CollisionShape3D.new()
			collider.shape = shape
			block.add_child(collider)
			_show(block, Vector3.ZERO, shape.size, "block")
			block.position = at
			node.add_child(block)
			blocks.append({"body": block, "home": Transform3D(Basis.IDENTITY, at), "thing": part["thing"], "serves": part["serves"]})
		"item":
			var thing := _item(part["what"], at)
			thing.axis_lock_linear_z = true
			# (the stone stops it, but nothing trips over it: he is on one line and cannot go round)
			thing.collision_layer = 16
			thing.collision_mask = 1
			node.add_child(thing)
			items[part["thing"]] = thing
			item_homes[part["thing"]] = thing.transform
		"ladder":
			var ladder := Ladder.new()
			ladder.height = part["high"]
			ladder.position = at
			ladder.rotation.y = part["yaw"]
			node.add_child(ladder)
		"rope":
			# A beam wedged across under the roof, and the rope made fast to it.
			_show(node, at + Vector3(0.0, 0.03, (TombLayout.BACK + TombLayout.FRONT) * 0.5), Vector3(0.16, 0.14, TombLayout.FRONT - TombLayout.BACK), "wood")
			_show(node, at + Vector3(0.0, -0.06, 0.0), Vector3(0.2, 0.08, 0.2), "wood")
			var rope := Rope.new()
			rope.length = part["long"]
			rope.drag = TombLayout.ROPE_DRAG
			rope.thickness = 0.035
			rope.position = at
			node.add_child(rope)
			ropes.append(rope)
		"sand":
			# A slot in the roof, and behind it all the sand the heap will hold.
			_show(node, at + Vector3(0.0, -0.02, 0.0), Vector3(0.5, 0.06, 0.5), "kerb")
			var cap: float = part["cap"]
			var fall := SandFall.new()
			fall.running = false
			fall.pile_cap = cap
			fall.rate = sand_rate(cap, 0.0)
			fall.position = at
			node.add_child(fall)
			sands[part["link"]] = fall
		"pool":
			var pool := Pool.new()
			pool.size = part["size"]
			pool.position = at
			node.add_child(pool)
		"ring":
			var ring := GrapplePoint.new()
			ring.ring = true
			ring.position = at
			node.add_child(ring)
		"mummy":
			var mummy := Mummy.new()
			mummy.kind = part["what"] as Mummy.Kind
			mummy.position = at + Vector3.UP * 0.05
			node.add_child(mummy)
			mummies.append({"node": mummy, "room": room, "guardian": part["guardian"], "safe": part["safe"], "east": part["east"], "lost": 0.0})
		"treasure":
			_treasure(node, at)
		"death":
			var area := Area3D.new()
			area.collision_mask = 2
			var shape := BoxShape3D.new()
			shape.size = part["size"]
			var collider := CollisionShape3D.new()
			collider.shape = shape
			area.add_child(collider)
			area.position = at
			node.add_child(area)
			deaths.append(area)
		"check":
			checks.append({"room": room, "at": at})
		"inscription":
			TombHooks.inscription(node, at, part["hint"], TombRandom.mix([layout.plan.seed_value, int(at.x * 10.0)]))
			writings.append({"at": at, "hint": part["hint"], "room": room})
		"scarabs":
			hooked.append(TombHooks.scarabs(node, at))
		"cobweb":
			hooked.append(TombHooks.cobweb(node, at, part["size"]))
		"jackal":
			var guard := TombHooks.jackal(node, at)
			if guard:
				mummies.append({"node": guard, "room": room, "guardian": true, "safe": at.x - 100.0, "east": false, "lost": 0.0})


## How much sand a second has to come in for a heap that is `radius` wide to be
## as wide as `cap` in `TombLayout.SAND_TIME`, getting higher at an even pace
## (a steady stream would raise it fast at first and then hardly at all).
static func sand_rate(cap: float, radius: float) -> float:
	var wide := maxf(radius, 0.4)
	return tan(SandPile.SLOPE) * PI * wide * wide * cap / TombLayout.SAND_TIME


func _scene(name: String, at: Vector3, yaw: float, node: Node3D) -> Node3D:
	var made := (load("res://props/%s.tscn" % name) as PackedScene).instantiate() as Node3D
	made.position = at
	made.rotation.y = yaw
	node.add_child(made)
	return made


# Something to look at that is not solid.
func _show(node: Node3D, at: Vector3, size: Vector3, made_of: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(made_of)
	visual.position = at
	node.add_child(visual)


func _plate(node: Node3D, at: Vector3, span: Vector3, latches: bool, mask: int) -> TombParts.Plate:
	var plate := TombParts.Plate.new()
	plate.span = span
	plate.latches = latches
	plate.position = at
	node.add_child(plate)
	# (a plate for a block takes no notice of him; a seal stone only of him)
	plate.collision_mask = mask
	return plate


func _item(kind: int, at: Vector3) -> RigidBody3D:
	match kind:
		TombPlan.Item.TORCH:
			var torch := HandTorch.new()
			torch.position = at + Vector3.UP * 0.02
			torch.rotation.z = 0.12
			torch.freeze = true
			return torch
		TombPlan.Item.HOOK:
			var hook := GrappleHook.new()
			hook.position = at + Vector3.UP * 0.16
			hook.rotation.x = PI * 0.5
			hook.freeze = true
			return hook
	var jar := (load("res://props/jar_canopic.tscn") as PackedScene).instantiate() as RigidBody3D
	jar.add_to_group(&"tomb_jars")
	jar.position = at + Vector3.UP * 0.3
	# (it stands where it is until it is taken up)
	jar.freeze = true
	return jar


# What he came for: a gold figure on a stone, and the space round it that takes it.
func _treasure(node: Node3D, at: Vector3) -> void:
	_stone(at + Vector3.UP * 0.35, Vector3(0.7, 0.7, 0.7), "loft", true, layout.plan.goal_trigger().room)
	treasure = Area3D.new()
	treasure.collision_mask = 2
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	treasure.add_child(collider)
	treasure.position = at + Vector3.UP * 0.9
	node.add_child(treasure)
	var figure := Node3D.new()
	figure.name = "Figure"
	treasure.add_child(figure)
	# A falcon of gold, in the fewest pieces that say so: body, head, beak, crown.
	for piece: Array in [[Vector3(0.0, 0.0, 0.0), Vector3(0.2, 0.34, 0.16)], [Vector3(0.03, 0.24, 0.0), Vector3(0.16, 0.14, 0.14)],
			[Vector3(0.13, 0.22, 0.0), Vector3(0.08, 0.05, 0.05)], [Vector3(0.0, 0.36, 0.0), Vector3(0.1, 0.12, 0.1)], [Vector3(0.0, -0.2, 0.0), Vector3(0.3, 0.06, 0.24)]]:
		_show(figure, piece[0], piece[1], "gold")
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.4)
	glow.light_energy = 0.9
	glow.omni_range = 3.5
	glow.position.y = 0.3
	figure.add_child(glow)


# A band of carved signs along the back wall.
func _signs(at: Vector3, long: float) -> MultiMeshInstance3D:
	var rng := TombRandom.new(TombRandom.mix([layout.plan.seed_value, int(at.x * 10.0), 31]))
	var signs := MultiMesh.new()
	signs.transform_format = MultiMesh.TRANSFORM_3D
	signs.mesh = BoxMesh.new()
	var columns := int(long / 0.42)
	signs.instance_count = columns * 2
	for column in columns:
		for row in 2:
			var size := Vector3(rng.spread(0.08, 0.3), rng.spread(0.1, 0.26), 0.04)
			var place := Vector3(column * 0.42 + rng.spread(-0.05, 0.05), row * 0.36, 0.0)
			signs.set_instance_transform(column * 2 + row, Transform3D(Basis.from_scale(size), place))
	var band := MultiMeshInstance3D.new()
	band.multimesh = signs
	band.material_override = _material("kerb")
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	band.position = at
	return band
