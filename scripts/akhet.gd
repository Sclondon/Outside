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
##
## What is seen of it is a Blender model (`models/khepri.glb`, built by
## `tools/build_khepri.py`, which keeps `tools/khepri.blend` to change by
## hand): the slab, the hills and the cradle, in the game's stone and gold
## and the model's colours, drawn as one mesh of four materials. What is
## solid of it (a box in each hill), where the beetle sits and the column
## of light are made here, from `HILL_OUT` and `HILL`: a hill reshaped in
## the model is not thereby solid anywhere else.

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

## The model it is read from: everything under `akhet` in it (`ground`, `hill_east`, `hill_west`, `cradle`).
const MODEL := "res://models/khepri.glb"

static var _column_shader: Shader
static var _mesh: ArrayMesh
static var _paints: Array[String] = []
static var _colours: Array[Color] = []

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
	# What is seen of it is the model's: one mesh, a surface for each of its materials.
	_read()
	var look := MeshInstance3D.new()
	look.mesh = _mesh
	for surface in _paints.size():
		look.set_surface_override_material(surface, _paint(_paints[surface], _colours[surface]))
	add_child(look)
	# The two hills are solid. (The slab is not: the sun rolls onto it.)
	for side: float in [-1.0, 1.0]:
		PuzzleKit.shape(self, Vector3(side * HILL_OUT, HILL.y * 0.4, 0.0), Vector3(HILL.x - 0.1, HILL.y * 0.8, HILL.z - 0.2))
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


# The game's own stone and gold, in the model's colours.
static func _paint(named: String, colour: Color) -> Material:
	match named:
		"hill_stone":
			return Sandstone.surface(colour, 0.26, 0.4, 0.6, 0.3)
		"ground_stone":
			return Sandstone.surface(colour, 0.2, 0.6, 0.6, 0.2)
	return Toon.gold(colour)


# Everything under `akhet` in the model, as one mesh: a surface for each material, in `_paints`.
static func _read() -> void:
	if _mesh:
		return
	_mesh = ArrayMesh.new()
	var model := (load(MODEL) as PackedScene).instantiate()
	var whole := model.find_child("akhet", true, false)
	if whole == null:
		push_error("Khepri's model has nothing in it called akhet")
		model.free()
		return
	var tools: Array[SurfaceTool] = []
	for part: Node in whole.get_children():
		var shown := part as MeshInstance3D
		if shown == null or shown.mesh == null:
			continue
		var place := shown.transform
		var lie := place.basis.inverse().transposed()
		for surface in shown.mesh.get_surface_count():
			var paint := shown.mesh.surface_get_material(surface) as BaseMaterial3D
			var named := String(paint.resource_name) if paint else ""
			var which := _paints.find(named)
			if which < 0:
				which = _paints.size()
				_paints.append(named)
				_colours.append(paint.albedo_color if paint else Sandstone.GOLD)
				tools.append(SurfaceTool.new())
				tools[which].begin(Mesh.PRIMITIVE_TRIANGLES)
			var arrays := shown.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := order.size() if not order.is_empty() else points.size()
			for i in count:
				var k := order[i] if not order.is_empty() else i
				tools[which].set_normal((lie * normals[k]).normalized())
				tools[which].add_vertex(place * points[k])
	model.free()
	for tool in tools:
		tool.index()
		tool.commit(_mesh)
