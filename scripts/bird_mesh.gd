class_name BirdMesh
## Builds a bird from the measurements in `BirdKinds`, and the shader that
## moves it. There are no bones. Every point of the mesh says what it is part
## of (body, wing, neck, head, leg, tail, crest) and how far along that part
## it is, and the shader bends each part from eight numbers given to each bird
## of a flock (`Birds` sends them as the custom data and the colour of its
## place in a MultiMesh):
##
##     custom  x, y   how far the inner and the outer half of the wing are raised (radians)
##             z      how far the wings are shut: 0 spread, 1 folded along its flanks
##             w      its legs: 0 up (trailing behind a heron, tucked under a sparrow), 1 down and
##                    standing on them, body tipped up as it stands; up to 2, one of them drawn up
##     colour  r, g   the bend of the lower and of the upper half of its neck (radians, up)
##             b      the nod of its head on that
##             a      its stride, -1..1 (or, for a bird with a crest, how far that is raised)
##
## So a flock of any size is one draw, and a bird far off is the same bird in
## a couple of dozen triangles (`far`).
##
## A point's first texture coordinate is (part, how far along it), and its
## second is (place in the kind's palette, nothing).

const BODY := 0.0
const WING := 1.0
const NECK := 2.0
const HEAD := 3.0
const LEG := 4.0
const TAIL := 5.0
const CREST := 6.0

## The outline of each sort of wing, root to tip: how far along, and how far
## its front and back edges are from the line of the shoulders, in chords.
const OUTLINES := {
	BirdKinds.Wing.BROAD: [[0.0, 0.3, -0.7], [0.25, 0.36, -0.7], [0.5, 0.4, -0.66], [0.75, 0.34, -0.6], [0.92, 0.2, -0.45], [1.0, 0.0, -0.2]],
	BirdKinds.Wing.POINTED: [[0.0, 0.3, -0.7], [0.25, 0.4, -0.62], [0.42, 0.45, -0.5], [0.7, 0.2, -0.38], [1.0, -0.35, -0.42]],
	BirdKinds.Wing.ROUND: [[0.0, 0.3, -0.7], [0.3, 0.4, -0.78], [0.6, 0.4, -0.74], [0.85, 0.26, -0.6], [1.0, 0.0, -0.3]],
}
## The same for a broad wing that ends in fingers: it stops short and square, and the fingers go on from there.
const FINGERED := [[0.0, 0.3, -0.7], [0.3, 0.36, -0.7], [0.6, 0.4, -0.66], [1.0, 0.32, -0.5]]
const FINGERS_FROM := 0.86
const WRISTS := {BirdKinds.Wing.BROAD: 0.5, BirdKinds.Wing.POINTED: 0.42, BirdKinds.Wing.ROUND: 0.5}
## How the neck is built: pointing forward and this much up.
const NECK_UP := 0.26

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 palette[10];
// Where the body tips up from as it stands (z, y), how far apart the legs are, and how high their tops.
uniform vec2 hips;
uniform float leg_apart;
uniform float leg_top;
// How far the body is tipped up, standing (radians), and whether the legs trail behind in flight (1) or are tucked up (0).
uniform float stance;
uniform float trail;
// The shoulder; how far out the wrist and the tip are from it; and where a folded wing reaches to.
uniform vec3 shoulder;
uniform float wrist;
uniform float reach;
uniform float fold_back;
uniform float fold_drop;
// The joints of the neck (z, y): its root, its middle, and the head. And the root of the crest.
uniform vec2 neck_root;
uniform vec2 neck_bend;
uniform vec2 head_at;
uniform vec2 crest_at;
uniform float crested;

varying vec3 tone;

vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void vertex() {
	float part = UV.x;
	float along = UV.y;
	vec4 wings = INSTANCE_CUSTOM;
	vec4 held = COLOR;
	tone = palette[int(UV2.x + 0.5)];
	float down = clamp(wings.w, 0.0, 1.0);
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	if (part > 3.5 && part < 4.5) {
		// A leg: thigh and shin, swung from the hip. Up, it trails straight out behind or is folded away under the belly.
		float side = sign(p.x);
		float up = 1.0 - down;
		float lifted = clamp(wings.w - 1.0, 0.0, 1.0) * step(0.0, side);
		float stride = (1.0 - crested) * held.a * side * down;
		float thigh = up * mix(-0.9, 1.45, trail) + stride * 0.45 - lifted * 1.0;
		float shin = thigh + up * mix(2.3, 0.0, trail) + max(-stride, 0.0) * 0.6 + lifted * 2.4;
		float small = mix(1.0, 0.6, up * (1.0 - trail));
		vec2 q = (p.zy - vec2(0.0, leg_top)) * small;
		vec2 knee = vec2(0.0, -leg_top * 0.5) * small;
		vec2 at = along <= 0.5 ? turn(q, -thigh) : turn(knee, -thigh) + turn(q - knee, -shin);
		p.zy = vec2(0.0, leg_top) + at;
		p.x = side * leg_apart + (p.x - side * leg_apart) * small;
		n.zy = turn(n.zy, along <= 0.5 ? -thigh : -shin);
	} else {
		if (part > 0.5 && part < 1.5) {
			// A wing: two halves, each raised by its own angle; shut, it lies back along the flank.
			float side = sign(p.x);
			float d = abs(p.x) - shoulder.x;
			float c = p.z - shoulder.z;
			vec2 inner = vec2(cos(wings.x), sin(wings.x));
			vec2 outer = vec2(cos(wings.y), sin(wings.y));
			vec2 out_up = d > wrist ? wrist * inner + (d - wrist) * outer : d * inner;
			vec3 open = vec3(side * (shoulder.x + out_up.x), shoulder.y + out_up.y, p.z);
			float far = d / reach;
			vec3 shut = vec3(side * (shoulder.x * (1.02 - 0.55 * far) + 0.004), shoulder.y + c * 0.5 - far * fold_drop, shoulder.z + c * 0.22 - far * fold_back);
			float a = d > wrist ? wings.y : wings.x;
			p = mix(open, shut, wings.z);
			n = normalize(mix(vec3(-sin(a) * side, cos(a), 0.0), vec3(side, 0.3, 0.0), wings.z));
		} else if (part > 4.5 && part < 5.5) {
			// The tail: a fan, shut when the wings are.
			p.x *= mix(0.4, 1.0, 1.0 - wings.z);
		} else if (part > 1.5) {
			// Neck, head and crest: a chain of three joints.
			float n_along = part < 2.5 ? along : 1.0;
			float a3 = held.b * (part < 2.5 ? smoothstep(0.86, 1.0, along) : 1.0);
			if (part > 5.5) {
				// (the feathers of a crest stand up one after another, the front one furthest)
				float lift = -held.a * (0.25 + 1.55 * (1.0 - along));
				p.zy = crest_at + turn(p.zy - crest_at, lift);
			}
			p.zy = head_at + turn(p.zy - head_at, a3);
			float a2 = held.g * smoothstep(0.3, 0.7, n_along);
			p.zy = neck_bend + turn(p.zy - neck_bend, a2);
			float a1 = held.r * smoothstep(0.0, 0.3, n_along);
			p.zy = neck_root + turn(p.zy - neck_root, a1);
			n.zy = turn(n.zy, a1 + a2 + a3);
		}
		// Standing, the whole of it is tipped up about its hips.
		float tip = stance * down;
		p.zy = hips + turn(p.zy - hips, tip);
		n.zy = turn(n.zy, tip);
	}
	VERTEX = p;
	NORMAL = n;
}

void fragment() {
	ALBEDO = tone;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	// Two flat tones with a hard edge, as every figure here is lit (see `Toon`).
	float reach_ = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + 0.3) / 1.3;
	float amount = facing * smoothstep(0.15, 0.6, reach_);
	DIFFUSE_LIGHT += cut(amount, 0.04) * mix(reach_, 1.0, 0.65) * LIGHT_COLOR / PI;
}
"""

static var _shader: Shader
static var _materials := {}
static var _near := {}
static var _far := {}


## The triangles of a mesh as they are gathered.
class Maker:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var parts := PackedVector2Array()
	var colours := PackedVector2Array()

	func point(at: Vector3, normal: Vector3, part: float, along: float, colour: int) -> void:
		points.append(at)
		normals.append(normal)
		parts.append(Vector2(part, along))
		colours.append(Vector2(colour, 0.0))

	## A triangle lit as facing `normal`, with how far along its part each corner is. (Its corners are
	## put in the order that makes that its front.)
	func tri(a: Vector3, b: Vector3, c: Vector3, part: float, colour: int, along_a: float, along_b: float, along_c: float, normal: Vector3) -> void:
		point(a, normal, part, along_a, colour)
		if (c - a).cross(b - a).dot(normal) >= 0.0:
			point(b, normal, part, along_b, colour)
			point(c, normal, part, along_c, colour)
		else:
			point(c, normal, part, along_c, colour)
			point(b, normal, part, along_b, colour)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, part: float, colour: int, along_ab: float, along_cd: float, normal: Vector3) -> void:
		tri(a, b, c, part, colour, along_ab, along_ab, along_cd, normal)
		tri(a, c, d, part, colour, along_ab, along_cd, along_cd, normal)

	## A flat triangle, lit as it lies, whose front is the side towards `out`.
	func face(a: Vector3, b: Vector3, c: Vector3, part: float, colour: int, along_a: float, along_b: float, along_c: float, out: Vector3) -> void:
		var flat := (c - a).cross(b - a).normalized()
		tri(a, b, c, part, colour, along_a, along_b, along_c, flat if flat.dot(out) >= 0.0 else -flat)

	func face_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, part: float, colour: int, along_ab: float, along_cd: float, out: Vector3) -> void:
		face(a, b, c, part, colour, along_ab, along_ab, along_cd, out)
		face(a, c, d, part, colour, along_ab, along_cd, along_cd, out)

	## A skin over a row of rings, each [middle, half width, half height, colour above, colour below, how far along],
	## the rings standing across the Z axis. A ring of no size closes an end.
	func loft(rings: Array, sides: int, part: float) -> void:
		for i in rings.size() - 1:
			var a: Array = rings[i]
			var b: Array = rings[i + 1]
			# (how much the skin leans forward or back between the two, for its normals)
			var run: float = maxf(absf(b[0].z - a[0].z), 0.0001)
			var lean_w: float = (a[1] - b[1]) / run * signf(b[0].z - a[0].z)
			for k in sides:
				var t0 := TAU * k / sides
				var t1 := TAU * (k + 1) / sides
				var colour: int = a[3] if sin((t0 + t1) * 0.5) > -0.2 else a[4]
				var corners: Array[Vector3] = []
				var facings: Array[Vector3] = []
				for pair: Array in [[a, t0], [b, t0], [b, t1], [a, t1]]:
					var ring: Array = pair[0]
					var t: float = pair[1]
					corners.append(ring[0] + Vector3(cos(t) * ring[1], sin(t) * ring[2], 0.0))
					facings.append(Vector3(cos(t) * maxf(ring[2], 0.001), sin(t) * maxf(ring[1], 0.001), 0.0).normalized().lerp(Vector3(0.0, 0.0, signf(lean_w)), minf(absf(lean_w) * 0.5, 0.8)).normalized())
				var alongs: Array[float] = [a[5], b[5], b[5], a[5]]
				for three: Array in [[0, 1, 2], [0, 2, 3]]:
					var order: Array = three
					var out: Vector3 = facings[three[0]] + facings[three[1]] + facings[three[2]]
					if (corners[three[2]] - corners[three[0]]).cross(corners[three[1]] - corners[three[0]]).dot(out) < 0.0:
						order = [three[0], three[2], three[1]]
					for corner: int in order:
						point(corners[corner], facings[corner], part, alongs[corner], colour)

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = parts
		arrays[Mesh.ARRAY_TEX_UV2] = colours
		var made := ArrayMesh.new()
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return made


## Where the parts of a kind are, in its own space, at the size it is drawn.
static func frame(kind: int) -> Dictionary:
	var k := BirdKinds.of(kind)
	var s: float = k["size"]
	var body: Vector3 = k["body"] * s
	var leg: float = k["leg"] * s
	var middle := leg + body.y * 0.5
	var neck: float = k["neck"] * s
	var neck_root := Vector3(0.0, middle + body.y * 0.15, body.z * 0.5)
	var way := Vector3(0.0, sin(NECK_UP), cos(NECK_UP))
	var shoulder := Vector3(body.x * 0.4, middle + body.y * 0.28, body.z * 0.25)
	var fingered: bool = k["fingers"] > 0
	var head: float = k["head"] * s
	var head_at := neck_root + way * neck
	return {
		"body": body, "leg": leg, "middle": middle, "neck_root": neck_root, "neck_bend": neck_root + way * neck * 0.5, "head_at": head_at,
		"head_middle": head_at + Vector3(0.0, head * 0.15, head * k["head_long"] * 0.5),
		"hips": Vector3(body.x * 0.22, leg + body.y * 0.3, 0.0), "leg_top": leg + body.y * 0.12,
		"shoulder": shoulder, "reach": k["span"] * s * 0.5 - shoulder.x, "wrist_at": WRISTS[k["wing"]] * (FINGERS_FROM if fingered else 1.0),
		"tail_root": Vector3(0.0, middle + body.y * 0.05, -body.z * 0.38),
	}


## The material that draws a kind: one for all of them there are.
static func material(kind: int) -> ShaderMaterial:
	if _materials.has(kind):
		return _materials[kind]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var k := BirdKinds.of(kind)
	var f := frame(kind)
	var made := ShaderMaterial.new()
	made.shader = _shader
	var palette: Array = (k["palette"] as Array).duplicate()
	var colours := PackedVector3Array()
	for i in 10:
		var colour: Color = (palette[mini(i, palette.size() - 1)] as Color).srgb_to_linear()
		colours.append(Vector3(colour.r, colour.g, colour.b))
	made.set_shader_parameter(&"palette", colours)
	var hips: Vector3 = f["hips"]
	var body: Vector3 = f["body"]
	made.set_shader_parameter(&"hips", Vector2(hips.z, hips.y))
	made.set_shader_parameter(&"leg_apart", hips.x)
	made.set_shader_parameter(&"leg_top", f["leg_top"])
	made.set_shader_parameter(&"stance", k["stance"])
	made.set_shader_parameter(&"trail", k["trail"])
	made.set_shader_parameter(&"shoulder", f["shoulder"])
	made.set_shader_parameter(&"wrist", f["wrist_at"] * f["reach"])
	made.set_shader_parameter(&"reach", f["reach"])
	# (a shut wing reaches back over the root of the tail)
	made.set_shader_parameter(&"fold_back", body.z * 0.68 + k["tail"] * k["size"] * 0.45)
	made.set_shader_parameter(&"fold_drop", body.y * 0.22)
	for joint: StringName in [&"neck_root", &"neck_bend", &"head_at"]:
		var at: Vector3 = f[joint]
		made.set_shader_parameter(joint, Vector2(at.z, at.y))
	var crest: Vector3 = f["head_middle"] + Vector3(0.0, k["head"] * k["size"] * 0.8, 0.0)
	made.set_shader_parameter(&"crest_at", Vector2(crest.z, crest.y))
	made.set_shader_parameter(&"crested", 1.0 if k["crest"] > 0.0 else 0.0)
	_materials[kind] = made
	return made


## The edges of a kind's wing at a place along it (0 the root, 1 the tip or where its fingers start): front and back, in chords.
static func _edges(k: Dictionary, u: float) -> Vector2:
	var outline: Array = FINGERED if k["fingers"] > 0 else OUTLINES[k["wing"]]
	for i in outline.size() - 1:
		var a: Array = outline[i]
		var b: Array = outline[i + 1]
		if u <= b[0] + 0.0001:
			var t := clampf((u - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return Vector2(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t))
	var last: Array = outline[outline.size() - 1]
	return Vector2(last[1], last[2])


## How long the tail is at a place across it (-1..1), as a share of its length.
static func _tail_length(shape: String, across: float) -> float:
	var out := absf(across)
	match shape:
		"wedge":
			return 1.0 - 0.45 * out
		"square":
			return 1.0 - 0.06 * out
		"fork":
			return 0.42 + 0.58 * pow(out, 1.5)
		"notch":
			return 0.82 + 0.18 * out
	return 1.0 - 0.25 * out * out


static func _wings(m: Maker, k: Dictionary, f: Dictionary, stations: int, strips: Array, fingers: bool) -> void:
	var s: float = k["size"]
	var shoulder: Vector3 = f["shoulder"]
	var reach: float = f["reach"]
	var chord: float = k["chord"] * s
	var cols: Array = k["wing_cols"]
	var bars: Array = k["wing_bars"]
	var fingered: bool = k["fingers"] > 0
	var scale_u := FINGERS_FROM if fingered else 1.0
	var wrist: float = WRISTS[k["wing"]]
	# The places along it: evenly, but one of them on the wrist.
	var us: Array[float] = []
	for i in stations + 1:
		us.append(float(i) / stations)
	var nearest := 1
	for i in range(1, stations):
		if absf(us[i] - wrist) < absf(us[nearest] - wrist):
			nearest = i
	us[nearest] = wrist
	for side: float in [1.0, -1.0]:
		for i in stations:
			var middle := (us[i] + us[i + 1]) * 0.5
			var e0 := _edges(k, us[i])
			var e1 := _edges(k, us[i + 1])
			var x0 := side * (shoulder.x + us[i] * scale_u * reach)
			var x1 := side * (shoulder.x + us[i + 1] * scale_u * reach)
			for j in strips.size() - 1:
				var colour: int = cols[(0 if middle < wrist else 3) + mini(j * 3 / (strips.size() - 1), 2)]
				if i == stations - 1 and not fingered and stations > 3:
					colour = cols[6]
				if not bars.is_empty() and (j > 0 or middle > wrist):
					colour = bars[i % 2]
				var a := Vector3(x0, shoulder.y, shoulder.z + lerpf(e0.x, e0.y, strips[j]) * chord)
				var b := Vector3(x1, shoulder.y, shoulder.z + lerpf(e1.x, e1.y, strips[j]) * chord)
				var c := Vector3(x1, shoulder.y, shoulder.z + lerpf(e1.x, e1.y, strips[j + 1]) * chord)
				var d := Vector3(x0, shoulder.y, shoulder.z + lerpf(e0.x, e0.y, strips[j + 1]) * chord)
				m.quad(a, b, c, d, WING, colour, 0.0, 0.0, Vector3.UP)
		if fingered and fingers:
			# The long feathers at the tip, spread like the fingers of a hand.
			var tip := _edges(k, 1.0)
			var x := side * (shoulder.x + scale_u * reach)
			var front := Vector3(x, shoulder.y, shoulder.z + tip.x * chord)
			var back := Vector3(x, shoulder.y, shoulder.z + tip.y * chord)
			var count: int = k["fingers"]
			var long := (1.0 - FINGERS_FROM) * reach * 1.15
			for i in count:
				var from := front.lerp(back, float(i) / count)
				var to := front.lerp(back, (i + 0.78) / count)
				var sweep := lerpf(0.05, -0.75, float(i) / maxf(count - 1, 1.0))
				var end := (from + to) * 0.5 + Vector3(side, 0.0, sweep).normalized() * long * lerpf(1.0, 0.8, float(i) / count)
				m.tri(from, end, to, WING, cols[6], 0.0, 0.0, 0.0, Vector3.UP)


## The whole bird, as it is seen near.
static func near(kind: int) -> ArrayMesh:
	if _near.has(kind):
		return _near[kind]
	var k := BirdKinds.of(kind)
	var f := frame(kind)
	var m := Maker.new()
	var s: float = k["size"]
	var sides: int = k["sides"]
	var body: Vector3 = f["body"]
	var middle: float = f["middle"]
	var cols: Array = k["body_cols"]

	# Body: fat in the middle, drawn out to the tail, blunt at the breast.
	var rings := []
	var profile := [[0.0, 0.04], [0.12, 0.5], [0.35, 0.93], [0.6, 1.0], [0.82, 0.74], [1.0, 0.3], [1.04, 0.0]]
	for i in profile.size():
		var t: float = profile[i][0]
		var wide: float = profile[i][1]
		var third := mini(i / 2, 2) if i < 4 else 2
		if i == 2 or i == 3:
			third = 1
		rings.append([Vector3(0.0, middle + body.y * 0.1 * (1.0 - t) * (1.0 - t), lerpf(-0.42, 0.58, t) * body.z), body.x * 0.5 * wide, body.y * 0.5 * wide, cols[third * 2], cols[third * 2 + 1], 0.0])
	m.loft(rings, sides, BODY)

	# Neck: from the breast to the head, thick where it leaves the body.
	var neck_root: Vector3 = f["neck_root"]
	var head_at: Vector3 = f["head_at"]
	var neck_r: float = k["neck_r"] * s
	var neck_cols: Array = k["neck_cols"]
	var thick := minf(body.x, body.y) * 0.3
	rings = []
	for i in 5:
		var t := i / 4.0
		var r := lerpf(thick, neck_r, minf(t * 2.4, 1.0))
		var colour: int = neck_cols[0 if t < 0.5 else 1]
		rings.append([neck_root.lerp(head_at, t), r, r, colour, colour, t])
	m.loft(rings, mini(sides, 6), NECK)

	# Head, bill and eyes.
	var head: float = k["head"] * s
	var long: float = head * k["head_long"]
	var at: Vector3 = f["head_middle"]
	var head_cols: Array = k["head_cols"]
	rings = []
	for step: Array in [[-1.0, 0.0], [-0.62, 0.78], [0.0, 1.0], [0.6, 0.72], [0.95, 0.3]]:
		rings.append([at + Vector3(0.0, 0.0, step[0] * long), head * step[1], head * step[1], head_cols[0], head_cols[1], 1.0])
	m.loft(rings, mini(sides, 6), HEAD)
	var bill: float = k["bill"] * s
	var bill_r: float = k["bill_r"] * s
	var curve: float = k["bill_curve"]
	var pieces := 3 if curve > 0.2 else 1
	var root := at + Vector3(0.0, -head * 0.08, long * 0.9)
	var before: Array[Vector3] = []
	for i in pieces + 1:
		var u := float(i) / pieces
		var spine := root + Vector3(0.0, -curve * bill * u * u, bill * u * (1.0 - 0.3 * curve * u))
		var r := bill_r * lerpf(1.3, 0.12, u)
		var ring: Array[Vector3] = [spine + Vector3(0.0, r, 0.0), spine + Vector3(r, -r * 0.6, 0.0), spine + Vector3(-r, -r * 0.6, 0.0)]
		if i > 0:
			for j in 3:
				m.face_quad(before[j], ring[j], ring[(j + 1) % 3], before[(j + 1) % 3], HEAD, k["bill_col"], 1.0, 1.0, (ring[j] + ring[(j + 1) % 3]) * 0.5 - spine)
		before = ring
	if k["eye_col"] >= 0:
		var e: float = head * k["eye"]
		for side: float in [1.0, -1.0]:
			var eye := at + Vector3(side * head * 0.99, head * 0.22, long * 0.3)
			var normal := Vector3(side, 0.1, 0.1).normalized()
			m.quad(eye + Vector3(0, e, 0), eye + Vector3(0, 0, e * 1.2), eye + Vector3(0, -e, 0), eye + Vector3(0, 0, -e * 1.2), HEAD, k["eye_col"], 1.0, 1.0, normal)

	# A crest: feathers lying back along the crown, each with a dark tip, that stand up into a fan.
	if k["crest"] > 0.0:
		var crest: float = k["crest"] * s
		var from := at + Vector3(0.0, head * 0.8, 0.0)
		for i in 5:
			var share := i / 4.0
			var base := from + Vector3(0.0, 0.0, lerpf(head * 0.5, -head * 0.5, share))
			var slant := lerpf(0.12, 0.0, share)
			var tip := base + Vector3(0.0, crest * slant, -crest * lerpf(0.85, 1.0, share))
			var wide := Vector3(0.0, crest * 0.11, 0.0)
			for side: float in [1.0, -1.0]:
				var normal := Vector3(side, 0.2, 0.0).normalized()
				var lean := Vector3(side * head * 0.12, 0.0, 0.0)
				m.quad(base + lean, base.lerp(tip, 0.72) + wide + lean, base.lerp(tip, 0.72) - wide * 0.3 + lean, base + lean - wide * 0.2, CREST, cols[2], share, share, normal)
				m.tri(base.lerp(tip, 0.72) + wide + lean, tip + lean, base.lerp(tip, 0.72) - wide * 0.3 + lean, CREST, 7, share, share, share, normal)

	_wings(m, k, f, k["wing_stations"], [0.0, 0.45, 0.8, 1.0], true)

	# Tail: a fan of feathers, a band of another colour at its end.
	var tail: float = k["tail"] * s
	var tail_w: float = k["tail_w"] * s
	var tail_root: Vector3 = f["tail_root"]
	var tail_cols: Array = k["tail_cols"]
	for i in 4:
		var x0 := i / 2.0 - 1.0
		var x1 := (i + 1) / 2.0 - 1.0
		var b0 := tail_root + Vector3(x0 * tail_w * 0.4, 0.0, 0.0)
		var b1 := tail_root + Vector3(x1 * tail_w * 0.4, 0.0, 0.0)
		var t0 := tail_root + Vector3(x0 * tail_w, -tail * 0.06, -tail * _tail_length(k["tail_shape"], x0))
		var t1 := tail_root + Vector3(x1 * tail_w, -tail * 0.06, -tail * _tail_length(k["tail_shape"], x1))
		m.quad(b1, b0, b0.lerp(t0, 0.68), b1.lerp(t1, 0.68), TAIL, tail_cols[0], 0.0, 0.0, Vector3.UP)
		m.quad(b1.lerp(t1, 0.68), b0.lerp(t0, 0.68), t0, t1, TAIL, tail_cols[1], 0.0, 0.0, Vector3.UP)

	# Legs: thigh, shin and a foot.
	var hips: Vector3 = f["hips"]
	var leg_top: float = f["leg_top"]
	var leg_r: float = k["leg_r"] * s
	var foot: float = k["foot"] * s
	for side: float in [1.0, -1.0]:
		var x := side * hips.x
		var last: Array[Vector3] = []
		for i in 3:
			var y := leg_top * (1.0 - i * 0.5)
			var ring: Array[Vector3] = [Vector3(x, y, leg_r), Vector3(x + leg_r, y, -leg_r * 0.7), Vector3(x - leg_r, y, -leg_r * 0.7)]
			if i > 0:
				for j in 3:
					m.face_quad(last[j], last[(j + 1) % 3], ring[(j + 1) % 3], ring[j], LEG, k["leg_col"], (i - 1) * 0.5, i * 0.5, (ring[j] + ring[(j + 1) % 3]) * 0.5 - Vector3(x, y, 0.0))
			last = ring
		m.tri(Vector3(x - foot * 0.45, 0.004, foot * 0.75), Vector3(x + foot * 0.45, 0.004, foot * 0.75), Vector3(x, 0.004, -foot * 0.35), LEG, k["leg_col"], 1.0, 1.0, 1.0, Vector3.UP)

	_near[kind] = m.mesh()
	(_near[kind] as ArrayMesh).surface_set_material(0, material(kind))
	return _near[kind]


## The same bird for a long way off: a body of eight triangles, wings of a few each (a soarer keeps
## the fingers at its wing tips: they are most of what is seen of it), and, for those that fly with
## them out behind, its legs. It is moved by the same shader.
static func far(kind: int) -> ArrayMesh:
	if _far.has(kind):
		return _far[kind]
	var k := BirdKinds.of(kind)
	var f := frame(kind)
	var m := Maker.new()
	var s: float = k["size"]
	var body: Vector3 = f["body"]
	var middle: float = f["middle"]
	var cols: Array = k["body_cols"]
	# (a neck that is carried out in front is part of its outline; one drawn back is not)
	var fly: Array = k["fly"]
	var ahead: float = k["neck"] * s * 0.9 if fly[0] < 0.5 else 0.0
	var nose := Vector3(0.0, middle, body.z * 0.58 + ahead + k["head"] * s * 1.6)
	var stern := Vector3(0.0, middle, -body.z * 0.42 - k["tail"] * s * 0.85)
	var ring: Array[Vector3] = [Vector3(body.x * 0.5, middle, body.z * 0.1), Vector3(0.0, middle + body.y * 0.5, body.z * 0.1), Vector3(-body.x * 0.5, middle, body.z * 0.1), Vector3(0.0, middle - body.y * 0.5, body.z * 0.1)]
	for i in 4:
		var colour: int = cols[2] if i < 2 else cols[3]
		var out := (ring[i] + ring[(i + 1) % 4]) * 0.5 - Vector3(0.0, middle, body.z * 0.1)
		m.face(ring[i], nose, ring[(i + 1) % 4], BODY, colour, 0.0, 0.0, 0.0, out)
		m.face(ring[(i + 1) % 4], stern, ring[i], BODY, colour, 0.0, 0.0, 0.0, out)
	var soars: bool = k["habit"] == BirdKinds.Habit.SOARER
	_wings(m, k, f, 2, [0.0, 0.45, 1.0] if soars else [0.0, 1.0], soars)
	if k["trail"] > 0.5:
		var top: float = f["leg_top"]
		var r: float = k["leg_r"] * s * 2.0
		m.tri(Vector3(r, top, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(-r, top, 0.0), LEG, k["leg_col"], 0.0, 1.0, 0.0, Vector3.FORWARD)
	_far[kind] = m.mesh()
	(_far[kind] as ArrayMesh).surface_set_material(0, material(kind))
	return _far[kind]


## How many triangles a mesh has.
static func triangles(mesh: ArrayMesh) -> int:
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
