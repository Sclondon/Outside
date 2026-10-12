class_name BookPage
extends Node3D
## A leaf of papyrus from a Book of the Dead, lying open or rolled up: it has
## on it the name of the keeper of a gate (`GateGuardian`), with his picture.
##
## He takes it by walking onto it (or with the act button: it is in the group
## `workable`). It comes up large to be read, the game standing still until a
## touch puts it away (`GuardianPanel`): the keeper as he looks, his name in
## signs and, under it, in English. Then it is his for as long as the level
## lasts: it is written into the journal, it is on the notebook's page of
## leaves, and the keeper's name has its English under it when he asks. A
## level started again has forgotten it (`BookOfTheDead`).
##
## Which name it carries is `who`; left at -1 it takes the name of the nearest
## keeper that has no leaf yet. `BookPage.new()` is a whole one, lying on the
## ground at this node.

## He has taken it: the place of its name in `BookOfTheDead.NAMES`.
signal taken(who: int)

## Whose name is on it (its place in `BookOfTheDead.NAMES`), or -1 for the nearest keeper's.
@export var who := -1
## Rolled up and tied, not lying open.
@export var rolled := false
## How near he must come to take it.
@export var reach := 0.7

## The name it turned out to carry (see `BookOfTheDead.name_leaves`).
var name_is := -1
## Whether he has it.
var is_taken := false

var _leaf: MeshInstance3D
var _paper: StandardMaterial3D
var _time := 0.0

static var _written: ImageTexture


func _ready() -> void:
	add_to_group(&"book_pages")
	add_to_group(&"workable")
	add_to_group(&"interest")
	_build()


## The name on it: its place in `BookOfTheDead.NAMES`.
func name_on_it() -> int:
	var book := BookOfTheDead.of(self)
	if book:
		book.name_leaves()
	return name_is if name_is >= 0 else maxi(who, 0)


## Picked up with the act button.
func work(_by: Node3D = null) -> void:
	take()


## He takes it: it is his, and comes up to be read. Says whether it was there to take.
func take(show := true) -> bool:
	if is_taken or not is_inside_tree():
		return false
	var name := name_on_it()
	is_taken = true
	visible = false
	remove_from_group(&"workable")
	var book := BookOfTheDead.of(self)
	if book and book.take(name):
		var keeper: Dictionary = BookOfTheDead.NAMES[name]
		Notebook.sketch(BookPage.sketch.bind(name),
			"A leaf of the Book of the Dead. The keeper of a gate, and his name: \"%s\"." % keeper["name"], "Papyrus")
	if show:
		GuardianPanel.read(self, name)
	taken.emit(name)
	return true


## Lying where it was again, not taken. (The level's memory of it is not changed.)
func reset() -> void:
	if is_taken:
		is_taken = false
		visible = true
		add_to_group(&"workable")


func _physics_process(delta: float) -> void:
	if is_taken:
		return
	_time += delta
	# (it catches the light a little, to be seen lying on the sand)
	_paper.emission_energy_multiplier = 0.18 + 0.14 * sin(_time * 2.4)
	_leaf.position.y = (0.2 if rolled else 0.16) + sin(_time * 1.7) * 0.03
	_leaf.rotation.y += delta * 0.7
	var boy := Nearby.player(get_tree())
	if boy == null or boy.is_limp:
		return
	var to := boy.global_position - global_position
	if Vector2(to.x, to.z).length() < reach and to.y > -1.4 and to.y < 0.9:
		take()


func _build() -> void:
	_paper = StandardMaterial3D.new()
	_paper.albedo_texture = _writing()
	_paper.roughness = 1.0
	_paper.metallic_specular = 0.0
	_paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paper.emission_enabled = true
	_paper.emission = BookOfTheDead.PAPYRUS
	_paper.emission_texture = _paper.albedo_texture
	_paper.emission_energy_multiplier = 0.2
	_paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if rolled:
		# A roll: the sheet wound round, a hand's breadth through.
		var sides := 10
		for n in sides:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var turn := TAU * (n + corner.x) / sides
				var out := Vector3(0.0, cos(turn), sin(turn))
				tool.set_normal(out)
				tool.set_uv(Vector2(corner.y, float(n + corner.x) / sides * 2.0))
				tool.add_vertex(out * 0.06 + Vector3(corner.y * 0.5 - 0.25, 0.0, 0.0))
	else:
		# A sheet lying open, its ends curled up a little.
		var strips := 8
		for n in strips:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var along := float(n + corner.x) / strips
				var curl := pow(absf(along - 0.5) * 2.0, 3.0) * 0.07
				tool.set_normal(Vector3.UP)
				tool.set_uv(Vector2(along, corner.y))
				tool.add_vertex(Vector3(along * 0.62 - 0.31, curl, corner.y * 0.44 - 0.22))
	_leaf = MeshInstance3D.new()
	_leaf.mesh = tool.commit()
	_leaf.material_override = _paper
	_leaf.rotation.z = 0.0 if rolled else 0.22
	_leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_leaf)
	# Its shadow on the ground: it floats a hand above it.
	var shade := MeshInstance3D.new()
	var disc := QuadMesh.new()
	disc.size = Vector2(0.6, 0.6)
	disc.orientation = PlaneMesh.FACE_Y
	shade.mesh = disc
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.albedo_color = Color(0.0, 0.0, 0.0, 0.3)
	dark.albedo_texture = _blot()
	shade.material_override = dark
	shade.position.y = 0.015
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shade)
	if rolled:
		PuzzleKit.rod(_leaf, Vector3.ZERO, 0.063, 0.05, Toon.surface(BookOfTheDead.RUBRIC), -1.0, 10).rotation.z = PI * 0.5


# What is written on it, from far enough off that it cannot be read: lines of
# signs in black, a line in red, and the picture in its frame.
static func _writing() -> ImageTexture:
	if _written:
		return _written
	var wide := 96
	var tall := 64
	var image := Image.create(wide, tall, false, Image.FORMAT_RGBA8)
	var dice := RandomNumberGenerator.new()
	dice.seed = 144
	for y in tall:
		for x in wide:
			var weave := 0.04 * sin(x * 2.1) + 0.05 * sin(y * 2.6) + dice.randf_range(-0.03, 0.03)
			image.set_pixel(x, y, BookOfTheDead.PAPYRUS.lightened(0.1).darkened(clampf(0.1 - weave, 0.0, 1.0)))
	image.fill_rect(Rect2i(6, 8, 30, 48), BookOfTheDead.PAPYRUS.lightened(0.3))
	for edge: Rect2i in [Rect2i(6, 8, 30, 1), Rect2i(6, 55, 30, 1), Rect2i(6, 8, 1, 48), Rect2i(35, 8, 1, 48)]:
		image.fill_rect(edge, BookOfTheDead.INK)
	# (the keeper, as a few blots: his block, his body, his head, his knife)
	image.fill_rect(Rect2i(11, 38, 10, 14), Color(0.24, 0.5, 0.42))
	image.fill_rect(Rect2i(14, 24, 7, 15), BookOfTheDead.LINEN.darkened(0.1))
	image.fill_rect(Rect2i(20, 36, 8, 5), BookOfTheDead.LINEN.darkened(0.1))
	image.fill_rect(Rect2i(24, 40, 4, 12), BookOfTheDead.LINEN.darkened(0.1))
	image.fill_rect(Rect2i(14, 15, 12, 8), BookOfTheDead.INK)
	image.fill_rect(Rect2i(28, 16, 2, 20), BookOfTheDead.INK)
	for row in 6:
		var y := 10 + row * 8
		var x := 42
		while x < wide - 8:
			var long := dice.randi_range(2, 5)
			image.fill_rect(Rect2i(x, y + dice.randi_range(0, 1), long, dice.randi_range(3, 5)), BookOfTheDead.RUBRIC if row == 0 else BookOfTheDead.INK)
			x += long + dice.randi_range(1, 3)
	image.generate_mipmaps()
	_written = ImageTexture.create_from_image(image)
	return _written


static var _blotted: ImageTexture


# A soft round shadow.
static func _blot() -> ImageTexture:
	if _blotted:
		return _blotted
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var out := Vector2(x - 15.5, y - 15.5).length() / 16.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - out, 0.0, 1.0)))
	_blotted = ImageTexture.create_from_image(image)
	return _blotted


## Draws what the journal keeps of a leaf: the keeper, and his name in signs.
static func sketch(on: CanvasItem, rect: Rect2, name: int) -> void:
	BookOfTheDead.draw_vignette(on, Rect2(rect.position, Vector2(rect.size.x * 0.34, rect.size.y)), name)
	BookOfTheDead.draw_signs(on, Rect2(rect.position + Vector2(rect.size.x * 0.38, rect.size.y * 0.12), Vector2(rect.size.x * 0.62, rect.size.y * 0.76)), name, NotebookInk.INK)
