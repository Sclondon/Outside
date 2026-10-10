class_name Sluice
extends StaticBody3D
## A sluice: a gate of boards in a frame of stone, with a wheel over it. Stand
## it by a tank of water (a `Pool`): it finds the nearest one itself, and while
## it is `open` it lets that water down by `drop`, and lets it rise again when
## it is shut, smoothly, at `speed`. The water really is lower: it is the
## `Pool` that moves, so he swims where it is still over his chest, wades
## where it is not, and walks the floor where it has gone. A level works it as
## it works a door, from whatever is linked to it. Its foot is at this node
## and the gate faces along its Z. `Sluice.new()` is a whole one.

## How far the water is let down, metres.
@export var drop := 2.0
## How fast the water goes down and comes up, metres a second.
@export var speed := 0.6
## How far off the water it works may be.
@export var finds_within := 30.0
## Whether it is letting the water out.
@export var open := false

## The water it works (found when it is first needed, and again if that is taken away).
var pool: Pool
## How far down the water is now, metres.
var lowered := 0.0

var _full := 0.0
var _gate: Node3D
var _wheel: Node3D


func _ready() -> void:
	add_to_group(&"interest")
	add_to_group(&"sluices")
	set_meta(&"surface", "stone")
	for x: float in [-0.55, 0.55]:
		PuzzleKit.shape(self, Vector3(x, 0.8, 0.0), Vector3(0.3, 1.6, 0.34))
		PuzzleKit.box(self, Vector3(x, 0.8, 0.0), Vector3(0.3, 1.6, 0.34), PuzzleKit.stone())
	PuzzleKit.shape(self, Vector3(0.0, 1.72, 0.0), Vector3(1.5, 0.24, 0.4))
	PuzzleKit.box(self, Vector3(0.0, 1.72, 0.0), Vector3(1.5, 0.24, 0.4), PuzzleKit.stone(PuzzleKit.DARK))
	PuzzleKit.box(self, Vector3(0.0, 0.05, 0.0), Vector3(1.5, 0.1, 0.5), PuzzleKit.stone(PuzzleKit.DARK))
	PuzzleKit.shape(self, Vector3(0.0, 0.45, 0.0), Vector3(0.8, 0.9, 0.1))
	# The gate: three boards and two straps of iron, hung from a screw that the wheel turns.
	_gate = Node3D.new()
	_gate.position.y = 0.1
	add_child(_gate)
	for i in 3:
		PuzzleKit.box(_gate, Vector3((i - 1) * 0.265, 0.42, 0.0), Vector3(0.255, 0.84, 0.07), PuzzleKit.wood(PuzzleKit.WOOD.darkened(0.08 * (i % 2))))
	for y: float in [0.2, 0.64]:
		PuzzleKit.box(_gate, Vector3(0.0, y, 0.0), Vector3(0.8, 0.06, 0.09), PuzzleKit.iron())
	PuzzleKit.rod(_gate, Vector3(0.0, 1.3, 0.0), 0.025, 1.0, PuzzleKit.iron(), -1.0, 6)
	_wheel = Node3D.new()
	_wheel.position.y = 1.9
	add_child(_wheel)
	PuzzleKit.ring(_wheel, Vector3.ZERO, 0.24, 0.045, PuzzleKit.bronze())
	for i in 2:
		var spoke := PuzzleKit.box(_wheel, Vector3.ZERO, Vector3(0.46, 0.03, 0.04), PuzzleKit.bronze())
		spoke.rotation.y = i * PI * 0.5
	_show()


## The water as it was, and the gate shut (unless something holds it open).
func reset() -> void:
	lowered = 0.0
	_place()
	_show()


func _exit_tree() -> void:
	# (taken out of the level: the water is as it would be without it)
	if is_instance_valid(pool):
		pool.position.y = _full
		if pool.water:
			pool.water.visible = true
	pool = null


func _physics_process(delta: float) -> void:
	if not is_instance_valid(pool) or not pool.is_inside_tree():
		pool = _nearest_pool()
		if pool == null:
			return
		_full = pool.position.y
		_place()
	var to := drop if open else 0.0
	if lowered == to:
		return
	lowered = move_toward(lowered, to, speed * delta)
	_place()
	_show()


func _place() -> void:
	if not is_instance_valid(pool):
		return
	pool.position.y = _full - lowered
	# (let down to its floor, there is none left to see)
	if pool.water:
		pool.water.visible = pool.size.y - lowered > 0.04


func _show() -> void:
	var up := clampf(lowered / maxf(drop, 0.01), 0.0, 1.0)
	_gate.position.y = 0.1 + up * 0.7
	_wheel.rotation.y = up * TAU * 1.5


# The water nearest it: measured to the edge of each, so that a sluice in the wall of a big tank is still nearest
# that (and in height too, less two metres, so that a tank upstairs is not taken for the one beside it).
func _nearest_pool() -> Pool:
	var best: Pool
	var nearest := finds_within
	for found: Node in get_tree().get_nodes_in_group(&"water"):
		var water := found as Pool
		if water == null or water.is_queued_for_deletion():
			continue
		var from := global_position - water.global_position
		var out := Vector3(maxf(absf(from.x) - water.size.x * 0.5, 0.0), maxf(absf(from.y + water.size.y * 0.5) - water.size.y * 0.5 - 2.0, 0.0), maxf(absf(from.z) - water.size.z * 0.5, 0.0)).length()
		if out < nearest:
			nearest = out
			best = water
	return best
