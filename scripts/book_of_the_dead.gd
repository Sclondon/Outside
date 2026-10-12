class_name BookOfTheDead
extends Node
## The keepers of the gates of the underworld, and what he has found out about
## them. The dead went through a row of gates, each kept by a seated demon with
## the head of a beast and a knife in its fist, and each to be passed only by
## saying the keeper's name: the names were written in the Book of the Dead
## (spells 144 to 147) so that the dead man would have them by him.
##
## Here is the list of names (`NAMES`), each with the head it has in this game,
## how it is written in signs and which spell it is from; the pictures of them
## that a leaf, the challenge and the notebook all draw (`draw_vignette`,
## `draw_signs`); and, as a node, which leaves he has found in this level. That
## node is found (or made) under the level with `BookOfTheDead.of(node)`: it
## goes when the level does, so a level started again has forgotten them.
##
## How true it is: see the README, "The gate guardians".

signal changed

enum Head { CROCODILE, SNAKE, VULTURE, HIPPOPOTAMUS, RAM, JACKAL, HARE, LION, BULL }

## What the heads are called, in the order of `Head`.
const HEADS := ["Crocodile", "Snake", "Vulture", "Hippopotamus", "Ram", "Jackal", "Hare", "Lion", "Bull"]

## The keepers: the name in English, how the Egyptian is said, the signs it is
## written with (as `Hieroglyphs.write` takes them between braces), the head,
## and where the name is from. Levels keep a keeper by its place in this list:
## add to the end of it only.
const NAMES := [
	{"name": "He whose face is turned back", "says": "sḫd-ḥr", "signs": "s-x:d-Hr:Z1", "head": Head.HARE, "from": "Spells 144 and 147: the keeper of the first gate"},
	{"name": "Eavesdropper", "says": "smtw", "signs": "s-m-t:w", "head": Head.JACKAL, "from": "Spells 144 and 147: the watcher at the first gate"},
	{"name": "He who eats the foulness of his hindquarters", "says": "wnm ḥwꜣꜣt nt pḥwy.f", "signs": "w-n:m-A2-H-w-A-A-t-n:t-p:H-w-y-f", "head": Head.VULTURE, "from": "Spells 144 and 147: the keeper of the third gate"},
	{"name": "Watchful of face", "says": "rs-ḥr", "signs": "r:s-Hr:Z1", "head": Head.LION, "from": "Spells 144 and 147: the watcher at the third gate"},
	{"name": "Hostile of face, many-voiced", "says": "ḫsf-ḥr ꜥšꜣ-ḫrw", "signs": "x:s-f-Hr:Z1-a:S-A-xrw", "head": Head.RAM, "from": "Spells 144 and 147: the keeper of the fourth gate"},
	{"name": "Watchful of heart", "says": "rs-ib", "signs": "r:s-ib:Z1", "head": Head.JACKAL, "from": "Spells 144 and 147: the watcher at the fourth gate"},
	{"name": "He who lives on snakes", "says": "ꜥnḫ m fnṯw", "signs": "anx-n:x-m-f:n:T-w-I12", "head": Head.SNAKE, "from": "Spells 144 and 147: the keeper of the fifth gate"},
	{"name": "Hippopotamus-faced, raging of power", "says": "db-ḥr khꜣ-ꜣt", "signs": "d-b-Hr:Z1-k-h-A-A-t", "head": Head.HIPPOPOTAMUS, "from": "Spells 144 and 147: the herald at the fifth gate"},
	{"name": "Seizer of bread, raging of voice", "says": "iṯ-t khꜣ-ḫrw", "signs": "i-T-t:X4-k-h-A-xrw", "head": Head.CROCODILE, "from": "Spells 144 and 147: the keeper of the sixth gate"},
	{"name": "Sharpest of them", "says": "mds-sn", "signs": "m-d:s-s:n:Z2", "head": Head.VULTURE, "from": "Spells 144 and 147: the keeper of the seventh gate"},
	{"name": "Loud of voice", "says": "ꜥꜣ-ḫrw", "signs": "aA:a-xrw-A2", "head": Head.LION, "from": "Spells 144 and 147: the watcher at the seventh gate"},
	{"name": "Long-horned bull", "says": "ngꜣw", "signs": "n:g-A-w-F1", "head": Head.BULL, "from": "Spell 146: the keeper of the fourth portal"},
	{"name": "He who stretches out his brow", "says": "dwn-ḥꜣt", "signs": "d-w-n:H-A-t", "head": Head.RAM, "from": "Spells 144 and 147: the keeper of the second gate"},
]

## The names alone, for a list to choose from (the level editor's): in the order of `NAMES`.
const TITLES := ["He whose face is turned back", "Eavesdropper", "He who eats the foulness of his hindquarters", "Watchful of face", "Hostile of face, many-voiced",
	"Watchful of heart", "He who lives on snakes", "Hippopotamus-faced, raging of power", "Seizer of bread, raging of voice", "Sharpest of them", "Loud of voice",
	"Long-horned bull", "He who stretches out his brow"]
## And for a leaf, which may also be left to take the name of the nearest keeper.
const LEAF_TITLES := ["The nearest keeper's", "He whose face is turned back", "Eavesdropper", "He who eats the foulness of his hindquarters", "Watchful of face",
	"Hostile of face, many-voiced", "Watchful of heart", "He who lives on snakes", "Hippopotamus-faced, raging of power", "Seizer of bread, raging of voice",
	"Sharpest of them", "Loud of voice", "Long-horned bull", "He who stretches out his brow"]

## The colour of each head, in the order of `Head`: the model's and the drawing's.
const HIDES := [Color(0.27, 0.42, 0.24), Color(0.52, 0.5, 0.2), Color(0.86, 0.74, 0.62), Color(0.42, 0.4, 0.5), Color(0.82, 0.74, 0.58),
	Color(0.1, 0.1, 0.12), Color(0.72, 0.58, 0.38), Color(0.78, 0.58, 0.26), Color(0.2, 0.14, 0.12)]
const LINEN := Color(0.9, 0.86, 0.74)
const LAPIS := Color(0.13, 0.22, 0.5)
const PAPYRUS := Color(0.86, 0.77, 0.55)
const PAPYRUS_DARK := Color(0.7, 0.6, 0.38)
const INK := Color(0.13, 0.1, 0.08)
const RUBRIC := Color(0.62, 0.16, 0.1)

## The leaves he has found in this level, as places in `NAMES`, in the order he found them.
var found: Array[int] = []


static var _pictures := {}


## The level's own: the one under the level that `node` is in (it is made if
## there is none yet). Null if `node` is in no scene.
static func of(node: Node) -> BookOfTheDead:
	if node == null or not node.is_inside_tree():
		return null
	var root := node.get_tree().root
	var level := node
	while level.get_parent() != null and level.get_parent() != root:
		level = level.get_parent()
	var book := level.get_node_or_null(^"BookOfTheDead") as BookOfTheDead
	if book == null:
		book = BookOfTheDead.new()
		book.name = "BookOfTheDead"
		level.add_child(book)
	return book


## Whether he has the leaf with this keeper's name on it.
func has(who: int) -> bool:
	return found.has(who)


## He has found the leaf of this keeper. Says whether it is new to him.
func take(who: int) -> bool:
	if who < 0 or who >= NAMES.size() or found.has(who):
		return false
	found.append(who)
	changed.emit()
	return true


## Gives every leaf that has no name chosen the name of the nearest keeper that
## has no leaf yet: nearest first, so that two leaves do not take the same.
## Called by a leaf whenever it needs its name: it comes out the same each time.
func name_leaves() -> void:
	var taken: Array[int] = []
	var loose: Array[BookPage] = []
	for leaf: Node in get_tree().get_nodes_in_group(&"book_pages"):
		var page := leaf as BookPage
		if page == null or of(page) != self:
			continue
		if page.who >= 0:
			page.name_is = page.who
			taken.append(page.who)
		else:
			page.name_is = -1
			loose.append(page)
	var keepers: Array[GateGuardian] = []
	for keeper: Node in get_tree().get_nodes_in_group(&"gate_guardians"):
		if keeper is GateGuardian and of(keeper) == self:
			keepers.append(keeper)
	while not loose.is_empty():
		var best := INF
		var best_page: BookPage
		var best_keeper: GateGuardian
		for page in loose:
			for keeper in keepers:
				if taken.has(keeper.who):
					continue
				var far := page.global_position.distance_squared_to(keeper.global_position)
				if far < best:
					best = far
					best_page = page
					best_keeper = keeper
		if best_page == null:
			break
		best_page.name_is = best_keeper.who
		taken.append(best_keeper.who)
		loose.erase(best_page)
	# (a leaf with no keeper left for it is a leaf of the first name nobody has)
	for page in loose:
		for who in NAMES.size():
			if not taken.has(who):
				page.name_is = who
				taken.append(who)
				break


## The three names a keeper offers: his own and two that are not, in an order.
## It comes from `seed` and from how many times he has been answered wrongly
## (`round`), and from nothing else: the same level deals the same names.
static func deal(who: int, seed: int, round: int) -> Array[int]:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([seed, who, round, "gate"])
	var others: Array[int] = []
	for other in NAMES.size():
		if other != who:
			others.append(other)
	var dealt: Array[int] = [who]
	for n in 2:
		var pick := dice.randi_range(0, others.size() - 1)
		dealt.append(others[pick])
		others.remove_at(pick)
	# (and in an order of its own)
	for n in range(2, 0, -1):
		var swap := dice.randi_range(0, n)
		var held := dealt[n]
		dealt[n] = dealt[swap]
		dealt[swap] = held
	return dealt


## The name as `Hieroglyphs.write` takes it: its signs, and what they mean.
static func text(who: int) -> String:
	return "{%s|%s}" % [NAMES[who]["signs"], NAMES[who]["name"]]


## A picture of the name in signs, drawn in ink: white where the ink is, to be
## coloured by whatever draws it. Made once for each name and kept.
static func picture(who: int) -> ImageTexture:
	if _pictures.has(who):
		return _pictures[who]
	var layout := Hieroglyphs.write(text(who), {"rules": false, "wrap": 6})
	var field := Hieroglyphs.picture(layout)
	field.clear_mipmaps()
	field.convert(Image.FORMAT_RGBA8)
	# (the picture says how far inside a sign each dot is, a half at its edge: here that is made a clean edge)
	var dots := field.get_data()
	for at in range(0, dots.size(), 4):
		dots[at] = 255
		dots[at + 1] = 255
		dots[at + 2] = 255
		dots[at + 3] = clampi(int((dots[at + 3] - 127.5) * 5.0 + 127.5), 0, 255)
	var inked := Image.create_from_data(field.get_width(), field.get_height(), false, Image.FORMAT_RGBA8, dots)
	inked.generate_mipmaps()
	var made := ImageTexture.create_from_image(inked)
	_pictures[who] = made
	return made


## Writes the name in signs, as large as will go into `rect` and in the middle of it.
static func draw_signs(on: CanvasItem, rect: Rect2, who: int, colour := INK, square := 0.0) -> void:
	var signs := picture(who)
	var size := signs.get_size()
	var fit := minf(rect.size.x / size.x, rect.size.y / size.y)
	# (a short name is not written bigger than `square` to a sign's square, if that is given)
	if square > 0.0:
		fit = minf(fit, square / Hieroglyphs.DOTS)
	var drawn := size * fit
	on.draw_texture_rect(signs, Rect2(rect.get_center() - drawn * 0.5, drawn), false, colour)


## A leaf of papyrus to draw on: its ground, the weave of it, a ruled border.
static func draw_papyrus(on: CanvasItem, rect: Rect2, border := true) -> void:
	on.draw_rect(rect, PAPYRUS)
	var step := 7.0
	var y := rect.position.y + step
	var n := 0
	while y < rect.end.y:
		on.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(PAPYRUS_DARK, 0.2 + 0.12 * ((n * 7) % 3)), 1.0)
		y += step
		n += 1
	var x := rect.position.x + step * 1.7
	while x < rect.end.x:
		on.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(PAPYRUS_DARK, 0.16), 1.0)
		x += step * 1.7
	on.draw_rect(rect, PAPYRUS_DARK.darkened(0.25), false, 2.0)
	if border:
		on.draw_rect(rect.grow(-9.0), INK, false, 2.0)
		on.draw_rect(rect.grow(-14.0), RUBRIC, false, 1.5)


## Draws a keeper as the papyri draw him: seated on a block, wrapped, with the
## head of his beast and a knife upright in his fist, looking to the right.
static func draw_vignette(on: CanvasItem, rect: Rect2, who: int) -> void:
	draw_keeper(on, rect, NAMES[who]["head"])


## The same, for a head.
static func draw_keeper(on: CanvasItem, rect: Rect2, head: int) -> void:
	# (it is drawn in a box 100 wide and 130 tall, the ground 112 down it, fitted into `rect`)
	var fit := minf(rect.size.x / 100.0, rect.size.y / 130.0)
	var from := rect.get_center() - Vector2(50.0, 53.0) * fit
	var pen := maxf(1.2, 1.3 * fit)
	var put := func(points: Array, fill: Color, line := true) -> void:
		var placed := PackedVector2Array()
		for point: Vector2 in points:
			placed.append(from + point * fit)
		on.draw_colored_polygon(placed, fill)
		if line:
			placed.append(placed[0])
			on.draw_polyline(placed, INK, pen, true)
	var stroke := func(points: Array, colour: Color, width: float) -> void:
		var placed := PackedVector2Array()
		for point: Vector2 in points:
			placed.append(from + point * fit)
		on.draw_polyline(placed, colour, width * fit, true)
	var hide: Color = HIDES[head]
	# The ground, and the block he sits on.
	put.call([Vector2(6, 106), Vector2(94, 106), Vector2(94, 112), Vector2(6, 112)], RUBRIC.lightened(0.15))
	put.call([Vector2(16, 78), Vector2(46, 78), Vector2(46, 106), Vector2(16, 106)], Color(0.24, 0.5, 0.42))
	put.call([Vector2(16, 62), Vector2(22, 62), Vector2(22, 78), Vector2(16, 78)], Color(0.24, 0.5, 0.42))
	# The wig down his back, his wrapped body, and the bands round it.
	if head != Head.LION and head != Head.SNAKE:
		put.call([Vector2(27, 20), Vector2(38, 30), Vector2(40, 48), Vector2(33, 48), Vector2(30, 40), Vector2(26, 50), Vector2(22, 46), Vector2(23, 28)], LAPIS)
	put.call([Vector2(27, 42), Vector2(44, 42), Vector2(46, 68), Vector2(62, 68), Vector2(65, 73), Vector2(64, 99), Vector2(74, 101), Vector2(74, 106), Vector2(52, 106),
		Vector2(52, 85), Vector2(26, 85), Vector2(24, 70)], LINEN)
	for band: Array in [[Vector2(26, 56), Vector2(45, 56)], [Vector2(25, 68), Vector2(46, 68)], [Vector2(52, 78), Vector2(64, 78)], [Vector2(52, 92), Vector2(64, 92)]]:
		stroke.call(band, RUBRIC, 1.6)
	# His neck, and the collar over it.
	put.call([Vector2(32, 44), Vector2(32, 34), Vector2(42, 34), Vector2(42, 44)], hide)
	put.call([Vector2(27, 42), Vector2(44, 42), Vector2(44, 47), Vector2(27, 47)], Color(0.86, 0.66, 0.2))
	# His arm, and the knife upright in his fist.
	stroke.call([Vector2(36, 48), Vector2(41, 63), Vector2(57, 63)], INK, 7.0)
	stroke.call([Vector2(36, 48), Vector2(41, 63), Vector2(57, 63)], LINEN if head != Head.BULL else LINEN, 4.6)
	put.call([Vector2(55, 58), Vector2(52, 40), Vector2(57, 20), Vector2(62, 40), Vector2(60, 58)], Color(0.9, 0.9, 0.84))
	stroke.call([Vector2(57.5, 58), Vector2(57.5, 70)], INK, 4.4)
	stroke.call([Vector2(57.5, 59), Vector2(57.5, 69)], Color(0.86, 0.66, 0.2), 2.4)
	# His head, over the knife; and the eye.
	_draw_head(put, stroke, head, hide)
	var eye: Vector2 = [Vector2(41, 22), Vector2(45, 10), Vector2(42, 18), Vector2(42, 19), Vector2(41, 20), Vector2(40, 23), Vector2(41, 21), Vector2(42, 20), Vector2(41, 21)][head]
	on.draw_circle(from + eye * fit, 2.1 * fit, Color(0.95, 0.9, 0.7), true, -1.0, true)
	on.draw_circle(from + eye * fit, 1.0 * fit, INK, true, -1.0, true)


# The head of each beast, from the side, on a neck that ends at (37, 36).
static func _draw_head(put: Callable, stroke: Callable, head: int, hide: Color) -> void:
	var pale := Color(0.93, 0.9, 0.8)
	match head:
		Head.JACKAL:
			put.call([Vector2(30, 35), Vector2(29, 22), Vector2(31, 4), Vector2(36, 16), Vector2(38, 4), Vector2(42, 17), Vector2(48, 21), Vector2(64, 27), Vector2(64, 30.5),
				Vector2(49, 32), Vector2(43, 36)], hide)
			stroke.call([Vector2(50, 29.5), Vector2(63, 29.5)], Color(0.5, 0.48, 0.5), 0.8)
		Head.CROCODILE:
			put.call([Vector2(30, 35), Vector2(30, 24), Vector2(35, 19), Vector2(39, 15), Vector2(44, 15), Vector2(47, 21), Vector2(70, 23), Vector2(73, 26), Vector2(71, 31),
				Vector2(47, 32), Vector2(43, 36)], hide)
			stroke.call([Vector2(47, 28), Vector2(50, 30), Vector2(53, 28), Vector2(56, 30), Vector2(59, 28), Vector2(62, 30), Vector2(65, 28), Vector2(68, 30), Vector2(71, 28)], pale, 1.2)
		Head.SNAKE:
			put.call([Vector2(31, 36), Vector2(24, 26), Vector2(26, 12), Vector2(33, 4), Vector2(42, 3), Vector2(52, 6), Vector2(56, 10), Vector2(53, 14), Vector2(45, 15),
				Vector2(46, 26), Vector2(43, 36)], hide)
			stroke.call([Vector2(34, 32), Vector2(31, 22), Vector2(33, 12)], hide.darkened(0.45), 1.4)
			stroke.call([Vector2(55, 11.5), Vector2(62, 12), Vector2(65, 9)], RUBRIC, 0.9)
			stroke.call([Vector2(62, 12), Vector2(65, 14.5)], RUBRIC, 0.9)
		Head.VULTURE:
			put.call([Vector2(32, 36), Vector2(32, 24), Vector2(35, 15), Vector2(41, 12), Vector2(47, 14), Vector2(50, 18), Vector2(50, 25), Vector2(44, 28), Vector2(43, 36)], hide)
			put.call([Vector2(50, 17), Vector2(58, 19), Vector2(62, 24), Vector2(60, 31), Vector2(57, 25), Vector2(50, 25)], Color(0.3, 0.26, 0.22))
			put.call([Vector2(29, 34), Vector2(45, 34), Vector2(46, 39), Vector2(28, 39)], pale)
		Head.HIPPOPOTAMUS:
			put.call([Vector2(29, 35), Vector2(29, 20), Vector2(31, 13), Vector2(35, 16), Vector2(42, 15), Vector2(50, 18), Vector2(62, 17), Vector2(67, 22), Vector2(67, 32),
				Vector2(60, 37), Vector2(48, 35), Vector2(43, 37)], hide)
			put.call([Vector2(58, 34), Vector2(60, 28), Vector2(62, 34)], pale)
			stroke.call([Vector2(63, 20), Vector2(65, 21)], INK, 1.2)
		Head.RAM:
			put.call([Vector2(30, 35), Vector2(30, 20), Vector2(36, 14), Vector2(45, 15), Vector2(55, 22), Vector2(58, 27), Vector2(56, 31), Vector2(48, 31), Vector2(43, 36)], hide)
			stroke.call([Vector2(38, 14), Vector2(31, 13), Vector2(26, 19), Vector2(27, 27), Vector2(33, 30), Vector2(38, 26), Vector2(36, 21), Vector2(33, 22)], INK, 4.4)
			stroke.call([Vector2(38, 14), Vector2(31, 13), Vector2(26, 19), Vector2(27, 27), Vector2(33, 30), Vector2(38, 26), Vector2(36, 21), Vector2(33, 22)], Color(0.6, 0.48, 0.3), 2.8)
		Head.HARE:
			put.call([Vector2(32, 17), Vector2(28, -6), Vector2(33, -8), Vector2(37, 15)], hide)
			put.call([Vector2(37, 16), Vector2(37, -7), Vector2(42, -6), Vector2(42, 16)], hide)
			put.call([Vector2(31, 35), Vector2(31, 22), Vector2(35, 16), Vector2(42, 15), Vector2(49, 19), Vector2(54, 25), Vector2(53, 29), Vector2(46, 31), Vector2(43, 36)], hide)
		Head.LION:
			put.call([Vector2(24, 44), Vector2(22, 26), Vector2(26, 14), Vector2(34, 9), Vector2(40, 12), Vector2(38, 30), Vector2(42, 46), Vector2(34, 50), Vector2(28, 48)], hide.darkened(0.4))
			put.call([Vector2(33, 35), Vector2(33, 20), Vector2(38, 13), Vector2(46, 13), Vector2(53, 17), Vector2(57, 23), Vector2(56, 30), Vector2(49, 33), Vector2(44, 36)], hide)
			put.call([Vector2(35, 15), Vector2(36, 9), Vector2(41, 10), Vector2(41, 14)], hide)
			stroke.call([Vector2(53, 26), Vector2(56.5, 25.5)], INK, 1.3)
		Head.BULL:
			stroke.call([Vector2(37, 15), Vector2(32, 6), Vector2(34, -5)], INK, 4.2)
			stroke.call([Vector2(37, 15), Vector2(32, 6), Vector2(34, -5)], pale, 2.6)
			stroke.call([Vector2(42, 15), Vector2(48, 7), Vector2(48, -5)], INK, 4.2)
			stroke.call([Vector2(42, 15), Vector2(48, 7), Vector2(48, -5)], pale, 2.6)
			put.call([Vector2(30, 35), Vector2(30, 20), Vector2(36, 14), Vector2(46, 15), Vector2(54, 21), Vector2(59, 28), Vector2(57, 33), Vector2(49, 33), Vector2(43, 36)], hide)
			put.call([Vector2(30, 19), Vector2(24, 17), Vector2(26, 22), Vector2(31, 23)], hide)
			put.call([Vector2(54, 28), Vector2(59, 28), Vector2(57, 33), Vector2(53, 33)], pale)
