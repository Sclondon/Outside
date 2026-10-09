class_name Inscription
extends Node3D
## Writing carved into stone: a panel `size` metres wide and tall, facing +Z,
## its middle at the node's origin, carrying `text` in hieroglyphs (see
## `Hieroglyphs.write` for what a text can be). Lay it against any flat face:
##
##     Inscription.on_box(wall, Vector3(4, 3, 0.6), Vector3.BACK, "@offering")   # on the +Z face of a box
##     add_child(Inscription.slab("The door opens to <Tut>", Vector2(2.4, 1.2))) # a slab of its own, standing on its foot
##     var carved := Inscription.new(); carved.text = "..."; carved.size = ...; face.add_child(carved)
##
## `translation()` is what it says in plain words, and every one is in the
## group `inscriptions`, for whatever wants to show the player a translation.
##
## How it is drawn. The signs are set out and drawn once into a small picture
## (`Hieroglyphs.texture`: about 64 dots to a sign, kept and shared between
## inscriptions that say the same), which holds not the signs themselves but
## how far each dot is from the edge of one. The panel is one flat rectangle
## laid a hair in front of the stone, drawn only where there is carving: the
## floor of each sign a little darker than the stone (or painted), and round
## its edge a narrow wall whose slope is read off the picture, so that the sun
## or a torch lights the side of every cut that faces it and leaves the other
## dark, as a chisel cut is lit. Nothing is worked out again after it is made,
## and the stone under it is whatever it was laid on.
##
## Because the picture is of distances, an edge is sharp however near the
## camera comes; and as it goes away the walls fade out before they are too
## small to draw, leaving the signs as flat darker shapes that do not shimmer.

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// In its alpha, how far inside a sign each dot is (a half is the edge); in its colour, the sign's paint.
uniform sampler2D carving : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 stone : source_color = vec3(0.66, 0.57, 0.43);
uniform vec3 ink : source_color = vec3(0.1, 0.08, 0.07);
// 1: lit in two hard tones; 0: smoothly.
uniform float banded = 0.0;
uniform float wrap = 0.15;
// How deep it is cut (0: not at all, only painted), and 1 if the signs stand out of the stone, not in it.
uniform float depth = 1.0;
uniform float raised = 0.0;
// How much of the signs is coloured (0: bare stone), and 1 if each has its own paint, 0 if all are `ink`.
uniform float tint = 0.0;
uniform float paint = 0.0;
// How weathered, 0..1.
uniform float wear = 0.2;
// How big the panel is, in metres, and its picture, in dots.
uniform vec2 size = vec2(1.0);
uniform vec2 dots = vec2(256.0);

varying vec3 plain;

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
	// Drawn a hair nearer than it is, so that it never fights with the stone it lies on.
	vec4 from_eye = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	from_eye.xyz *= 0.998;
	POSITION = PROJECTION_MATRIX * from_eye;
}

void fragment() {
	vec2 at = UV * size;
	vec4 here = texture(carving, UV);
	// How many dots of the picture one dot of the screen covers: the cut's walls fade out as they get too small to draw.
	float cover = max(fwidth(UV.x) * dots.x, fwidth(UV.y) * dots.y);
	float near = clamp(3.0 - cover * 0.8, 0.0, 1.0);
	vec2 dot_size = max(cover, 1.0) / dots;
	// Which way the edge of the sign runs here: uphill is into the sign.
	vec2 slope = vec2(texture(carving, UV + vec2(dot_size.x, 0.0)).a, texture(carving, UV + vec2(0.0, dot_size.y)).a) - here.a;
	float steep = length(slope);
	vec2 inward = steep > 0.003 ? slope / steep : vec2(0.0);

	// Weather: the edges are eaten ragged, the paint flakes, and whole patches of the face have gone.
	float inside = here.a - wear * 0.24 * patches(at * 31.0);
	float flaked = smoothstep(wear - 0.06, wear + 0.06, patches(at * 9.0 + 31.0) * 0.8 + patches(at * 37.0) * 0.3);
	float spall = patches(at * 2.3 + 7.3) * 0.75 + patches(at * 7.1) * 0.25;
	float lost = smoothstep(1.0 - wear * 0.6, 1.05 - wear * 0.6, spall);

	float soft = max(fwidth(inside) * 0.7, 0.02);
	float in_sign = smoothstep(0.5 - soft, 0.5 + soft, inside);
	// The wall of the cut: a narrow band inside the edge of a sunk sign, or outside the edge of a raised one.
	float wall = mix(in_sign * (1.0 - smoothstep(0.62, 0.9, inside)), smoothstep(0.14, 0.24, inside) * (1.0 - in_sign), raised);
	vec2 tilt = inward * wall * depth * near * mix(1.0, -1.0, raised) * 1.15;
	plain = NORMAL;
	NORMAL = normalize(NORMAL + TANGENT * tilt.x - BINORMAL * tilt.y);

	vec3 pigment = mix(ink, here.rgb, paint);
	float coloured = tint * flaked;
	// The floor of a sunk sign is in its own shade, the more so where the walls can no longer be seen.
	vec3 floor_colour = mix(stone * (1.0 - depth * mix(mix(0.45, 0.27, near), -0.07, raised)), pigment, coloured);
	vec3 colour = mix(floor_colour, mix(stone, pigment, coloured), wall * 0.75);
	// The side of a cut that faces the sky is lighter than the side that faces the ground, whatever the sun is doing.
	colour *= 1.0 - tilt.y * 0.2;
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float shown = mix(in_sign, max(in_sign, smoothstep(0.14, 0.24, inside)), raised * depth);
	// (a sign that is neither cut nor coloured is not there)
	shown *= max(coloured, min(depth, 1.0));
	ALPHA = shown * (1.0 - lost);
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
	// In hard light the wall that faces the light is a tone brighter than the face of the stone.
	float lip = cut(towards - dot(plain, LIGHT), 0.1) * 0.4 * hard;
	DIFFUSE_LIGHT += mix(soft, hard + lip, banded) * LIGHT_COLOR / PI;
}
"""

## What it says: see `Hieroglyphs.write`. "@name" is a text from `InscriptionTexts`.
@export_multiline var text := "": set = _set_text
## How wide and tall the panel is, in metres. The writing is set out to fit it.
@export var size := Vector2(2.0, 1.0): set = _set_size
## Set out in columns, read downwards, not in rows.
@export var columns := false: set = _set_columns
## Read from the right, the signs facing right, as the Egyptians liked best.
@export var right_to_left := false: set = _set_right_to_left
## How big a square of writing is, in metres. 0: as big as will fit the panel.
@export var sign_size := 0.0: set = _set_sign_size
## Lines ruled between the rows or columns.
@export var rules := true: set = _set_rules
## Goes on repeating the text until the panel is full (with `sign_size`): for dressing a long wall.
@export var fill := false: set = _set_fill
## Cut into the stone. Not carved, it is only painted on.
@export var carved := true: set = _set_carved
## The signs stand out of the stone and the ground round them is cut away, not the other way about.
@export var raised := false: set = _set_raised
## Each sign painted in its own colour.
@export var painted := false: set = _set_painted
## The colour of the stone it is cut in: that of whatever it lies on.
@export var colour := Sandstone.COLOUR: set = _set_colour
## How weathered it is, 0..1: ragged edges, flaked paint, patches lost.
@export_range(0.0, 1.0) var wear := 0.2: set = _set_wear
## How far the writing keeps from the edge of the panel, metres.
@export var margin := 0.06
## Metres beyond which it is not drawn (0: always).
@export var draw_distance := 70.0

## How it was set out (see `Hieroglyphs.write`), once it has been made.
var layout := {}

static var _shader: Shader

var _panel: MeshInstance3D
var _stale := false


func _ready() -> void:
	add_to_group(&"inscriptions")
	rebuild()


## What it says, in plain words.
func translation() -> String:
	return Hieroglyphs.read(text)


## An inscription laid on one face of a box `box` metres in size whose middle
## is the origin of `body`: `side` is which face (Vector3.BACK is +Z, the
## front; LEFT, RIGHT, FORWARD, UP). It covers the face, less `inset` metres all
## round. `options` are any of its properties, by name: {"painted": true, "wear": 0.5}.
static func on_box(body: Node3D, box: Vector3, side: Vector3, what: String, options := {}, inset := 0.0) -> Inscription:
	var made := Inscription.new()
	var up := Vector3.FORWARD if absf(side.y) > 0.5 else Vector3.UP
	var across := up.cross(side).normalized()
	made.transform = Transform3D(Basis(across, up, side), side * (absf(box.dot(side)) * 0.5 + 0.002))
	made.size = Vector2(absf(box.dot(across)) - inset * 2.0, absf(box.dot(up)) - inset * 2.0)
	made.colour = options.get("colour", made.colour)
	made.text = what
	for key: String in options:
		made.set(key, options[key])
	body.add_child(made)
	return made


## A slab of stone standing on its foot at the origin, `across` metres wide
## and tall and `thick` deep, with the text on its front (+Z), and on its back
## too if `both`. It is solid.
static func slab(what: String, across := Vector2(2.0, 1.2), thick := 0.25, options := {}, both := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	var box := Vector3(across.x, across.y, thick)
	var shape := BoxShape3D.new()
	shape.size = box
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = across.y * 0.5
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = box
	var stone := MeshInstance3D.new()
	stone.name = "Stone"
	stone.mesh = mesh
	stone.material_override = Toon.surface(options.get("colour", Sandstone.COLOUR))
	stone.position.y = across.y * 0.5
	body.add_child(stone)
	on_box(stone, box, Vector3.BACK, what, options, 0.04).name = "Front"
	if both:
		on_box(stone, box, Vector3.FORWARD, what, options, 0.04).name = "Back"
	return body


## What an "inscription" in a level's layout makes (see `LevelLayout.FIELDS`):
## a slab of its own standing on the ground, or the bare writing to stand
## against a wall that is there already. Either way its foot is at the origin.
static func from_item(item: Dictionary) -> Node3D:
	var named := int(item.get("named", 0))
	var what: String = item.get("text", "")
	if named > 0 and named <= InscriptionTexts.ORDER.size():
		what = "@" + InscriptionTexts.ORDER[named - 1]
	var across := Vector2(item.get("width", 2.4), item.get("height", 1.2))
	var options := {"columns": item.get("columns", false), "right_to_left": item.get("rtl", false), "sign_size": item.get("sign", 0.0), "fill": item.get("fill", false),
		"carved": item.get("carved", true), "painted": item.get("painted", false), "wear": item.get("wear", 0.2),
		"colour": Pyramid.STONES[clampi(int(item.get("stone", 0)), 0, Pyramid.STONES.size() - 1)]}
	if item.get("slab", true):
		return slab(what, across, 0.25, options, item.get("both", false))
	var holder := Node3D.new()
	var made := Inscription.new()
	made.size = across
	made.text = what
	for key: String in options:
		made.set(key, options[key])
	made.position = Vector3(0.0, across.y * 0.5, 0.002)
	holder.add_child(made)
	return holder


## Sets the writing out and makes the panel again. Changing a property does
## this by itself, a moment later.
func rebuild() -> void:
	_stale = false
	if _panel == null:
		_panel = MeshInstance3D.new()
		_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_panel)
	layout = _fitted()
	set_meta(&"reads", layout.get("reading", ""))
	if layout.get("signs", []).is_empty():
		_panel.mesh = null
		return
	# The picture covers just the writing, which stands in the middle of the panel.
	var square := _square_size()
	var half: Vector2 = layout["size"] / 100.0 * square * 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-half.x, half.y, 0.0), Vector3(half.x, half.y, 0.0), Vector3(half.x, -half.y, 0.0), Vector3(-half.x, -half.y, 0.0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_panel.mesh = mesh
	_panel.visibility_range_end = draw_distance
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var picture := Hieroglyphs.texture(layout)
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"carving", picture)
	material.set_shader_parameter(&"dots", Vector2(picture.get_size()))
	material.set_shader_parameter(&"size", half * 2.0)
	material.set_shader_parameter(&"stone", colour)
	material.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
	material.set_shader_parameter(&"depth", 1.0 if carved or raised else 0.0)
	material.set_shader_parameter(&"raised", 1.0 if raised else 0.0)
	material.set_shader_parameter(&"tint", 1.0 if painted or not (carved or raised) else 0.0)
	material.set_shader_parameter(&"paint", 1.0 if painted else 0.0)
	material.set_shader_parameter(&"wear", wear)
	_panel.material_override = material


# How big a square of writing came out, in metres.
func _square_size() -> float:
	return layout.get("square", sign_size)


# The text set out to fit the panel: at `sign_size`, or as big as will go.
func _fitted() -> Dictionary:
	var room := Vector2(maxf(size.x - margin * 2.0, 0.05), maxf(size.y - margin * 2.0, 0.05))
	var along := room.y if columns else room.x
	var across := room.x if columns else room.y
	# (a line of writing, with the room it keeps round it and its rule, in hundredths of a square)
	var pitch := 100.0 + (Hieroglyphs.RULE_MARGIN * 2.0 + Hieroglyphs.RULE if rules else 10.0)
	var extra := Hieroglyphs.RULE if rules else 0.0
	var options := {"columns": columns, "rtl": right_to_left, "rules": rules, "fill": fill}
	var made := {}
	if sign_size > 0.0:
		options["wrap"] = maxf(along / sign_size - 0.12, 1.0)
		options["limit"] = maxi(int((across / sign_size * 100.0 - extra) / pitch), 1)
		made = Hieroglyphs.write(text, options)
		made["square"] = sign_size
		return made
	for lines in range(1, 25):
		var square := across / ((lines * pitch + extra) / 100.0)
		options["wrap"] = maxf(along / square - 0.12, 1.0)
		options["limit"] = lines
		made = Hieroglyphs.write(text, options)
		made["square"] = square
		var long: float = made["size"].y if columns else made["size"].x
		if int(made["lines"]) <= lines and long / 100.0 * square <= along + 0.001:
			break
	return made


func _changed() -> void:
	if is_inside_tree() and not _stale:
		_stale = true
		rebuild.call_deferred()


func _set_text(value: String) -> void:
	text = value
	_changed()


func _set_size(value: Vector2) -> void:
	size = value
	_changed()


func _set_columns(value: bool) -> void:
	columns = value
	_changed()


func _set_right_to_left(value: bool) -> void:
	right_to_left = value
	_changed()


func _set_sign_size(value: float) -> void:
	sign_size = value
	_changed()


func _set_rules(value: bool) -> void:
	rules = value
	_changed()


func _set_fill(value: bool) -> void:
	fill = value
	_changed()


func _set_carved(value: bool) -> void:
	carved = value
	_changed()


func _set_raised(value: bool) -> void:
	raised = value
	_changed()


func _set_painted(value: bool) -> void:
	painted = value
	_changed()


func _set_colour(value: Color) -> void:
	colour = value
	_changed()


func _set_wear(value: float) -> void:
	wear = value
	_changed()
