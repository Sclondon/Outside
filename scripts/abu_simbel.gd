class_name AbuSimbel
extends StaticBody3D
## The temples of Abu Simbel, cut into a sandstone cliff above the Nile in
## Nubia by Ramesses II, as they stood in the 1910s: by the river where they
## were cut, with the sand of the desert above still pouring down the gully
## between them. `AbuSimbel.new()` is the whole place, at its true size.
##
## Its stone is models, made in Blender by `tools/build_abu_simbel.py` (which
## says which object is which) and kept in `models/abu_simbel/abu_simbel.glb`.
## This script sets them out, makes what is solid, the sand, the writing, the
## light inside and the sun down the axis.
##
## This node is on the ground before the door of the Great Temple, which looks
## along +Z (to the river, and the sunrise). North is +X: the Small Temple is
## 100 m that way, turned a little towards the great one.
##
## The Great Temple: a hill of rock with the facade cut back into it, 35 m wide
## and 30 high, leaning like a pylon; four seated colossi of the king, 20 m
## high, the second from the left broken off at the waist with its head and
## body lying before it; the queen, the king's mother and children at their
## legs; baboons along the top, the cornice and its roll; Ra-Horakhty in his
## niche over the door; and a terrace in front with a balustrade and statues.
## Inside, on one line 60 m into the hill: the great hall with eight pillars of
## the king as Osiris, a second hall of four pillars, a vestibule, and the
## sanctuary, where Ptah, Amun-Ra, the king and Ra-Horakhty sit against the
## far wall. Four long store-rooms open off the first hall.
##
## The Small Temple, of Hathor and Nefertari: six standing colossi 10 m high
## between leaning buttresses (the king four times and the queen twice, as tall
## as he is), a hall of six pillars with the head of Hathor, a vestibule, and a
## sanctuary where the cow of Hathor comes out of the rock.
##
## `drift` is the sand: at 0 a heap up in the gully, at 1 a fan across the
## north of the great facade that buries the northern colossi to the chest and
## all but shuts the door, so that he must crawl in over it under the lintel, as
## Belzoni did in 1817. It can be walked up. A ramp of blown sand up the back
## of the hill is the way to its top.
##
## `sun_on_axis` is the morning (two a year) when the rising sun shines down
## the whole length of the Great Temple onto three of the four gods; Ptah, a
## god of the dark, is left in shadow. The light is a `SunBeam`: it is stopped
## by whatever stands in its way (sand in the door, a door a level's maker
## hangs there, the boy), and while it reaches the sanctuary the temple is `on`
## and says so (`changed`), as a `SunDisc` does: so it works whatever a
## pressure plate works.
##
## For a level's maker there are `Marker3D`s, each in a group: `abu_simbel_door`
## (GreatDoor, SmallDoor), `abu_simbel_hall`, `abu_simbel_sanctuary`,
## `abu_simbel_top` (the top of each hill); and `GrapplePoint`s at the knees
## and the shoulders of the colossi.
##
## What it costs is in `triangles`, `draw_calls`, `shapes` and `build_ms`. The
## colossi are one mesh drawn three times and a broken one; pillars, baboons
## and the small temple's figures are drawn as many of one; and what is inside
## is only drawn while the camera is near enough to see it. What is solid is
## boxes and a few hulls, with the skin of the hill and the sand as triangles.

signal changed(on: bool)

enum Which { BOTH, GREAT, SMALL }

const MODELS := "res://models/abu_simbel/abu_simbel.glb"
## The stone of the place: Nubian sandstone.
const STONE := Color(0.74, 0.56, 0.4)
## Where the Small Temple stands from the Great (at true size), and how far it is turned.
const NORTH := Vector3(100.0, 0.0, 6.0)
const NORTH_TURN := -14.0
const NAMES := "{sw*t-bit:t nb-tA:tA|The King of Upper and Lower Egypt, Lord of the Two Lands,} <Ramesses> {di-anx mi-ra D:t:tA|given life like Ra for ever.}"
const BELOVED := "<Ramesses> beloved of Amun {di-anx|given life}"
const QUEEN := "<Ramesses> made this house in the mountain for the great wife (Nefertari) {mr-i*i|beloved} of Hathor"
## The seated colossus, in metres at true size (as `tools/build_abu_simbel.py` makes it): half the width of its
## pedestal, the pedestal's height and how far forward it comes; the throne; the top of the lap and how far
## forward the knees come; the feet; the waist, the shoulders and the chest; the head and the top of the crown.
const SEATED := {
	"base_half": 3.5, "base_top": 1.5, "base_front": 8.0, "throne_half": 3.1, "seat": 6.4,
	"lap": 8.1, "knee_front": 6.2, "foot_top": 2.4, "foot_front": 7.7, "foot_half": 2.1,
	"waist": 9.3, "shoulder": 13.0, "shoulder_half": 3.45, "chest_front": 3.0, "head_top": 17.4, "head_front": 3.5, "crown": 20.2,
}

const INSIDE := """
shader_type spatial;
render_mode ambient_light_disabled;

uniform mat4 to_temple;
uniform vec3 albedo : source_color = vec3(0.74, 0.56, 0.4);
// The middle of the foot of the door, how wide and high the opening is, how much of it is clear of sand, and how far in the temple goes.
uniform vec3 door;
uniform vec2 opening = vec2(1.3, 6.4);
uniform float clear = 1.0;
uniform float reach = 60.0;
// The sun down the axis: 1 while it reaches the sanctuary. `shaft` is what it falls on: from x, to x, from y, to y.
uniform float sun = 0.0;
uniform vec4 shaft;
uniform float far_end = -60.0;
uniform float banded = 0.0;
uniform float painted = 1.0;
uniform sampler2D relief : filter_linear_mipmap, repeat_enable;
uniform vec3 relief_size = vec3(16.0, 8.0, 1.0);
//CARVING

varying vec3 at;
varying vec3 lie;
varying vec3 kind;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void vertex() {
	mat4 whole = to_temple * MODEL_MATRIX;
	at = (whole * vec4(VERTEX, 1.0)).xyz;
	lie = normalize(mat3(whole) * NORMAL);
	kind = COLOR.rgb;
}

// How much daylight comes this far in from the door, and how much of the sun on its two mornings.
vec3 daylight(vec3 p, vec3 n) {
	float deep = max(door.z - p.z, 0.0);
	vec3 to_door = vec3(door.x, door.y + opening.y * 0.6, door.z) - p;
	float facing = clamp(dot(n, normalize(to_door)), 0.0, 1.0);
	float spread = opening.x + deep * 0.8;
	float in_cone = 1.0 - smoothstep(spread * 0.5, spread * 1.7, abs(p.x - door.x));
	float direct = in_cone * (0.15 + 0.85 * facing) * 1.1 / (1.0 + pow(deep / (reach * 0.16), 2.0));
	float bounce = 0.3 * exp(-deep / (reach * 0.16));
	float day = (direct + bounce) * clear + 0.045;
	float in_shaft = step(shaft.x, p.x) * step(p.x, shaft.y) * step(shaft.z, p.y) * step(p.y, shaft.w) * step(0.25, n.z);
	float glow = exp(-abs(p.z - far_end) / (reach * 0.08)) * 0.3;
	return vec3(day) + sun * (in_shaft * 1.25 + glow) * vec3(1.0, 0.82, 0.5);
}

void fragment() {
	vec3 n = normalize(lie);
	vec3 colour = albedo * kind.r;
//SURFACE
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = colour * daylight(at, n);
}

void light() {
	// (the sun and the sky do not come in through the rock: only what is carried in lights it)
	if (!LIGHT_IS_DIRECTIONAL) {
		float reached = clamp(ATTENUATION, 0.0, 1.0);
		float towards = dot(NORMAL, LIGHT);
		float edge = max(fwidth(towards), 0.0005);
		float hard = smoothstep(0.04 - edge, 0.04 + edge, (towards + 0.15) / 1.15) * reached;
		DIFFUSE_LIGHT += mix(clamp(towards, 0.0, 1.0) * reached, hard, banded) * LIGHT_COLOR / PI;
	}
}
"""

# What the walls are: stone with beds in it, the battle carved along the long walls (green 1), stars on the ceiling (blue a half).
const WALLS := """
	vec2 on_wall = vec2(abs(n.x) > abs(n.z) ? at.z : at.x, at.y - door.y);
	float beds = hash(vec2(floor(on_wall.y * 3.0), 7.0));
	colour *= 0.95 + 0.08 * beds;
	if (kind.g > 0.5 && on_wall.y > relief_size.z && on_wall.y < relief_size.z + relief_size.y) {
		vec2 uv = vec2(on_wall.x / relief_size.x, 1.0 - (on_wall.y - relief_size.z) / relief_size.y);
		vec2 px = vec2(1.5 / 512.0, 1.5 / 256.0);
		vec4 here = texture(relief, uv);
		float slope = (texture(relief, uv + vec2(px.x, 0.0)).r - texture(relief, uv - vec2(px.x, 0.0)).r) * 0.6
				+ (texture(relief, uv - vec2(0.0, px.y)).r - texture(relief, uv + vec2(0.0, px.y)).r);
		vec3 paint = here.g < 0.33 ? vec3(0.62, 0.25, 0.14) : (here.g < 0.66 ? vec3(0.83, 0.66, 0.25) : vec3(0.2, 0.38, 0.5));
		colour = mix(colour, mix(colour * 0.72, paint, painted * 0.85), here.r);
		colour *= 1.0 + clamp(slope, -1.0, 1.0) * 0.55;
	}
	if (kind.b < 0.75 && painted > 0.5) {
		// The ceiling: a night sky, dark blue with rows of yellow stars.
		vec2 sky = at.xz * 1.6;
		vec2 star = fract(sky) - 0.5;
		float lit = step(abs(star.x) + abs(star.y), 0.16) * step(0.3, hash(floor(sky)));
		colour = mix(vec3(0.1, 0.17, 0.3), vec3(0.85, 0.68, 0.25), lit) * kind.r;
	}
"""

# Writing cut in a wall inside: the picture an `Inscription` made, lit as the walls are.
const CARVING_UNIFORMS := """
uniform sampler2D carving : filter_linear_mipmap;
"""
const CARVING := """
	float inside = texture(carving, UV).a;
	float soft = max(fwidth(inside) * 0.7, 0.02);
	float in_sign = smoothstep(0.5 - soft, 0.5 + soft, inside);
	colour = mix(colour * 0.55, mix(texture(carving, UV).rgb, vec3(0.8, 0.62, 0.3), 0.3), painted * 0.8);
	ALPHA = in_sign;
"""

## How big: 1 is the true size.
@export_range(0.5, 1.0) var size := 1.0
## Which of the temples.
@export var which := Which.BOTH
## The sand between the temples and over the north of the great facade, 0..1.
@export_range(0.0, 1.0) var drift := 0.35
## How weathered, 0..1.
@export_range(0.0, 1.0) var wear := 0.4
## Whether the carving inside still has its colours.
@export var painted := true
## The morning when the sun shines down the axis of the Great Temple.
@export var sun_on_axis := false
## The colour of the rock.
@export var colour := STONE

## Whether the sun is reaching the sanctuary now.
var on := false
## What it costs: triangles drawn at most, draw calls at most, shapes to collide with, and how long it took to make (ms).
var triangles := 0
## How many of those are inside the temples, and so not drawn from far off.
var inside_triangles := 0
var draw_calls := 0
var shapes := 0
var build_ms := 0.0
## How high the hill of the Great Temple (or of the Small, if that is all there is) stands.
var height := 0.0
## The light down the axis, if `sun_on_axis`.
var beam: SunBeam

var _s := 1.0
var _xf := Transform3D.IDENTITY
var _sand: SurfaceTool
var _sand_count := 0
var _hill := PackedVector3Array()
var _sand_faces := PackedVector3Array()
# What is solid, for `is_in_stone`: boxes as [the way into the box's own space, its half size], the rooms, and the skin of the hills sorted by where it is.
var _solids: Array = []
var _rooms: Array = []
var _sorted := {}
# What is inside each temple: [nodes, where its middle is, how far off it is still drawn].
var _insides: Array = []
var _materials: Array = []
var _rock: Material
var _far_end := 0.0
var _door_sand := 0.0

static var _relief: ImageTexture
static var _shaders := {}
static var _meshes := {}


## The temples as an item of a level's layout says (see `LevelLayout.FIELDS`).
static func from_item(item: Dictionary) -> AbuSimbel:
	var made := AbuSimbel.new()
	made.size = item.get("scale", 1.0)
	made.which = clampi(int(item.get("which", 0)), 0, 2) as Which
	made.drift = item.get("drift", 0.35)
	made.wear = item.get("wear", 0.4)
	made.painted = item.get("painted", true)
	made.sun_on_axis = item.get("sun", false)
	return made


## A part of the model, by the name of its object in the .blend.
static func part(called: String) -> Mesh:
	if _meshes.is_empty():
		var scene := (load(MODELS) as PackedScene).instantiate()
		for found in scene.find_children("*", "MeshInstance3D", true, false):
			_meshes[String(found.name)] = (found as MeshInstance3D).mesh
		scene.free()
	return _meshes.get(called)


func _ready() -> void:
	set_meta(&"surface", "stone")
	set_notify_transform(true)
	build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_tell_materials()


## The rock everything outside is made of. (One place, so that another rock can be put in its stead.)
func rock() -> Material:
	return Sandstone.surface(colour, 2.8, 5.0, 0.25 + 0.6 * wear, 0.2 + 0.6 * wear)


## Makes it (again) from its numbers.
func build() -> void:
	var began := Time.get_ticks_usec()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_s = clampf(size, 0.2, 2.0)
	_sand = SurfaceTool.new()
	_sand.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sand_count = 0
	_hill.clear()
	_sand_faces.clear()
	_solids.clear()
	_rooms.clear()
	_sorted.clear()
	_insides.clear()
	_materials.clear()
	_rock = rock()
	beam = null
	on = false
	triangles = 0
	inside_triangles = 0
	draw_calls = 0
	shapes = 0
	var north := Transform3D(Basis(Vector3.UP, deg_to_rad(NORTH_TURN)), NORTH * _s)
	if which != Which.SMALL:
		_xf = Transform3D.IDENTITY
		_build_great()
	if which != Which.GREAT:
		_xf = north if which == Which.BOTH else Transform3D.IDENTITY
		_build_small()
	_xf = Transform3D.IDENTITY
	if which == Which.BOTH:
		# The ridge behind the gully, that joins the two hills.
		_hill_part("ridge")
	if which != Which.SMALL:
		_build_drift()
	if not _hill.is_empty():
		var skin := ConcavePolygonShape3D.new()
		skin.backface_collision = true
		skin.set_faces(_hill)
		_solid(skin, Transform3D.IDENTITY)
	if _sand_count > 0:
		_sand.index()
		_sand.generate_normals()
		var heap_mesh := _sand.commit()
		var shown := MeshInstance3D.new()
		shown.name = "Sand"
		shown.mesh = heap_mesh
		shown.material_override = Sand.surface()
		add_child(shown)
		triangles += _sand_count
		draw_calls += 1
		var ground := StaticBody3D.new()
		ground.name = "SandBody"
		ground.set_meta(&"surface", "sand")
		var heap := ConcavePolygonShape3D.new()
		heap.backface_collision = true
		heap.set_faces(_sand_faces)
		var collider := CollisionShape3D.new()
		collider.shape = heap
		ground.add_child(collider)
		add_child(ground)
		shapes += 1
	_tell_materials()
	_sand = null
	build_ms = (Time.get_ticks_usec() - began) / 1000.0


## Whether a place (in the world) is inside solid stone: in one of the boxes
## that are the statues, walls and pillars, or under the skin of a hill and
## not in a room. For checking that nothing leaves him there.
func is_in_stone(place: Vector3) -> bool:
	var here := to_local(place)
	for solid: Array in _solids:
		var within: Vector3 = (solid[0] as Transform3D) * here
		var half: Vector3 = solid[1]
		if absf(within.x) < half.x - 0.12 and absf(within.y) < half.y - 0.12 and absf(within.z) < half.z - 0.12:
			return true
	for room: Array in _rooms:
		if (room[1] as AABB).has_point((room[0] as Transform3D) * here):
			return false
	# Under the skin of a hill: a line straight up from here goes out through it an odd number of times.
	if _sorted.is_empty():
		for i in range(0, _hill.size(), 3):
			var low := Vector2(minf(_hill[i].x, minf(_hill[i + 1].x, _hill[i + 2].x)), minf(_hill[i].z, minf(_hill[i + 1].z, _hill[i + 2].z)))
			var high := Vector2(maxf(_hill[i].x, maxf(_hill[i + 1].x, _hill[i + 2].x)), maxf(_hill[i].z, maxf(_hill[i + 1].z, _hill[i + 2].z)))
			for cx in range(int(floor(low.x / 6.0)), int(floor(high.x / 6.0)) + 1):
				for cz in range(int(floor(low.y / 6.0)), int(floor(high.y / 6.0)) + 1):
					var key := Vector2i(cx, cz)
					if not _sorted.has(key):
						_sorted[key] = PackedInt32Array()
					(_sorted[key] as PackedInt32Array).append(i)
	var crossed := 0
	var seen := {}
	for i: int in _sorted.get(Vector2i(int(floor(here.x / 6.0)), int(floor(here.z / 6.0))), PackedInt32Array()):
		var hit: Variant = Geometry3D.ray_intersects_triangle(here, Vector3(0.0003, 1.0, 0.0002), _hill[i], _hill[i + 1], _hill[i + 2])
		if hit != null:
			# (two faces that meet at an edge the line passes through are one crossing)
			var level := roundi((hit as Vector3).y * 50.0)
			if not seen.has(level):
				seen[level] = true
				crossed += 1
	return crossed % 2 == 1 and here.y > 0.0


func _physics_process(_delta: float) -> void:
	var reaches := false
	if beam and beam.path.size() >= 2:
		reaches = to_local(beam.path[beam.path.size() - 1]).z < _far_end
	if reaches != on:
		on = reaches
		for material: ShaderMaterial in _materials:
			material.set_shader_parameter(&"sun", 1.0 if on else 0.0)
		changed.emit(on)


func _process(_delta: float) -> void:
	# What is inside is drawn only from near by.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := to_local(camera.global_position)
	for inside: Array in _insides:
		var seen: bool = eye.distance_to(inside[1]) < float(inside[2])
		for node: Node3D in inside[0]:
			node.visible = seen


func _tell_materials() -> void:
	if not is_inside_tree():
		return
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"to_temple", (global_transform * (material.get_meta(&"temple") as Transform3D)).affine_inverse())


# --- The Great Temple ---------------------------------------------------------
# (the numbers are those of `tools/build_abu_simbel.py`, which makes the stone: change them in both)

func _build_great() -> void:
	var s := _s
	var k := SEATED
	var th := 1.2 * s
	var lean := 0.07
	var top := th + 32.8 * s
	var hw := 17.5 * s
	var narrows := 2.0 / 30.0
	var dw := 1.3 * s
	var dh := 6.4 * s
	var thick := 3.5 * s
	var out := 19.0 * s
	var whole := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO)
	height = 46.0 * s
	_hill_part("great_hill")
	_ramp(Vector2(0.0, -37.5 * s), Vector2(-0.62, -0.78), 9.0 * s, height)
	_show("great_facade", whole, _rock, "GreatFacade")

	# What is solid of the front: the terrace, its steps and balustrade, and the wall either side of the door and over it.
	var tw := hw + 3.0 * s
	_box(Vector3(-tw, -1.0, -thick), Vector3(tw, th, out))
	var stair := 2.6 * s
	var steps := ceili(1.2 / 0.2)
	for i in steps:
		_box(Vector3(-stair, -1.0, out + i * 0.36 * s), Vector3(stair, th - (i + 1) * th / steps, out + (i + 1) * 0.36 * s))
	var rail := 1.1 * s
	var falcons: Array[Transform3D] = []
	var kings: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		var from := stair + 0.4 * s
		_box(Vector3(minf(side * from, side * tw), th, out - 0.9 * s), Vector3(maxf(side * from, side * tw), th + rail, out))
		# (falcons and small figures of the king stand along it)
		for i in 5:
			var x := side * lerpf(from + 1.0 * s, tw - 1.0 * s, i / 4.0)
			var stood := _xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.9 * s), Vector3(x, th + rail, out - 0.45 * s))
			if i % 2 == 0:
				falcons.append(stood)
			else:
				kings.append(stood)
			_box(Vector3(x - 0.4 * s, th + rail, out - 0.8 * s), Vector3(x + 0.4 * s, th + rail + 1.8 * s, out - 0.1 * s))
	_many("falcon", falcons, _rock, "Falcons")
	_many("small_figure", kings, _rock, "TerraceKings")
	var face := func(x: float, y: float, z := 0.0) -> Vector3: return Vector3(x, th + y, z - y * lean)
	var edge := func(y: float) -> float: return hw - y * narrows
	for side: float in [-1.0, 1.0]:
		_hull([face.call(side * dw, 0.0), face.call(side * hw, 0.0), face.call(side * edge.call(32.8 * s), 32.8 * s), face.call(side * dw, 32.8 * s),
			Vector3(side * dw, th, -thick), Vector3(side * hw, th, -thick), Vector3(side * hw, top, -thick - 2.0 * s), Vector3(side * dw, top, -thick - 2.0 * s)])
		_note_box(Vector3(minf(side * dw, side * edge.call(32.8 * s)), th, -thick), Vector3(maxf(side * dw, side * edge.call(32.8 * s)), top, -32.8 * s * lean))
	_hull([face.call(-dw, dh), face.call(dw, dh), face.call(dw, 32.8 * s), face.call(-dw, 32.8 * s),
		Vector3(-dw, th + dh, -thick), Vector3(dw, th + dh, -thick), Vector3(dw, top, -thick - 2.0 * s), Vector3(-dw, top, -thick - 2.0 * s)])
	_note_box(Vector3(-dw, th + dh, -thick), Vector3(dw, top, -32.8 * s * lean))
	_box(Vector3(-edge.call(30.0 * s), th + 28.6 * s, -2.2 * s), Vector3(edge.call(30.0 * s), th + 30.0 * s, -1.1 * s))

	# Ra-Horakhty in his niche over the door, and the baboons along the top (time has had a few of them).
	_show("ra_horakhty", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 6.2 * s), face.call(0.0, 7.8 * s, -0.6 * s)), _rock, "RaHorakhty")
	var apes: Array[Transform3D] = []
	var random := RandomNumberGenerator.new()
	random.seed = 71
	for i in 22:
		if wear > 0.2 and random.randf() < (wear - 0.2) * 0.45:
			continue
		var x: float = lerpf(-1.0, 1.0, (i + 0.5) / 22.0) * (edge.call(30.0 * s) - 0.2 * s)
		apes.append(_xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.5 * s), face.call(x, 30.0 * s, 0.05 * s)))
	_many("baboon", apes, _rock, "Baboons")

	# The four colossi, and between each pair a princess on a block of her own.
	var inner := dw + 0.3 * s + float(k["base_half"]) * s
	var outer := inner + 8.3 * s
	var seated: Array[Transform3D] = []
	for cx: float in [-outer, -inner, inner, outer]:
		var stood := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(cx, th, 0.0))
		var broken := is_equal_approx(cx, -inner)
		if broken:
			_show("colossus_broken", stood, _rock, "BrokenColossus")
		else:
			seated.append(_xf * stood)
		_colossus_solid(cx, th, broken)
	_many("colossus", seated, _rock, "Colossi")
	var princesses: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		var mid := side * (inner + outer) * 0.5
		var gap := (outer - inner) * 0.5 - float(k["throne_half"]) * s
		_box(Vector3(mid - 0.75 * s, th, 0.0), Vector3(mid + 0.75 * s, th + float(k["base_top"]) * s, 6.0 * s))
		_box(Vector3(mid - gap - 0.05 * s, th, -2.0 * s), Vector3(mid + gap + 0.05 * s, th + float(k["seat"]) * s, 3.4 * s))
		princesses.append(_xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 4.6 * s), Vector3(mid, th + float(k["base_top"]) * s, 4.2 * s)))
		_box(Vector3(mid - gap - 0.05 * s, th, 3.4 * s), Vector3(mid + gap + 0.05 * s, th + 5.6 * s, 5.0 * s))
	_many("small_figure", princesses, _rock, "Princesses")
	# What fell from the broken one: his body and head on their back before his feet, and the crown beside them.
	var lies := Transform3D(Basis(Vector3(-0.66, 0.0, -0.75), Vector3(-0.75, 0.0, 0.66), Vector3(0.0, 1.0, 0.0)).orthonormalized().scaled(Vector3.ONE * s),
		Vector3(-inner + 9.0 * s, th - 0.2 * s, 2.8 * s))
	_show("colossus_fallen", lies, _rock, "FallenColossus")
	_box_turned(lies, Vector3(-3.3, 9.4, -2.6), Vector3(3.3, 13.0, 2.6))
	_box_turned(lies, Vector3(-2.3, 13.0, -2.6), Vector3(2.3, 17.3, 3.4))
	var cap := Transform3D(Basis.from_euler(Vector3(1.35, 0.6, 0.2)).scaled(Vector3.ONE * s), Vector3(-inner - 11.5 * s, th + 1.0 * s, 15.0 * s))
	_show("crown_fallen", cap * Transform3D(Basis.IDENTITY, Vector3(0.0, -3.4, 0.3)), _rock, "FallenCrown")
	_box_turned(cap, Vector3(-1.7, -1.6, -1.6), Vector3(1.7, 1.5, 1.6))
	for i in 3:
		var low := Vector3(-inner + (-9.6 + i * 1.5) * s, th, (8.6 + i * 1.5) * s)
		_box(low, low + Vector3(1.9, 0.9 + 0.45 * i, 1.7) * s)

	# Writing on the facade: the king's names along the top, down the door and beside the niche.
	var tilt := Basis(Vector3.RIGHT, -atan(lean))
	_write(NAMES, Vector2(edge.call(26.0 * s) * 2.0 - 3.0 * s, 1.5 * s), Transform3D(tilt, face.call(0.0, 26.0 * s, 0.03)), {"fill": true, "draw_distance": 260.0})
	for side: float in [-1.0, 1.0]:
		_write(NAMES, Vector2(0.85 * s, dh - 0.4 * s), Transform3D(tilt, face.call(side * 1.8 * s, dh * 0.5, 0.03)), {"columns": true, "right_to_left": side < 0.0, "draw_distance": 90.0})
		_write(BELOVED, Vector2(1.6 * s, 6.6 * s), Transform3D(tilt, face.call(side * 3.9 * s, 11.4 * s, 0.03)), {"columns": true, "right_to_left": side < 0.0, "draw_distance": 160.0})

	# --- Inside, on one line into the hill.
	var nodes: Array = []
	var outside := triangles
	var m := _inside_material(Vector3(0.0, th, 0.0), Vector2(dw, dh), 63.0 * s)
	nodes.append(_show("great_inside", whole, m, "GreatInside"))
	var z := -thick
	var high1 := 10.5 * s
	var half1 := 8.2 * s
	var deep := 18.0 * s
	var d2 := 1.1 * s
	var h2 := 5.0 * s
	var wall := 1.6 * s
	_passage(Vector3(-dw, th, -thick), Vector3(dw, th + dh, 0.0), false)
	# The store-rooms off the great hall, two a side.
	var side_doors: Array = []
	for i in 2:
		var mid := z - (5.2 + 8.0 * i) * s
		for side in 2:
			var sign := -1.0 if side == 0 else 1.0
			side_doors.append([side, mid - 0.9 * s, mid + 0.9 * s, 3.4 * s])
			var a := sign * half1
			var b := sign * (half1 + wall)
			var c := sign * (half1 + wall + 12.0 * s)
			_passage(Vector3(minf(a, b), th, mid - 0.9 * s), Vector3(maxf(a, b), th + 3.4 * s, mid + 0.9 * s), true)
			_room(Vector3(minf(b, c), th, mid - 1.7 * s), Vector3(maxf(b, c), th + 4.0 * s, mid + 1.7 * s), [[1 - side, mid - 0.9 * s, mid + 0.9 * s, 3.4 * s]])
	_room(Vector3(-half1, th, z - deep), Vector3(half1, th + high1, z), [[3, -dw, dw, dh], [2, -d2, d2, h2]] + side_doors)
	# Eight pillars, each with the king as Osiris on the side towards the aisle.
	var osirides: Array[Transform3D] = []
	for i in 4:
		var pz := z - (2.9 + 4.1 * i) * s
		for side: float in [-1.0, 1.0]:
			var px := side * 5.5 * s
			_box(Vector3(px - 1.5 * s, th, pz - 1.5 * s), Vector3(px + 1.5 * s, th + high1, pz + 1.5 * s))
			_box(Vector3(minf(px - side * 1.5 * s, px - side * 2.6 * s), th, pz - 1.5 * s), Vector3(maxf(px - side * 1.5 * s, px - side * 2.6 * s), th + 7.0 * s, pz + 1.5 * s))
			osirides.append(_xf * Transform3D(Basis(Vector3.UP, -side * PI * 0.5).scaled(Vector3.ONE * s), Vector3(px, th, pz)))
	nodes.append(_many("osiride_pillar", osirides, m, "Osirides"))
	_mark("GreatDoor", &"abu_simbel_door", Vector3(0.0, th, 3.0 * s))
	_mark("GreatHall", &"abu_simbel_hall", Vector3(0.0, th, z - deep * 0.5))
	z -= deep
	_passage(Vector3(-d2, th, z - wall), Vector3(d2, th + h2, z), false)
	z -= wall
	# The second hall, of four square pillars.
	var half2 := 5.5 * s
	var deep2 := 7.6 * s
	var high2 := 7.0 * s
	var d3 := 1.0 * s
	var h3 := 4.2 * s
	_room(Vector3(-half2, th, z - deep2), Vector3(half2, th + high2, z), [[3, -d2, d2, h2], [2, -d3, d3, h3]])
	var post := 1.6 * s
	var posts: Array[Transform3D] = []
	for i in 2:
		for side: float in [-1.0, 1.0]:
			var at := Vector3(side * 2.9 * s, th, z - deep2 * (i + 1) / 3.0)
			posts.append(_xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), at))
			_box(at - Vector3(post, 0.0, post) * 0.5, at + Vector3(post * 0.5, high2, post * 0.5))
			nodes.append(_write_inside(NAMES if i == 0 else "@praise", Vector2(post - 0.2 * s, 3.6 * s), Transform3D(Basis(Vector3.UP, -side * PI * 0.5),
				at + Vector3(-side * (post * 0.5 + 0.01), high2 * 0.45, 0.0)), m, true))
	nodes.append(_many("square_pillar", posts, m, "Pillars"))
	z -= deep2
	_passage(Vector3(-d3, th, z - wall), Vector3(d3, th + h3, z), false)
	z -= wall
	# The vestibule, across the way.
	var deep3 := 3.2 * s
	var high3 := 5.6 * s
	var d4 := 0.9 * s
	var h4 := 3.8 * s
	_room(Vector3(-half2, th, z - deep3), Vector3(half2, th + high3, z), [[3, -d3, d3, h3], [2, -d4, d4, h4]])
	for side: float in [-1.0, 1.0]:
		nodes.append(_write_inside("@hymn", Vector2(half2 - d4 - 0.8 * s, 2.6 * s), Transform3D(Basis.IDENTITY, Vector3(side * (half2 + d4) * 0.5, th + high3 * 0.5, z - deep3 + 0.01)), m, false))
	z -= deep3
	_passage(Vector3(-d4, th, z - wall), Vector3(d4, th + h4, z), false)
	z -= wall
	# The sanctuary: an altar for the god's boat, and the four who sit on a bench against the far wall.
	var half4 := 2.0 * s
	var deep4 := 7.0 * s
	var high4 := 4.6 * s
	_room(Vector3(-half4, th, z - deep4), Vector3(half4, th + high4, z), [[3, -d4, d4, h4]])
	var god := 0.14 * s
	var bench := 0.25 * s
	var gods := ["god_ptah", "god_amun", "god_king", "god_ra"]
	for i in 4:
		nodes.append(_show(gods[i], Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * god), Vector3((i - 1.5) * s, th + bench, z - deep4)), m, gods[i].capitalize().replace(" ", "")))
	_box(Vector3(-half4, th, z - deep4), Vector3(half4, th + bench + 17.0 * god, z - deep4 + 1.2 * s))
	_box(Vector3(-0.6 * s, th, z - 3.75 * s), Vector3(0.6 * s, th + 0.9 * s, z - 2.55 * s))
	for side: float in [-1.0, 1.0]:
		nodes.append(_write_inside("@offering", Vector2(deep4 * 0.6, 1.8 * s), Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(side * (half4 - 0.01), th + high4 * 0.55, z - deep4 * 0.4)), m, false))
	_mark("GreatSanctuary", &"abu_simbel_sanctuary", Vector3(0.0, th, z - deep4 * 0.2))
	_mark("GreatTop", &"abu_simbel_top", Vector3(0.0, height, -37.5 * s))
	_far_end = z - deep4 + 1.2 * s + 0.4
	# The light down the axis: three of the four are in it.
	m.set_shader_parameter(&"shaft", Vector4(-half4 * 0.5, half4, th + 0.3 * s, th + h4))
	m.set_shader_parameter(&"far_end", z - deep4)
	_insides.append([nodes, _xf * Vector3(0.0, th, -30.0 * s), 30.0 * s + 80.0])
	inside_triangles += triangles - outside
	if sun_on_axis:
		beam = SunBeam.new()
		beam.name = "Sun"
		beam.stand = false
		beam.height = 0.0
		beam.width = 0.4 * s
		beam.reach = out + 72.0 * s
		beam.colour = Color(1.0, 0.82, 0.5)
		# (low enough that the boy stands in it, and to one side of the altar)
		beam.transform = _xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0.75 * s, th + 0.95 * s, out + 2.0))
		add_child(beam)
		draw_calls += 2
	# Where a hook will hold: the knees and the shoulders of each colossus.
	for cx: float in [-outer, -inner, inner, outer]:
		GrapplePoint.mark(self, _xf * Vector3(cx, th + (float(k["lap"]) + 0.3) * s, (float(k["knee_front"]) + 0.1) * s))
		if not is_equal_approx(cx, -inner):
			GrapplePoint.mark(self, _xf * Vector3(cx + 3.0 * s, th + (float(k["shoulder"]) + 0.3) * s, 2.6 * s))


# What is solid of a colossus: its pedestal, the throne and his legs as one block, his feet, his lap, and above the waist his body, head and crown.
func _colossus_solid(cx: float, th: float, broken: bool) -> void:
	var s := _s
	var k := SEATED
	var at := Vector3(cx, th, 0.0)
	_box(at + Vector3(-k["base_half"], 0.0, -2.0) * s, at + Vector3(k["base_half"], k["base_top"], k["base_front"]) * s)
	_box(at + Vector3(-k["throne_half"] - 0.1, k["base_top"], -2.0) * s, at + Vector3(k["throne_half"] + 0.1, k["seat"], 6.3) * s)
	_box(at + Vector3(-k["foot_half"], k["base_top"], 6.3) * s, at + Vector3(k["foot_half"], k["foot_top"], k["foot_front"]) * s)
	_box(at + Vector3(-2.5, k["seat"], -2.0) * s, at + Vector3(2.5, k["lap"], k["knee_front"]) * s)
	if broken:
		_box(at + Vector3(-2.3, k["lap"], -2.0) * s, at + Vector3(2.3, k["waist"], 2.7) * s)
		return
	_box(at + Vector3(-k["shoulder_half"], k["lap"], -2.6) * s, at + Vector3(k["shoulder_half"], k["shoulder"], k["chest_front"]) * s)
	_box(at + Vector3(-2.6, k["shoulder"], -2.6) * s, at + Vector3(2.6, k["head_top"], k["head_front"]) * s)
	_box(at + Vector3(-1.9, k["head_top"], -2.6) * s, at + Vector3(1.9, k["crown"], 1.8) * s)


# --- The Small Temple ---------------------------------------------------------

func _build_small() -> void:
	var s := _s
	var th := 0.6 * s
	var tall := 12.4 * s
	var top := th + 13.8 * s
	var niche := 3.1 * s
	var butt := 1.15 * s
	var middle := 3.4 * s
	var hw := middle * 0.5 + 3.0 * (niche + butt)
	var out := 1.6 * s
	var dw := 0.9 * s
	var dh := 3.6 * s
	var thick := 2.4 * s
	var lobe_top := 30.0 * s
	var whole := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO)
	if which == Which.SMALL:
		height = lobe_top
		_ramp(Vector2(0.0, -28.5 * s), Vector2(-0.62, -0.78), 7.0 * s, lobe_top)
	_hill_part("small_hill")
	_show("small_facade", whole, _rock, "SmallFacade")
	# Solid: the terrace and its steps, the wall, the buttresses that lean against it, the colossi in their niches, and the band along the top.
	var before := 8.0 * s
	_box(Vector3(-hw - 1.5 * s, -1.0, -thick), Vector3(hw + 1.5 * s, th, before))
	for i in 3:
		_box(Vector3(-hw - 1.5 * s, -1.0, before + i * 0.36 * s), Vector3(hw + 1.5 * s, th - (i + 1) * th / 3.0, before + (i + 1) * 0.36 * s))
	_box(Vector3(-hw, th, -thick), Vector3(-dw, top, 0.0))
	_box(Vector3(dw, th, -thick), Vector3(hw, top, 0.0))
	_box(Vector3(-dw, th + dh, -thick), Vector3(dw, top, 0.0))
	_box(Vector3(-hw, th + tall, 0.0), Vector3(hw, top, out - tall * 0.1 + 0.2 * s))
	var kings: Array[Transform3D] = []
	var queens: Array[Transform3D] = []
	var stature := 7.6 * s
	var plinth := 0.6 * s
	var x := -hw
	for i in 13:
		var wide := middle if i == 6 else (butt if i % 2 == 0 else niche)
		if i % 2 == 0:
			var parts: Array = [[x, x + wide, th]] if i != 6 else [[x, -dw, th], [dw, x + wide, th], [-dw, dw, th + dh]]
			for part: Array in parts:
				var from: float = part[2]
				_hull([Vector3(part[0], from, out - (from - th) * 0.1), Vector3(part[1], from, out - (from - th) * 0.1), Vector3(part[1], from, 0.0), Vector3(part[0], from, 0.0),
					Vector3(part[0], th + tall, out - tall * 0.1), Vector3(part[1], th + tall, out - tall * 0.1), Vector3(part[1], th + tall, 0.0), Vector3(part[0], th + tall, 0.0)])
			if i != 6:
				_write(QUEEN if i < 6 else NAMES, Vector2(wide - 0.2 * s, tall * 0.8), Transform3D(Basis(Vector3.RIGHT, -atan(0.1)), Vector3(x + wide * 0.5, th + tall * 0.5, out - tall * 0.05 + 0.03)),
					{"columns": true, "right_to_left": i > 6, "draw_distance": 120.0})
		else:
			var stood := _xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * stature), Vector3(x + wide * 0.5, th + plinth, 0.75 * s))
			if i == 3 or i == 9:
				queens.append(stood)
			else:
				kings.append(stood)
			_box(Vector3(x, th, 0.0), Vector3(x + wide, th + plinth + stature * 0.84, out - 0.15 * s))
		x += wide
	_many("king_standing", kings, _rock, "Kings")
	_many("queen_standing", queens, _rock, "Queens")

	# Inside: the hall of six pillars, the vestibule, and the sanctuary.
	var nodes: Array = []
	var outside := triangles
	var m := _inside_material(Vector3(0.0, th, out), Vector2(dw, dh), 26.0 * s)
	nodes.append(_show("small_inside", whole, m, "SmallInside"))
	_passage(Vector3(-dw, th, -thick), Vector3(dw, th + dh, out), false)
	var z := -thick
	var half1 := 5.5 * s
	var deep1 := 10.8 * s
	var high1 := 4.4 * s
	var d2 := 0.9 * s
	var h2 := 3.2 * s
	var wall := 1.3 * s
	_room(Vector3(-half1, th, z - deep1), Vector3(half1, th + high1, z), [[3, -dw, dw, dh], [2, -d2, d2, h2]])
	var post := 1.3 * s
	var heads: Array[Transform3D] = []
	for i in 3:
		for side: float in [-1.0, 1.0]:
			var at := Vector3(side * 2.5 * s, th, z - deep1 * (i + 0.7) / 3.4)
			_box(at - Vector3(post, 0.0, post) * 0.5, at + Vector3(post * 0.5, high1, post * 0.5))
			heads.append(_xf * Transform3D(Basis(Vector3.UP, -side * PI * 0.5).scaled(Vector3.ONE * s), at))
			nodes.append(_write_inside(QUEEN, Vector2(post * 0.6, high1 - post * 1.7), Transform3D(Basis(Vector3.UP, -side * PI * 0.5), at + Vector3(-side * (post * 0.5 + 0.01), (high1 - post * 1.5) * 0.5, 0.0)), m, true))
	nodes.append(_many("hathor_pillar", heads, m, "Hathors"))
	_mark("SmallDoor", &"abu_simbel_door", Vector3(0.0, th, out + 2.5 * s))
	_mark("SmallHall", &"abu_simbel_hall", Vector3(0.0, th, z - deep1 * 0.5))
	z -= deep1
	_passage(Vector3(-d2, th, z - wall), Vector3(d2, th + h2, z), false)
	z -= wall
	var deep2 := 2.8 * s
	_room(Vector3(-half1, th, z - deep2), Vector3(half1, th + 3.8 * s, z), [[3, -d2, d2, h2], [2, -d2, d2, h2]])
	z -= deep2
	_passage(Vector3(-d2, th, z - wall), Vector3(d2, th + h2, z), false)
	z -= wall
	var deep3 := 3.4 * s
	_room(Vector3(-1.5 * s, th, z - deep3), Vector3(1.5 * s, th + 3.4 * s, z), [[3, -d2, d2, h2]])
	var cow := 2.3 * s
	nodes.append(_show("cow", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * cow), Vector3(0.0, th, z - deep3 + 0.05 * s)), m, "Cow"))
	_box(Vector3(-0.35 * cow, th, z - deep3), Vector3(0.35 * cow, th + cow * 1.05, z - deep3 + 0.8 * cow))
	_mark("SmallSanctuary", &"abu_simbel_sanctuary", Vector3(0.0, th, z - deep3 * 0.3))
	_mark("SmallTop", &"abu_simbel_top", Vector3(0.0, lobe_top, -28.5 * s))
	_insides.append([nodes, _xf * Vector3(0.0, th, -12.0 * s), 14.0 * s + 60.0])
	inside_triangles += triangles - outside


# --- The hill and the sand ----------------------------------------------------

# A hill of the model: drawn, and its skin solid.
func _hill_part(called: String) -> void:
	var placed := _xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _s), Vector3.ZERO)
	_show(called, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _s), Vector3.ZERO), _rock, called.capitalize().replace(" ", ""))
	for point in part(called).get_faces():
		_hill.append(placed * point)


# Sand as a sheet of points, `rows[i][j]` (in this node's own space): drawn, and solid.
func _sand_sheet(rows: Array) -> void:
	for i in rows.size() - 1:
		var a: PackedVector3Array = rows[i]
		var b: PackedVector3Array = rows[i + 1]
		for j in a.size() - 1:
			_sand_quad(a[j], a[j + 1], b[j + 1], b[j])


# Four corners of sand, seen from above.
func _sand_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var up := (b - a).cross(c - a).y + (c - a).cross(d - a).y < 0.0
	for corner: Vector3 in ([a, b, c, a, c, d] if up else [a, c, b, a, d, c]):
		_sand.add_vertex(corner)
		_sand_faces.append(corner)
	_sand_count += 2


# A ramp of blown sand up the back of a hill to its top: a ridge he can walk up.
func _ramp(middle: Vector2, way: Vector2, from: float, top: float) -> void:
	way = way.normalized()
	var across := Vector2(-way.y, way.x)
	var long := top / tan(deg_to_rad(27.0))
	var half := 2.4 * _s
	var steps := 8
	var rows: Array = []
	for i in steps + 1:
		var t := float(i) / steps
		var h := top * (1.0 - t) + 0.05
		var centre := middle + way * (from + long * t)
		# (its sides lie at the angle sand lies at, but steeper the nearer the top, where it is banked against the
		# rock: lying at that angle all the way up, the top of it stood out 75 m either side, far past the hill,
		# and its upper end was open there: he could walk in under the sand, and see through it from the river)
		var lies := deg_to_rad(lerpf(62.0, 33.0, smoothstep(0.0, 0.45, t)))
		var foot := half + (h + 1.5) / tan(lies)
		var row := PackedVector3Array()
		for corner: Array in [[-foot, -1.5], [-half, h], [half, h], [foot, -1.5]]:
			var p: Vector2 = centre + across * float(corner[0])
			row.append(_xf * Vector3(p.x, corner[1], p.y))
		rows.append(row)
	_sand_sheet(rows)


# How high the drift lies at a place (in this node's own space), before the temple is thought of.
func _drift_height(x: float, z: float, peak: float) -> float:
	return peak - tan(deg_to_rad(30.0)) * Vector2(x - 30.0 * _s, z + 14.0 * _s).length()


# The fan of sand down the gully and across the north of the great facade, and the tongue of it that runs in at the door.
func _build_drift() -> void:
	var s := _s
	var th := 1.2 * s
	var dw := 1.3 * s
	var dh := 6.4 * s
	var thick := 3.5 * s
	var hw := 17.5 * s
	var slope := tan(deg_to_rad(30.0))
	# At 1 the sand at the door leaves a gap under the lintel that he can only crawl through.
	var full := th + dh - 0.85 + slope * Vector2(30.0 * s, 14.5 * s).length()
	var peak := full * (0.25 + 0.75 * clampf(drift, 0.0, 1.0))
	var far := peak / slope
	var cell := maxf(far / 11.0, 1.5)
	# (a row of the sheet runs just inside the facade, so that no crack is left between sand and wall)
	var row_at := -1.5 * s
	var zs: Array[float] = []
	var z := row_at
	while z > -14.0 * s - far - cell:
		zs.push_front(z)
		z -= cell
	# (and one under the outer edge of the lintel, where the gap is least)
	var lip := -dh * 0.07 - 0.3 * s
	zs.append(lip)
	zs.append(0.5 * s)
	z = 0.5 * s + cell
	while z < -14.0 * s + far + cell:
		zs.append(z)
		z += cell
	var xs: Array[float] = []
	var x := -dw
	while x > 30.0 * s - far - cell:
		xs.push_front(x)
		x -= cell
	xs.append(dw)
	x = dw + cell
	while x < 30.0 * s + far + cell:
		xs.append(x)
		x += cell
	var at_door := _drift_height(0.0, 0.5 * s, peak)
	_door_sand = at_door
	var high := func(px: float, pz: float) -> float:
		var h := _drift_height(px, maxf(pz, 0.5 * s) if absf(px) < hw and pz > -thick else pz, peak)
		if pz < 0.0 and absf(px) <= dw + 0.01:
			# (in the doorway it runs down into the hall)
			h = minf(h, at_door - maxf(lip - pz, 0.0) * 0.62)
		return maxf(h, -0.6)
	for i in zs.size() - 1:
		for j in xs.size() - 1:
			var corners: Array[Vector3] = []
			var shown := false
			for c: Array in [[j, i + 1], [j + 1, i + 1], [j + 1, i], [j, i]]:
				var h: float = high.call(xs[c[0]], zs[c[1]])
				shown = shown or h > -0.3
				corners.append(Vector3(xs[c[0]], h, zs[c[1]]))
			# (nothing of it inside the temple, but in the doorway)
			var behind := zs[i + 1] <= row_at + 0.01 and absf(xs[j] + xs[j + 1]) * 0.5 < hw and zs[i] > -70.0 * s
			if behind:
				shown = false
			if shown:
				_sand_quad(corners[0], corners[1], corners[2], corners[3])
	# The tongue in the passage and the hall, spreading from the door.
	var inside := at_door - (lip - row_at) * 0.62 - th
	if inside > 0.1:
		var rows: Array = []
		var run := inside / 0.62
		rows.append(PackedVector3Array([Vector3(-dw, th + inside, row_at), Vector3(dw, th + inside, row_at)]))
		var end := PackedVector3Array()
		for corner: float in [-dw, dw]:
			end.append(Vector3(corner, th + inside - minf(thick + row_at, run) * 0.62, row_at - minf(thick + row_at, run)))
		rows.append(end)
		_sand_sheet(rows)
		var left := inside - (thick + row_at) * 0.62
		if left > 0.1:
			var fan: Array = []
			for i in 4:
				var row := PackedVector3Array()
				for j in 9:
					var angle := PI * j / 8.0
					var r := left / 0.62 * i / 3.0
					row.append(Vector3(cos(angle) * (dw + r), th + left * (1.0 - i / 3.0) - (0.15 if i == 3 else 0.0), -thick - sin(angle) * r))
				fan.append(row)
			_sand_sheet(fan)
	for material: ShaderMaterial in _materials:
		if (material.get_meta(&"temple") as Transform3D).is_equal_approx(Transform3D.IDENTITY):
			material.set_shader_parameter(&"clear", clampf((th + dh - at_door) / dh, 0.12, 1.0))


# --- Rooms: what is solid of them (the model has their walls) ---------------------

# A room cut in the rock, solid all round. `doors` are the ways out of it, each
# [wall, from, to, height]: wall 0 is -X, 1 +X, 2 -Z (the far end), 3 +Z; from
# and to are along the wall.
func _room(low: Vector3, high: Vector3, doors: Array) -> void:
	_rooms.append([_xf.affine_inverse(), AABB(low, high - low).grow(0.02)])
	_box(Vector3(low.x, low.y - 1.0, low.z), Vector3(high.x, low.y, high.z))
	_box(Vector3(low.x, high.y, low.z), Vector3(high.x, high.y + 0.8, high.z))
	var t := 0.8
	for wall in 4:
		var along_x := wall >= 2
		var a0 := low.x if along_x else low.z
		var a1 := high.x if along_x else high.z
		var fixed: float = [low.x, high.x, low.z, high.z][wall]
		var back: float = [-t, t, -t, t][wall]
		var holes: Array = []
		for door: Array in doors:
			if door[0] == wall:
				holes.append(door)
		holes.sort_custom(func(p: Array, q: Array) -> bool: return p[1] < q[1])
		# [from, to, from how high]
		var pieces: Array = []
		var reached := a0
		for hole: Array in holes:
			pieces.append([reached, hole[1], low.y])
			pieces.append([hole[1], hole[2], low.y + float(hole[3])])
			reached = hole[2]
		pieces.append([reached, a1, low.y])
		for piece: Array in pieces:
			if piece[1] - piece[0] < 0.01:
				continue
			if along_x:
				_box(Vector3(piece[0], piece[2], minf(fixed, fixed + back)), Vector3(piece[1], high.y, maxf(fixed, fixed + back)))
			else:
				_box(Vector3(minf(fixed, fixed + back), piece[2], piece[0]), Vector3(maxf(fixed, fixed + back), high.y, piece[1]))


# A way through a wall between two rooms: `across` if it runs along X.
func _passage(low: Vector3, high: Vector3, across: bool) -> void:
	_rooms.append([_xf.affine_inverse(), AABB(low, high - low).grow(0.02)])
	_box(Vector3(low.x, low.y - 1.0, low.z), Vector3(high.x, low.y, high.z))
	_box(Vector3(low.x, high.y, low.z), Vector3(high.x, high.y + 0.8, high.z))
	if across:
		_box(Vector3(low.x, low.y, low.z - 0.6), Vector3(high.x, high.y, low.z))
		_box(Vector3(low.x, low.y, high.z), Vector3(high.x, high.y, high.z + 0.6))
	else:
		_box(Vector3(low.x - 0.6, low.y, low.z), Vector3(low.x, high.y, high.z))
		_box(Vector3(high.x, low.y, low.z), Vector3(high.x + 0.6, high.y, high.z))


# --- Showing, and what is solid ---------------------------------------------------

func _solid(shape: Shape3D, where: Transform3D) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = where
	add_child(collider)
	shapes += 1


func _box(low: Vector3, high: Vector3) -> void:
	_box_turned(Transform3D.IDENTITY, low, high)


# A solid box in the space `local` gives (which may be turned, and scaled the same every way).
func _box_turned(local: Transform3D, low: Vector3, high: Vector3) -> void:
	var grown := local.basis.get_scale().x
	var shape := BoxShape3D.new()
	shape.size = (high - low).abs() * grown
	var where := _xf * Transform3D(local.basis.orthonormalized(), local * ((low + high) * 0.5))
	_solid(shape, where)
	_solids.append([where.affine_inverse(), shape.size * 0.5])


# Stone that is solid some other way (a hull), noted as a box for `is_in_stone`.
func _note_box(low: Vector3, high: Vector3) -> void:
	_solids.append([(_xf * Transform3D(Basis.IDENTITY, (low + high) * 0.5)).affine_inverse(), (high - low).abs() * 0.5])


func _hull(corners: Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for corner: Vector3 in corners:
		points.append(_xf * corner)
	shape.points = points
	_solid(shape, Transform3D.IDENTITY)


# A part of the model, where `local` puts it in the temple being made.
func _show(what: String, local: Transform3D, material: Material, called: String) -> MeshInstance3D:
	var shown := MeshInstance3D.new()
	shown.name = called
	shown.mesh = part(what)
	shown.material_override = material
	shown.transform = _xf * local
	add_child(shown)
	triangles += _count(what)
	draw_calls += 1
	return shown


# One part drawn many times.
func _many(what: String, places: Array[Transform3D], material: Material, called: String) -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = part(what)
	many.instance_count = places.size()
	for i in places.size():
		many.set_instance_transform(i, places[i])
	var shown := MultiMeshInstance3D.new()
	shown.name = called
	shown.multimesh = many
	shown.material_override = material
	add_child(shown)
	triangles += _count(what) * places.size()
	draw_calls += 1
	return shown


static func _count(what: String) -> int:
	var mesh := part(what)
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		total += (indices as PackedInt32Array).size() / 3 if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _mark(called: String, group: StringName, local: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = called
	marker.position = _xf * local
	marker.add_to_group(group)
	add_child(marker)


# Writing on the stone outside.
func _write(what: String, across: Vector2, local: Transform3D, options := {}) -> Inscription:
	var made := Inscription.new()
	made.size = across
	made.colour = colour
	made.wear = clampf(wear * 0.6, 0.0, 0.6)
	made.text = what
	for key: String in options:
		made.set(key, options[key])
	made.transform = _xf * local
	add_child(made)
	draw_calls += 1
	triangles += 2
	return made


# Writing on a wall inside: set out by an `Inscription`, and lit as the walls are.
func _write_inside(what: String, across: Vector2, local: Transform3D, like: ShaderMaterial, columns: bool) -> Inscription:
	var made := _write(what, across, local, {"columns": columns, "painted": painted, "draw_distance": 40.0})
	made.rebuild()
	var panel := made.get_child(0) as MeshInstance3D
	if panel and panel.material_override:
		var material := like.duplicate() as ShaderMaterial
		material.shader = _shader(true)
		material.set_shader_parameter(&"carving", (panel.material_override as ShaderMaterial).get_shader_parameter(&"carving"))
		material.set_meta(&"temple", _xf)
		panel.material_override = material
		_materials.append(material)
	return made


static func _shader(carving: bool) -> Shader:
	if not _shaders.has(carving):
		var made := Shader.new()
		made.code = INSIDE.replace("//CARVING", CARVING_UNIFORMS if carving else "").replace("//SURFACE", CARVING if carving else WALLS)
		_shaders[carving] = made
	return _shaders[carving]


# The material of what is inside a temple, whose door is at `door` in the temple's own space.
func _inside_material(door: Vector3, opening: Vector2, reach: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader(false)
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"door", door)
	material.set_shader_parameter(&"opening", opening)
	material.set_shader_parameter(&"reach", reach)
	material.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
	material.set_shader_parameter(&"painted", 1.0 if painted else 0.0)
	material.set_shader_parameter(&"relief", _battle())
	material.set_shader_parameter(&"relief_size", Vector3(16.0, 8.0, 1.0) * _s)
	material.set_shader_parameter(&"shaft", Vector4(1.0, -1.0, 0.0, 0.0))
	material.set_meta(&"temple", _xf)
	_materials.append(material)
	return material


# The battle of Kadesh, near enough: ranks of soldiers, chariots, the king in
# his chariot larger than all, and the fallen. A picture made once: red is
# where a figure is cut, green which colour it was painted.
static func _battle() -> ImageTexture:
	if _relief:
		return _relief
	var stamps := {}
	# Each stamp is a list of blobs [x, y, half width, half height, paint] and lines [x0, y0, x1, y1, half thickness, paint], on a square of 32.
	var drawings := {
		"soldier": [[16, 5, 3, 3, 0.1], [16, 15, 3.5, 7, 0.1], [13, 26, 1.5, 6, 0.1, 15, 21], [19, 26, 1.5, 6, 0.1, 17, 21], [24, 2, 24, 30, 0.7, 0.5], [9, 14, 4, 6, 0.5]],
		"chariot": [[8, 24, 6, 6, 0.5], [8, 24, 3.5, 3.5, -1.0], [9, 16, 5, 4, 0.5], [8, 8, 3, 6, 0.1], [8, 2, 2.5, 2.5, 0.1], [14, 17, 30, 15, 0.8, 0.5],
			[23, 13, 7, 4, 0.9], [29, 8, 2.5, 5, 0.9], [30, 4, 3, 2, 0.9], [18, 20, 17, 30, 1.0, 0.9], [22, 20, 24, 30, 1.0, 0.9], [27, 20, 30, 28, 1.0, 0.9]],
		"fallen": [[6, 26, 3, 3, 0.1], [17, 27, 8, 3, 0.1], [26, 24, 30, 20, 1.2, 0.1], [24, 28, 31, 29, 1.2, 0.1]],
		"fort": [[16, 20, 12, 11, 0.5], [6, 7, 3, 3, 0.5], [16, 7, 3, 3, 0.5], [26, 7, 3, 3, 0.5], [16, 24, 3, 7, -1.0]],
	}
	for name: String in drawings:
		var stamp := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var inside := false
				var paint := 0.0
				for part: Array in drawings[name]:
					var hit := false
					if part.size() == 5:
						hit = pow((x - part[0]) / float(part[2]), 2.0) + pow((y - part[1]) / float(part[3]), 2.0) <= 1.0
					elif part.size() == 6:
						var a := Vector2(part[0], part[1])
						var b := Vector2(part[2], part[3])
						hit = Geometry2D.get_closest_point_to_segment(Vector2(x, y), a, b).distance_to(Vector2(x, y)) <= float(part[4])
					else:
						hit = Geometry2D.get_closest_point_to_segment(Vector2(x, y), Vector2(part[0], part[1]), Vector2(part[5], part[6])).distance_to(Vector2(x, y)) <= float(part[2])
					if hit:
						inside = float(part[-1] if part.size() != 7 else part[4]) >= 0.0
						paint = maxf(float(part[-1] if part.size() != 7 else part[4]), 0.0)
				stamp.set_pixel(x, y, Color(1.0 if inside else 0.0, paint, 0.0, 1.0 if inside else 0.0))
		stamps[name] = stamp
	var picture := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0.0, 0.0, 0.0, 0.0))
	var whole := Rect2i(0, 0, 32, 32)
	var random := RandomNumberGenerator.new()
	random.seed = 1274
	# Four registers. The king, three registers high, drives into the top three from the left; a fort stands at the right.
	var king := (stamps["chariot"] as Image).duplicate() as Image
	king.resize(96, 96, Image.INTERPOLATE_BILINEAR)
	picture.blend_rect(king, Rect2i(0, 0, 96, 96), Vector2i(20, 48))
	var fort := (stamps["fort"] as Image).duplicate() as Image
	fort.resize(72, 72, Image.INTERPOLATE_BILINEAR)
	picture.blend_rect(fort, Rect2i(0, 0, 72, 72), Vector2i(420, 60))
	for row in 4:
		var x := 4 if row == 0 or row == 3 else 124
		var end := 508 if row == 0 or row == 3 else 412
		while x < end - 30:
			var name: String = ["soldier", "chariot", "chariot", "soldier"][row]
			if random.randf() < 0.18 and row > 0:
				name = "fallen"
			var wide := 22 if name == "soldier" else 34
			picture.blend_rect(stamps[name], whole, Vector2i(x, 12 + row * 60))
			x += wide
	for y in 256:
		# (a line under each register)
		if y % 60 == 46 or y % 60 == 47:
			for x in 512:
				picture.set_pixel(x, y, Color(1.0, 0.5, 0.0, 1.0))
	picture.generate_mipmaps()
	_relief = ImageTexture.create_from_image(picture)
	return _relief
