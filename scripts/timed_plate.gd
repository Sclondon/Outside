class_name TimedPlate
extends TombParts.Plate
## A pressure plate that stays down for a while after he steps off it, and
## then comes up: on for `seconds` from when the weight leaves it, so that a
## door it opens has to be run for. A sand-glass on a post beside it is turned
## over as it is pressed and shows how long is left, and the slab itself rises
## back as the sand runs out. It is a `TombParts.Plate` (`changed`, `pressed`),
## and a level wires it up as it does any plate. `TimedPlate.new()` is a whole
## one; the glass stands at its +X edge.

## How long it stays on after the weight is off it.
@export var seconds := 6.0

## How long it has left, seconds.
var left := 0.0

var _glass: Node3D
var _upper: MeshInstance3D
var _lower: MeshInstance3D
var _thread: MeshInstance3D
var _turned := 0.0


func _init() -> void:
	span = Vector3(1.2, 0.5, 1.2)


func _ready() -> void:
	super()
	var post := Vector3(span.x * 0.5 + 0.28, 0.0, 0.0)
	var body := StaticBody3D.new()
	body.set_meta(&"surface", "stone")
	PuzzleKit.shape(body, post + Vector3(0.0, 0.3, 0.0), Vector3(0.26, 0.6, 0.26))
	add_child(body)
	PuzzleKit.box(self, post + Vector3(0.0, 0.3, 0.0), Vector3(0.24, 0.6, 0.24), PuzzleKit.stone())
	PuzzleKit.box(self, post + Vector3(0.0, 0.03, 0.0), Vector3(0.34, 0.06, 0.34), PuzzleKit.stone(PuzzleKit.DARK))
	# The glass: two bulbs point to point between two plates of bronze, on three rods.
	_glass = Node3D.new()
	_glass.position = post + Vector3(0.0, 0.84, 0.0)
	add_child(_glass)
	for end: float in [-1.0, 1.0]:
		PuzzleKit.rod(_glass, Vector3(0.0, end * 0.215, 0.0), 0.13, 0.03, PuzzleKit.bronze(), -1.0, 12)
	for i in 3:
		var out := Vector3(sin(i * TAU / 3.0), 0.0, cos(i * TAU / 3.0)) * 0.11
		PuzzleKit.rod(_glass, out, 0.01, 0.42, PuzzleKit.bronze(), -1.0, 5)
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.8, 0.92, 0.95, 0.16)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.2
	clear.cull_mode = BaseMaterial3D.CULL_BACK
	var sand := Toon.surface(Color(0.8, 0.52, 0.2))
	# (a bulb is a cone, its point at the waist; the sand in it is a cone inside that)
	var top := PuzzleKit.rod(_glass, Vector3(0.0, 0.1, 0.0), 0.012, 0.2, clear, 0.095, 12)
	var bottom := PuzzleKit.rod(_glass, Vector3(0.0, -0.1, 0.0), 0.095, 0.2, clear, 0.012, 12)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bottom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_upper = PuzzleKit.rod(_glass, Vector3.ZERO, 0.0, 0.17, sand, 0.08, 10)
	_lower = PuzzleKit.rod(_glass, Vector3.ZERO, 0.08, 0.17, sand, 0.0, 10)
	_thread = PuzzleKit.rod(_glass, Vector3(0.0, -0.1, 0.0), 0.006, 0.18, sand, -1.0, 4)
	_show_sand()


## As it was when it was made: up, and the sand run through.
func reset() -> void:
	left = 0.0


func _physics_process(delta: float) -> void:
	var weight := false
	for body in get_overlapping_bodies():
		if body is RigidBody3D or body is CharacterBody3D:
			weight = true
			break
	if weight:
		if left <= 0.0:
			# (the glass is turned over)
			_turned = 1.0
		left = seconds
	else:
		left = maxf(left - delta, 0.0)
	var now := left > 0.0
	if now != pressed:
		pressed = now
		changed.emit(pressed)
	# Down under a weight; and it rises back as the sand runs out.
	var down := 1.0 if weight else (0.25 + 0.75 * left / seconds if now else 0.0)
	_slab.position.y = move_toward(_slab.position.y, lerpf(-0.035, -0.075, down), delta * 0.3)
	_turned = maxf(_turned - delta / 0.35, 0.0)
	_show_sand()


func _show_sand() -> void:
	var full := clampf(left / maxf(seconds, 0.01), 0.0, 1.0)
	_glass.rotation.z = PI * smoothstep(0.0, 1.0, _turned)
	# What has yet to run is in the upper bulb, and the rest lies in the lower.
	var above := maxf(pow(full, 1.0 / 3.0), 0.001)
	var below := maxf(pow(1.0 - full, 1.0 / 3.0), 0.001)
	_upper.scale = Vector3.ONE * above
	_upper.position.y = 0.02 + 0.085 * above
	_lower.scale = Vector3(below, below * 0.6, below)
	_lower.position.y = -0.2 + 0.085 * below * 0.6
	_thread.visible = full > 0.0 and _turned <= 0.0
