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
## Here it is one small mesh made in code, a unit long and facing +Z, to be
## drawn many at a time as a MultiMesh (`ScarabSwarm`). Its six legs are moved
## in the shader: each point of a leg says how far down the leg it is and which
## three legs it steps with (its first texture coordinate: these are not
## colours, because the web's renderer gives a MultiMesh without colours of its
## own no settled colour to its points), and the instance says how far through
## a stride it is (`INSTANCE_CUSTOM.x`, in whole strides), so a beetle that
## stands still stops its legs. The second texture coordinate is how much a
## point shines: the shell does, with a blue-green sheen that turns from blue
## to green as it turns from the eye; legs do not.
##
## `amulet()` is the same beetle as a thing of gold and lapis the size of a hand.

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

static var _shader: Shader
static var _mesh: ArrayMesh


## The beetle, legs and all, in the material that moves them. One for everybody.
static func mesh() -> ArrayMesh:
	if _mesh == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_shell(tool, true)
		_head(tool)
		_legs(tool)
		_mesh = tool.commit()
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


## A scarab as a jewel: two meshes a unit long, [the body, head and base (for
## gold), the wing cases (for lapis)].
static func amulet() -> Array[ArrayMesh]:
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	_dome(body, Vector3(0.0, 0.05, 0.19), Vector3(0.29, 0.21, 0.15), 8, 2, 1.0)
	_head(body)
	# (a flat oval base, standing a little proud of the beetle all round: what a seal is cut into)
	var rim := 12
	for k in rim:
		var a := TAU * k / rim
		var b := TAU * (k + 1) / rim
		var one := Vector3(cos(a) * 0.36, 0.0, sin(a) * 0.56)
		var two := Vector3(cos(b) * 0.36, 0.0, sin(b) * 0.56)
		for up: float in [0.05, 0.0]:
			body.set_uv(Vector2.ZERO)
			body.set_uv2(Vector2(1.0, 0.0))
			body.set_normal(Vector3.UP if up > 0.0 else Vector3.DOWN)
			var points := [Vector3(0.0, up, 0.0), one + Vector3.UP * up, two + Vector3.UP * up]
			if up == 0.0:
				points.reverse()
			for point: Vector3 in points:
				body.add_vertex(point)
		body.set_normal(Vector3(cos(a), 0.0, sin(a)))
		for point: Vector3 in [one, two + Vector3.UP * 0.05, one + Vector3.UP * 0.05, one, two, two + Vector3.UP * 0.05]:
			body.add_vertex(point)
	var cases := SurfaceTool.new()
	cases.begin(Mesh.PRIMITIVE_TRIANGLES)
	_dome(cases, Vector3(0.0, 0.05, -0.2), Vector3(0.31, 0.27, 0.3), 8, 3, 1.0)
	return [body.commit(), cases.commit()]


# The wing cases and the shield over the thorax: two low domes.
static func _shell(tool: SurfaceTool, _whole: bool) -> void:
	_dome(tool, Vector3(0.0, 0.06, -0.19), Vector3(0.33, 0.27, 0.33), 8, 3, 1.0)
	_dome(tool, Vector3(0.0, 0.06, 0.2), Vector3(0.31, 0.2, 0.16), 8, 2, 0.4)


# Half of an egg, standing on its cut face.
static func _dome(tool: SurfaceTool, middle: Vector3, radii: Vector3, around: int, rings: int, shine: float) -> void:
	var rows: Array = []
	for ring in rings + 1:
		var high := PI * 0.5 * ring / rings
		var row: Array[Vector3] = []
		for k in around + 1:
			var turn := TAU * k / around
			row.append(Vector3(cos(turn) * cos(high), sin(high), sin(turn) * cos(high)))
		rows.append(row)
	tool.set_uv(Vector2.ZERO)
	tool.set_uv2(Vector2(shine, 0.0))
	for ring in rings:
		for k in around:
			var quad: Array[Vector3] = [rows[ring][k], rows[ring + 1][k + 1], rows[ring + 1][k], rows[ring][k], rows[ring][k + 1], rows[ring + 1][k + 1]]
			for unit in quad:
				tool.set_normal((unit / radii).normalized())
				tool.add_vertex(middle + unit * radii)


# The head shield: a flat plate, its front edge cut into six teeth.
static func _head(tool: SurfaceTool) -> void:
	var edge: Array[Vector3] = []
	for k in 13:
		var turn := lerpf(-PI * 0.5, PI * 0.5, k / 12.0)
		var far := 0.2 if k % 2 == 1 else 0.14
		edge.append(Vector3(sin(turn) * far * 1.15, 0.05, 0.31 + cos(turn) * far))
	tool.set_uv(Vector2.ZERO)
	tool.set_uv2(Vector2(0.7, 0.0))
	tool.set_normal(Vector3(0.0, 0.94, 0.34))
	for k in 12:
		tool.add_vertex(Vector3(0.0, 0.13, 0.3))
		tool.add_vertex(edge[k + 1])
		tool.add_vertex(edge[k])


# Six legs: out and up to a knee, then down to a foot. The fore legs reach
# forward and are broad (they dig); the hind legs are long and trail.
static func _legs(tool: SurfaceTool) -> void:
	for side: float in [-1.0, 1.0]:
		for pair in 3:
			var along: float = [0.2, 0.02, -0.16][pair]
			var hip := Vector3(side * 0.22, 0.08, along)
			var knee := Vector3(side * 0.37, 0.15, along + [0.1, -0.02, -0.12][pair])
			var foot := Vector3(side * [0.4, 0.47, 0.42][pair], 0.0, along + [0.24, -0.06, -0.34][pair])
			# (the legs of one side step in turn, and each with its opposite of the next pair)
			var step := 0.5 if (pair % 2 == 0) == (side > 0.0) else 0.0
			var thick: float = [0.06, 0.04, 0.045][pair]
			_limb(tool, hip, knee, thick, 0.0, 0.45, step)
			_limb(tool, knee, foot, thick * 0.8, 0.45, 1.0, step)


# One piece of a leg: two flat strips crossed, tapering.
static func _limb(tool: SurfaceTool, from: Vector3, to: Vector3, thick: float, low: float, high: float, step: float) -> void:
	var along := (to - from).normalized()
	var across := along.cross(Vector3.UP).normalized()
	var over := across.cross(along)
	for way: Vector3 in [across, over]:
		var normal := way.cross(along).normalized()
		if normal.y < 0.0:
			normal = -normal
		tool.set_normal(normal.lerp(Vector3.UP, 0.5).normalized())
		var corners := [[from - way * thick, low], [from + way * thick, low], [to + way * thick * 0.6, high], [from - way * thick, low], [to + way * thick * 0.6, high], [to - way * thick * 0.6, high]]
		for corner: Array in corners:
			tool.set_uv(Vector2(corner[1], step))
			tool.set_uv2(Vector2.ZERO)
			tool.add_vertex(corner[0])
