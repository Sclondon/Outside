class_name Scarab
## What a scarab looks like: the sacred scarab, Scarabaeus sacer, the dung
## beetle of the Egyptian desert. It is all black, 25 to 38 mm long, broad and
## rather flat: domed wing cases with a seam down the middle, a wide shield
## over the thorax, and a flat head shield whose front edge is cut into six
## teeth, a rake for digging (with the four teeth on each fore leg they make
## the arc of "rays" the Egyptians saw as the rising sun). It rolls its ball
## backwards, head down, pushing with its hind legs.
## (https://en.wikipedia.org/wiki/Scarabaeus_sacer)
##
## Here it is one small mesh, a unit long and facing +Z, to be drawn many at
## a time as a MultiMesh (`ScarabSwarm`). It is a Blender model: the object
## `scarab` in `models/khepri.glb`, built by `tools/build_khepri.py` (which
## keeps `tools/khepri.blend` to look at and change by hand, and says what to
## mind in changing it). Its six legs are moved in the shader: each point of a
## leg says how far down the leg it is and which three legs it steps with (its
## first texture coordinate, the model's UV map: these are not colours, because
## the web's renderer gives a MultiMesh without colours of its own no settled
## colour to its points), and the instance says how far through a stride it is
## (`INSTANCE_CUSTOM.x`, in whole strides), so a beetle that stands still stops
## its legs. The second texture coordinate is how much a point shines, which
## is made here from how rough the model's material is: the shell is not
## rough and shines, with a blue-green sheen that turns from blue to green as
## it turns from the eye; legs are rough and do not. The model's materials are
## merged into one surface, so the swarm is one draw call still.
##
## `amulet()` is the same beetle as a thing of gold and lapis the size of a
## hand: the object `scarab_amulet` in the same model.

const SHADER := """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec3 shell : source_color = vec3(0.035, 0.04, 0.05);
uniform vec3 sheen_blue : source_color = vec3(0.12, 0.36, 0.8);
uniform vec3 sheen_green : source_color = vec3(0.06, 0.6, 0.5);
uniform float sheen = 1.1;
uniform float gloss = 70.0;
// How far a foot swings fore and aft and how high it lifts, in lengths of the beetle.
uniform float reach = 0.11;
uniform float lift = 0.05;

varying float shiny;

void vertex() {
	float turn = (INSTANCE_CUSTOM.x + UV.y) * TAU;
	VERTEX.z += sin(turn) * reach * UV.x;
	VERTEX.y += max(cos(turn), 0.0) * lift * UV.x;
	shiny = UV2.x;
}

void fragment() {
	ALBEDO = shell;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float near = clamp(ATTENUATION, 0.0, 1.0);
	float amount = dot(NORMAL, LIGHT) * smoothstep(0.1, 0.5, near);
	float lit = cut(amount, 0.02);
	float strength = mix(near, 1.0, 0.5);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	// The sheen: one hard-edged light on the shell, and a band of it round the
	// edge, blue seen square on and green seen aslant.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 hue = mix(sheen_blue, sheen_green, smoothstep(0.25, 0.8, graze));
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.5);
	float rim = cut(graze, 0.74) * 0.5;
	SPECULAR_LIGHT += max(shine, rim) * lit * shiny * sheen * hue * strength * LIGHT_COLOR / PI;
}
"""

const MODEL := "res://models/khepri.glb"

static var _shader: Shader
static var _mesh: ArrayMesh
static var _amulet: ArrayMesh


## The beetle, legs and all, in the material that moves them. One for everybody.
static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _laid_out(modelled("scarab"))
		_mesh.surface_set_material(0, material())
	return _mesh


## The material a beetle is drawn in.
static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var made := ShaderMaterial.new()
	made.shader = _shader
	return made


## A scarab as a jewel, a unit long: one mesh, a surface for each of the
## model's materials (`amulet_gold`: the thorax, the head and the base;
## `amulet_stone`: the wing cases), each still in the material it has there.
static func amulet() -> ArrayMesh:
	if _amulet == null:
		_amulet = modelled("scarab_amulet")
	return _amulet


## The mesh of a thing in the model, by the name it has there.
static func modelled(which: String) -> ArrayMesh:
	var model := (load(MODEL) as PackedScene).instantiate()
	var part := model.find_child(which, true, false) as MeshInstance3D
	var found := part.mesh as ArrayMesh if part else null
	model.free()
	if found == null:
		push_error("The scarabs' model has nothing in it called %s" % which)
		return ArrayMesh.new()
	return found


# The model's beetle as the swarm's shader wants it: all one surface, each point with its normal, what the model
# says of its leg (its first texture coordinate) and how much it shines (its second: the more, the less rough the
# model's material is).
static func _laid_out(from: ArrayMesh) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface in from.get_surface_count():
		var paint := from.surface_get_material(surface) as BaseMaterial3D
		var shine := snappedf(1.0 - paint.roughness, 0.01) if paint else 0.0
		var arrays := from.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var legs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := order.size() if not order.is_empty() else points.size()
		tool.set_uv2(Vector2(shine, 0.0))
		for i in count:
			var k := order[i] if not order.is_empty() else i
			var leg := legs[k] if k < legs.size() else Vector2.ZERO
			# (how far down the leg, in hundredths; and which three it steps with, 0 or a half)
			tool.set_uv(Vector2(snappedf(leg.x, 0.01), snappedf(leg.y, 0.5)))
			tool.set_normal(normals[k])
			tool.add_vertex(points[k])
	tool.index()
	return tool.commit()
