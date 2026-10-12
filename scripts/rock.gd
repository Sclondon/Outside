class_name Rock
## Living rock, drawn by a shader: cliffs, mesas and the lumps the wind leaves
## standing in the desert (`Cliff`, `RockFormation`, `RockField`,
## `KingsValley`, `DesertHorizon`). `Sandstone` is stone that has been cut and
## laid in courses; this is stone as it was found.
##
##     mesh.surface_set_material(0, Rock.material(Rock.CHALK, 3))
##
## What it draws, none of it a picture: all of it is worked out from where on
## the model a point is, so it stays put when the thing is moved or turned, and
## each part fades away before it is too small to draw, so that a cliff far off
## is plain rock in bands and does not shimmer.
## - Strata: beds lying level, each a little lighter or darker than the next,
##   a dark parting under each, and now and then a band of quite another tone.
##   They wander up and down a little along a face.
## - Weathering: streaks run down steep faces, and the rock is rubbed pale
##   where it sticks out.
## - Cracks: joints that run up and down a face, in stretches.
## - Sand: it lies on whatever is nearly level (a ledge, a top), and is drifted
##   against the foot; a mesh says where more of it lies through the colour of
##   its corners.
## - Scree: broken rock lying at the foot, stones of all tones with dark between.
##
## A mesh tells it more through the colour of each corner:
##     red     how light the rock is there (1: as it comes; less: darker)
##     green   how much sand lies over it (0 none, 1 all sand)
##     blue    1 for scree and rubble, 0 for whole rock
## A mesh with no colours is whole rock.
##
## It is lit as the rest of the world is (`Toon.surface`): in hard bands when
## the menu says so, smoothly otherwise.
##
## `Rock.Builder` is what the things made of it build their meshes with: from
## models (`RockModels`, made in Blender by `tools/build_rocks.py`) and, for a
## cliff, from numbers.

## The rock it comes in (a level keeps which, by its place in `STONES`).
const CHALK := Color(0.87, 0.83, 0.73)
const LIMESTONE := Color(0.8, 0.69, 0.51)
const SANDSTONE := Color(0.72, 0.51, 0.35)
const BASALT := Color(0.24, 0.22, 0.21)
const STONES: Array[Color] = [CHALK, LIMESTONE, SANDSTONE, BASALT]
const STONE_NAMES: Array[String] = ["Chalk", "Limestone", "Sandstone", "Dark basalt"]

const SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.8, 0.69, 0.51);
// The sand that lies on it.
uniform vec3 sand : source_color = vec3(0.83, 0.68, 0.45);
// 1: lit in two hard tones; 0: smoothly.
uniform float banded = 0.0;
uniform float wrap = 0.15;
// How thick a bed of it is, in metres; how weathered, 0..1; how cracked, 0..1.
uniform float bed = 0.8;
uniform float wear = 0.6;
uniform float cracks = 0.5;
// Any number: another gives other beds and other cracks.
uniform float seed = 0.0;
// How much sand lies on its ledges and tops, 0..1.
uniform float dusted = 0.6;
// How plainly its beds show, 0..1 (hard dark rock hardly shows them).
uniform float bedded = 1.0;
// Air between it and the eye, for what stands far off: its colour, and how thick.
uniform vec4 haze = vec4(0.8, 0.83, 0.82, 0.0);

varying vec3 place;
varying vec3 lie;
varying vec3 kind;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float patches(vec2 p) {
	vec2 whole = floor(p);
	vec2 part = fract(p);
	part = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash(whole), hash(whole + vec2(1.0, 0.0)), part.x),
			mix(hash(whole + vec2(0.0, 1.0)), hash(whole + vec2(1.0, 1.0)), part.x), part.y);
}

void vertex() {
	place = VERTEX;
	lie = NORMAL;
	kind = COLOR.rgb;
}

// How much of a thing `size` metres across can still be drawn, 0..1, where a
// pixel covers `pixel` metres: it is gone before it is small enough to flicker.
float seen(float size, float pixel) {
	return clamp(size * 0.4 / pixel - 0.2, 0.0, 1.0);
}

void fragment() {
	vec3 facing = normalize(lie);
	float pixel = max(length(fwidth(place)), 0.0001);
	float steep = 1.0 - smoothstep(0.35, 0.8, facing.y);
	// Across the face and up it.
	vec2 at = vec2(abs(facing.x) > abs(facing.z) ? place.z : place.x, place.y);
	float rubble = kind.b;

	// The beds: they lie level, and wander up and down a little along a face.
	float level = place.y / bed + (patches(place.xz * 0.06 + seed) - 0.5) * 1.8 + seed * 3.7;
	float row = floor(level);
	float within = fract(level);
	float beds = seen(bed, pixel) * (1.0 - rubble) * bedded;
	float tone = 1.0 + (hash(vec2(row, 1.3)) - 0.5) * 0.26 * beds;
	// (now and then one of quite another tone: a band of marl, or of flint)
	tone -= step(0.84, hash(vec2(row, 7.1))) * 0.13 * beds;
	tone += step(0.9, hash(vec2(row, 4.7))) * 0.08 * beds;
	// (and a dark parting under each, where the softer rock has weathered back)
	float thin = seen(0.1, pixel) * (1.0 - rubble) * steep * bedded;
	tone -= (1.0 - smoothstep(0.05, 0.05 + pixel / bed, within)) * (0.14 + 0.2 * hash(vec2(row, 2.9))) * thin;
	tone += smoothstep(0.86, 0.96, within) * 0.05 * thin;
	// Thin layers within a bed.
	tone += (patches(vec2(at.x * 0.09, place.y * 11.0 + seed)) - 0.5) * 0.09 * seen(0.12, pixel) * steep * (1.0 - rubble);
	// Streaks run down a steep face, the more the older it is.
	float runs = patches(vec2(at.x * 1.2, at.y * 0.16 + 3.0 + seed)) * patches(at * 0.23 + 11.0);
	tone -= smoothstep(0.28, 0.5, runs) * 0.15 * wear * steep * seen(0.8, pixel);
	// Broad patches lighter and darker, which is all there is to see far off.
	tone += (patches(place.xz * 0.045 + vec2(place.y * 0.11, seed)) - 0.5) * 0.12;

	// Cracks: joints running up and down a face, in stretches.
	float wander = patches(vec2(at.x * 0.42, at.y * 0.07) + 23.0 + seed) + 0.16 * patches(at * 1.1 + 7.0) + 0.04 * patches(at * 4.7);
	float stretch = smoothstep(0.4, 0.7, patches(at * vec2(0.3, 0.12) + 90.0));
	float from_crack = abs(wander - 0.6) / max(fwidth(wander), 0.00001);
	float thick = (0.006 + 0.03 * stretch) / pixel;
	float crack = (1.0 - smoothstep(max(thick - 0.5, 0.0), thick + 0.5, from_crack)) * clamp(thick * 2.0, 0.0, 1.0) * stretch * cracks * steep * (1.0 - rubble);

	// Scree: stones of all tones lying against each other, with dark between.
	if (rubble > 0.5) {
		vec2 among = (place.xz + place.y * 0.6) / 0.45;
		vec2 whole = floor(among);
		vec2 part = fract(among);
		float nearest = 8.0;
		float next = 8.0;
		float which = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cell = whole + vec2(float(i), float(j));
				vec2 to_stone = abs(vec2(float(i), float(j)) + vec2(hash(cell), hash(cell + 57.0)) - part);
				float off = max(to_stone.x, to_stone.y) * 0.75 + min(to_stone.x, to_stone.y) * 0.4;
				if (off < nearest) {
					next = nearest;
					nearest = off;
					which = hash(cell + 13.0);
				} else if (off < next) {
					next = off;
				}
			}
		}
		float stones = seen(0.45, pixel * 1.5);
		tone += ((which - 0.5) * 0.3 + (0.5 - nearest) * 0.12) * stones;
		float between = 0.02 + 0.07 * hash(whole + 3.0);
		tone -= (1.0 - smoothstep(between, between + pixel * 2.5, next - nearest)) * 0.16 * seen(0.2, pixel);
	}

	// Sand: on whatever is nearly level, in ragged patches, and wherever the mesh says.
	float ragged = (patches(place.xz * 0.9 + seed) - 0.5) * 0.5 + (patches(place.xz * 3.7) - 0.5) * 0.2 * seen(0.3, pixel);
	float lying = smoothstep(0.62, 0.9, facing.y + ragged * 0.4) * dusted;
	float sandy = clamp(max(lying * (0.25 + 0.75 * smoothstep(0.35, 0.65, patches(place.xz * 0.21 + 5.0 + seed) + ragged * 0.3)), smoothstep(0.3, 0.7, kind.g + ragged * step(0.02, kind.g))), 0.0, 1.0);
	vec3 colour = albedo * kind.r * tone * (1.0 - 0.6 * crack);
	colour = mix(colour, sand * (1.0 + (patches(place.xz * 5.0) - 0.5) * 0.08 * seen(0.2, pixel)), sandy * (1.0 - 0.45 * rubble));
	float veil = 1.0 - exp(-haze.a * length(VERTEX));
	ALBEDO = colour * (1.0 - veil);
	EMISSION = haze.rgb * veil;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float towards = dot(NORMAL, LIGHT);
	float hard = cut((towards + wrap) / (1.0 + wrap) * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float soft = clamp(towards, 0.0, 1.0) * reach;
	DIFFUSE_LIGHT += mix(soft, hard, banded) * LIGHT_COLOR / PI;
}
"""

static var _shader: Shader
static var _materials := {}
static var _drift: ShaderMaterial


## The sand that is banked against rock: sand as the ground is (`Sand.surface`), and a little
## paler, as the swept ground rock stands on is. One material, shared.
static func drift() -> ShaderMaterial:
	if _drift == null:
		_drift = Sand.surface(Sand.COLOUR.lerp(Sand.WHITE, 0.3) * 1.04)
		_drift.set_shader_parameter(&"variety", 0.0)
	return _drift


## A material for rock of a colour. `seed` is any number: another gives other
## beds and other cracks. `bed` is how thick its beds are, in metres. (The
## same three always give the same material, shared: do not change it.)
static func material(colour := LIMESTONE, seed := 0, bed := 0.8) -> ShaderMaterial:
	var key := "%s %d %s %s" % [colour.to_html(), seed, bed, Settings.world_banded]
	if _materials.has(key):
		return _materials[key]
	var made := _dressed(colour, seed, bed)
	_materials[key] = made
	return made


## A material for rock that stands far off, with air between it and the eye
## (`air` is the colour of that air, and its alpha how thick it is: about 0.001).
## Nothing lies on it, and it is not shared.
static func far_material(colour: Color, seed: int, air: Color) -> ShaderMaterial:
	var made := _dressed(colour, seed, 6.0)
	made.set_shader_parameter(&"haze", air)
	made.set_shader_parameter(&"dusted", 0.0)
	return made


## The colour of a stone, by its place in `STONES`.
static func stone(which: int) -> Color:
	return STONES[clampi(which, 0, STONES.size() - 1)]


static func _dressed(colour: Color, seed: int, bed: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var made := ShaderMaterial.new()
	made.shader = _shader
	made.set_shader_parameter(&"albedo", colour)
	made.set_shader_parameter(&"sand", Sand.COLOUR)
	made.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
	made.set_shader_parameter(&"bed", bed)
	made.set_shader_parameter(&"seed", float(seed % 97) * 0.37)
	# (dark rock is hard: it shows less of its beds and more of its cracks)
	made.set_shader_parameter(&"wear", 0.6 if colour.v > 0.4 else 0.25)
	made.set_shader_parameter(&"cracks", 0.6 if colour.v > 0.4 else 0.9)
	made.set_shader_parameter(&"bedded", 1.0 if colour.v > 0.4 else 0.25)
	return made


## A number from 0 to 1 made from two whole numbers: the same every time.
static func chance(a: int, b: int) -> float:
	var n := (a * 374761393 + b * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


## Smooth unevenness, 0..1, over a plane: the same every time.
static func rough(x: float, z: float) -> float:
	var whole_x := floori(x)
	var whole_z := floori(z)
	var part_x := x - whole_x
	var part_z := z - whole_z
	part_x = part_x * part_x * (3.0 - 2.0 * part_x)
	part_z = part_z * part_z * (3.0 - 2.0 * part_z)
	return lerpf(lerpf(chance(whole_x, whole_z), chance(whole_x + 1, whole_z), part_x),
			lerpf(chance(whole_x, whole_z + 1), chance(whole_x + 1, whole_z + 1), part_x), part_z)


## Gathers the triangles of a mesh of rock, and of the sand that lies against
## it, and makes the mesh: one surface of rock and, if there is any, one of
## sand (and one for each other material a model put into it has). Models
## (`RockModels`) are put in with `add`, each where `place` says; what is made
## from numbers (a cliff) with `tri`, `quad` and `block`.
class Builder:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var sand_points := PackedVector3Array()
	var sand_normals := PackedVector3Array()
	## What else has been put in, by the name of its material: each [points, normals, colours].
	var others := {}
	## Moves everything added from now on.
	var place := Transform3D.IDENTITY

	## How many triangles so far.
	func triangles() -> int:
		var corners := points.size() + sand_points.size()
		for other: Array in others.values():
			corners += (other[0] as PackedVector3Array).size()
		@warning_ignore("integer_division")
		return corners / 3

	## Puts a model in, where `place` is: its `rock` into the rock (made lighter
	## or darker by `tone`), its `sand` into the sand, and anything else into
	## `others`. Says what is solid of it, as sets of points where they now are.
	func add(model: String, tone := 1.0) -> Array:
		var mesh := RockModels.mesh(model)
		if mesh == null:
			return []
		# (a thing made wider than it is high leans its faces: they are turned to match)
		var turn := place.basis.inverse().transposed()
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var from: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var faces: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var tints: Variant = arrays[Mesh.ARRAY_COLOR]
			var order: Variant = arrays[Mesh.ARRAY_INDEX]
			var material := mesh.surface_get_material(surface)
			var named := material.resource_name if material else "rock"
			var moved := PackedVector3Array()
			moved.resize(from.size())
			var turned := PackedVector3Array()
			turned.resize(from.size())
			for i in from.size():
				moved[i] = place * from[i]
				turned[i] = (turn * faces[i]).normalized()
			var count: int = (order as PackedInt32Array).size() if order != null else from.size()
			var into_points := points
			var into_normals := normals
			var into_colours := colours
			if named == "sand":
				into_points = sand_points
				into_normals = sand_normals
				into_colours = PackedColorArray()
			elif named != "rock":
				if not others.has(named):
					others[named] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
				into_points = others[named][0]
				into_normals = others[named][1]
				into_colours = others[named][2]
			for corner in count:
				var i: int = (order as PackedInt32Array)[corner] if order != null else corner
				into_points.append(moved[i])
				into_normals.append(turned[i])
				if named != "sand":
					var tint: Color = (tints as PackedColorArray)[i] if tints != null else Color.WHITE
					tint.r *= tone
					into_colours.append(tint)
			# (packed arrays are handed about by value: put back what was added to)
			if named == "sand":
				sand_points = into_points
				sand_normals = into_normals
			elif named == "rock":
				points = into_points
				normals = into_normals
				colours = into_colours
			else:
				others[named] = [into_points, into_normals, into_colours]
		var solid: Array = []
		for hull: PackedVector3Array in RockModels.hulls(model):
			var here := PackedVector3Array()
			for point in hull:
				here.append(place * point)
			solid.append(here)
		return solid

	## A flat triangle, facing more or less `out`.
	func tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
		a = place * a
		b = place * b
		c = place * c
		var normal := (b - a).cross(c - a)
		if normal.dot(place.basis * out) < 0.0:
			var swap := b
			b = c
			c = swap
			normal = -normal
		normal = normal.normalized()
		points.append(a)
		points.append(c)
		points.append(b)
		for i in 3:
			normals.append(normal)
			colours.append(tint)

	## A flat four-sided face (its corners in order round it), facing more or less `out`.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, tint: Color) -> void:
		tri(a, b, c, out, tint)
		tri(a, c, d, out, tint)

	## A block: a box put where `where` says and `size` across, each corner
	## moved by up to `wobble` of its size, so that no two are alike. `key` is
	## any number. Says where its corners now are.
	func block(where: Transform3D, size: Vector3, tint: Color, wobble := 0.0, key := 0) -> PackedVector3Array:
		var corners := PackedVector3Array()
		for i in 8:
			var corner := Vector3(-0.5 if i & 1 == 0 else 0.5, -0.5 if i & 2 == 0 else 0.5, -0.5 if i & 4 == 0 else 0.5)
			if wobble > 0.0:
				corner += Vector3(Rock.chance(key, i * 3) - 0.5, Rock.chance(key, i * 3 + 1) - 0.5, Rock.chance(key, i * 3 + 2) - 0.5) * wobble
			corners.append(where * (corner * size))
		var middle := where.origin
		for face: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
			var out := (corners[face[0]] + corners[face[2]]) * 0.5 - middle
			quad(corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]], out, tint)
		var moved := PackedVector3Array()
		for corner in corners:
			moved.append(place * corner)
		return moved

	## Sand: a flat triangle of it, facing more or less `out`.
	func sand_tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
		a = place * a
		b = place * b
		c = place * c
		var normal := (b - a).cross(c - a)
		if normal.dot(place.basis * out) < 0.0:
			var swap := b
			b = c
			c = swap
			normal = -normal
		normal = normal.normalized()
		sand_points.append(a)
		sand_points.append(c)
		sand_points.append(b)
		for i in 3:
			sand_normals.append(normal)

	func sand_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
		sand_tri(a, b, c, out)
		sand_tri(a, c, d, out)

	## The mesh: its rock wearing `stone`, its sand `Rock.drift()` (if no other
	## is given), and whatever else is in it the material of that
	## name in `more` (or `stone`, if there is none).
	func mesh(stone: Material, sand: Material = null, more := {}) -> ArrayMesh:
		var made := ArrayMesh.new()
		if not points.is_empty():
			_surface(made, points, normals, colours, stone)
		if not sand_points.is_empty():
			_surface(made, sand_points, sand_normals, PackedColorArray(), sand if sand else Rock.drift())
		for named: String in others:
			_surface(made, others[named][0], others[named][1], others[named][2], more.get(named, stone))
		return made

	func _surface(made: ArrayMesh, at: PackedVector3Array, facing: PackedVector3Array, tints: PackedColorArray, material: Material) -> void:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = at
		arrays[Mesh.ARRAY_NORMAL] = facing
		if not tints.is_empty():
			arrays[Mesh.ARRAY_COLOR] = tints
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		made.surface_set_material(made.get_surface_count() - 1, material)
