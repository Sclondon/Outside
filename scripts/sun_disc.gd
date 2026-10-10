class_name SunDisc
extends StaticBody3D
## What a `SunBeam` is brought to: a sun of gold between two horns of bronze,
## on a post of stone. While the light falls on it, straight or by way of any
## number of mirrors, it glows and is on (`changed`): so it works a door, or
## anything else a pressure plate works. With `latches`, once lit it stays on.
## Its foot is at this node, and the middle of the sun is `height` above it;
## the light may come at it from any side. `SunDisc.new()` is a whole one.

signal changed(on: bool)

## How big across the sun is.
const SUN := 0.46

## How high the middle of the sun is.
@export var height := 0.7
## Once the light has found it, it stays on.
@export var latches := false
## Whether the light is on it (or has been, if it latches).
@export var on := false

var _struck := 0
var _sun: MeshInstance3D
var _lamp: OmniLight3D
var _dull: Material
var _lit: StandardMaterial3D
var _starts_on := false


## The sun disc a ray has hit, if what it hit is the sun of one.
static func of(collider: Object) -> SunDisc:
	var node := collider as Node
	if node and node.is_in_group(&"sun_disc_suns"):
		return node.get_meta(&"disc") as SunDisc
	return null


func _ready() -> void:
	add_to_group(&"interest")
	add_to_group(&"sun_discs")
	set_meta(&"surface", "stone")
	_starts_on = on
	var tall := maxf(height - SUN * 0.5 - 0.12, 0.2)
	PuzzleKit.shape(self, Vector3(0.0, tall * 0.5, 0.0), Vector3(0.34, tall, 0.34))
	PuzzleKit.box(self, Vector3(0.0, tall * 0.5, 0.0), Vector3(0.3, tall, 0.3), PuzzleKit.stone())
	PuzzleKit.box(self, Vector3(0.0, 0.04, 0.0), Vector3(0.46, 0.08, 0.46), PuzzleKit.stone(PuzzleKit.DARK))
	PuzzleKit.box(self, Vector3(0.0, tall - 0.03, 0.0), Vector3(0.4, 0.06, 0.4), PuzzleKit.stone(PuzzleKit.DARK))
	# The horns: a cup of bronze under the sun, and a horn up either side of it.
	var middle := Vector3(0.0, height, 0.0)
	PuzzleKit.rod(self, Vector3(0.0, tall + 0.05, 0.0), 0.1, 0.1, PuzzleKit.bronze(), 0.05, 8)
	for side: float in [-1.0, 1.0]:
		for part: Array in [[0.24, -0.2, 0.9, 0.05], [0.32, 0.0, 0.25, 0.042], [0.3, 0.2, -0.3, 0.032]]:
			var horn := PuzzleKit.rod(self, middle + Vector3(side * float(part[0]), part[1], 0.0), part[3], 0.24, PuzzleKit.bronze(), float(part[3]) * 0.75, 6)
			horn.rotation.z = -side * float(part[2])
	_dull = Toon.gold()
	_lit = StandardMaterial3D.new()
	_lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lit.albedo_color = Color(1.0, 0.93, 0.62)
	_lit.disable_fog = true
	_sun = PuzzleKit.ball(self, middle, SUN * 0.5, _dull)
	_sun.scale.z = 0.45
	# The sun, for the light to find: a ball, so that it is found from any side.
	var target := StaticBody3D.new()
	target.add_to_group(&"sun_disc_suns")
	target.set_meta(&"disc", self)
	target.set_meta(&"surface", "metal")
	var round := SphereShape3D.new()
	round.radius = SUN * 0.5
	var collider := CollisionShape3D.new()
	collider.shape = round
	target.add_child(collider)
	target.position = middle
	add_child(target)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.85, 0.5)
	_lamp.light_energy = 1.6
	_lamp.omni_range = 5.0
	_lamp.position = middle + Vector3(0.0, 0.1, 0.5)
	_lamp.visible = false
	add_child(_lamp)
	_show()


## The light is on it: said by the beam, every step that it is.
func strike(_by: Node3D = null) -> void:
	_struck = 3


## Whether the light is on it now (whatever `on` says of one that latches).
func is_struck() -> bool:
	return _struck > 0


## As it was when it was made.
func reset() -> void:
	_struck = 0
	_switch(_starts_on)


func _switch(to: bool) -> void:
	if to == on:
		return
	on = to
	_show()
	changed.emit(on)


func _show() -> void:
	_sun.material_override = _lit if on else _dull
	_lamp.visible = on


func _physics_process(_delta: float) -> void:
	_struck = maxi(_struck - 1, 0)
	_switch(_struck > 0 or (latches and on))
