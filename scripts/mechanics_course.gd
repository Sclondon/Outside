extends Node3D
## A plain, well-lit course with one station for each thing the player can do,
## in order: push a block, duck, slide, climb a ledge, climb a rope, throw.
## Run `mechanics.tscn` to use it. Each station is a checkpoint.

const Plate := TombParts.Plate
const Door := TombParts.Door

const DEPTH := 7.0
const GROUND := Color(0.2, 0.21, 0.23)
const PROP := Color(0.3, 0.31, 0.34)
const MARK := Color(0.5, 0.4, 0.24)
const SKY := Color(0.42, 0.46, 0.5)
## Passing each of these makes it the place to come back to.
const CHECKPOINTS: Array[float] = [12.5, 19.5, 26.0, 30.5, 40.0]
const HIGH := 4.6

var _player: Player
var _checkpoint := 0
var _rocks: Array[RigidBody3D] = []
var _rock_starts: Array[Vector3] = []
var _bridge: AnimatableBody3D
var _bridge_out := false


func _ready() -> void:
	_build_light()
	_box(StaticBody3D.new(), Vector3(25.0, -2.0, -19.0), Vector3(64.0, 4.0, 62.0), GROUND)
	_wall(Vector3(25.0, 8.0, DEPTH * 0.5 + 0.5), Vector3(64.0, 18.0, 1.0))
	_wall(Vector3(25.0, 8.0, -DEPTH * 0.5 - 0.5), Vector3(64.0, 18.0, 1.0))
	_wall(Vector3(-6.5, 8.0, 0.0), Vector3(1.0, 18.0, DEPTH + 2.0))
	_wall(Vector3(56.5, 8.0, 0.0), Vector3(1.0, 18.0, DEPTH + 2.0))

	# 1. Push: the block onto the plate holds the door up.
	_sign(6.0, 3.0, "PUSH\nwalk into the block")
	_block(Vector3(4.0, 0.45, 0.0))
	var door := Door.new(Vector3(0.5, 2.4, DEPTH), PROP.darkened(0.2))
	door.position = Vector3(11.3, 1.2, 0.0)
	add_child(door)
	_plate(8.0, 0.0, false).changed.connect(func(pressed: bool) -> void: door.is_open = pressed)
	_box(StaticBody3D.new(), Vector3(9.22, 0.125, 0.0), Vector3(0.24, 0.25, DEPTH), PROP.darkened(0.15))

	# 2. Duck: too low to walk under.
	_sign(16.5, 3.4, "DUCK\nhold duck (C)")
	_span(15.0, 18.0, 0.95, 2.7)

	# 3. Slide: lower still. Run at it and duck.
	_sign(23.8, 3.4, "SLIDE\nrun, then duck")
	_span(23.0, 24.6, 0.7, 2.7)

	# 4. Ledge: jump at it and he catches the edge. Push on to climb, pull back to drop.
	_sign(28.0, 3.4, "LEDGE\njump at the wall")
	_span(29.0, 34.0, 0.0, 2.1)

	# 5. Rope: jump into it, climb with up and down, jump to leap off.
	_sign(36.3, 8.4, "ROPE\njump in, up/down, jump off")
	var rope := Rope.new()
	rope.length = 6.2
	rope.position = Vector3(36.3, 7.5, 0.0)
	add_child(rope)
	_prop(Vector3(36.3, 7.6, -1.8), Vector3(0.25, 0.25, 4.2), PROP)
	_span(39.0, 44.0, 0.0, HIGH)

	# 6. Throw: pick a rock up, and land it on the plate across the gap.
	_sign(41.5, HIGH + 3.0, "THROW\nact (E) picks up, act again throws")
	for z: float in [-1.0, 0.0, 1.0]:
		_rock(Vector3(41.0 + z * 0.3, HIGH + 0.15, z))
	_span(48.0, 56.0, 0.0, HIGH)
	_plate(49.9, HIGH, true, 3.2).changed.connect(func(pressed: bool) -> void: _bridge_out = _bridge_out or pressed)
	_bridge = AnimatableBody3D.new()
	_box(_bridge, Vector3(50.2, HIGH - 0.15, 0.0), Vector3(4.2, 0.3, DEPTH), MARK.darkened(0.2))
	_sign(52.5, HIGH + 2.6, "END")

	_settle_in.call_deferred()


func _build_light() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.64, 0.7)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = SKY
	environment.fog_density = 0.012
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)
	var sky := MeshInstance3D.new()
	var sheet := QuadMesh.new()
	sheet.size = Vector2(1200.0, 500.0)
	sky.mesh = sheet
	sky.material_override = _material(SKY)
	sky.position = Vector3(25.0, 120.0, -260.0)
	add_child(sky)


func _settle_in() -> void:
	_player = get_parent().get_node_or_null("Player") as Player
	if _player:
		_player.respawned.connect(_restore_rocks)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var at := _player.global_position
	if _checkpoint < CHECKPOINTS.size() and at.x > CHECKPOINTS[_checkpoint] and _player.is_on_floor():
		_player.set_spawn(Vector3(CHECKPOINTS[_checkpoint] + 0.3, at.y + 0.05, 0.0))
		_checkpoint += 1
	# The bridge runs out from under the far side once the plate has been hit.
	_bridge.position.x = move_toward(_bridge.position.x, 46.0 if _bridge_out else 50.2, 2.0 * delta)
	# Never leave him with nothing to throw.
	if _rocks.all(func(rock: RigidBody3D) -> bool: return rock.global_position.y < HIGH - 1.0 and rock != _player.carried):
		_restore_rocks()


func _restore_rocks() -> void:
	for i in _rocks.size():
		if _rocks[i] == _player.carried:
			continue
		_rocks[i].linear_velocity = Vector3.ZERO
		_rocks[i].angular_velocity = Vector3.ZERO
		_rocks[i].global_position = _rock_starts[i]


func _sign(x: float, y: float, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 1.0, 1.0, 0.8)
	label.outline_size = 0
	label.position = Vector3(x, y, -DEPTH * 0.5 + 0.2)
	add_child(label)


func _plate(x: float, y: float, latches: bool, width := 1.5) -> Plate:
	var plate := Plate.new()
	plate.span = Vector3(width, 0.5, DEPTH)
	plate.latches = latches
	plate.position = Vector3(x, y, 0.0)
	add_child(plate)
	return plate


func _block(at: Vector3) -> void:
	var block := RigidBody3D.new()
	block.mass = 20.0
	block.lock_rotation = true
	var surface := PhysicsMaterial.new()
	surface.friction = 0.6
	block.physics_material_override = surface
	_box(block, at, Vector3(0.9, 0.9, 0.9), MARK)


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
	visual.material_override = _material(MARK.lightened(0.15))
	rock.add_child(visual)
	rock.position = at
	add_child(rock)
	_rocks.append(rock)
	_rock_starts.append(at)


## A solid slab across the walkable depth, by its extents in X and Y.
func _span(from_x: float, to_x: float, from_y: float, to_y: float) -> void:
	_box(StaticBody3D.new(), Vector3((from_x + to_x) * 0.5, (from_y + to_y) * 0.5, 0.0), Vector3(to_x - from_x, to_y - from_y, DEPTH), PROP)


func _prop(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(color)
	visual.position = at
	add_child(visual)


func _wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	add_child(body)


func _box(body: PhysicsBody3D, at: Vector3, size: Vector3, color: Color) -> PhysicsBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(color)
	body.add_child(visual)
	body.position = at
	add_child(body)
	return body


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic_specular = 0.0
	return material
