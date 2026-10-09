class_name NotebookInk
## Pencil, ink and paper for the notebook (scripts/menu.gd): everything on its
## pages is drawn in code by these, onto whatever CanvasItem is handed over.
## Lines waver a little and writing leans a little, each always the same way
## for the same line or words, so nothing shimmers when a page is drawn again.
##
## The writing is in Patrick Hand (fonts/PatrickHand-Regular.ttf, by Patrick
## Wagesreiter, under the SIL Open Font Licence: fonts/OFL.txt). If the file is
## not there the engine's own font is used.

const FONT := "res://fonts/PatrickHand-Regular.ttf"

const PAPER := Color(0.925, 0.885, 0.775)
const PAPER_DARK := Color(0.80, 0.74, 0.61)
const CARD := Color(0.955, 0.93, 0.85)
const PENCIL := Color(0.27, 0.26, 0.28)
const FAINT := Color(0.27, 0.26, 0.28, 0.62)
const INK := Color(0.15, 0.12, 0.12)
const BLUE := Color(0.15, 0.20, 0.38)
const RED := Color(0.64, 0.20, 0.15)
const RULE := Color(0.36, 0.48, 0.62, 0.30)
const LEATHER := Color(0.34, 0.21, 0.13)
const LEATHER_DARK := Color(0.22, 0.13, 0.08)

## Drawings by name, for `sketch`: each is a list of strokes, a stroke a run of
## x, y pairs across a square 0..1 (y down). A stroke of four numbers after
## "o" is an oval: its middle, and half its width and height.
const SKETCHES := {
	"pyramid": [
		[0.30, 0.70, 0.52, 0.25, 0.78, 0.70], [0.52, 0.25, 0.60, 0.70],
		[0.536, 0.34, 0.744, 0.70], [0.552, 0.43, 0.708, 0.70], [0.568, 0.52, 0.672, 0.70], [0.584, 0.61, 0.636, 0.70],
		[0.40, 0.56, 0.47, 0.56], [0.37, 0.63, 0.46, 0.63], [0.45, 0.47, 0.49, 0.47],
		[0.05, 0.70, 0.17, 0.48, 0.29, 0.70], [0.17, 0.48, 0.21, 0.70],
		[0.0, 0.72, 0.2, 0.70, 0.45, 0.73, 0.7, 0.70, 1.0, 0.73],
		[0.08, 0.86, 0.3, 0.80, 0.5, 0.86, 0.75, 0.81, 0.95, 0.87],
		["o", 0.84, 0.20, 0.06, 0.06],
		[0.90, 0.72, 0.89, 0.55, 0.91, 0.42], [0.91, 0.42, 0.80, 0.42], [0.91, 0.42, 0.83, 0.33], [0.91, 0.42, 0.94, 0.31],
		[0.91, 0.42, 1.0, 0.37], [0.91, 0.42, 0.99, 0.47],
	],
	"yard": [
		[0.03, 0.76, 0.97, 0.76],
		[0.12, 0.54, 0.34, 0.54, 0.34, 0.76, 0.12, 0.76, 0.12, 0.54], [0.12, 0.54, 0.34, 0.76], [0.34, 0.54, 0.12, 0.76],
		[0.18, 0.38, 0.32, 0.38, 0.32, 0.54, 0.18, 0.54, 0.18, 0.38],
		[0.50, 0.76, 0.55, 0.22], [0.63, 0.76, 0.66, 0.22],
		[0.515, 0.66, 0.635, 0.66], [0.525, 0.55, 0.642, 0.55], [0.535, 0.44, 0.648, 0.44], [0.545, 0.33, 0.655, 0.33],
		[0.88, 0.76, 0.88, 0.18, 0.76, 0.18], [0.88, 0.28, 0.80, 0.18], [0.77, 0.18, 0.78, 0.50],
		["o", 0.78, 0.53, 0.02, 0.03],
		[0.05, 0.90, 0.25, 0.86, 0.5, 0.91, 0.8, 0.87, 0.97, 0.90],
	],
	"scarab": [
		["o", 0.5, 0.20, 0.11, 0.08], ["o", 0.5, 0.36, 0.20, 0.10], ["o", 0.5, 0.63, 0.24, 0.23], [0.5, 0.45, 0.5, 0.86],
		[0.30, 0.36, 0.15, 0.28, 0.11, 0.17], [0.27, 0.56, 0.10, 0.55, 0.05, 0.66], [0.31, 0.76, 0.16, 0.83, 0.13, 0.95],
		[0.70, 0.36, 0.85, 0.28, 0.89, 0.17], [0.73, 0.56, 0.90, 0.55, 0.95, 0.66], [0.69, 0.76, 0.84, 0.83, 0.87, 0.95],
		[0.36, 0.55, 0.40, 0.75], [0.64, 0.55, 0.60, 0.75],
	],
	"pot": [
		[0.37, 0.14, 0.63, 0.14], [0.39, 0.14, 0.42, 0.27, 0.27, 0.43, 0.24, 0.60, 0.34, 0.80, 0.5, 0.86],
		[0.61, 0.14, 0.58, 0.27, 0.73, 0.43, 0.76, 0.60, 0.66, 0.80, 0.5, 0.86],
		[0.26, 0.48, 0.74, 0.48], [0.24, 0.58, 0.76, 0.58],
		[0.26, 0.57, 0.31, 0.49, 0.36, 0.57, 0.41, 0.49, 0.46, 0.57, 0.51, 0.49, 0.56, 0.57, 0.61, 0.49, 0.66, 0.57, 0.71, 0.49, 0.75, 0.57],
	],
	"eye": [
		[0.10, 0.46, 0.30, 0.31, 0.55, 0.28, 0.80, 0.36, 0.92, 0.46], [0.10, 0.46, 0.35, 0.56, 0.60, 0.56, 0.80, 0.50, 0.92, 0.46],
		["o", 0.50, 0.42, 0.09, 0.10], [0.08, 0.26, 0.35, 0.15, 0.65, 0.14, 0.95, 0.25],
		[0.45, 0.56, 0.43, 0.82], [0.60, 0.56, 0.74, 0.76, 0.88, 0.82, 0.95, 0.74, 0.89, 0.68],
	],
	"ankh": [
		["o", 0.5, 0.26, 0.13, 0.18], [0.5, 0.44, 0.5, 0.92], [0.26, 0.52, 0.74, 0.52],
	],
	"leaf": [
		[0.10, 0.90, 0.30, 0.66, 0.52, 0.42, 0.90, 0.10], [0.30, 0.66, 0.26, 0.40, 0.48, 0.18, 0.90, 0.10],
		[0.30, 0.66, 0.56, 0.68, 0.80, 0.44, 0.90, 0.10], [0.40, 0.55, 0.38, 0.36], [0.40, 0.55, 0.60, 0.55],
		[0.56, 0.39, 0.56, 0.24], [0.56, 0.39, 0.74, 0.38],
	],
}

## The signs `signs` draws, one after another: stand-ins, in the same form as
## SKETCHES, for a row of hieroglyphs until there are real ones to show.
const SIGNS := [
	[[0.5, 0.95, 0.5, 0.1], [0.5, 0.1, 0.72, 0.3, 0.5, 0.5]],
	[[0.05, 0.5, 0.2, 0.36, 0.35, 0.5, 0.5, 0.36, 0.65, 0.5, 0.8, 0.36, 0.95, 0.5]],
	[["o", 0.5, 0.5, 0.3, 0.3], ["o", 0.5, 0.5, 0.05, 0.05]],
	[[0.08, 0.5, 0.5, 0.32, 0.92, 0.5, 0.5, 0.68, 0.08, 0.5]],
	[["o", 0.36, 0.30, 0.14, 0.13], [0.22, 0.30, 0.08, 0.34], [0.40, 0.42, 0.60, 0.50, 0.86, 0.50, 0.70, 0.72, 0.44, 0.72, 0.34, 0.50], [0.52, 0.72, 0.52, 0.92], [0.62, 0.72, 0.62, 0.92]],
	[[0.12, 0.72, 0.2, 0.42, 0.5, 0.28, 0.8, 0.42, 0.88, 0.72, 0.12, 0.72]],
	[["o", 0.5, 0.24, 0.13, 0.16], [0.5, 0.40, 0.5, 0.92], [0.28, 0.50, 0.72, 0.50]],
]

static var _font: Font
## How everything is turned and moved while something on a card is being drawn (see `card`).
static var base := Transform2D.IDENTITY


static func font() -> Font:
	if _font == null:
		_font = load(FONT) as Font if ResourceLoader.exists(FONT) else ThemeDB.fallback_font
	return _font


## A number from -1 to 1 that is always the same for the same `n`.
static func chance(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0


## A line drawn by hand: not quite straight.
static func line(on: CanvasItem, from: Vector2, to: Vector2, colour := PENCIL, width := 1.7, shake := 0.9) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var steps := maxi(2, int(length / 14.0))
	var across := (to - from).orthogonal() / length
	var key := from.x * 0.37 + from.y * 1.31 + to.x * 0.73 + to.y * 0.11
	var points := PackedVector2Array()
	for i in steps + 1:
		var off := chance(key + i * 1.7) * shake * (0.3 if i == 0 or i == steps else 1.0)
		points.append(from.lerp(to, float(i) / steps) + across * off)
	on.draw_polyline(points, colour, width, true)


## A run of such lines through `points`.
static func path(on: CanvasItem, points: PackedVector2Array, colour := PENCIL, width := 1.7, shake := 0.9) -> void:
	for i in points.size() - 1:
		line(on, points[i], points[i + 1], colour, width, shake)


## A box ruled by hand: its corners cross a little.
static func box(on: CanvasItem, rect: Rect2, colour := PENCIL, width := 1.7) -> void:
	var over := 2.5
	line(on, rect.position - Vector2(over, 0), Vector2(rect.end.x + over, rect.position.y), colour, width)
	line(on, Vector2(rect.end.x, rect.position.y - over), rect.end + Vector2(0, over), colour, width)
	line(on, rect.end + Vector2(over, 0), Vector2(rect.position.x - over, rect.end.y), colour, width)
	line(on, Vector2(rect.position.x, rect.end.y + over), rect.position - Vector2(0, over), colour, width)


## A ring put round something with one turn of the wrist: an oval that does not quite meet itself.
static func ring(on: CanvasItem, centre: Vector2, radii: Vector2, colour := RED, width := 2.2, key := 0.0) -> void:
	var points := PackedVector2Array()
	var start := -2.4 + chance(key + centre.x) * 0.3
	for i in 31:
		var t := float(i) / 30.0
		var angle := start + t * TAU * 1.07
		var swell := 1.0 + 0.05 * sin(angle * 2.0 + key) + 0.045 * (t - 0.5)
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * swell)
	on.draw_polyline(points, colour, width, true)


## A tick, as tall as `reach`, its foot at `at`.
static func tick(on: CanvasItem, at: Vector2, reach: float, colour := RED, width := 3.0) -> void:
	on.draw_polyline([at + Vector2(-reach * 0.42, -reach * 0.38), at, at + Vector2(reach * 0.36, -reach * 0.62), at + Vector2(reach * 0.8, -reach * 1.15)], colour, width, true)


## A word struck out: two quick strokes through it.
static func strike(on: CanvasItem, from: Vector2, to: Vector2, colour := PENCIL) -> void:
	line(on, from + Vector2(0, 1.5), to + Vector2(0, -2.5), colour, 2.0, 1.2)
	line(on, from + Vector2(3, -2.5), to + Vector2(-2, 1.5), colour, 1.6, 1.2)


## How wide some writing is.
static func width_of(text: String, size: int) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Writes a line, its baseline starting at `at`, leaning a hair one way or the
## other (or by `lean`, in radians, if that is given). Returns how wide it came out.
static func write(on: CanvasItem, at: Vector2, text: String, size := 22, colour := INK, lean := INF) -> float:
	if lean == INF:
		lean = chance(float(text.hash() % 977)) * 0.011
	_place(on, at, lean)
	on.draw_string(font(), Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
	_back(on)
	return width_of(text, size)


## The same, with its middle at `at`.
static func write_mid(on: CanvasItem, at: Vector2, text: String, size := 22, colour := INK, lean := INF) -> float:
	var wide := width_of(text, size)
	write(on, at - Vector2(wide * 0.5, 0.0), text, size, colour, lean)
	return wide


## Breaks writing into lines no wider than `wide`.
static func wrap(text: String, wide: float, size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for paragraph in text.split("\n"):
		var so_far := ""
		for word in paragraph.split(" ", false):
			var longer := word if so_far == "" else so_far + " " + word
			if so_far != "" and width_of(longer, size) > wide:
				lines.append(so_far)
				so_far = word
			else:
				so_far = longer
		lines.append(so_far)
	return lines


## Writes lines one under another, `lead` apart, the first baseline at `at`. Returns how far down they went.
static func write_lines(on: CanvasItem, at: Vector2, lines: PackedStringArray, size := 22, colour := INK, lead := 30.0) -> float:
	for i in lines.size():
		# (no hand keeps a margin dead straight)
		write(on, at + Vector2(chance(i * 3.1 + at.y) * 1.5, i * lead), lines[i], size, colour)
	return lines.size() * lead


## A page: cream paper, `ruling` on it (0 plain, 1 ruled in lines `gap` apart
## from `first` down, 2 squared), a stain or two, and the shadow of the gutter
## down the side the spine is on (`spine`: 1 at its right, -1 at its left).
static func paper(on: CanvasItem, size: Vector2, ruling := 1, spine := 1, key := 0.0, first := 70.0, gap := 30.0) -> void:
	on.draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	# Foxing, and the ring a cup left
	for i in 9:
		var at := Vector2(0.5 + 0.48 * chance(key + i * 5.3), 0.5 + 0.48 * chance(key + i * 9.1)) * size
		on.draw_circle(at, 2.0 + 5.0 * absf(chance(key + i * 2.2)), Color(0.55, 0.38, 0.18, 0.07), true, -1.0, true)
	var cup := Vector2(0.5 + 0.3 * chance(key + 40.0), 0.5 + 0.36 * chance(key + 41.0)) * size
	on.draw_arc(cup, 46.0, chance(key) * 3.0, chance(key) * 3.0 + 4.6, 40, Color(0.5, 0.33, 0.14, 0.09), 4.0, true)
	on.draw_arc(cup, 43.0, chance(key) * 3.0 + 0.6, chance(key) * 3.0 + 3.4, 30, Color(0.5, 0.33, 0.14, 0.05), 7.0, true)
	if ruling == 1:
		var y := first
		while y < size.y - 12.0:
			on.draw_line(Vector2(0.0, y), Vector2(size.x, y), RULE, 1.2)
			y += gap
	elif ruling == 2:
		var squared := Color(RULE, 0.17)
		var x := 20.0
		while x < size.x:
			on.draw_line(Vector2(x, 0.0), Vector2(x, size.y), squared, 1.0)
			x += 20.0
		var down := 20.0
		while down < size.y:
			on.draw_line(Vector2(0.0, down), Vector2(size.x, down), squared, 1.0)
			down += 20.0
	# The gutter, and the worn outer edges
	var dark := Color(0.25, 0.16, 0.08, 0.30)
	var clear := Color(0.25, 0.16, 0.08, 0.0)
	var inner := size.x if spine > 0 else 0.0
	var reach := -46.0 * spine
	on.draw_polygon([Vector2(inner, 0), Vector2(inner + reach, 0), Vector2(inner + reach, size.y), Vector2(inner, size.y)], [dark, clear, clear, dark])
	var outer := 0.0 if spine > 0 else size.x
	var edge := Color(0.45, 0.32, 0.16, 0.16)
	on.draw_polygon([Vector2(outer, 0), Vector2(outer - reach * 0.4, 0), Vector2(outer - reach * 0.4, size.y), Vector2(outer, size.y)], [edge, clear, clear, edge])
	on.draw_polygon([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, 12), Vector2(0, 12)], [edge, edge, clear, clear])
	on.draw_polygon([Vector2(0, size.y), Vector2(size.x, size.y), Vector2(size.x, size.y - 14), Vector2(0, size.y - 14)], [edge, edge, clear, clear])


## Draws strokes (see SKETCHES) into `rect`.
static func strokes(on: CanvasItem, rect: Rect2, list: Array, colour := PENCIL, width := 1.7) -> void:
	for stroke: Array in list:
		if stroke[0] is String:
			var centre := rect.position + Vector2(stroke[1], stroke[2]) * rect.size
			ring(on, centre, Vector2(stroke[3], stroke[4]) * minf(rect.size.x, rect.size.y), colour, width, centre.x)
			continue
		var points := PackedVector2Array()
		for i in range(0, stroke.size(), 2):
			points.append(rect.position + Vector2(stroke[i], stroke[i + 1]) * rect.size)
		path(on, points, colour, width, 0.6)


## Draws something into `rect`: one of SKETCHES by name, a picture, or whatever
## a Callable(on, rect) draws. (See Notebook, scripts/notebook.gd.)
static func sketch(on: CanvasItem, what: Variant, rect: Rect2, colour := PENCIL) -> void:
	if what is Callable:
		(what as Callable).call(on, rect)
	elif what is Texture2D:
		var picture := what as Texture2D
		var fit := minf(rect.size.x / picture.get_width(), rect.size.y / picture.get_height())
		var size := Vector2(picture.get_size()) * fit
		on.draw_texture_rect(picture, Rect2(rect.position + (rect.size - size) * 0.5, size), false)
	elif what is String and SKETCHES.has(what):
		# (kept square, so that a round thing stays round)
		var side := minf(rect.size.x, rect.size.y)
		var wide := minf(rect.size.x, side * 1.5)
		strokes(on, Rect2(rect.position + (rect.size - Vector2(wide, side)) * 0.5, Vector2(wide, side)), SKETCHES[what], colour)
	elif what is String and what == "glyphs":
		signs(on, rect, 7, colour)
	elif what is String:
		write(on, rect.position + Vector2(0.0, rect.size.y * 0.7), what, int(rect.size.y * 0.6), colour)


## A row of `count` signs across `rect`, between two ruled lines, as an
## inscription is copied. They are stand-ins: see SIGNS.
static func signs(on: CanvasItem, rect: Rect2, count := 7, colour := PENCIL) -> void:
	var side := minf(rect.size.y - 8.0, rect.size.x / count)
	line(on, rect.position, rect.position + Vector2(side * count + 8.0, 0.0), colour, 1.4)
	line(on, rect.position + Vector2(0.0, rect.size.y), rect.position + Vector2(side * count + 8.0, rect.size.y), colour, 1.4)
	for i in count:
		var cell := Rect2(rect.position + Vector2(4.0 + i * side, (rect.size.y - side) * 0.5), Vector2(side, side)).grow(-side * 0.08)
		strokes(on, cell, SIGNS[(i * 3 + 1) % SIGNS.size()], colour, 1.8)


## A dab of paint from the box.
static func dab(on: CanvasItem, rect: Rect2, colour: Color) -> void:
	var centre := rect.get_center()
	var radii := rect.size * 0.42
	var points := PackedVector2Array()
	for i in 18:
		var angle := TAU * i / 18.0
		var swell := 1.0 + 0.09 * chance(centre.x * 0.31 + centre.y * 0.17 + i * 2.3)
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * swell)
	on.draw_colored_polygon(points, colour)
	# (wet at one side, and the brush lifted off at the other)
	on.draw_arc(centre, radii.x * 0.62, -2.6, -1.2, 10, colour.lightened(0.28), 2.5, true)
	var rim := points.duplicate()
	rim.append(points[0])
	on.draw_polyline(rim, colour.darkened(0.3), 1.4, true)


## A scrap of cloth, cut with pinking shears and stuck down a little askew.
static func scrap(on: CanvasItem, rect: Rect2, colour: Color) -> void:
	var lean := chance(rect.position.x * 0.7 + rect.position.y) * 0.05
	_place(on, rect.get_center(), lean)
	var half := rect.size * 0.5
	var points := PackedVector2Array()
	var teeth := int(rect.size.x / 7.0)
	for i in teeth + 1:
		points.append(Vector2(-half.x + rect.size.x * i / teeth, -half.y + (2.5 if i % 2 == 0 else 0.0)))
	for i in teeth + 1:
		points.append(Vector2(half.x - rect.size.x * i / teeth, half.y - (2.5 if i % 2 == 0 else 0.0)))
	on.draw_colored_polygon(points, colour)
	# The weave
	var thread := colour.lightened(0.16)
	thread.a = 0.5
	for i in range(1, int(rect.size.y / 6.0)):
		on.draw_line(Vector2(-half.x + 2.0, -half.y + i * 6.0), Vector2(half.x - 2.0, -half.y + i * 6.0), thread, 1.0)
	var rim := points.duplicate()
	rim.append(points[0])
	on.draw_polyline(rim, colour.darkened(0.35), 1.2, true)
	_back(on)


## Something stuck in on its own bit of paper: the paper, a shadow under it,
## turned by `lean`. What is drawn after this, at the same places on the page
## as if it lay straight, is turned with it, until `card_done`.
static func card(on: CanvasItem, rect: Rect2, lean := 0.0, colour := CARD) -> void:
	var centre := rect.get_center()
	on.draw_set_transform(centre + Vector2(2.0, 3.0), lean)
	on.draw_rect(Rect2(-rect.size * 0.5, rect.size), Color(0.2, 0.12, 0.05, 0.22))
	base = Transform2D(lean, centre) * Transform2D(0.0, -centre)
	_back(on)
	on.draw_rect(rect, colour)
	on.draw_rect(rect, Color(0.4, 0.3, 0.16, 0.35), false, 1.0)


static func card_done(on: CanvasItem) -> void:
	base = Transform2D.IDENTITY
	_back(on)


static func _place(on: CanvasItem, at: Vector2, lean: float) -> void:
	on.draw_set_transform_matrix(base * Transform2D(lean, at))


static func _back(on: CanvasItem) -> void:
	on.draw_set_transform_matrix(base)
