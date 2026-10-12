class_name KhepriCourt
extends Node3D
## A small walled court to try `Khepri` in: the test yard's station for it,
## and what its test and its pictures are run in. It is a floor of squares,
## nine by nine, a metre each, and the sun starts in one corner of it, at
## square (0, 0), going along the wall (squares are counted as the sun counts
## them: `square(x, y)`, x to its right, y the way it sets off).
##
## Left to itself the sun goes round and round by the walls, through a dark
## roofed alcove in the far corner, past a sun disc that it lights, and over a
## plate that holds a side gate up while the sun is on it. The horizon stands
## in the middle, at (4, 2), and the sun does not come to it until he has
## pushed two blocks: the one at (2, 5) along to the wall at (0, 5), which
## turns the sun across the court; and the one at (5, 6) down against the
## pillar to (5, 4), which turns it again, down into the cradle. Then the sun
## rises and the door in the near wall opens. The lever by the way in lets the
## sun go and stops it; the plate beside the lever puts everything back.
##
## The way in has a sill, and so have the gates: low enough to jump, too high
## for the sun, which therefore cannot leave. `KhepriCourt.new()` is a whole one.

const PROP := Color(0.6, 0.54, 0.46)
const DARK := Color(0.4, 0.35, 0.3)
const MARK := Color(0.55, 0.4, 0.26)
## How many squares it is each way, and how high its floor stands above the node.
const SQUARES := 9
const FLOOR := 0.04
## Where the two blocks start, and where they are to be pushed to.
const BLOCKS: Array[Vector2i] = [Vector2i(2, 5), Vector2i(5, 6)]
const BLOCK_GOALS: Array[Vector2i] = [Vector2i(0, 5), Vector2i(5, 4)]
## Where the horizon is.
const AKHET := Vector2i(4, 2)

## Whether it has a sign over the way in saying what to do.
@export var signed := true

var khepri: Khepri
var akhet: Akhet
var lever: Lever
## The door the horizon opens, and the gate the plate holds up.
var door: TombParts.Door
var side_gate: TombParts.Door
var plate: TombParts.Plate
var disc: SunDisc
var blocks: Array[RigidBody3D] = []

var _block_starts: Array[Transform3D] = []


func _ready() -> void:
	var half := SQUARES * 0.5
	var out := half + 0.2
	# The floor: one slab, and every other square of it a shade darker.
	_solid(Vector3(0.0, FLOOR - 0.05, 0.0), Vector3(out * 2.0 + 0.4, 0.1, out * 2.0 + 0.4), PROP.lightened(0.08))
	var squares := SurfaceTool.new()
	squares.begin(Mesh.PRIMITIVE_TRIANGLES)
	squares.set_normal(Vector3.UP)
	for x in SQUARES:
		for y in SQUARES:
			if (x + y) % 2 == 0:
				continue
			var middle := _local(x, y) + Vector3.UP * 0.003
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				squares.add_vertex(middle + Vector3(corner.x, 0.0, corner.y) * 0.5)
	var chequer := MeshInstance3D.new()
	chequer.mesh = squares.commit()
	chequer.material_override = Toon.surface(PROP.darkened(0.12))
	chequer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(chequer)
	# (and a mark where each block is to go)
	for goal in BLOCK_GOALS:
		var mark := PuzzleKit.box(self, _local(goal.x, goal.y) + Vector3.UP * 0.005, Vector3(0.8, 0.004, 0.8), Toon.surface(MARK.darkened(0.15)))
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# The walls. The near one (y = -0.5) has the way in, at x = 2, and the door the horizon opens, at x = 6.
	var low := 1.0
	var high := 1.9
	var end := out + 0.2
	_wall(Vector2(-end, -out), Vector2(_x(6) - 1.0, -out), low)
	_wall(Vector2(_x(6) + 1.0, -out), Vector2(_x(2) - 0.6, -out), low)
	_wall(Vector2(_x(2) + 0.6, -out), Vector2(end, -out), low)
	_wall(Vector2(_x(2) - 0.6, -out), Vector2(_x(2) + 0.6, -out), 0.3)
	door = _gate(Vector3(_x(6), FLOOR, -out), 0.0)
	# The far wall (y = 8.5), higher where the alcove is.
	_wall(Vector2(-1.5, out), Vector2(end, out), low)
	_wall(Vector2(-end, out), Vector2(-1.5, out), high)
	# The wall on the sun's left as it sets off (x = -0.5).
	_wall(Vector2(out, -end), Vector2(out, end), low)
	# The wall on its right (x = 8.5): the side gate at y = 4, and higher where the alcove is.
	_wall(Vector2(-out, -end), Vector2(-out, -1.0), low)
	_wall(Vector2(-out, 1.0), Vector2(-out, 2.35), low)
	_wall(Vector2(-out, 2.35), Vector2(-out, end), high)
	side_gate = _gate(Vector3(-out, FLOOR, 0.0), PI * 0.5)
	# The alcove: the far right corner roofed over, and walled off but for its mouth and the sun's way out.
	_wall(Vector2(-3.5, 2.5), Vector2(-1.5, 2.5), high, 0.3)
	_solid(Vector3(-3.2, FLOOR + high + 0.08, 3.6), Vector3(3.6, 0.16, 2.6), DARK)

	# The pillar the second block is pushed against.
	_solid(_local(5, 3) + Vector3.UP * 0.6, Vector3(0.9, 1.2, 1.0), DARK.lightened(0.08))
	# The horizon, and the door it opens.
	akhet = Akhet.new()
	akhet.position = _local(AKHET.x, AKHET.y)
	add_child(akhet)
	akhet.changed.connect(func(on: bool) -> void: door.is_open = on)
	# A sun disc the sun passes, and a plate it rolls over.
	disc = SunDisc.new()
	disc.position = _local(7, 5)
	add_child(disc)
	plate = TombParts.Plate.new()
	plate.span = Vector3(0.96, 0.5, 0.96)
	plate.position = _local(8, 2) + Vector3.UP * 0.036
	add_child(plate)
	plate.changed.connect(func(pressed: bool) -> void: side_gate.is_open = pressed)
	# The blocks.
	for start in BLOCKS:
		var block := RigidBody3D.new()
		block.add_to_group(&"interest")
		block.mass = 20.0
		block.lock_rotation = true
		var surface := PhysicsMaterial.new()
		surface.friction = 0.6
		block.physics_material_override = surface
		_box(block, Vector3.ZERO, Vector3(0.9, 0.9, 0.9), MARK)
		block.position = _local(start.x, start.y) + Vector3.UP * 0.45
		add_child(block)
		blocks.append(block)
		_block_starts.append(block.transform)

	# The sun, in its corner.
	khepri = Khepri.new()
	khepri.position = _local(0, 0)
	add_child(khepri)
	# Outside, by the way in: the lever that lets it go, and a plate that puts everything back.
	lever = Lever.new()
	lever.position = Vector3(_x(2) + 1.5, 0.0, -out - 1.0)
	add_child(lever)
	lever.changed.connect(func(on: bool) -> void: khepri.running = on)
	var again := TombParts.Plate.new()
	again.span = Vector3(1.2, 0.5, 1.2)
	again.position = Vector3(_x(2) - 1.8, 0.0, -out - 1.2)
	add_child(again)
	again.collision_mask = 2
	again.changed.connect(func(pressed: bool) -> void:
		if pressed:
			reset())
	if signed:
		_sign(Vector3(_x(2), 3.3, -out - 0.4), "KHEPRI AND THE SUN
the lever lets it go  ·  it turns right at whatever is in its way
push a block into its way, stand in its way, or act beside it to turn it
bring the sun to the horizon  ·  the plate puts it all back")


## The middle of a square, in the world: counted as the sun counts them, from where it starts.
func square(x: int, y: int) -> Vector3:
	return global_transform * _local(x, y)


## Everything back as it was: the blocks, the sun, the horizon, the lever.
func reset() -> void:
	for i in blocks.size():
		blocks[i].linear_velocity = Vector3.ZERO
		blocks[i].angular_velocity = Vector3.ZERO
		blocks[i].transform = _block_starts[i]
	lever.reset()
	khepri.reset()
	akhet.reset()
	disc.reset()


func _x(x: int) -> float:
	return (SQUARES - 1) * 0.5 - x


func _local(x: int, y: int) -> Vector3:
	return Vector3(_x(x), FLOOR, y - (SQUARES - 1) * 0.5)


# A wall from one place to another (x, z), standing on the ground.
func _wall(from: Vector2, to: Vector2, tall: float, thick := 0.4) -> void:
	var long := (to - from).abs()
	var middle := (from + to) * 0.5
	_solid(Vector3(middle.x, (FLOOR + tall) * 0.5, middle.y), Vector3(maxf(long.x, thick), FLOOR + tall, maxf(long.y, thick)), PROP)


# A gate in a wall: two posts and a lintel, a sill the sun cannot cross, and the slab that lifts.
func _gate(at: Vector3, yaw: float) -> TombParts.Door:
	var frame := Node3D.new()
	frame.position = at
	frame.rotation.y = yaw
	add_child(frame)
	for x: float in [-0.85, 0.85]:
		_box(_body(frame), Vector3(x, 1.1, 0.0), Vector3(0.3, 2.2, 0.5), PROP.darkened(0.05))
	_box(_body(frame), Vector3(0.0, 2.35, 0.0), Vector3(2.0, 0.3, 0.5), PROP.darkened(0.05))
	_box(_body(frame), Vector3(0.0, 0.15, 0.0), Vector3(1.4, 0.3, 0.4), PROP)
	var slab := TombParts.Door.new(Vector3(1.4, 1.9, 0.3), DARK.lightened(0.1))
	slab.position = Vector3(0.0, 0.3 + 0.95, 0.0)
	frame.add_child(slab)
	return slab


func _body(on: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	on.add_child(body)
	return body


func _solid(at: Vector3, size: Vector3, colour: Color) -> StaticBody3D:
	var body := _body(self)
	_box(body, Vector3.ZERO, size, colour)
	body.position = at
	return body


func _box(body: PhysicsBody3D, at: Vector3, size: Vector3, colour: Color) -> void:
	PuzzleKit.shape(body, at, size)
	PuzzleKit.box(body, at, size, Toon.surface(colour))


func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 1.0, 1.0, 0.85)
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.5)
	label.position = at
	add_child(label)
