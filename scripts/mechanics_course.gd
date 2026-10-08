extends Node3D
## The test ground: an open yard to run about in, with a station for each thing
## the player can do set out round it, and a pen each for the hounds and the
## mummy. Run `mechanics.tscn`. The camera orbits here; drag to turn it.
##
## Stations are checkpoints: he comes back to the last one he was near.

const Plate := TombParts.Plate
const Door := TombParts.Door

const GROUND := Color(0.3, 0.32, 0.34)
const PROP := Color(0.42, 0.44, 0.47)
const DARK := Color(0.26, 0.27, 0.3)
const MARK := Color(0.62, 0.5, 0.3)
const SKY := Color(0.5, 0.56, 0.62)
const YARD := 42.0
const TALL := 4.6
## How far the bridge runs out from under the far tower.
const BRIDGE_TRAVEL := 4.2

var _player: Player
var _stations: Array[Vector3] = []
var _station := -1
var _rocks: Array[RigidBody3D] = []
var _rock_starts: Array[Vector3] = []
var _bridge: AnimatableBody3D
var _bridge_home := 0.0
var _bridge_out := false
var _hounds: Array[Hound] = []
var _mummy: Mummy


func _ready() -> void:
	_build_light()
	_build_yard()
	_build_push(Vector3(10.0, 0.0, -9.0))
	_build_low(Vector3(22.0, 0.0, 0.0))
	_build_climb(Vector3(0.0, 0.0, 14.0))
	_build_hounds(Vector3(-14.0, 0.0, 0.0))
	_build_mummy(Vector3(0.0, 0.0, -18.0))
	_build_stairs(Vector3(-28.0, 0.0, 18.0))
	_settle_in.call_deferred()


func _build_light() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.66, 0.74)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = SKY
	environment.fog_density = 0.008
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _build_yard() -> void:
	_solid(Vector3(0.0, -1.0, 0.0), Vector3(YARD * 2.0, 2.0, YARD * 2.0), GROUND)
	# A wall to see, and a taller one that cannot be climbed or thrown over
	for edge: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var along := Vector3(absf(edge.z), 0.0, absf(edge.x))
		_solid(edge * YARD + Vector3.UP * 0.9, along * YARD * 2.0 + (Vector3.ONE - along) * Vector3(1.0, 1.8, 1.0), DARK)
		_barrier(edge * (YARD + 0.4) + Vector3.UP * 10.0, along * YARD * 2.0 + (Vector3.ONE - along) * Vector3(1.0, 20.0, 1.0))
	# Something to run round, so it does not feel like a car park
	var random := RandomNumberGenerator.new()
	random.seed = 5
	for i in 16:
		var at := Vector3(random.randf_range(-36.0, 36.0), 0.0, random.randf_range(-36.0, 36.0))
		if at.length() < 30.0:
			continue
		var size := Vector3(random.randf_range(1.0, 3.0), random.randf_range(0.6, 3.5), random.randf_range(1.0, 3.0))
		_solid(at + Vector3.UP * size.y * 0.5, size, PROP)


## 1. Push: the block runs between two rails onto a plate that holds the gate up.
func _build_push(at: Vector3) -> void:
	_station_here(at + Vector3(-4.0, 0.0, 0.0), "PUSH\nwalk into the block", 3.0)
	_block(at + Vector3(-2.0, 0.45, 0.0))
	for z: float in [-0.75, 0.75]:
		_solid(at + Vector3(1.0, 0.1, z), Vector3(7.6, 0.2, 0.2), DARK)
	_solid(at + Vector3(4.9, 0.125, 0.0), Vector3(0.24, 0.25, 1.7), DARK)
	var plate := _plate(at + Vector3(3.85, 0.0, 0.0), Vector3(1.5, 0.5, 1.3), false)
	# The gate, between two posts, with something behind it to walk through to
	var gate := Door.new(Vector3(0.4, 2.4, 3.0), DARK.lightened(0.1))
	gate.position = at + Vector3(7.0, 1.2, 0.0)
	add_child(gate)
	for z: float in [-3.5, 3.5]:
		_solid(at + Vector3(7.0, 1.6, z), Vector3(0.6, 3.2, 4.0), PROP)
	_solid(at + Vector3(7.0, 2.9, 0.0), Vector3(0.6, 1.0, 3.0), PROP)
	plate.changed.connect(func(pressed: bool) -> void: gate.is_open = pressed)


## 2 and 3. Duck under the first bar; the second is lower and needs a slide.
func _build_low(at: Vector3) -> void:
	_station_here(at + Vector3(-4.0, 0.0, 0.0), "DUCK, then SLIDE\nhold duck (C)  ·  run, then duck", 3.4)
	for step: Array in [[0.0, 3.0, 0.95], [7.0, 1.6, 0.7]]:
		var middle: Vector3 = at + Vector3(step[0], 0.0, 0.0)
		_solid(middle + Vector3(0.0, step[2] + 0.6, 0.0), Vector3(step[1], 1.2, 6.0), PROP)
		# Closed off at the sides, so the only way on is under
		for z: float in [-5.0, 5.0]:
			_solid(middle + Vector3(0.0, 1.1, z), Vector3(step[1], 2.2, 4.0), DARK)


## 4, 5 and 6. A wall to catch, a rope up to the high tower, and rocks to throw
## across to the far one, which runs a bridge out.
func _build_climb(at: Vector3) -> void:
	_station_here(at + Vector3(0.0, 0.0, -5.0), "LEDGE\njump at the wall, jump again to climb", 3.6)
	_solid(at + Vector3(0.0, 1.05, 0.0), Vector3(4.0, 2.1, 4.0), PROP)

	_sign(at + Vector3(4.3, 8.6, 0.0), "ROPE\njump in  ·  up and down  ·  jump off")
	var rope := Rope.new()
	rope.length = 6.2
	rope.position = at + Vector3(4.3, 7.5, 0.0)
	add_child(rope)
	_prop(at + Vector3(4.3, 7.6, 1.6), Vector3(0.25, 0.25, 3.6), DARK)
	_prop(at + Vector3(4.3, 3.8, 3.3), Vector3(0.3, 7.6, 0.3), DARK)
	_solid(at + Vector3(9.5, TALL * 0.5, 0.0), Vector3(5.0, TALL, 5.0), PROP)

	_station_here(at + Vector3(9.0, TALL, 0.0), "THROW\nact (E) picks up, act again throws", 3.0)
	for z: float in [-1.0, 0.0, 1.0]:
		_rock(at + Vector3(9.5 + z * 0.3, TALL + 0.15, z))
	_solid(at + Vector3(18.5, TALL * 0.5, 0.0), Vector3(5.0, TALL, 5.0), PROP)
	var target := _plate(at + Vector3(17.9, TALL, 0.0), Vector3(3.2, 0.5, 3.2), true)
	target.changed.connect(func(pressed: bool) -> void: _bridge_out = _bridge_out or pressed)
	# The bridge waits inside the far tower and runs out to the near one.
	_bridge = AnimatableBody3D.new()
	_shape(_bridge, at + Vector3(18.2, TALL - 0.15, 0.0), Vector3(BRIDGE_TRAVEL, 0.3, 2.4), MARK.darkened(0.2))
	_bridge_home = _bridge.position.x


## 7. Hounds: the plate lets them loose, and calls them off again.
func _build_hounds(at: Vector3) -> void:
	_station_here(at, "HOUNDS\nthe plate lets them loose,\nand calls them off", 3.6)
	_plate(at + Vector3(-3.0, 0.0, 0.0), Vector3(1.6, 0.5, 1.6), false, true).changed.connect(_toggle_hounds)
	# Somewhere to climb out of their reach
	_solid(at + Vector3(-6.0, 1.05, -6.0), Vector3(3.0, 2.1, 3.0), PROP)
	for kennel: Vector3 in [Vector3(-18.0, 0.1, -1.5), Vector3(-19.5, 0.1, 1.5)]:
		var hound := Hound.new()
		hound.position = at + kennel
		add_child(hound)
		hound.caught.connect(_on_caught.bind(hound))
		_hounds.append(hound)


## 8. The mummy: the plate wakes it, and puts it back.
func _build_mummy(at: Vector3) -> void:
	_station_here(at, "MUMMY\nthe plate wakes it,\nand puts it back", 3.6)
	_plate(at + Vector3(0.0, 0.0, -3.0), Vector3(1.6, 0.5, 1.6), false, true).changed.connect(_toggle_mummy)
	_block(at + Vector3(0.0, 0.45, -7.0))
	_solid(at + Vector3(0.0, 0.125, -10.0), Vector3(8.0, 0.25, 0.24), DARK)
	_mummy = Mummy.new()
	_mummy.position = at + Vector3(0.0, 0.05, -14.0)
	add_child(_mummy)
	_mummy.caught.connect(_on_caught.bind(_mummy))


## Stairs up to a deck, a ramp back down: ordinary ground to check his feet on.
func _build_stairs(at: Vector3) -> void:
	for i in 8:
		_solid(at + Vector3(i * 0.45, 0.1 + i * 0.1, 0.0), Vector3(0.45, 0.2 * (i + 1), 3.0), PROP)
	_solid(at + Vector3(5.6, 0.8, 0.0), Vector3(4.0, 1.6, 3.0), PROP)
	var ramp := _solid(at + Vector3(10.1, 0.62, 0.0), Vector3(5.4, 0.4, 3.0), PROP)
	ramp.rotation.z = -atan2(1.6, 5.0)


func _settle_in() -> void:
	_player = get_parent().get_node_or_null("Player") as Player
	if _player == null:
		return
	_player.respawned.connect(_restore_rocks)
	_player.respawned.connect(_call_off)
	_mummy.target = _player
	for hound in _hounds:
		hound.target = _player


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var at := _player.global_position
	if _player.is_on_floor():
		for i in _stations.size():
			if i != _station and at.distance_to(_stations[i]) < 3.0:
				_station = i
				_player.set_spawn(_stations[i] + Vector3.UP * 0.05)
	var bridge_to := _bridge_home - BRIDGE_TRAVEL if _bridge_out else _bridge_home
	_bridge.position.x = move_toward(_bridge.position.x, bridge_to, 2.0 * delta)
	# Never leave him with nothing to throw.
	if _rocks.all(func(rock: RigidBody3D) -> bool: return rock.global_position.y < TALL - 1.0 and rock != _player.carried):
		_restore_rocks()


func _restore_rocks() -> void:
	for i in _rocks.size():
		if _rocks[i] == _player.carried:
			continue
		_rocks[i].linear_velocity = Vector3.ZERO
		_rocks[i].angular_velocity = Vector3.ZERO
		_rocks[i].global_position = _rock_starts[i]


func _toggle_hounds(pressed: bool) -> void:
	if not pressed:
		return
	var loose := not _hounds[0].chasing
	for hound in _hounds:
		if loose:
			hound.chasing = true
		else:
			hound.reset()


func _toggle_mummy(pressed: bool) -> void:
	if not pressed:
		return
	if _mummy.is_awake():
		_mummy.reset()
	else:
		_mummy.wake()


## Caught: he goes down, then starts again from the last station.
func _on_caught(by: Node3D) -> void:
	if _player.is_limp:
		return
	_player.ragdoll((_player.global_position - by.global_position).normalized() * 24.0 + Vector3.UP * 12.0)
	for hound in _hounds:
		hound.chasing = false
	await get_tree().create_timer(2.2).timeout
	if _player.is_limp:
		_player.respawn()


func _call_off() -> void:
	for hound in _hounds:
		hound.reset()
	_mummy.reset()


## A station: a sign over it, and a place to come back to.
func _station_here(at: Vector3, text: String, height: float) -> void:
	_stations.append(at)
	_sign(at + Vector3.UP * height, text)


func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 1.0, 1.0, 0.85)
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.5)
	label.position = at
	add_child(label)


func _plate(at: Vector3, span: Vector3, latches: bool, player_only := false) -> Plate:
	var plate := Plate.new()
	plate.span = span
	plate.latches = latches
	plate.position = at
	add_child(plate)
	if player_only:
		# The switches for the hounds and the mummy answer to the player alone.
		plate.collision_mask = 2
	return plate


func _block(at: Vector3) -> void:
	var block := RigidBody3D.new()
	block.mass = 20.0
	block.lock_rotation = true
	var surface := PhysicsMaterial.new()
	surface.friction = 0.6
	block.physics_material_override = surface
	_shape(block, at, Vector3(0.9, 0.9, 0.9), MARK)


## Something to pick up and throw: any RigidBody3D in the group "throwable".
func _rock(at: Vector3) -> void:
	var rock := RigidBody3D.new()
	rock.add_to_group(&"throwable")
	rock.mass = 2.0
	# Falls briskly, to match how the player jumps.
	rock.gravity_scale = 2.0
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	var collider := CollisionShape3D.new()
	collider.shape = shape
	rock.add_child(collider)
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 8
	mesh.rings = 4
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(MARK.lightened(0.15))
	rock.add_child(visual)
	rock.position = at
	add_child(rock)
	_rocks.append(rock)
	_rock_starts.append(at)


## A fixed solid box.
func _solid(at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	return _shape(StaticBody3D.new(), at, size, color) as StaticBody3D


## Scenery with no collision.
func _prop(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(color)
	visual.position = at
	add_child(visual)


## A wall nothing can see.
func _barrier(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	add_child(body)


func _shape(body: PhysicsBody3D, at: Vector3, size: Vector3, color: Color) -> PhysicsBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(color)
	body.add_child(visual)
	body.position = at
	add_child(body)
	return body
