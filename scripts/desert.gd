class_name Desert
extends Node3D
## The desert (`desert.tscn`): dunes several hundred metres across, an oasis, a
## camp, a ruined colonnade, the sphinx, and the great pyramid behind it.
##
## It is made here from a layout (`LevelLayout`): the one the game came with
## (`levels/desert.json`), or the one saved on this device by the level editor
## (`scripts/level_editor.gd`, behind "Edit this level" in the menu), which is
## how it is changed. The scene itself holds only the light (`Sky`, `Sun`:
## ordinary nodes, turn the sun and change the sky there), the `Terrain`, the
## player, the camera and the controls.
##
## The layout says what the ground is (`DesertTerrain.shape_from`) and lists
## everything on it. Each item becomes a node under `Items` (`make`): a prop
## from `props/`, a gun or target from `guns/`, water, a person, a part of a
## puzzle. PROPS.md says what each prop is.
##
## Puzzles are made of things that are either on or off (a pressure plate, a
## target that has been knocked down, a pot that has been smashed) and things
## worked by them (a door, a bridge, a sand fall, a hound, the mummy): each of
## these keeps `links`, the ids of what works it.
##
## What else this does: the light on the web, checkpoints, catching, and
## putting back loose things that have been lost.

const Plate := TombParts.Plate
const Door := TombParts.Door

## How much of the sun is left on in the web's renderer (see `Sand.sky`).
const WEB_SUN := 0.3
const STONE := Color(0.62, 0.55, 0.44)
const WOOD := Color(0.5, 0.38, 0.24)

## Where to put him when the level next opens, if anywhere: the editor's "Play from here".
static var play_from := Vector3.INF

## How near a checkpoint he must come for it to become where he starts again.
@export var checkpoint_radius := 5.0

## What the level is made from.
var layout: Dictionary:
	set(value):
		layout = value
		if mirage:
			heat(float(layout.get("mirage", HeatMirage.USUAL)))
## The ground.
var terrain: DesertTerrain
## The wind over the level.
var wind: SandWind
## The heat over the level: how much the distance swims is the layout's `mirage`.
var mirage: HeatMirage
## What each item was made into, by its id. (Pads and dunes are only ground: they have none.)
var nodes := {}

var _items: Node3D
var _player: Player
var _marks: Array[Node3D] = []
var _mark: Node3D
var _loose: Array[RigidBody3D] = []
var _loose_starts: Array[Transform3D] = []
# Which triggers are on, by id.
var _on := {}
# What is worked by triggers: [item, node].
var _worked: Array = []
var _hounds: Array[Hound] = []


func _enter_tree() -> void:
	# Before the ground makes its sand: on the web a sun that casts shadows
	# comes out much too bright. There it is turned down and the sand is told,
	# just as in the test yard.
	Sand.sun_gain = 1.0
	Sand.sky = Color.BLACK
	var sun := get_node_or_null(^"Sun") as DirectionalLight3D
	var sky := get_node_or_null(^"Sky") as WorldEnvironment
	if sun and sky and sky.environment and RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy *= WEB_SUN
		Sand.sun_gain = 1.0 / WEB_SUN
		Sand.sky = sky.environment.ambient_light_color.srgb_to_linear() * sky.environment.ambient_light_energy
		sky.environment.fog_enabled = false
	# And before the ground is made at all, it is told what shape to be.
	layout = LevelLayout.load_layout()
	terrain = get_node(^"Terrain") as DesertTerrain
	terrain.shape_from(layout)


func _ready() -> void:
	add_to_group(&"editable_level")
	_items = Node3D.new()
	_items.name = "Items"
	add_child(_items)
	for item: Dictionary in layout["items"]:
		make(item)
	mirage = HeatMirage.new()
	add_child(mirage)
	heat(float(layout.get("mirage", HeatMirage.USUAL)))
	_weather()
	_settle_in.call_deferred()


## Sets how much the heat makes the distance swim, 0..1 (0: not at all).
func heat(strength: float) -> void:
	mirage.strength = clampf(strength, 0.0, 1.0)


## How high the ground is at a place.
func height_at(x: float, z: float) -> float:
	return terrain.height_at(x, z)


## Where an item stands.
func place_of(item: Dictionary) -> Vector3:
	var at: Array = item["at"]
	if item.has("y"):
		return Vector3(at[0], item["y"], at[1])
	return Vector3(at[0], height_at(at[0], at[1]) + item.get("lift", 0.0), at[1])


## How an item is turned.
func turn_of(item: Dictionary) -> Basis:
	var basis := Basis.from_euler(Vector3(deg_to_rad(item.get("tilt_x", 0.0)), deg_to_rad(item.get("yaw", 0.0)), deg_to_rad(item.get("tilt_z", 0.0))))
	if item.get("kind", "") == "prop":
		var stretch: Array = item.get("stretch", [1.0, 1.0, 1.0])
		basis = basis.scaled_local(Vector3(stretch[0], stretch[1], stretch[2]) * float(item.get("scale", 1.0)))
	return basis


## Makes an item's node (none, for what is only ground) and puts it in the level.
func make(item: Dictionary) -> Node3D:
	var id: int = item["id"]
	forget(id)
	var made := _made(item)
	if made == null:
		return null
	made.set_meta(&"item", id)
	# (placed before it enters the level: most things note where they start as they do)
	if not (made is Pool):
		made.transform = Transform3D(turn_of(item), place_of(item))
	_items.add_child(made)
	nodes[id] = made
	_wire(item, made)
	return made


## Takes an item's node out of the level.
func forget(id: int) -> void:
	if nodes.has(id):
		var old: Node = nodes[id]
		nodes.erase(id)
		if is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.queue_free()
	_worked = _worked.filter(func(entry: Array) -> bool: return entry[0]["id"] != id)


## Moves an item's node to where the item now says it is.
func put(item: Dictionary) -> void:
	var node: Node3D = nodes.get(item["id"])
	if node and not (node is Pool):
		node.global_transform = Transform3D(turn_of(item), place_of(item))
		if node.has_meta(&"home"):
			node.set_meta(&"home", node.position)
	elif node:
		make(item)


## Makes the ground again from the layout, and stands everything on it afresh.
func reshape() -> void:
	terrain.shape_from(layout)
	terrain.rebuild()
	for item: Dictionary in layout["items"]:
		if item["kind"] in ["pond", "river", "pool"]:
			make(item)
		else:
			put(item)
	_weather()


func _made(item: Dictionary) -> Node3D:
	var what: String = item.get("what", "")
	match item["kind"]:
		"prop", "thing":
			var path := "res://%s/%s.tscn" % ["props" if item["kind"] == "prop" else "guns", what]
			if not ResourceLoader.exists(path):
				return null
			var prop := (load(path) as PackedScene).instantiate() as Node3D
			# Every brazier, torch stand and campfire is lit.
			for marker in prop.find_children("Flame*", "Marker3D", true, false):
				marker.add_child(Fire.brazier())
			# And whatever would hold a grappling hook will: the ends of a lintel, the top of a column, the crown of a palm.
			GrapplePoint.auto(prop, what)
			return prop
		"pyramid":
			return Pyramid.from_item(item)
		"pond", "river":
			for water: Dictionary in terrain.waters():
				if water["id"] == item["id"]:
					var rect: Rect2 = water["rect"]
					var pool := Pool.new()
					pool.size = Vector3(rect.size.x, float(water["depth"]) + 0.6, rect.size.y)
					pool.position = Vector3(rect.get_center().x, water["level"], rect.get_center().y)
					var points: PackedVector2Array = water["points"]
					if points.size() > 1:
						pool.set_meta(&"flow", (points[points.size() - 1] - points[0]).normalized() * 0.5)
					return pool
			return null
		"pool":
			var tank := Pool.new()
			tank.size = Vector3(item.get("size_x", 6.0), item.get("depth", 3.0), item.get("size_z", 6.0))
			tank.position = place_of(item)
			return tank
		"person":
			return _person(item, what)
		"plate":
			var plate := Plate.new()
			plate.span = Vector3(item.get("span_x", 1.6), 0.5, item.get("span_z", 1.6))
			plate.latches = item.get("latches", false)
			if item.get("only_him", false):
				plate.collision_mask = 2
			return plate
		"door":
			return Door.new(Vector3(item.get("wide", 3.0), item.get("tall", 2.6), item.get("thick", 0.4)), STONE.darkened(0.25))
		"mover":
			var mover := AnimatableBody3D.new()
			var size := Vector3(item.get("wide", 2.4), item.get("thick", 0.3), item.get("long", 4.0))
			var shape := BoxShape3D.new()
			shape.size = size
			var collider := CollisionShape3D.new()
			collider.shape = shape
			mover.add_child(collider)
			var mesh := BoxMesh.new()
			mesh.size = size
			var visual := MeshInstance3D.new()
			visual.mesh = mesh
			visual.material_override = Toon.surface(WOOD)
			mover.add_child(visual)
			return mover
		"torch":
			var torch := HandTorch.new()
			torch.lit = item.get("lit", true)
			return torch
		"grapple":
			var hook := GrappleHook.new()
			hook.reach = item.get("reach", 9.5)
			return hook
		"grapple_point":
			var point := GrapplePoint.new()
			point.ring = item.get("ring", true)
			return point
		"rope":
			var rope := Rope.new()
			rope.length = item.get("length", 5.5)
			return rope
		"ladder":
			var ladder := Ladder.new()
			ladder.height = item.get("height", 4.0)
			return ladder
		"sandfall":
			var fall := SandFall.new()
			fall.width = item.get("width", 0.0)
			fall.running = item.get("running", true)
			return fall
		"checkpoint", "start":
			var mark := Marker3D.new()
			if item["kind"] == "checkpoint":
				mark.add_to_group(&"checkpoints")
			return mark
		"sign":
			var label := Label3D.new()
			label.text = String(item.get("text", "")).replace("\\n", "\n")
			label.font_size = 56
			label.pixel_size = 0.006
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.modulate = Color(1.0, 1.0, 1.0, 0.85)
			label.outline_size = 8
			label.outline_modulate = Color(0.0, 0.0, 0.0, 0.5)
			return label
	return null


func _person(item: Dictionary, who: String) -> Node3D:
	match who:
		"townsperson":
			var someone := Townsperson.new()
			someone.seed = int(item.get("seed", 1))
			someone.sex = int(item.get("sex", 0)) as CharacterLook.Sex
			someone.wander = item.get("wander", 3.5)
			return someone
		"brother":
			return Brother.new()
		"cat":
			var cat := Cat.new()
			cat.coat = int(item.get("coat", 0)) as Cat.Coat
			cat.tame = item.get("tame", 0.6)
			cat.curiosity = item.get("curiosity", 0.6)
			return cat
		"hound":
			var hound := Hound.new()
			hound.breed = int(item.get("breed", 0)) as Hound.Breed
			return hound
		"mummy":
			var mummy := Mummy.new()
			mummy.kind = int(item.get("sort", 0)) as Mummy.Kind
			return mummy
		"camel":
			var camel := Camel.new()
			camel.saddled = item.get("saddled", false)
			camel.packed = item.get("packed", false)
			camel.couched = item.get("couched", false)
			camel.roam = item.get("roam", 6.0)
			if item.get("tethered", false):
				# (to a peg a little way from where it is put)
				camel.tether = place_of(item) + Vector3(1.2, 0.0, 0.0)
			return camel
		"jackal_mummy":
			var jackal := JackalMummy.new()
			jackal.rest = int(item.get("rest", 0)) as JackalMummy.Rest
			jackal.finery = int(item.get("finery", 0)) as JackalMummy.Finery
			# (it wakes itself when he comes near; what it is linked to wakes it too: see `_physics_process`)
			jackal.wake_within = item.get("alert", 5.0)
			return jackal
		"hyena":
			var hyena := Hyena.new()
			hyena.bold = item.get("bold", 0.4)
			hyena.roam = item.get("roam", 12.0)
			return hyena
	return null


# What an item's node has to be told once it is in the level.
func _wire(item: Dictionary, made: Node3D) -> void:
	var id: int = item["id"]
	if made is Pool:
		var pool := made as Pool
		if item["kind"] != "pool":
			# (it lies in the ground, not in a tank: there are no sides to it to draw)
			pool.water.sides = false
			if pool.has_meta(&"flow"):
				pool.water.flow = pool.get_meta(&"flow")
				pool.water.foam_drift = 0.25
	elif made is Plate:
		(made as Plate).changed.connect(func(pressed: bool) -> void: _on[id] = pressed)
	elif made is ShootTarget:
		(made as ShootTarget).fell.connect(func() -> void: _on[id] = true)
		(made as ShootTarget).hit.connect(func(_by: Node3D, _at: Vector3, _score: float) -> void: _on[id] = true)
	elif made is Breakable:
		(made as Breakable).shattered.connect(func(_by: Node3D) -> void: _on[id] = true)
	elif made is Hound:
		_hounds.append(made)
		(made as Hound).caught.connect(_on_caught.bind(made))
	elif made is Mummy:
		(made as Mummy).caught.connect(_on_caught.bind(made))
	elif made is JackalMummy:
		(made as JackalMummy).caught.connect(_on_caught.bind(made))
	elif made is Hyena:
		(made as Hyena).caught.connect(_on_caught.bind(made))
	if made is RigidBody3D and made.is_in_group(&"throwable"):
		_loose.append(made)
		_loose_starts.append(made.global_transform)
	if item.has("links") or item["kind"] in ["door", "mover", "sandfall"] or made is Hound or made is Mummy:
		made.set_meta(&"home", made.position)
		_worked.append([item, made])
	# (a mummified jackal and a hyena are put back when he starts again, as a hound is, whether or not anything works them)
	if (made is JackalMummy or made is Hyena) and not item.has("links"):
		_worked.append([item, made])
	if _player:
		_introduce(made)


# The wind, and damp sand round whatever water there is.
func _weather() -> void:
	if wind:
		wind.queue_free()
	wind = SandWind.new()
	wind.weather = int(layout.get("weather", 1)) as SandWind.Weather
	wind.direction = terrain.wind
	add_child(wind)
	mirage.wind = wind
	var sand := terrain.ground as SandGround
	if sand == null:
		return
	for item: Dictionary in layout["items"]:
		var at := Vector2(item["at"][0], item["at"][1])
		match item["kind"]:
			"pool":
				sand.paint(Sand.Kind.DAMP, at, maxf(item.get("size_x", 6.0), item.get("size_z", 6.0)) * 0.5 + 1.5, 1.0, 3.5)
			"pond":
				sand.paint(Sand.Kind.DAMP, at, float(item.get("radius", 8.0)) + 2.0, 1.0, 3.5)
			"river":
				var points: Array = item.get("points", [])
				for i in points.size() - 1:
					sand.paint_line(Sand.Kind.DAMP, Vector2(points[i][0], points[i][1]), Vector2(points[i + 1][0], points[i + 1][1]), float(item.get("width", 9.0)) * 0.5 + 1.5, 1.0, 3.0)


func _settle_in() -> void:
	_player = get_parent().get_node_or_null(^"Player") as Player
	if _player == null:
		return
	mirage.subject = _player
	# He starts where the layout says, or where the editor left off.
	var start := play_from
	play_from = Vector3.INF
	if start == Vector3.INF:
		for item: Dictionary in layout["items"]:
			if item["kind"] == "start":
				start = place_of(item)
	if start != Vector3.INF:
		start.y = maxf(start.y, height_at(start.x, start.z)) + 0.05
		_player.global_position = start
		_player.velocity = Vector3.ZERO
		_player.set_spawn(start)
		var camera := get_parent().get_node_or_null(^"Camera") as FollowCamera
		if camera:
			camera.snap()
	_player.respawned.connect(_call_off)
	for node: Node3D in nodes.values():
		_introduce(node)
	for mark: Node in get_tree().get_nodes_in_group(&"checkpoints"):
		if mark is Node3D:
			_marks.append(mark)


# Tells one of the level's people who the player is.
func _introduce(node: Node3D) -> void:
	if node is Brother:
		(node as Brother).follow(_player)
	elif node is Hound:
		(node as Hound).target = _player
	elif node is Mummy:
		(node as Mummy).target = _player
	elif node is JackalMummy:
		(node as JackalMummy).target = _player
	elif node is Hyena:
		(node as Hyena).target = _player


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var at := _player.global_position
	if _player.is_on_floor():
		for mark in _marks:
			if is_instance_valid(mark) and mark != _mark and at.distance_to(mark.global_position) < checkpoint_radius:
				_mark = mark
				_player.set_spawn(mark.global_position + Vector3.UP * 0.05)
	# Anything loose that has left the world goes back where it was put.
	for i in _loose.size():
		var thing := _loose[i]
		if is_instance_valid(thing) and thing != _player.carried and thing.global_position.y < _player.kill_height:
			thing.linear_velocity = Vector3.ZERO
			thing.angular_velocity = Vector3.ZERO
			thing.global_transform = _loose_starts[i]
	# Whatever is worked by a trigger does as its triggers say.
	for entry: Array in _worked:
		var item: Dictionary = entry[0]
		var node: Node3D = entry[1]
		if not is_instance_valid(node):
			continue
		var links: Array = item.get("links", [])
		var count := 0
		for link: int in links:
			if _on.get(link, false):
				count += 1
		var worked := not links.is_empty() and (count == links.size() if item.get("needs_all", false) else count > 0)
		if item.get("inverted", false):
			worked = not worked
		var near := at.distance_to(node.global_position) < float(item.get("alert", 0.0))
		if node is Door:
			(node as Door).is_open = worked
		elif node is SandFall:
			(node as SandFall).running = bool(item.get("running", true)) != worked
		elif node is Hound:
			if (worked or near) and not _player.is_limp:
				(node as Hound).chasing = true
		elif node is Mummy:
			if (worked or near) and not (node as Mummy).is_awake():
				(node as Mummy).wake()
		elif node is JackalMummy:
			if worked and not (node as JackalMummy).is_awake():
				(node as JackalMummy).wake()
		elif node is AnimatableBody3D:
			var home: Vector3 = node.get_meta(&"home")
			var way: Vector3 = [node.basis.z, Vector3.UP, node.basis.x][int(item.get("way", 0))].normalized()
			var to := home + way * float(item.get("travel", 4.0)) if worked else home
			node.position = node.position.move_toward(to, float(item.get("speed", 2.0)) * delta)


## Caught: he goes down, then starts again from the last checkpoint.
func _on_caught(by: Node3D) -> void:
	if _player == null or _player.is_limp:
		return
	_player.ragdoll((_player.global_position - by.global_position).normalized() * 24.0 + Vector3.UP * 12.0)
	for hound in _hounds:
		if is_instance_valid(hound):
			hound.chasing = false
	await get_tree().create_timer(2.2).timeout
	if _player.is_limp:
		_player.respawn()


func _call_off() -> void:
	for entry: Array in _worked:
		if not is_instance_valid(entry[1]):
			continue
		if entry[1] is Hound:
			(entry[1] as Hound).reset()
		elif entry[1] is Mummy:
			(entry[1] as Mummy).reset()
		elif entry[1] is JackalMummy:
			(entry[1] as JackalMummy).reset()
		elif entry[1] is Hyena:
			(entry[1] as Hyena).reset()
