class_name BaMesh
## What a Ba looks like: a bird with a person's head, as the Book of the Dead
## draws the part of a dead man that flies out of his tomb by day. The body is a
## falcon's, pale; the wings are banded as painted wings are (turquoise over the
## arm, a line of gold, long pale feathers tipped with dark blue); the head is a
## man's, in the striped headcloth of blue and gold, with eyes drawn long in
## black. It has a bird's legs, and two small arms that it holds up.
##
## The model is `models/ba.glb`, built in Blender by `tools/build_ba.py` (which
## also keeps `tools/ba.blend`, to look at and change by hand). It has no
## bones: it is separate things that `Ba` moves, each named for what it is:
## `body`, `head`, `wing_arm` and `wing_hand` (the two halves of one wing: the
## other wing is the same two turned over), `legs`, `arms`. Where each is
## hinged is its origin in the model (`at`). It faces +Z and is in metres.
##
## Its colours are the model's materials. Here each thing is made into one
## mesh with one material, every point carrying the colour of the material it
## had (as a custom value: the renderers do not agree what a mesh's own
## colours mean), so that a Ba is eight things to draw however many colours it
## is painted in. That material lights it in two flat tones as the figures are
## lit, adds a little light of its own (`glow`), and can thin it away to
## nothing (`fade`): it is thinned by leaving out points of it, which every
## renderer can do.

const MODEL := "res://models/ba.glb"
const PIECES: Array[String] = ["body", "head", "wing_arm", "wing_hand", "legs", "arms"]

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

// How much it shines by itself, and how much of it is there (1: all, 0: none).
uniform float glow = 0.5;
uniform float fade = 1.0;

varying vec3 tint;

void vertex() {
	tint = CUSTOM0.rgb;
}

void fragment() {
	if (fade < 0.999) {
		float grain = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
		if (grain >= fade) {
			discard;
		}
	}
	// (what it gives out it does not also take: it is no brighter in the sun for shining)
	ALBEDO = tint * (1.0 - glow * 0.5);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = tint * glow;
	// (the wings are flat and seen from both sides)
	if (dot(NORMAL, VIEW) < 0.0) {
		NORMAL = -NORMAL;
	}
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + 0.3) / 1.3;
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float strength = mix(reach, 1.0, 0.65);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
}
"""

## The soft light in the air round it: a round card turned to the camera and
## added to what is behind it (as a fire's is).
const HALO := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(0.75, 0.9, 1.0);
uniform float power = 0.2;

void vertex() {
	float big = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * big, INV_VIEW_MATRIX[1] * big, INV_VIEW_MATRIX[2] * big, MODEL_MATRIX[3]);
}

void fragment() {
	float out_from = length(UV * 2.0 - 1.0);
	float soft = 1.0 - smoothstep(0.0, 1.0, out_from);
	ALBEDO = colour * (soft * soft * 0.5 + pow(soft, 4.0) * 0.5) * power;
}
"""

static var _shader: Shader
static var _halo: Shader
static var _made := {}
static var _places := {}


## The material all of one Ba is drawn in.
static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var made := ShaderMaterial.new()
	made.shader = _shader
	return made


## The material of the light round it.
static func halo() -> ShaderMaterial:
	if _halo == null:
		_halo = Shader.new()
		_halo.code = HALO
	var made := ShaderMaterial.new()
	made.shader = _halo
	return made


## One of the things it is made of (see `PIECES`), as one mesh. Read from the model once.
static func piece(which: String) -> ArrayMesh:
	_read()
	return _made.get(which)


## Where a thing is hinged, within the thing it hangs from: the head and the arms and `wing_arm` from the
## body, `wing_hand` from `wing_arm`; `body` is how high the body is carried over the feet.
static func at(which: String) -> Vector3:
	_read()
	return _places.get(which, Vector3.ZERO)


## How many triangles the whole of it is.
static func triangles() -> int:
	var count := 0
	for which in PIECES:
		count += piece(which).get_faces().size() / 3 * (2 if which.begins_with("wing") else 1)
	return count


static func _read() -> void:
	if not _made.is_empty():
		return
	var model := (load(MODEL) as PackedScene).instantiate()
	for which in PIECES:
		var part := model.find_child(which, true, false) as MeshInstance3D
		if part == null:
			push_error("The Ba's model has nothing in it called %s" % which)
			_made[which] = ArrayMesh.new()
			continue
		_places[which] = part.position
		_made[which] = _as_one(part.mesh)
	model.free()


# A mesh of several materials as a mesh of one, each point keeping the colour of the material it had.
static func _as_one(mesh: Mesh) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGB_FLOAT)
	for surface in mesh.get_surface_count():
		var paint := mesh.surface_get_material(surface) as BaseMaterial3D
		var colour := (paint.albedo_color if paint else Color.WHITE).srgb_to_linear()
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := order.size() if not order.is_empty() else points.size()
		tool.set_custom(0, colour)
		for i in count:
			var k := order[i] if not order.is_empty() else i
			tool.set_normal(normals[k])
			tool.add_vertex(points[k])
	return tool.commit()
