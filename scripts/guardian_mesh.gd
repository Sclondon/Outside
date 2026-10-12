class_name GuardianMesh
## What a gate guardian is made of (`GateGuardian`), and the leaf of papyrus
## that names it (`BookPage`).
##
## The model is `models/guardian.glb`, built in Blender by
## `tools/build_guardian.py` (which also keeps `tools/guardian.blend`, to look
## at and change by hand). It has no bones: it is separate things, each named
## for what it is, which `GateGuardian` moves. The figure is there twice, in
## wrappings and in a kilt (`trunk_wrapped`, `trunk_kilt`, and so on); each of
## the nine heads is a thing of its own (`head_jackal`, ...); and there are the
## knives, the great knife that bars a gateway, and the leaf open and rolled.
## Where each is hinged is its origin in the model (`at`). It faces +Z and is
## in metres.
##
##     part.mesh = GuardianMesh.piece(["trunk_wrapped", "wig"], BookOfTheDead.Head.JACKAL)
##     part.position = GuardianMesh.at("arm_wrapped_left")
##
## Its colours are the model's materials. `piece` makes one mesh of the things
## it is given, with one material, every point carrying the colour of the
## material it had (as a custom value: the renderers do not agree what a mesh's
## own colours mean): so a guardian is ten things to draw, one for each part
## that moves, however many colours it is painted in. That material lights it
## as the world is lit (`Toon.surface`). A few of the model's materials mean
## something by their names:
##   - `gold` and `blade` shine as gold does (`Sandstone.gold`).
##   - `eye` is lit from within, and shows in the dark.
##   - `stone` (the plinth) is drawn as the game's sandstone, in that colour:
##     the one thing that is a draw of its own.
##   - `hide` (the neck, the fists of the wrapped figure) is painted in the
##     colour of the head's own hide: the head's material whose name ends in
##     `_hide`.
##   - a head with anything in `wig` has the wig down its back (`has_wig`).

const MODEL := "res://models/guardian.glb"
## The heads, by the names they have in the model, in the order of `BookOfTheDead.Head`.
const HEADS: Array[String] = ["crocodile", "snake", "vulture", "hippopotamus", "ram", "jackal", "hare", "lion", "bull"]

const SHADER := """
shader_type spatial;

// 1: light and shadow are cut into two flat tones, as the world's are. 0: smooth.
uniform float banded = 1.0;
uniform float wrap = 0.15;

varying vec3 tint;
// What it is made of: 0 cloth, hide or paint; 1 metal; 2 an eye, lit from within.
varying float stuff;

void vertex() {
	tint = CUSTOM0.rgb;
	stuff = CUSTOM0.a;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	float metal = step(0.5, stuff) * step(stuff, 1.5);
	float eye = step(1.5, stuff);
	ALBEDO = tint * (1.0 - eye);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// (metal has a bright edge where it is seen side-on, and a glow of its own in shadow)
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = tint * (eye + metal * (0.22 + 0.3 * mix(smoothstep(0.55, 0.95, graze), cut(graze, 0.78), banded)));
}

void light() {
	float metal = step(0.5, stuff) * step(stuff, 1.5);
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float towards = dot(NORMAL, LIGHT);
	float hard = cut((towards + wrap) / (1.0 + wrap) * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float soft = clamp(towards, 0.0, 1.0) * reach;
	DIFFUSE_LIGHT += mix(soft, hard, banded) * LIGHT_COLOR / PI;
	float caught = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 5.0);
	float stepped = cut(caught, 0.3) * 0.45 + cut(caught, 0.62) * 0.55;
	SPECULAR_LIGHT += metal * mix(caught, stepped, banded) * 0.8 * step(0.0, towards) * reach * LIGHT_COLOR / PI * vec3(1.0, 0.86, 0.5);
}
"""

static var _shader: Shader
static var _materials := {}
static var _read_from := {}
static var _places := {}
static var _made := {}


## The one material all of every guardian is drawn in (but for its plinth).
static func material() -> ShaderMaterial:
	var banded := Settings.world_banded
	if not _materials.has(banded):
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER
		var made := ShaderMaterial.new()
		made.shader = _shader
		made.set_shader_parameter(&"banded", 1.0 if banded else 0.0)
		_materials[banded] = made
	return _materials[banded]


## The things named, as one mesh to draw (see `HEADS` and the model for the
## names). `kind` is the head the figure has (`BookOfTheDead.Head`): what is
## painted `hide` takes that head's colour.
static func piece(names: Array, kind := -1) -> ArrayMesh:
	var key := "%s|%d|%s" % ["+".join(names), kind, Settings.world_banded]
	if not _made.has(key):
		_made[key] = _as_one(names, hide(kind))
	return _made[key]


## The head of a beast (`BookOfTheDead.Head`): facing +Z, the top of the neck at its origin.
static func head(kind: int) -> ArrayMesh:
	return piece(["head_" + HEADS[kind]])


## Whether a head has the cloth of a wig down its back.
static func has_wig(kind: int) -> bool:
	return _colour_of("head_" + HEADS[kind], "wig", true) != null


## The colour of a head's hide.
static func hide(kind: int) -> Color:
	if kind < 0 or kind >= HEADS.size():
		return Color.WHITE
	var found: Variant = _colour_of("head_" + HEADS[kind], "_hide", false)
	return found if found != null else BookOfTheDead.HIDES[kind]


## Where a thing is hinged, within the thing it hangs from: an arm's shoulder
## in the trunk, a knife's fist in the arm, the `neck` in the trunk.
static func at(which: String) -> Vector3:
	_read()
	return _places.get(which, Vector3.ZERO)


## How high a thing stands above its origin, as it is modelled.
static func tall(which: String) -> float:
	var mesh := model_mesh(which)
	return mesh.get_aabb().end.y if mesh else 1.0


## A thing as it is in the model: a surface for each of its materials, and whatever else the model gave it.
static func model_mesh(which: String) -> Mesh:
	_read()
	return _read_from.get(which)


## How many triangles a mesh is.
static func triangles(mesh: Mesh) -> int:
	return mesh.get_faces().size() / 3 if mesh else 0


static func _read() -> void:
	if not _read_from.is_empty():
		return
	var model := (load(MODEL) as PackedScene).instantiate()
	for part: Node3D in model.find_children("*", "Node3D", true, false):
		_places[String(part.name)] = part.position
		if part is MeshInstance3D:
			_read_from[String(part.name)] = (part as MeshInstance3D).mesh
	model.free()


# The colour of the material of a thing whose name is `named` (or ends with it), or null.
static func _colour_of(which: String, named: String, whole: bool) -> Variant:
	var mesh := model_mesh(which)
	if mesh == null:
		return null
	for surface in mesh.get_surface_count():
		var paint := mesh.surface_get_material(surface) as BaseMaterial3D
		if paint and (paint.resource_name == named if whole else paint.resource_name.ends_with(named)):
			return paint.albedo_color
	return null


# Several things of several materials as one mesh of one, each point keeping the colour of the material it
# had. What is stone is a second surface, in the game's sandstone.
static func _as_one(names: Array, hide_colour: Color) -> ArrayMesh:
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	paint.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone_colour := Sandstone.COLOUR
	var painted := false
	var stony := false
	for which: String in names:
		var mesh := model_mesh(which)
		if mesh == null:
			push_error("The guardian's model has nothing in it called %s" % which)
			continue
		for surface in mesh.get_surface_count():
			var original := mesh.surface_get_material(surface) as BaseMaterial3D
			var named := original.resource_name if original else ""
			var colour := original.albedo_color if original else Color.WHITE
			var tool := paint
			if named == "stone":
				tool = stone
				stone_colour = colour
				stony = true
			else:
				painted = true
				if named == "hide":
					colour = hide_colour
				colour = colour.srgb_to_linear()
				colour.a = 1.0 if named == "gold" or named == "blade" else 2.0 if named == "eye" else 0.0
				paint.set_custom(0, colour)
			var arrays := mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := order.size() if not order.is_empty() else points.size()
			for i in count:
				var k := order[i] if not order.is_empty() else i
				tool.set_normal(normals[k])
				tool.add_vertex(points[k])
	var made := ArrayMesh.new()
	if painted:
		paint.index()
		paint.commit(made)
		made.surface_set_material(made.get_surface_count() - 1, material())
	if stony:
		stone.index()
		stone.commit(made)
		made.surface_set_material(made.get_surface_count() - 1, Toon.sandstone(stone_colour))
	return made
