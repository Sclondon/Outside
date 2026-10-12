class_name Akhet
extends StaticBody3D
## The horizon, as the sign for it draws it (akhet: the sun between two hills):
## two low hills of sandstone with a cradle of gold between them. It is where
## `Khepri` is to bring the sun. When the sun is rolled into the cradle it is
## taken: it rises between the hills on a short column of light and stays
## there, and from then on the Akhet is on (`changed`), for good. So it works
## a door, a bridge, or anything else a pressure plate works. Until then it is
## off.
##
## Its foot is at this node, which is the middle of the cradle; the hills
## stand to either side of it along its X, and are solid. It takes three
## squares in a row (a hill, the cradle, a hill), and the sun comes into it
## along its Z, from either side. Stand it on the squares the sun keeps to.
## `Akhet.new()` is a whole one.

signal changed(on: bool)

## How far from the cradle the middle of each hill is, how wide and deep a hill is, and how high.
const HILL_OUT := 0.94
const HILL := Vector3(0.84, 0.62, 1.0)
## How near the middle of the cradle the sun has to come to be taken, metres.
const TAKES := 0.35

## How high the sun rises: how far its foot is lifted off the floor.
@export var rise := 0.55
## Whether the sun has risen in it.
@export var on := false

var _holds: Khepri
var _column: MeshInstance3D
var _starts_on := false

static var _column_shader: Shader

const COLUMN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.8, 0.36);
uniform float strength = 0.7;

void fragment() {
	// Brightest where it is looked through the middle of, and streaked along its length.
	float through = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float streaks = 0.75 + 0.25 * step(0.5, fract(UV.x * 9.0));
	ALBEDO = colour * through * streaks * strength * mix(1.0, 0.45, UV.y);
}
"""


func _ready() -> void:
	add_to_group(&"interest")
	add_to_group(&"akhets")
	set_meta(&"surface", "stone")
	_starts_on = on
	var stone := Sandstone.surface(Sandstone.COLOUR, 0.21, 0.42, 0.6, 0.3)
	var dark := Sandstone.surface(Sandstone.COLOUR.darkened(0.22), 0.2, 0.6, 0.6, 0.2)
	# The ground it stands on: a thin slab (not solid: the sun rolls onto it), and a strip of gold along each edge.
	PuzzleKit.box(self, Vector3(0.0, 0.012, 0.0), Vector3(HILL_OUT * 2.0 + HILL.x + 0.16, 0.024, HILL.z + 0.16), dark)
	for z: float in [-1.0, 1.0]:
		PuzzleKit.box(self, Vector3(0.0, 0.016, z * (HILL.z * 0.5 + 0.03)), Vector3(HILL_OUT * 2.0 + HILL.x + 0.06, 0.03, 0.05), Toon.gold())
	# The two hills.
	for side: float in [-1.0, 1.0]:
		var hill := MeshInstance3D.new()
		var half := SphereMesh.new()
		half.is_hemisphere = true
		half.radius = 0.5
		half.height = 0.5
		half.radial_segments = 14
		half.rings = 5
		hill.mesh = half
		hill.scale = Vector3(HILL.x, HILL.y * 2.0, HILL.z)
		hill.position = Vector3(side * HILL_OUT, 0.0, 0.0)
		hill.material_override = stone
		add_child(hill)
		PuzzleKit.shape(self, Vector3(side * HILL_OUT, HILL.y * 0.4, 0.0), Vector3(HILL.x - 0.1, HILL.y * 0.8, HILL.z - 0.2))
		# (a band of gold round the foot of each)
		var band := PuzzleKit.ring(self, Vector3(side * HILL_OUT, 0.05, 0.0), 0.47, 0.07, Toon.gold())
		band.scale = Vector3(HILL.x, 1.0, HILL.z)
	# The cradle: a dish of gold let into the slab, and a ring round it.
	PuzzleKit.rod(self, Vector3(0.0, 0.02, 0.0), 0.36, 0.03, Toon.gold(), -1.0, 16)
	PuzzleKit.ring(self, Vector3(0.0, 0.035, 0.0), 0.4, 0.07, PuzzleKit.bronze())
	# The column of light the sun stands on, once it has it.
	_column = MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.2
	shaft.bottom_radius = 0.3
	shaft.height = 1.0
	shaft.radial_segments = 12
	shaft.rings = 1
	shaft.cap_top = false
	shaft.cap_bottom = false
	_column.mesh = shaft
	if _column_shader == null:
		_column_shader = Shader.new()
		_column_shader.code = COLUMN_SHADER
	var light := ShaderMaterial.new()
	light.shader = _column_shader
	_column.material_override = light
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.visible = false
	add_child(_column)


## Whether it will take a sun that has come to where `sun` is: it has none yet, and that is in its cradle.
func takes(sun: Khepri) -> bool:
	if on or _holds != null:
		return false
	var off := sun.global_position - global_position
	return absf(off.y) < 0.5 and Vector2(off.x, off.z).length() < TAKES


## Given the sun: said by `Khepri`, which then lifts it to `risen()` and says `set_on`.
func receive(sun: Khepri) -> void:
	_holds = sun


## Where the foot of the sun comes to when it has risen.
func risen() -> Vector3:
	return global_position + Vector3.UP * rise


## Where the beetle sits: the top of the hill on its +X side.
func perch() -> Vector3:
	return global_transform * Vector3(HILL_OUT, HILL.y - 0.02, 0.0)


## The sun it holds, if it has one.
func sun() -> Khepri:
	return _holds


## On or off, whatever is in it: on is what `Khepri` says when the sun has risen.
func set_on(to: bool) -> void:
	if to == on:
		return
	on = to
	changed.emit(on)


## As it was when it was made: off, and its sun back where it started.
func reset() -> void:
	var had := _holds
	_holds = null
	_column.visible = false
	set_on(_starts_on)
	if had and is_instance_valid(had) and had.akhet() == self:
		had.reset()


func _process(_delta: float) -> void:
	# The column stands from the cradle to the middle of the sun, as high as the sun has got.
	if _holds == null or not is_instance_valid(_holds):
		return
	var tall := _holds.global_position.y + Khepri.R - global_position.y
	_column.visible = tall > Khepri.R + 0.04
	_column.scale.y = tall
	_column.position.y = tall * 0.5
