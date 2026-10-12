class_name ColourWheel
extends RefCounted
## A colour wheel: a ring of every hue, and inside it a square of that hue
## from white (top left) to its full strength (top right) and down to black.
## Wherever the game has a colour to choose, it is chosen on one of these.
##
## It is drawn by whoever has it, on anything that can be drawn on (`draw`),
## in the pencil and paint of the notebook; and is told of a finger or a mouse
## by the same (`press`, `drag`, `release`), in the same coordinates it was
## drawn in. A finger that comes down on the ring turns the hue and goes on
## turning it wherever it is dragged; one that comes down in the square moves
## about the square. A gamepad points at a hue with one stick (`point`) and
## moves in the square with the other or the d-pad (`move`).
##
##     var wheel := ColourWheel.new()
##     wheel.set_colour(colour)
##     wheel.draw(self, Rect2(...))            # in _draw
##     if wheel.press(at): ...                 # then drag(at) and release()
##     wheel.colour()                          # what it stands at
##
## `changed` is sent whenever what it stands at changes.

signal changed

## How much of the wheel's radius the ring of hues takes, and the gap between the ring and the square.
const RING := 0.26
const GAP := 0.05
## How far outside the ring a finger may come down and still be meant for it, as a part of the radius.
const SLACK := 0.14

## What it stands at: the hue (0 to 1, red at the top and round with the clock), how strong, how bright.
var hue := 0.0
var strength := 0.0
var bright := 1.0
## Where it was last drawn.
var rect := Rect2()
## What a finger has hold of: "" (nothing), "ring" or "square".
var held := ""


func colour() -> Color:
	return Color.from_hsv(hue, strength, bright)


## Sets it to a colour. (A grey has no hue, and black no strength either: what it stood at is kept for those.)
func set_colour(to: Color) -> void:
	if to.is_equal_approx(colour()):
		return
	if to.s > 0.001 and to.v > 0.001:
		hue = to.h
	if to.v > 0.001:
		strength = to.s
	bright = to.v


func centre() -> Vector2:
	return rect.get_center()


func radius() -> float:
	return minf(rect.size.x, rect.size.y) * 0.5


## The square inside the ring.
func square() -> Rect2:
	var half := radius() * (1.0 - RING - GAP) * 0.7071
	return Rect2(centre() - Vector2(half, half), Vector2(half, half) * 2.0)


# Where on the ring a hue is, and which hue a direction from the middle is.
func _at_hue(of: float, out: float) -> Vector2:
	return centre() + Vector2.from_angle(of * TAU - PI * 0.5) * out


func _hue_towards(way: Vector2) -> float:
	return fposmod((way.angle() + PI * 0.5) / TAU, 1.0)


## A finger (or a mouse) has come down at `at`. Says whether it was on the wheel, and so has hold of it.
func press(at: Vector2) -> bool:
	var out := at.distance_to(centre())
	var r := radius()
	if square().grow(r * GAP * 0.5).has_point(at):
		held = "square"
	elif out <= r * (1.0 + SLACK) and out >= r * (1.0 - RING - GAP):
		held = "ring"
	else:
		held = ""
		return false
	drag(at)
	return true


## The finger that has hold of it has moved to `at`.
func drag(at: Vector2) -> void:
	var was := [hue, strength, bright]
	if held == "ring":
		if at.distance_to(centre()) > 2.0:
			hue = _hue_towards(at - centre())
	elif held == "square":
		var box := square()
		strength = clampf((at.x - box.position.x) / box.size.x, 0.0, 1.0)
		bright = clampf(1.0 - (at.y - box.position.y) / box.size.y, 0.0, 1.0)
	if was != [hue, strength, bright]:
		changed.emit()


func release() -> void:
	held = ""


## A stick pointed at a hue: the hue on the ring that way from the middle. (Not pushed far, it says nothing.)
func point(stick: Vector2) -> void:
	if stick.length() < 0.6:
		return
	var to := _hue_towards(stick)
	if not is_equal_approx(to, hue):
		hue = to
		changed.emit()


## Moves about the square: `by.x` to the right is stronger, `by.y` down is darker; each a part of the whole square.
func move(by: Vector2) -> void:
	if by == Vector2.ZERO:
		return
	var was := [strength, bright]
	strength = clampf(strength + by.x, 0.0, 1.0)
	bright = clampf(bright - by.y, 0.0, 1.0)
	if was != [strength, bright]:
		changed.emit()


## Turns the hue by a part of the whole way round.
func turn(by: float) -> void:
	if by != 0.0:
		hue = fposmod(hue + by, 1.0)
		changed.emit()


## Draws it to fill `into` on `on`. `marked` draws it as the thing a gamepad
## has hold of: its two knobs bolder, in `mark`.
func draw(on: CanvasItem, into: Rect2, marked := false, mark := NotebookInk.RED) -> void:
	rect = into
	var c := centre()
	var r := radius()
	var inner := r * (1.0 - RING)
	# The ring: a quad for every five degrees, each end its own hue, so that it runs smoothly round.
	var count := 72
	for i in count:
		var a := float(i) / count
		var b := float(i + 1) / count
		var ca := Color.from_hsv(a, 1.0, 1.0)
		var cb := Color.from_hsv(fposmod(b, 1.0), 1.0, 1.0)
		on.draw_polygon([_at_hue(a, inner), _at_hue(a, r), _at_hue(b, r), _at_hue(b, inner)], [ca, ca, cb, cb])
	# The square: white to the hue across, and down to black, in a grid fine enough to look smooth.
	var box := square()
	var cells := 10
	for y in cells:
		for x in cells:
			var corners := PackedVector2Array()
			var paints := PackedColorArray()
			for corner: Vector2 in [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]:
				var part := corner / float(cells)
				corners.append(box.position + part * box.size)
				paints.append(Color.from_hsv(hue, part.x, 1.0 - part.y))
			on.draw_polygon(corners, paints)
	# Pencil round all of it, as everything in the book is drawn.
	NotebookInk.ring(on, c, Vector2(r, r), NotebookInk.PENCIL, 2.0, 1.0)
	NotebookInk.ring(on, c, Vector2(inner, inner), NotebookInk.PENCIL, 1.6, 2.0)
	NotebookInk.box(on, box, NotebookInk.PENCIL, 1.8)
	# Where it stands: a knob on the ring, and one in the square, each with the colour in it.
	var knob := _at_hue(hue, (r + inner) * 0.5)
	var size := r * RING * 0.62
	on.draw_circle(knob, size + 2.5, Color(0.1, 0.08, 0.07, 0.9))
	on.draw_circle(knob, size, Color.from_hsv(hue, 1.0, 1.0))
	on.draw_arc(knob, size + 2.5, 0.0, TAU, 24, NotebookInk.CARD, 2.0, true)
	var spot := box.position + Vector2(strength, 1.0 - bright) * box.size
	var small := r * 0.085
	on.draw_circle(spot, small + 2.5, Color(0.1, 0.08, 0.07, 0.9))
	on.draw_circle(spot, small, colour())
	on.draw_arc(spot, small + 2.5, 0.0, TAU, 20, NotebookInk.CARD, 2.0, true)
	if marked:
		NotebookInk.ring(on, knob, Vector2(size + 8.0, size + 7.0), mark, 3.0, 4.0)
		NotebookInk.ring(on, spot, Vector2(small + 8.0, small + 7.0), mark, 3.0, 5.0)
