class_name BaMesh
## What a Ba looks like: a bird with a person's head, as the Book of the Dead
## draws the part of a dead man that flies out of his tomb by day. The body is a
## falcon's, pale; the wings are banded as painted wings are (turquoise over the
## arm, a line of gold, long pale feathers tipped with dark blue); the head is a
## man's, in the striped headcloth of blue and gold, with eyes drawn long in
## black. It has a bird's legs, and two small arms that it holds up.
##
## It is made here in code, in pieces that `Ba` moves: the body with its tail,
## the head, each wing in two halves (arm and hand), the legs, and the arms.
## Everything faces +Z and is in metres; a Ba stands half a metre high. Every
## point carries its own colour (as a custom value). The first texture coordinate is how far along
## a striped thing a point is, in stripes, and the second says whether it is
## striped at all: the stripes are drawn by the shader, and fade into one
## colour when they are too far off to be told apart.
##
## The one material lights it in two flat tones as the figures are lit, adds a
## little light of its own (`glow`), and can thin it away to nothing (`fade`):
## it is thinned by leaving out points of it, which every renderer can do.

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

// How much it shines by itself, and how much of it is there (1: all, 0: none).
uniform float glow = 0.5;
uniform float fade = 1.0;
uniform vec3 stripe : source_color = vec3(0.14, 0.25, 0.6);

varying float striped;
varying vec3 tint;

void vertex() {
	striped = UV2.x;
	tint = CUSTOM0.rgb;
}

void fragment() {
	if (fade < 0.999) {
		float grain = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
		if (grain >= fade) {
			discard;
		}
	}
	float wave = abs(fract(UV.x) - 0.5) * 2.0;
	float pixel = max(fwidth(UV.x) * 2.0, 0.0001);
	float band = smoothstep(0.5 - pixel, 0.5 + pixel, wave);
	// (too far off to tell the stripes apart, they run together)
	band = mix(band, 0.5, clamp(pixel * 1.4 - 0.4, 0.0, 1.0));
	vec3 colour = mix(tint, stripe, band * striped);
	// (what it gives out it does not also take: it is no brighter in the sun for shining)
	ALBEDO = colour * (1.0 - glow * 0.5);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = colour * glow;
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

const FEATHER := Color(0.9, 0.86, 0.72)
const BREAST := Color(0.97, 0.95, 0.88)
const TURQUOISE := Color(0.26, 0.64, 0.62)
const GOLD := Color(0.88, 0.62, 0.14)
const LAPIS := Color(0.14, 0.25, 0.6)
const SKIN := Color(0.78, 0.5, 0.32)
const INK := Color(0.05, 0.04, 0.05)
const LEG := Color(0.86, 0.62, 0.22)

## Where the pieces go, in the body's own space (it lies along +Z as it flies).
const NECK := Vector3(0.0, 0.045, 0.125)
const SHOULDER := Vector3(0.07, 0.05, 0.055)
const CHEST := Vector3(0.0, -0.02, 0.12)
## How long the arm of a wing is, to where the hand of it begins.
const ARM := 0.2
const HAND := 0.26

static var _shader: Shader
static var _halo: Shader
static var _made := {}


## The material all of one Ba is drawn in.
static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var made := ShaderMaterial.new()
	made.shader = _shader
	made.set_shader_parameter(&"stripe", LAPIS)
	return made


## The material of the light round it.
static func halo() -> ShaderMaterial:
	if _halo == null:
		_halo = Shader.new()
		_halo.code = HALO
	var made := ShaderMaterial.new()
	made.shader = _halo
	return made


## One of the pieces: "body", "head", "arm_wing", "hand_wing" (of the wing on
## its +X side: the other is the same turned over), "legs", "arms". Made once.
static func piece(which: String) -> ArrayMesh:
	if _made.has(which):
		return _made[which]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# (colours go as plain numbers of the mesh's own, not as its colours: the renderers do not agree what those mean)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGB_FLOAT)
	match which:
		"body":
			_body(tool)
		"head":
			_head(tool)
		"arm_wing":
			_arm_wing(tool)
		"hand_wing":
			_hand_wing(tool)
		"legs":
			_legs(tool)
		"arms":
			_arms(tool)
	var mesh := tool.commit()
	_made[which] = mesh
	return mesh


## How many triangles the whole of it is.
static func triangles() -> int:
	var count := 0
	for which: String in ["body", "head", "legs", "arms"]:
		count += piece(which).get_faces().size() / 3
	for which: String in ["arm_wing", "hand_wing"]:
		count += piece(which).get_faces().size() / 3 * 2
	return count


# --- The pieces ---

# A falcon's body, deep in the chest and drawn out behind, and its tail: a fan
# of five feathers, banded.
static func _body(tool: SurfaceTool) -> void:
	_plain(tool)
	# (rings from the tail end to the breast: where along it, how wide, how deep, how far the middle is dropped)
	var rings := [[-0.17, 0.012, 0.012, 0.0], [-0.12, 0.05, 0.045, 0.0], [-0.04, 0.08, 0.074, -0.004], [0.05, 0.09, 0.088, -0.01], [0.115, 0.068, 0.072, -0.004], [0.155, 0.022, 0.03, 0.012]]
	var around := 8
	for i in rings.size() - 1:
		for k in around:
			var corners: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var colours: Array[Color] = []
			for pair: Array in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k + 1]]:
				var ring: Array = rings[pair[0]]
				var turn := TAU * float(pair[1]) / around
				var out := Vector3(cos(turn) * float(ring[1]), sin(turn) * float(ring[2]), 0.0)
				corners.append(out + Vector3(0.0, ring[3], ring[0]))
				normals.append(Vector3(cos(turn) / maxf(ring[1], 0.02), sin(turn) / maxf(ring[2], 0.02), 0.0).normalized())
				# (pale underneath and on the breast, cream above)
				colours.append(FEATHER.lerp(BREAST, clampf(0.5 - sin(turn) * 0.9 + float(ring[0]) * 3.0, 0.0, 1.0)))
			for corner: int in [0, 1, 2, 0, 2, 3]:
				tool.set_custom(0, (colours[corner]).srgb_to_linear())
				tool.set_normal(normals[corner])
				tool.add_vertex(corners[corner])
	# A collar of gold and turquoise where the neck leaves the breast
	_blob(tool, NECK + Vector3(0.0, -0.012, 0.0), Vector3(0.05, 0.026, 0.05), GOLD, 8, 3)
	# The tail
	var root := Vector3(0.0, 0.0, -0.13)
	for k in 5:
		var one := lerpf(-0.6, 0.6, k / 5.0)
		var two := lerpf(-0.6, 0.6, (k + 1) / 5.0)
		var far := 0.2 - absf(k - 2.0) * 0.012
		var a := root + Vector3(sin(one) * 0.045, 0.004, -cos(one) * 0.02)
		var b := root + Vector3(sin(two) * 0.045, 0.004, -cos(two) * 0.02)
		var c := root + Vector3(sin(two) * far, -0.006, -cos(two) * far)
		var d := root + Vector3(sin(one) * far, -0.006, -cos(one) * far)
		var mid_ad := a.lerp(d, 0.72)
		var mid_bc := b.lerp(c, 0.72)
		_flat(tool, [a, b, mid_bc, mid_ad], FEATHER)
		_flat(tool, [mid_ad, mid_bc, c.lerp(d, 0.2), d.lerp(c, 0.2)], LAPIS.lerp(TURQUOISE, 0.25))


# A man's head, and the headcloth: a cap of it over his brow, the wings of it
# standing out behind his ears, and a lappet hanging down each side of his face.
static func _head(tool: SurfaceTool) -> void:
	_plain(tool)
	var face := Vector3(0.0, 0.088, 0.006)
	# The neck, and the head on it
	_blob(tool, Vector3(0.0, 0.02, 0.0), Vector3(0.03, 0.04, 0.03), SKIN, 6, 3)
	_blob(tool, face, Vector3(0.056, 0.068, 0.062), SKIN, 10, 6)
	# His nose, his ears
	_flat(tool, [face + Vector3(0.0, 0.012, 0.06), face + Vector3(-0.011, -0.016, 0.057), face + Vector3(0.0, -0.02, 0.076)], SKIN.darkened(0.12))
	_flat(tool, [face + Vector3(0.0, 0.012, 0.06), face + Vector3(0.0, -0.02, 0.076), face + Vector3(0.011, -0.016, 0.057)], SKIN.darkened(0.04))
	for side: float in [-1.0, 1.0]:
		_blob(tool, face + Vector3(side * 0.056, -0.004, 0.0), Vector3(0.01, 0.02, 0.014), SKIN.darkened(0.1), 5, 3)
		# An eye, drawn long, and the brow over it
		var eye := face + Vector3(side * 0.024, 0.01, 0.0562)
		_flat(tool, [eye + Vector3(-0.013, 0.0, 0.002), eye + Vector3(0.0, -0.007, 0.004), eye + Vector3(0.013, 0.0, -0.001), eye + Vector3(0.0, 0.008, 0.003)], Color(0.97, 0.96, 0.92))
		_flat(tool, [eye + Vector3(-0.005, 0.0, 0.006), eye + Vector3(0.0, -0.006, 0.006), eye + Vector3(0.005, 0.0, 0.005), eye + Vector3(0.0, 0.007, 0.006)], INK)
		_flat(tool, [eye + Vector3(side * 0.011, 0.002, 0.0), eye + Vector3(side * 0.011, -0.003, 0.0), eye + Vector3(side * 0.03, -0.001, -0.02)], INK)
		_flat(tool, [eye + Vector3(-side * 0.014, 0.012, 0.002), eye + Vector3(-side * 0.014, 0.017, 0.001), eye + Vector3(side * 0.02, 0.019, -0.008), eye + Vector3(side * 0.02, 0.014, -0.006)], INK)
	# His mouth
	_flat(tool, [face + Vector3(-0.014, -0.034, 0.05), face + Vector3(0.0, -0.039, 0.054), face + Vector3(0.014, -0.034, 0.05), face + Vector3(0.0, -0.031, 0.055)], Color(0.55, 0.22, 0.16))
	# The headcloth. Its cap: the top and back of a ball a little bigger than his head, cut away over his face.
	var cap := Vector3(0.063, 0.076, 0.07)
	var around := 12
	var rows := 6
	for row in rows:
		for k in around:
			var corners: Array[Vector3] = []
			var open := false
			for pair: Array in [[row, k], [row + 1, k], [row + 1, k + 1], [row, k + 1]]:
				var high := lerpf(PI * 0.5, -PI * 0.42, float(pair[0]) / rows)
				var turn := TAU * float(pair[1]) / around
				var unit := Vector3(sin(turn) * cos(high), sin(high), cos(turn) * cos(high))
				# (the face looks out from under it: nothing in front below the brow)
				if (unit.z > 0.25 and unit.y < 0.4) or (unit.z > -0.3 and unit.y < 0.05):
					open = true
				corners.append(unit)
			if open:
				continue
			for corner: int in [0, 1, 2, 0, 2, 3]:
				var unit := corners[corner]
				tool.set_custom(0, (GOLD).srgb_to_linear())
				# (striped from the brow back over the crown)
				tool.set_uv(Vector2((atan2(unit.y, unit.z) + (TAU if unit.y < 0.0 else 0.0)) / 0.42, 0.0))
				tool.set_uv2(Vector2(1.0, 0.0))
				tool.set_normal((unit / cap).normalized())
				tool.add_vertex(face + Vector3(0.0, 0.004, -0.004) + unit * cap)
	_plain(tool)
	# Its wings, standing out behind the ears: one flat piece, wide at the shoulders
	var top := 0.15
	var foot := 0.012
	_striped(tool, [Vector3(-0.05, top, -0.012), Vector3(0.05, top, -0.012), Vector3(0.118, foot, -0.004), Vector3(-0.118, foot, -0.004)], Vector3.BACK, 0.03)
	# and the lappets, down onto the breast
	for side: float in [-1.0, 1.0]:
		_striped(tool, [Vector3(side * 0.04, 0.05, 0.05), Vector3(side * 0.1, 0.045, 0.012), Vector3(side * 0.085, -0.055, 0.03), Vector3(side * 0.04, -0.06, 0.056)], Vector3(side * 0.3, 0.1, 1.0).normalized(), 0.03)
		# (and the side of the cloth between them and the wing behind)
		_striped(tool, [Vector3(side * 0.1, 0.045, 0.012), Vector3(side * 0.118, foot, -0.004), Vector3(side * 0.085, -0.055, 0.03)], Vector3(side, 0.0, 0.3).normalized(), 0.03)


# The arm of a wing, from the shoulder out along +X: small feathers of
# turquoise over the bone, a line of gold, and the long feathers behind.
static func _arm_wing(tool: SurfaceTool) -> void:
	_plain(tool)
	var count := 4
	for k in count:
		var one := ARM * k / count
		var two := ARM * (k + 1) / count
		_feather(tool, Vector3(one, 0.0, 0.05), Vector3(two, 0.0, 0.055), Vector3(one + 0.008, -0.012, -0.135 - 0.006 * k), Vector3(two, -0.012, -0.14 - 0.006 * k))


# The hand of a wing: five long feathers fanned out to its tip.
static func _hand_wing(tool: SurfaceTool) -> void:
	_plain(tool)
	var count := 5
	for k in count:
		var one := float(k) / count
		var two := float(k + 1) / count
		# (the front edge runs out to the tip; the feathers are swept further back the further out they grow)
		var lead_one := Vector3(HAND * 0.62 * one, 0.0, 0.055 - 0.03 * one * one)
		var lead_two := Vector3(HAND * 0.62 * two, 0.0, 0.055 - 0.03 * two * two)
		var sweep_one := lerpf(0.0, 1.05, one)
		var sweep_two := lerpf(0.0, 1.05, two)
		var long_one := lerpf(0.2, 0.19, one)
		var long_two := lerpf(0.2, 0.19, two)
		var tip_one := lead_one + Vector3(sin(sweep_one) * long_one, -0.014, -cos(sweep_one) * long_one)
		var tip_two := lead_two + Vector3(sin(sweep_two) * long_two, -0.014, -cos(sweep_two) * long_two)
		_feather(tool, lead_one, lead_two, tip_one, tip_two)


# One feather's width of wing, from the front edge (a, b) back to the tips (c, d).
static func _feather(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var cover_a := a.lerp(c, 0.36)
	var cover_b := b.lerp(d, 0.36)
	var gold_a := a.lerp(c, 0.46)
	var gold_b := b.lerp(d, 0.46)
	var dark_a := a.lerp(c, 0.8)
	var dark_b := b.lerp(d, 0.8)
	_flat(tool, [a, b, cover_b, cover_a], TURQUOISE)
	_flat(tool, [cover_a, cover_b, gold_b, gold_a], GOLD)
	_flat(tool, [gold_a, gold_b, dark_b, dark_a], FEATHER)
	# (the tip is rounded off, and stands a little apart from the next)
	_flat(tool, [dark_a, dark_b, d.lerp(c, 0.12), c.lerp(d, 0.5) + (c - a).normalized() * 0.012, c.lerp(d, 0.12)], LAPIS.lerp(TURQUOISE, 0.2))


# A bird's legs: thigh feathers, a shank, three toes forward and one back.
# Their feet are at the ground (y 0) and their hips 0.2 above it.
static func _legs(tool: SurfaceTool) -> void:
	_plain(tool)
	for side: float in [-1.0, 1.0]:
		var hip := Vector3(side * 0.036, 0.2, -0.005)
		var knee := Vector3(side * 0.038, 0.115, 0.012)
		var foot := Vector3(side * 0.04, 0.008, 0.0)
		_blob(tool, hip.lerp(knee, 0.35), Vector3(0.026, 0.06, 0.03), FEATHER, 6, 3)
		_limb(tool, knee, foot, 0.0085, LEG)
		for toe: Vector3 in [Vector3(side * 0.03, 0.0, 0.05), Vector3(0.0, 0.0, 0.058), Vector3(-side * 0.026, 0.0, 0.046), Vector3(0.0, 0.0, -0.032)]:
			var end := foot + toe + Vector3(0.0, -0.006, 0.0)
			var across := toe.cross(Vector3.UP).normalized() * 0.007
			_flat(tool, [foot - across, foot + across, end], LEG)


# Two small arms, held up before it with the hands open, as a man's are who
# greets the sun. They are drawn as it stands upright: the shoulders are at
# the middle, the hands up and forward.
static func _arms(tool: SurfaceTool) -> void:
	_plain(tool)
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.05, 0.0, 0.0)
		var elbow := Vector3(side * 0.068, -0.03, 0.06)
		var wrist := Vector3(side * 0.062, 0.05, 0.1)
		_limb(tool, shoulder, elbow, 0.011, SKIN)
		_limb(tool, elbow, wrist, 0.009, SKIN)
		_blob(tool, wrist + Vector3(0.0, 0.016, 0.004), Vector3(0.011, 0.02, 0.008), SKIN, 5, 3)
		# (a band of gold at the wrist)
		_blob(tool, wrist, Vector3(0.012, 0.007, 0.012), GOLD, 5, 2)


# --- What they are made from ---

static func _plain(tool: SurfaceTool) -> void:
	tool.set_uv(Vector2.ZERO)
	tool.set_uv2(Vector2.ZERO)


# A ball, squashed to `radii`.
static func _blob(tool: SurfaceTool, middle: Vector3, radii: Vector3, colour: Color, around: int, rows: int) -> void:
	tool.set_custom(0, (colour).srgb_to_linear())
	for row in rows:
		for k in around:
			var corners: Array[Vector3] = []
			for pair: Array in [[row, k], [row + 1, k], [row + 1, k + 1], [row, k + 1]]:
				var high := lerpf(PI * 0.5, -PI * 0.5, float(pair[0]) / rows)
				var turn := TAU * float(pair[1]) / around
				corners.append(Vector3(sin(turn) * cos(high), sin(high), cos(turn) * cos(high)))
			for corner: int in [0, 1, 2, 0, 2, 3]:
				tool.set_normal((corners[corner] / radii).normalized())
				tool.add_vertex(middle + corners[corner] * radii)


# A flat piece with any number of corners, all of one colour.
static func _flat(tool: SurfaceTool, corners: Array, colour: Color) -> void:
	var normal := ((corners[1] as Vector3) - (corners[0] as Vector3)).cross((corners[2] as Vector3) - (corners[0] as Vector3)).normalized()
	# (which way round it was given does not matter: both sides are drawn. Flat things are lit as if they faced up or out.)
	if normal.y < -0.3:
		normal = -normal
	tool.set_custom(0, (colour).srgb_to_linear())
	tool.set_normal(normal)
	for k in range(1, corners.size() - 1):
		tool.add_vertex(corners[0])
		tool.add_vertex(corners[k])
		tool.add_vertex(corners[k + 1])


# A flat piece of the headcloth: gold, striped across with blue, a stripe every `gap` of its height.
static func _striped(tool: SurfaceTool, corners: Array, normal: Vector3, gap: float) -> void:
	tool.set_custom(0, (GOLD).srgb_to_linear())
	tool.set_normal(normal)
	tool.set_uv2(Vector2(1.0, 0.0))
	for k in range(1, corners.size() - 1):
		for corner: Vector3 in [corners[0], corners[k], corners[k + 1]]:
			tool.set_uv(Vector2(corner.y / gap, 0.0))
			tool.add_vertex(corner)
	_plain(tool)


# A thin limb: two flat strips crossed, tapering a little.
static func _limb(tool: SurfaceTool, from: Vector3, to: Vector3, thick: float, colour: Color) -> void:
	var along := (to - from).normalized()
	var across := along.cross(Vector3.FORWARD if absf(along.z) < 0.8 else Vector3.RIGHT).normalized()
	var over := across.cross(along)
	tool.set_custom(0, (colour).srgb_to_linear())
	for way: Vector3 in [across, over]:
		var normal := way.cross(along).normalized()
		tool.set_normal(normal)
		for corner: Vector3 in [from - way * thick, from + way * thick, to + way * thick * 0.8, from - way * thick, to + way * thick * 0.8, to - way * thick * 0.8]:
			tool.add_vertex(corner)
