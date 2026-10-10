class_name SunBeam
extends Node3D
## A beam of sunlight: caught by a lens of rock crystal in a ring of bronze on
## a stone stand, and thrown out level along this node's +Z from `height`
## above its foot (tipped up by `pitch`). Without the stand it is only the
## light, to come in through a hole in a wall.
##
## The beam is really followed, every step of the game: a ray is cast along
## it, and where that meets the face of a `Mirror` it goes on as a mirror would
## send it, for as many mirrors as there are up to `BOUNCES`. Whatever else it
## meets stops it: a wall, a block pushed into it, the boy himself. If what it
## meets is a `SunDisc`, the disc is told (`SunDisc.strike`), and is on for as
## long as the light is on it. `path` is where the light goes, and `ends_on`
## what it ends on.
##
## What is drawn is three thin strips along each stretch of it, crossed, pale
## and soft at the edges, and a spot where it ends. `SunBeam.new()` is a whole one.

## How many mirrors one beam will go by.
const BOUNCES := 8
const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float strength = 0.5;
uniform float clock = 0.0;

void fragment() {
	// Bright down the middle, nothing at the edge; and it shimmers a little along its length.
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float soft = across * across * (3.0 - 2.0 * across);
	float shimmer = 0.9 + 0.1 * sin(UV.y * 9.0 - clock * 5.0);
	ALBEDO = colour.rgb;
	ALPHA = clamp((soft * 0.6 + pow(across, 8.0) * 0.6) * strength * shimmer, 0.0, 1.0);
}
"""

## Whether the light is coming.
@export var shining := true
## How high above this node the light starts.
@export var height := 0.7
## How far it is tipped up, degrees.
@export var pitch := 0.0
## How far it goes, mirrors and all.
@export var reach := 40.0
## Whether it has a stand, and a lens on it.
@export var stand := true
## How wide the beam is drawn.
@export var width := 0.16
@export var colour := Color(1.0, 0.9, 0.6)

## Where the light goes, in the world: where it starts, each mirror, and where it ends. Empty while it is not shining.
var path := PackedVector3Array()
## What it ends on (nothing, if it runs out in the air).
var ends_on: Object
## How many mirrors it goes by.
var bounces := 0

var _beam: MeshInstance3D
var _spot: MeshInstance3D
var _lens: MeshInstance3D
var _material: ShaderMaterial
var _drawn := PackedVector3Array()
var _own: Array[RID] = []
var _clock := 0.0

static var _shader: Shader


func _ready() -> void:
	add_to_group(&"sun_beams")
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter(&"colour", colour)
	_beam = MeshInstance3D.new()
	_beam.mesh = ImmediateMesh.new()
	_beam.material_override = _material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	add_child(_beam)
	_beam.global_transform = Transform3D.IDENTITY
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.97, 0.82)
	glow.disable_fog = true
	_spot = PuzzleKit.ball(self, Vector3.ZERO, width * 0.55, glow)
	_spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spot.top_level = true
	_spot.visible = false
	if stand:
		_build_stand(glow)


func _build_stand(glow: Material) -> void:
	var body := StaticBody3D.new()
	body.set_meta(&"surface", "stone")
	var tall := maxf(height - 0.34, 0.2)
	PuzzleKit.shape(body, Vector3(0.0, tall * 0.5, 0.0), Vector3(0.46, tall, 0.46))
	add_child(body)
	_own.append(body.get_rid())
	PuzzleKit.box(self, Vector3(0.0, tall * 0.5, 0.0), Vector3(0.42, tall, 0.42), PuzzleKit.stone())
	PuzzleKit.box(self, Vector3(0.0, 0.04, 0.0), Vector3(0.56, 0.08, 0.56), PuzzleKit.stone(PuzzleKit.DARK))
	PuzzleKit.box(self, Vector3(0.0, tall - 0.03, 0.0), Vector3(0.5, 0.06, 0.5), PuzzleKit.stone(PuzzleKit.DARK))
	# The lens, in its ring, on a foot of bronze: tipped as the beam is.
	PuzzleKit.rod(self, Vector3(0.0, tall + 0.04, 0.0), 0.08, 0.08, PuzzleKit.bronze(), 0.03, 8)
	var head := Node3D.new()
	head.position.y = height
	head.rotation.x = -deg_to_rad(pitch)
	add_child(head)
	var ring := PuzzleKit.ring(head, Vector3.ZERO, 0.24, 0.05, PuzzleKit.bronze())
	ring.rotation.x = PI * 0.5
	_lens = PuzzleKit.ball(head, Vector3.ZERO, 0.22, Toon.surface(Color(0.78, 0.9, 0.94)))
	_lens.scale.z = 0.3
	_lens.set_meta(&"lit", glow)
	_lens.set_meta(&"dull", _lens.material_override)


## Which way the light sets out, in the world.
func way() -> Vector3:
	var tip := deg_to_rad(pitch)
	return (global_basis.orthonormalized() * Vector3(0.0, sin(tip), cos(tip))).normalized()


## Where the light starts, in the world.
func source() -> Vector3:
	return global_transform * Vector3(0.0, height, 0.0)


## Follows the light from its source to where it ends: fills in `path`,
## `bounces` and `ends_on`, and tells a `SunDisc` it ends on.
func trace() -> void:
	path.clear()
	bounces = 0
	ends_on = null
	if not shining or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var from := source()
	var going := way()
	var left := reach
	path.append(from)
	while left > 0.01:
		var query := PhysicsRayQueryParameters3D.create(from, from + going * left)
		query.exclude = _own
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			path.append(from + going * left)
			return
		var at: Vector3 = hit["position"]
		path.append(at)
		left -= from.distance_to(at)
		var mirror := Mirror.of(hit["collider"])
		var face := mirror.normal() if mirror else Vector3.ZERO
		# (it must fall on a face of the disc, not on its edge, to be thrown off again)
		if mirror == null or bounces >= BOUNCES or absf((hit["normal"] as Vector3).dot(face)) < 0.7 or absf(going.dot(face)) < 0.02:
			ends_on = hit["collider"]
			var disc := SunDisc.of(ends_on)
			if disc:
				disc.strike(self)
			return
		bounces += 1
		going = going.bounce(face).normalized()
		from = at + going * 0.03


func _physics_process(_delta: float) -> void:
	trace()
	if path != _drawn:
		_drawn = path.duplicate()
		_draw()


func _process(delta: float) -> void:
	_clock += delta
	_material.set_shader_parameter(&"clock", _clock)


# Each stretch of the beam is three strips through its middle line, turned a third of a turn from one another.
func _draw() -> void:
	var mesh := _beam.mesh as ImmediateMesh
	mesh.clear_surfaces()
	_spot.visible = path.size() > 1 and ends_on != null
	if _lens:
		_lens.material_override = _lens.get_meta(&"lit" if path.size() > 1 else &"dull")
	if path.size() < 2:
		return
	_spot.global_position = path[path.size() - 1]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var run := b - a
		var long := run.length()
		if long < 0.001:
			continue
		var forward := run / long
		var side := forward.cross(Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT).normalized()
		for turn in 3:
			var out := side.rotated(forward, turn * PI / 3.0) * width * 0.5
			var corners := [[a - out, Vector2(0.0, along)], [a + out, Vector2(1.0, along)], [b + out, Vector2(1.0, along + long)], [b - out, Vector2(0.0, along + long)]]
			for corner: int in [0, 1, 2, 0, 2, 3]:
				mesh.surface_set_uv(corners[corner][1])
				mesh.surface_add_vertex(corners[corner][0])
		along += long
	mesh.surface_end()
