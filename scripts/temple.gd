class_name Temple
extends StaticBody3D
## An Egyptian temple, made from numbers as a `Pyramid` is: its mesh and what
## is solid are worked out when it enters the level (or when `build` is
## called), and the same numbers always make the same temple. The middle of
## its length is at the origin, its floor a step above the ground there, and
## it faces +Z: he comes to the pylon from that side and walks in towards -Z.
##
## It is one thing set out several ways. A temple is a row of parts along an
## axis, each made by `TempleParts` from a few numbers: a pylon (two leaning
## towers and the gate between), courts open to the sky with columns round
## them, halls of columns under a roof of slabs, and at the far end the
## sanctuary, a room inside a room, with the god's granite shrine in it. Round
## that there can be an enclosure wall with a walk between it and the temple,
## a well, a lake; and before the pylon obelisks, colossi and falcons.
## `plan` says which row of parts:
##     EDFU       the temple of Horus: the most complete in Egypt. A pylon 36 m
##                high, a court, two halls of columns, the sanctuary with its
##                naos, and the enclosure wall, all roofed.
##     LUXOR      long and open: the pylon of Ramesses II with his colossi and
##                the one obelisk left, his court (the mosque of Abu el-Haggag
##                standing in it on what had not been dug), the great colonnade
##                of fourteen columns, the sun court of Amenhotep III, a hall of
##                thirty-two columns, and the sanctuary.
##     KOM_OMBO   two of everything, for Sobek and Horus the Elder: two gates,
##                two aisles, two sanctuaries side by side, on a rise. Its front
##                half is down to stumps; the columns of its halls stand.
##     CUSTOM     whatever the numbers under "Your own" say.
##
## `size` is how big it all is: 1 is the size of the real thing (Edfu is 137 m
## long). Whatever the size, doorways stay wide and high enough for him, steps
## stay steps, and columns never stand so close that he could be caught
## between them. `ruin` takes it apart: roof slabs go, columns snap and their
## drums lie about, walls come down to a few courses, sand drifts in. `buried`
## fills it with sand, inside and out, as all of these were before they were
## dug. `painted` is how much of the old colour is left.
##
## For whoever makes a level, it marks its places with `Marker3D`s in groups:
## `temple_sanctuary` (before each naos), `temple_doorways` (the foot of every
## doorway on the axis: each says how `wide` and `tall` it is, for a door),
## `temple_pylon_top`, `temple_court` and `temple_avenue` (places along the
## way up to it, for sphinxes). `ways` is the way in, from before the gate to
## each sanctuary, and `open` whether he can get all the way along it.
##
## What it costs is in `triangles`, `shapes` and `build_ms` once it is built.
## All the walls, roofs and statues are one mesh; all the columns of a kind in
## one part are one draw, and far off a coarser one.

enum Plan { EDFU, LUXOR, KOM_OMBO, CUSTOM }

const STONES := Pyramid.STONES
## How far below its floor it goes on, for ground that is not quite level.
const FOOT := 3.0
## How far its paving stands above the ground.
const PAVE := 0.15
## The least a doorway is wide and high, and the least room between two solid things he may walk between.
const DOOR := Vector2(2.2, 2.9)
const ROOM := 1.2
const C := TempleParts.Capital
const S := preload("res://scripts/temple_stone.gd")
## What a king says of himself on a wall: his titles, with his name in the ring.
const KING_TEXT := "{sw*t-bit:t nb-tA:tA <%s> sA-ra nb-xa:Z2 di-anx mi-ra D:t:tA|The King of Upper and Lower Egypt, Lord of the Two Lands, %s, Son of Ra, Lord of Crowns, given life like Ra for ever.}"
const KINGS := {Plan.EDFU: ["p:t-wA-l-m-i*i-s", "Ptolemy"], Plan.LUXOR: ["ra-ms-s-sw", "Ramesses"], Plan.KOM_OMBO: ["p:t-wA-l-m-i*i-s", "Ptolemy"], Plan.CUSTOM: ["ra-ms-s-sw", "Ramesses"]}

## Which temple.
@export var plan := Plan.EDFU
## How big: 1 is the size of the real one.
@export_range(0.2, 1.5) var size := 1.0
## How ruined, 0..1.
@export_range(0.0, 1.0) var ruin := 0.0
## Which ruin: another number breaks it differently.
@export var seed := 1
## How deep in sand it is, inside and out: 1 is to the top of the columns of its great hall.
@export_range(0.0, 1.0) var buried := 0.0
## How much of the old paint is left, 0..1.
@export_range(0.0, 1.0) var painted := 0.15
## The colour of its stone.
@export var colour := STONES[0]

@export_group("Your own")
## How wide the court is inside, in metres at full size.
@export var width := 40.0
## How high the pylon is (0: none).
@export var pylon_height := 28.0
## How long the court is (0: none), and how many rows of columns stand round it.
@export var court_depth := 34.0
@export_range(0, 2) var court_rows := 1
## Which capital its columns have.
@export var capital := C.COMPOSITE
## How many halls of columns, how many columns across each and how many deep.
@export_range(0, 3) var halls := 2
@export_range(2, 10) var hall_across := 6
@export_range(1, 8) var hall_deep := 3
## How high the columns of the first hall are.
@export var column_height := 12.0
## How much higher the middle aisle of the first hall is than the rest, with grilles to let the light in (0: no higher).
@export var nave := 0.0
## Two of everything, side by side.
@export var doubled := false
## Whether the halls are roofed.
@export var roofed := true
## A wall round it all, with a walk inside it.
@export var enclosure := true
## A sacred lake beside it, and a well.
@export var lake := false
@export var well := false
## How many obelisks (0..2), seated colossi and falcons stand before the pylon.
@export_range(0, 2) var obelisks := 0
@export_range(0, 2) var colossi := 0
@export_range(0, 2) var falcons := 0
## How high a rise it stands on, with steps up to it.
@export var rise := 0.0

## How long and wide it came out, in metres, and how high its pylon (or its highest wall) is.
var length := 0.0
var breadth := 0.0
var height := 0.0
## How many triangles it is drawn with when he is among its columns, and when he is far off.
var triangles := 0
var triangles_far := 0
## How many shapes it collides with, how many columns it has, and how long it took to build.
var shapes := 0
var columns := 0
var build_ms := 0.0
## The way in, for each axis: points from before the gate to the sanctuary, in its own space.
var ways: Array[PackedVector3Array] = []
## Whether he can walk all the way in, and if not, why not.
var open := true
var shut_by := ""
## How deep the sand lies, in metres above the floor.
var sand := 0.0

var _p: TempleParts
var _k := 1.0
var _axes: Array[float] = [0.0]
var _twin := 0.0
var _fallen: Array = []
var _decals: Array = []
var _carvings: Array = []
var _marks: Array = []
var _hooks: Array[Vector3] = []
var _pools: Array = []
var _drift_spots: Array[Vector3] = []
var _column_luck: RandomNumberGenerator
var _wall_luck: RandomNumberGenerator
var _roof_luck: RandomNumberGenerator
var _prev_width := 0.0
var _prev_shade := 1.0
var _prev_top := 0.0
var _enclosed := false
var _reference := 10.0


## A temple as an item of a level's layout says (see `LevelLayout.FIELDS`).
static func from_item(item: Dictionary) -> Temple:
	var made := Temple.new()
	made.plan = {"edfu": Plan.EDFU, "luxor": Plan.LUXOR, "kom_ombo": Plan.KOM_OMBO}.get(item.get("what", ""), Plan.CUSTOM)
	made.size = item.get("size", 1.0)
	made.ruin = item.get("ruin", 0.0)
	made.seed = int(item.get("seed", 1))
	made.buried = item.get("buried", 0.0)
	made.painted = item.get("painted", 0.15)
	made.colour = STONES[clampi(int(item.get("stone", 0)), 0, STONES.size() - 1)]
	made.width = item.get("width", 40.0)
	made.pylon_height = item.get("pylon", 28.0)
	made.court_depth = item.get("court", 34.0)
	made.court_rows = int(item.get("court_rows", 1))
	made.capital = clampi(int(item.get("capital", 2)), 0, 3) as C
	made.halls = int(item.get("halls", 2))
	made.hall_across = int(item.get("across", 6))
	made.hall_deep = int(item.get("deep", 3))
	made.column_height = item.get("column", 12.0)
	made.nave = item.get("nave", 0.0)
	made.doubled = item.get("doubled", false)
	made.roofed = item.get("roofed", true)
	made.enclosure = item.get("enclosure", true)
	made.lake = item.get("lake", false)
	made.well = item.get("well", false)
	made.obelisks = int(item.get("obelisks", 0))
	made.colossi = int(item.get("colossi", 0))
	made.falcons = int(item.get("falcons", 0))
	made.rise = item.get("rise", 0.0)
	return made


func _ready() -> void:
	build()


## The parts of each plan, front to back, in metres at full size. A part is
##     t          "pylon", "court", "hall" or "shrine"
##     w, d       how wide and deep it is inside
##     front      how a court or hall is closed towards the front: "wall" (with a
##                doorway on each axis), "screen" (half-height walls between the
##                columns of its first row) or "none"
##     capital, col_h, col_r     its columns
##     across, deep              how many, in a hall; `rows`, `sides` ("f", "s"
##                and "b": front, sides, back), `portico` and `spacing` in a court
##     roof       how much of its roof it has, 0..1
##     standing   how much of its height stands, 0..1; `firm` if its columns outlast its walls
func _parts() -> Dictionary:
	match plan:
		Plan.EDFU:
			return {"falcons": 2, "falcon_h": 3.4, "enclosure": {"w": 46.0, "h": 10.8, "t": 2.2, "rear": 5.0}, "well": true, "parts": [
				{"t": "pylon", "w": 79.0, "h": 36.0, "d": 11.0, "gate_w": 5.6, "gate_h": 15.5, "niches": 2},
				{"t": "court", "w": 46.0, "d": 44.0, "rows": 1, "sides": "fs", "capital": C.COMPOSITE, "col_h": 9.6, "col_r": 0.92, "portico": 6.2, "spacing": 3.7, "roof": 1.0, "fills": true},
				{"t": "hall", "w": 36.0, "d": 17.0, "across": 6, "deep": 3, "capital": C.COMPOSITE, "col_h": 12.6, "col_r": 1.15, "front": "screen", "roof": 1.0, "shoulders": false, "falcon": true},
				{"t": "hall", "w": 30.0, "d": 14.0, "across": 4, "deep": 3, "capital": C.COMPOSITE, "col_h": 10.0, "col_r": 1.0, "front": "wall", "roof": 1.0, "door": [3.6, 8.0]},
				{"t": "hall", "w": 30.0, "d": 5.5, "h": 9.4, "front": "wall", "roof": 1.0, "door": [3.2, 7.0]},
				{"t": "hall", "w": 30.0, "d": 5.0, "h": 9.0, "front": "wall", "roof": 1.0, "door": [3.0, 6.5]},
				{"t": "shrine", "w": 30.0, "d": 24.0, "h": 8.6, "roof": 1.0, "door": [2.8, 6.0], "naos": 4.2}]}
		Plan.LUXOR:
			return {"obelisk_h": 25.0, "obelisks": [-1.0], "pedestals": [1.0], "colossi": 2, "colossus_h": 14.0, "standing_colossi": [1.0], "parts": [
				{"t": "pylon", "w": 65.0, "h": 24.0, "d": 8.5, "gate_w": 4.8, "gate_h": 12.0, "niches": 2},
				{"t": "court", "w": 51.0, "d": 57.0, "h": 10.5, "rows": 2, "sides": "fsb", "capital": C.BUD, "col_h": 9.4, "col_r": 0.95, "portico": 8.5, "spacing": 4.3, "roof": 0.0, "mosque": true},
				{"t": "hall", "w": 21.0, "d": 52.0, "h": 13.0, "across": 2, "deep": 7, "capital": C.OPEN, "col_h": 19.0, "col_r": 1.55, "front": "wall", "roof": 0.0, "door": [4.2, 9.5], "front_h": 15.0, "guards": true},
				{"t": "court", "w": 52.0, "d": 46.0, "h": 6.0, "rows": 2, "sides": "fs", "capital": C.BUD, "col_h": 11.6, "col_r": 1.05, "portico": 9.0, "spacing": 4.5, "roof": 0.0, "front": "none", "standing": 0.5, "firm": true},
				{"t": "hall", "w": 52.0, "d": 19.0, "h": 6.0, "across": 8, "deep": 4, "capital": C.BUD, "col_h": 11.6, "col_r": 1.05, "front": "none", "roof": 0.0, "standing": 0.5, "firm": true},
				{"t": "hall", "w": 19.0, "d": 12.0, "h": 8.0, "front": "wall", "roof": 1.0, "door": [3.0, 6.0]},
				{"t": "hall", "w": 19.0, "d": 10.0, "across": 2, "deep": 2, "capital": C.BUD, "col_h": 7.4, "col_r": 0.7, "front": "wall", "roof": 1.0, "door": [2.8, 5.6]},
				{"t": "shrine", "w": 19.0, "d": 22.0, "h": 7.6, "roof": 1.0, "door": [2.6, 5.2], "naos": 0.0}]}
		Plan.KOM_OMBO:
			return {"twin": 7.6, "rise": 1.6, "enclosure": {"w": 44.0, "h": 9.0, "t": 2.0, "rear": 4.5, "standing": 0.28}, "well": true, "lake": true, "parts": [
				{"t": "pylon", "w": 56.0, "h": 20.0, "d": 7.0, "gate_w": 4.0, "gate_h": 9.0, "standing": 0.13},
				{"t": "court", "w": 44.0, "d": 22.0, "rows": 1, "sides": "fs", "capital": C.COMPOSITE, "col_h": 8.2, "col_r": 0.95, "portico": 5.5, "spacing": 4.2, "roof": 0.0, "standing": 0.16, "fills": true, "altar": true},
				{"t": "hall", "w": 36.0, "d": 15.0, "across": 5, "deep": 3, "capital": C.COMPOSITE, "col_h": 12.0, "col_r": 1.1, "front": "screen", "roof": 0.5, "shoulders": false, "firm": true},
				{"t": "hall", "w": 31.0, "d": 11.0, "across": 5, "deep": 2, "capital": C.COMPOSITE, "col_h": 9.4, "col_r": 0.85, "front": "wall", "roof": 0.35, "door": [3.0, 6.6], "firm": true},
				{"t": "hall", "w": 31.0, "d": 4.6, "h": 8.0, "front": "wall", "roof": 0.0, "door": [2.8, 6.0], "standing": 0.7},
				{"t": "hall", "w": 31.0, "d": 4.6, "h": 7.6, "front": "wall", "roof": 0.0, "door": [2.8, 5.6], "standing": 0.55},
				{"t": "shrine", "w": 31.0, "d": 17.0, "h": 7.2, "roof": 0.0, "door": [2.6, 5.2], "naos": 0.0, "standing": 0.38}]}
	# Your own.
	var parts: Array = []
	var screened := capital == C.COMPOSITE or capital == C.HATHOR
	var inner := width * (0.82 if enclosure else 1.0)
	if pylon_height > 0.5:
		parts.append({"t": "pylon", "w": width * 1.7, "h": pylon_height, "d": maxf(pylon_height * 0.3, 4.0), "gate_w": 5.0, "gate_h": pylon_height * 0.43, "niches": 2})
	if court_depth > 1.0:
		parts.append({"t": "court", "w": width, "d": court_depth, "h": column_height * 0.9, "rows": court_rows, "sides": "fs", "capital": capital, "col_h": column_height * 0.78, "col_r": column_height * 0.072,
			"portico": column_height * 0.5, "spacing": column_height * 0.31, "roof": 1.0 if roofed else 0.0, "fills": enclosure})
	for i in halls:
		var high := column_height * pow(0.82, i)
		parts.append({"t": "hall", "w": inner * pow(0.86, i), "d": hall_deep * high * (0.46 if i == 0 else 0.4), "across": maxi(hall_across - 2 * i, 2), "deep": hall_deep, "capital": capital,
			"col_h": high, "col_r": high * 0.09, "front": "screen" if i == 0 and screened else "wall", "roof": 1.0 if roofed else 0.0, "shoulders": not enclosure,
			"nave": nave if i == 0 else 0.0, "door": [3.4, high * 0.62]})
	var last := inner * pow(0.86, maxi(halls - 1, 0))
	parts.append({"t": "hall", "w": last, "d": 5.0, "h": column_height * 0.62, "front": "wall", "roof": 1.0, "door": [3.0, column_height * 0.5]})
	parts.append({"t": "shrine", "w": last, "d": last * 0.7, "h": column_height * 0.6, "roof": 1.0, "door": [2.8, column_height * 0.44], "naos": 4.0})
	var made := {"parts": parts, "well": well, "lake": lake, "rise": rise, "colossi": colossi, "colossus_h": pylon_height * 0.5, "falcons": falcons, "falcon_h": 3.4,
		"obelisk_h": pylon_height * 0.95, "obelisks": [[], [-1.0], [-1.0, 1.0]][obelisks]}
	if doubled:
		made["twin"] = 7.6
	if enclosure:
		made["enclosure"] = {"w": width, "h": column_height * 0.86, "t": 2.0, "rear": 5.0}
	return made


## Makes it (again) from its numbers.
func build() -> void:
	var began := Time.get_ticks_usec()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_p = TempleParts.new()
	_k = clampf(size, 0.1, 2.0)
	_fallen.clear()
	_decals.clear()
	_carvings.clear()
	_marks.clear()
	_hooks.clear()
	_pools.clear()
	_drift_spots.clear()
	ways.clear()
	open = true
	shut_by = ""
	columns = 0
	_column_luck = _luck(11)
	_wall_luck = _luck(23)
	_roof_luck = _luck(37)
	var set_out := _parts()
	var parts: Array = set_out["parts"]
	_twin = float(set_out.get("twin", 0.0)) * _k
	if _twin > 0.0:
		_twin = maxf(_twin, DOOR.x + 2.4)
		_axes = [-_twin * 0.5, _twin * 0.5]
	else:
		_axes = [0.0]
	_enclosed = set_out.has("enclosure")
	# How long it is, so that its middle can be put at the origin; and how high its great hall's columns are, which sand is measured by.
	length = 0.0
	_reference = 0.0
	for part: Dictionary in parts:
		length += _depth(part)
		if part["t"] == "hall" and part.has("col_h"):
			_reference = maxf(_reference, float(part["col_h"]) * _k)
	if _reference <= 0.0:
		_reference = 10.0 * _k
	var rear := 0.0
	if _enclosed:
		rear = maxf(float(set_out["enclosure"]["rear"]) * _k, ROOM + 0.4) + _thick(set_out["enclosure"])
		length += rear
	var floor_y := PAVE + float(set_out.get("rise", 0.0)) * _k
	_p.shift = Vector3(0.0, floor_y, length * 0.5)
	sand = buried * _reference
	height = 0.0
	breadth = 0.0

	# The parts, front to back.
	var z := 0.0
	var doors_at: Array = []
	var pylon_back := 0.0
	_prev_width = 0.0
	_prev_shade = 1.0
	_prev_top = 0.0
	var sanctuaries: Array[Vector3] = []
	for index in parts.size():
		var part: Dictionary = parts[index]
		part["i"] = index
		breadth = maxf(breadth, float(part["w"]) * _k + 2.0 * _thick(part))
		match part["t"]:
			"pylon":
				z = _pylon(part, z, doors_at)
				pylon_back = z
			"court":
				z = _court(part, z, doors_at)
			"hall":
				z = _hall(part, z, doors_at)
			"shrine":
				z = _shrine(part, z, doors_at, sanctuaries)
	if _enclosed:
		_enclosure(set_out["enclosure"], pylon_back, z - rear)
		breadth = maxf(breadth, float(set_out["enclosure"]["w"]) * _k + 2.0 * _thick(set_out["enclosure"]))
	_approach(set_out, parts[0])
	var beside := breadth * 0.5
	if set_out.get("well", false):
		var at := Vector3(-(beside + 5.0 * _k + 2.0), 0.0, -length * 0.55)
		if _enclosed:
			at.x = -(float(set_out["enclosure"]["w"]) * 0.5 * _k - ROOM - 2.2)
			at.z = -length + rear * 0.5 + (2.0 if rear > 7.0 else 100.0)
			if at.z > 0.0:
				at = Vector3(-(beside + 5.0 * _k + 2.0), 0.0, -length * 0.55)
		_well(at, maxf(1.3 * _k, 0.9))
		_mark("Nilometer", at, &"temple_well")
	if set_out.get("lake", false):
		_lake(Vector3(beside + 7.0 * _k + 3.0, 0.0, -length * 0.6), Vector2(maxf(18.0 * _k, 6.0), maxf(13.0 * _k, 5.0)))

	# The ground it stands on: paving, or a rise with steps up to it.
	var ground := Rect2(-beside, -length, breadth, length)
	for rect: Rect2 in _p.standing:
		ground = ground.merge(rect)
	ground = ground.grow(1.5 + 1.5 * _k)
	var lanes: Array[Rect2] = []
	for axis: float in _axes:
		var lane := maxf(_door(parts[0].get("gate_w", 4.0), 0.0).x, DOOR.x) + 1.4
		lanes.append(Rect2(axis - lane * 0.5, ground.position.y - 30.0, lane, ground.size.y + 60.0))
	_rubble(ground, lanes)
	var paving := TempleParts.tint(1.0, S.COURSED)
	_p.box(Vector3(ground.position.x, -floor_y - FOOT, ground.position.y), Vector3(ground.end.x, 0.0, ground.end.y), paving)
	if floor_y > PAVE + 0.2:
		# Steps up the front of the rise, as wide as the gates and more.
		var steps := ceili((floor_y - PAVE) / 0.2)
		var each := (floor_y - PAVE) / steps
		var half := minf(_twin * 0.5 + 9.0 * _k + 3.0, ground.size.x * 0.5)
		for step in steps:
			_p.box(Vector3(-half, -floor_y - FOOT, ground.end.y + step * 0.4), Vector3(half, -each * (step + 1), ground.end.y + (step + 1) * 0.4), paving)
	if sand > 0.05:
		_bury(ground, floor_y)

	# The way in, and whether sand or fallen stone has shut it.
	for which in _axes.size():
		var way := PackedVector3Array()
		var axis := _axes[which]
		var level := maxf(sand, 0.0)
		way.append(Vector3(axis, level - (floor_y if sand <= 0.05 else 0.0), 14.0 * _k + 8.0 + (floor_y - PAVE) * 2.0 + sand * 2.2) + _p.shift)
		way.append(Vector3(axis, level, 2.0) + _p.shift)
		for door: Array in doors_at:
			if is_equal_approx(door[0], axis):
				way.append(Vector3(axis, level, door[1]) + _p.shift)
				if sand > 0.05 and door[2] - sand < 1.45 and open:
					open = false
					shut_by = "sand fills the doorway %.1f m in (it is %.1f m high and the sand %.1f m deep)" % [-door[1], door[2], sand]
		if which < sanctuaries.size():
			way.append(sanctuaries[which] + Vector3.UP * level + _p.shift)
		ways.append(way)

	_finish()
	build_ms = (Time.get_ticks_usec() - began) / 1000.0


# ---- Numbers. ----

func _luck(salt: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = hash([seed, salt])
	return random


# How thick a part's walls are.
func _thick(part: Dictionary) -> float:
	return maxf(float(part.get("t_wall", part.get("t", 1.6) if part.get("t") is float else 1.6)) * _k, 0.6)


# How much of the temple's length a part takes up.
func _depth(part: Dictionary) -> float:
	var deep := float(part["d"]) * _k
	if part["t"] != "pylon" and part.get("front", "none" if part["t"] == "court" else "wall") == "wall":
		deep += _thick(part)
	if part["t"] == "shrine":
		deep += _thick(part)
	return deep


# A doorway of a size at full size, as it is at this size: never too small for him.
func _door(wide: float, tall: float) -> Vector2:
	return Vector2(maxf(wide * _k, DOOR.x), maxf(tall * _k, DOOR.y))


# How light it is in a part: 1 under the sky, less under what is left of a roof.
func _shade(part: Dictionary, dark := 0.44) -> float:
	var whole: float = part.get("standing", 1.0)
	var kept := clampf(float(part.get("roof", 0.0)) * (1.0 - ruin * 1.3), 0.0, 1.0) if whole > 0.99 else 0.0
	return lerpf(1.0, dark, kept)


func _mark(called: String, at: Vector3, group: StringName, more := {}) -> void:
	_marks.append([called, at + Vector3.UP * maxf(sand, 0.0), group, more])


# Writing for a wall he comes close to: `middle` of the panel, which way it faces, how big, and what it says.
func _carve(text: String, middle: Vector3, facing: Vector3, panel: Vector2, shade: float) -> void:
	if middle.y - panel.y * 0.5 < sand + 0.2:
		return
	_carvings.append([text, middle, facing, panel, shade])


func _king() -> String:
	return KING_TEXT % KINGS[plan]


# ---- The pylon. ----

func _pylon(part: Dictionary, z0: float, doors_at: Array) -> float:
	var wide := float(part["w"]) * _k
	var high := float(part["h"]) * _k
	var deep := maxf(float(part["d"]) * _k, 1.8)
	var gate := _door(part["gate_w"], part["gate_h"])
	var whole: float = part.get("standing", 1.0)
	# The gateway is the model's, stretched until its opening is the size wanted.
	var by_gate := Vector3(gate.x / TempleParts.GATE_OPEN.x, gate.y / TempleParts.GATE_OPEN.y, deep / TempleParts.GATE.z)
	var gate_wide := TempleParts.GATE.x * by_gate.x
	var jamb := (gate_wide - gate.x) * 0.5
	var block := _twin * 0.5 + gate_wide * 0.5
	var crown := TempleParts.GATE_CORNICE * by_gate.y
	var gate_top := TempleParts.GATE.y * by_gate.y - crown
	var back := z0 - deep
	height = maxf(height, high * whole)
	var carved := TempleParts.tint(1.0, S.RELIEF)
	var doors: Array = []
	for axis: float in _axes:
		doors.append([axis, gate.x, gate.y])
		doors_at.append([axis, z0 - deep * 0.5, gate.y])
		_mark("Doorway", Vector3(axis, 0.0, z0 - deep * 0.5), &"temple_doorways", {"wide": gate.x, "tall": gate.y, "thick": deep})
	var broken := ruin if whole > 0.99 else maxf(ruin, 0.3)
	if whole > 0.99 and ruin < 0.45:
		for axis: float in _axes:
			_p.place("pylon_gateway", Transform3D(Basis.from_scale(by_gate), Vector3(axis, 0.0, z0)), 1.0, false)
			for side: float in [-1.0, 1.0]:
				_p.solid_box(Vector3(minf(axis + side * gate.x * 0.5, axis + side * gate_wide * 0.5), 0.0, back), Vector3(maxf(axis + side * gate.x * 0.5, axis + side * gate_wide * 0.5), gate_top, z0))
			_p.solid_box(Vector3(axis - gate.x * 0.5, gate.y, back), Vector3(axis + gate.x * 0.5, gate_top, z0))
			_p.solid_box(Vector3(axis - gate_wide * 0.5 - crown * 0.3, gate_top, back - crown * 0.3), Vector3(axis + gate_wide * 0.5 + crown * 0.3, gate_top + crown, z0 + crown * 0.3))
			_hooks.append(Vector3(axis, gate_top + crown, z0 + crown * 0.3))
			# The king's titles down each jamb, where he walks in past them.
			var panel := Vector2(minf(jamb * 0.7, 1.4), minf(gate.y * 0.6, 5.0))
			for side: float in [-1.0, 1.0]:
				_carve(_king(), Vector3(axis + side * (gate.x * 0.5 + jamb * 0.5), 0.5 + panel.y * 0.5 + sand, z0 + 0.004), Vector3.BACK, panel, 1.0)
		if _twin > gate_wide + 0.05:
			# (between two gateways, plain wall)
			_p.box(Vector3(-(_twin - gate_wide) * 0.5, 0.0, back), Vector3((_twin - gate_wide) * 0.5, gate_top, z0), carved)
	else:
		# Fallen: what is left of the jambs is plain wall.
		_p.wall(-block, block, back, z0, gate_top, true, {"doors": doors, "front": carved, "standing": whole, "ruin": broken * 0.6, "random": _wall_luck, "course": _course()})
	# The towers.
	var across := wide * 0.5 - block
	var by := Vector3(across / TempleParts.TOWER.x, high / TempleParts.TOWER.y, deep / TempleParts.TOWER.z)
	for side: float in [-1.0, 1.0]:
		var left := "_left" if side < 0.0 else ""
		if whole < 0.99 or ruin >= 0.5:
			# Down to its lower courses: the broken tower, as high as what is left, solid in the steps it is broken off in.
			var top := maxf(high * whole * (1.1 - broken * 0.55), _course() * 2.0)
			_p.place("pylon_tower_ruin" + left, Transform3D(Basis.from_scale(Vector3(by.x, top / TempleParts.TOWER.y, by.z)), Vector3(side * block, 0.0, z0)), 1.0, false)
			var steps := TempleParts.TOWER_RUIN.size()
			for step in steps:
				var from := block + across * step / steps
				var to := block + across * (step + 1) / steps
				_p.solid_box(Vector3(minf(side * from, side * to), 0.0, back), Vector3(maxf(side * from, side * to), top * TempleParts.TOWER_RUIN[step], z0))
			continue
		_p.place("pylon_tower" + left, Transform3D(Basis.from_scale(by), Vector3(side * block, 0.0, z0)), 1.0, false)
		var lean_in := TempleParts.TOWER_LEAN.x * by.x
		var lean_out := TempleParts.TOWER_LEAN.y * by.x
		var lean_z := TempleParts.TOWER_LEAN.z * by.z
		var x_in := block + lean_in
		var x_out := wide * 0.5 - lean_out
		_p.solid_hull(PackedVector3Array([Vector3(side * block, 0.0, z0), Vector3(side * block, 0.0, back), Vector3(side * wide * 0.5, 0.0, z0), Vector3(side * wide * 0.5, 0.0, back),
			Vector3(side * x_in, high, z0 - lean_z), Vector3(side * x_in, high, back + lean_z), Vector3(side * x_out, high, z0 - lean_z), Vector3(side * x_out, high, back + lean_z)]))
		_p.standing.append(Rect2(minf(side * block, side * wide * 0.5), back, across, deep))
		var cap := TempleParts.TOWER_CORNICE * by.y
		_p.solid_box(Vector3(minf(side * x_in, side * x_out) - cap * 0.3, high, back + lean_z - cap * 0.3), Vector3(maxf(side * x_in, side * x_out) + cap * 0.3, high + cap, z0 - lean_z + cap * 0.3))
		height = maxf(height, high + cap)
		_mark("PylonTop", Vector3(side * (x_in + x_out) * 0.5, high + cap - sand, z0 - deep * 0.5), &"temple_pylon_top")
		# The king smiting his enemies, towards the gate, and the god he does it before: cut into the
		# lower half of its face, between the slots for the flagstaffs.
		var split := 0.52
		var tall := high * split * 0.8
		var between := (TempleParts.TOWER_NICHES.x + TempleParts.TOWER_NICHES.y) * 0.5
		for figure: Array in [["king", between, tall, side > 0.0], ["god", TempleParts.TOWER_NICHES.x * 0.5, tall * 0.92, side < 0.0]]:
			var along: float = block + across * figure[1]
			var up: float = figure[2]
			var mid_y := high * split * 0.5
			if up * 0.5 * 100.0 / 120.0 > across * 0.14:
				up = across * 0.14 * 2.4
			_decals.append([figure[0], Vector3(side * along, mid_y, z0 - lean_z * mid_y / high + 0.03), Vector3.RIGHT * up * 0.5 * 100.0 / 120.0, Vector3(0.0, up * 0.5, -lean_z * up * 0.5 / high), figure[3]])
	_prev_width = float(part["w"]) * _k
	_prev_shade = 1.0
	_prev_top = 0.0
	return back


func _course() -> float:
	return clampf(0.9 * _k, 0.45, 1.0)


# ---- Columns. ----

# Stands a column, or what ruin has left of it. Says whether it stands whole.
func _column(part: Dictionary, kind: C, at: Vector3, high: float, radius: float, shade: float) -> bool:
	columns += 1
	var whole: float = part.get("standing", 1.0)
	var firm: bool = part.get("firm", false)
	var luck := _column_luck.randf()
	var how := _column_luck.randf()
	var breaks := ruin * (0.45 if firm else 0.8) - (0.12 if firm else 0.0)
	if (whole > 0.99 or firm) and luck >= breaks:
		var by := high / TempleParts.COLUMN_HEIGHT
		var named := TempleParts.COLUMNS[kind]
		_p.place(named, Transform3D(Basis.from_scale(Vector3(radius, by, radius)), at), shade, false, str(part["i"]), named + "_far")
		_p.solid_cylinder(at, radius * 1.3, TempleParts.COLUMN_FOOT * by)
		_p.solid_cylinder(at, radius, high)
		return true
	# Snapped: what is left stands, and its drums lie somewhere near.
	var left := high * (whole if whole < 0.99 else 1.0) * lerpf(0.12, 0.7, how)
	if whole < 0.99:
		left = high * whole * lerpf(0.5, 1.5, how)
	if ruin > 0.55 and how < (ruin - 0.55) * 1.2:
		left = minf(left, radius * 0.6)
	left = maxf(left, 0.35)
	_p.place("column_broken", Transform3D(Basis(Vector3.UP, luck * TAU) * Basis.from_scale(Vector3(radius, left, radius)), at), shade, false)
	_p.solid_cylinder(at, radius, left * 0.86)
	if whole > 0.99 or how > 0.6:
		for drum in 1 + int(how * 2.5):
			_fallen.append([at, radius * 0.9, radius * lerpf(1.6, 2.6, _column_luck.randf())])
	return false


# The beams that lie from column to column along a row of them: `row` is each
# column's place and whether it stands. Says which stretches of the row carry one.
func _architraves(row: Array, high: float, radius: float, beam: float, reach: float, shade: float) -> Array:
	var runs: Array = []
	var half := radius * 0.82
	var from := -1
	for i in row.size() + 1:
		var joined: bool = i < row.size() and row[i][1] and from >= 0 and (row[i][0] - row[i - 1][0]).length() <= reach
		if joined:
			continue
		if from >= 0 and i - 1 > from:
			var a: Vector3 = row[from][0]
			var b: Vector3 = row[i - 1][0]
			_beam("architrave", Vector3(minf(a.x, b.x) - half, high, minf(a.z, b.z) - half), Vector3(maxf(a.x, b.x) + half, high + beam, maxf(a.z, b.z) + half), shade)
			runs.append([a, b])
			# A hook will hold on a beam that has open air under it.
			if (a - b).length() > radius * 5.0 and _hooks.size() < 28 and runs.size() % 2 == 1:
				_hooks.append((a + (b - a).normalized() * minf((row[from + 1][0] - a).length() * 0.5, (a - b).length() * 0.5)) + Vector3.UP * (high + beam))
		from = i if i < row.size() and row[i][1] else -1
	return runs


# A beam or a slab (the model named), stretched to fill a box, and solid.
func _beam(named: String, low: Vector3, high: Vector3, shade := 1.0) -> void:
	_p.place(named, Transform3D(Basis.from_scale(high - low), Vector3((low.x + high.x) * 0.5, low.y, (low.z + high.z) * 0.5)), shade, false)
	_p.solid_box(low, high)


# ---- A court. ----

func _court(part: Dictionary, z0: float, doors_at: Array) -> float:
	var wide := float(part["w"]) * _k
	var deep := float(part["d"]) * _k
	var thick := _thick(part)
	var whole: float = part.get("standing", 1.0)
	var col_h := float(part["col_h"]) * _k
	var radius := float(part["col_r"]) * _k
	var beam := maxf(0.1 * col_h, 0.45)
	var slab := maxf(0.05 * col_h, 0.3)
	var wall_h: float = float(part.get("h", 0.0)) * _k if part.has("h") else col_h + beam + slab
	var back := z0 - deep
	var rows := int(part.get("rows", 1))
	var sides: String = part.get("sides", "fs")
	var carved := TempleParts.tint(0.95, S.RELIEF)
	var outside := TempleParts.tint(1.0, S.RELIEF)
	var broken := ruin if whole > 0.99 else maxf(ruin, 0.3)
	if part.get("front", "none") == "none" and _prev_width > 0.0 and absf(_prev_width - wide) > 1.0 and part.get("shoulders", true):
		# Where it is wider than what it follows, walls close the difference.
		var narrow := minf(_prev_width, wide) * 0.5
		for side: float in [-1.0, 1.0]:
			_p.wall(minf(side * narrow, side * (maxf(_prev_width, wide) * 0.5 + thick)), maxf(side * narrow, side * (maxf(_prev_width, wide) * 0.5 + thick)), z0 - thick, z0, wall_h, true,
				{"front": outside, "back": carved, "standing": whole, "ruin": broken, "random": _wall_luck, "course": _course()})
	if not part.get("fills", false):
		for side: float in [-1.0, 1.0]:
			_p.wall(back, z0, minf(side * wide * 0.5, side * (wide * 0.5 + thick)), maxf(side * wide * 0.5, side * (wide * 0.5 + thick)), wall_h, false,
				{"front": outside if side > 0.0 else carved, "back": carved if side > 0.0 else outside, "standing": whole, "ruin": broken, "random": _wall_luck, "course": _course()})
	_mark("Court", Vector3(0.0, 0.0, z0 - deep * 0.5), &"temple_court")
	_drift_spots.append(Vector3(wide * 0.5 - 2.0, 0.0, z0 - 2.5))
	_drift_spots.append(Vector3(-wide * 0.5 + 2.0, 0.0, back + 2.5))
	if rows < 1:
		_prev_width = wide
		_prev_shade = 1.0
		_prev_top = 0.0
		return back
	# The columns: a ring (or two) round it, set in from the wall.
	var portico := maxf(float(part["portico"]) * _k, radius * 2.0 + ROOM + 0.3)
	var spacing := maxf(float(part["spacing"]) * _k, radius * 2.0 + ROOM)
	radius = minf(radius, (portico / rows - ROOM) * 0.5)
	var lane := maxf(_door(4.5, 0.0).x, DOOR.x) * 0.5 + radius + 0.7
	var roofed: bool = float(part.get("roof", 0.0)) > 0.0 and whole > 0.99
	var under := TempleParts.tint(0.6, S.COURSED)
	for ring in rows:
		var off := portico * (ring + 1) / rows
		var x_side := wide * 0.5 - off
		var z_front := z0 - (off if "f" in sides else spacing * 0.5)
		var z_back := back + (off if "b" in sides else spacing * 0.5)
		var count := maxi(roundi((z_front - z_back) / spacing), 1)
		for side: float in [-1.0, 1.0]:
			var row: Array = []
			if "s" in sides:
				for i in count + 1:
					var at := Vector3(side * x_side, 0.0, lerpf(z_front, z_back, float(i) / count))
					row.append([at, _column(part, part["capital"], at, col_h, radius, 1.0)])
				var runs := _architraves(row, col_h, radius, beam, spacing * 1.6, 0.9)
				if roofed and ring == rows - 1:
					for run: Array in runs:
						if _roof_luck.randf() >= ruin * 1.1:
							_beam("roof_slab", Vector3(minf(side * (x_side - radius), side * wide * 0.5), col_h + beam, run[1].z - radius), Vector3(maxf(side * (x_side - radius), side * wide * 0.5), col_h + beam + slab, run[0].z + radius))
		for which: String in ["f", "b"]:
			if not which in sides:
				continue
			var z_row := z_front if which == "f" else z_back
			var across := maxi(roundi(x_side * 2.0 / spacing), 2)
			var row: Array = []
			if "s" in sides:
				row.append([Vector3(-x_side, 0.0, z_row), false])
			for j in range(0 if not "s" in sides else 1, across if "s" in sides else across + 1):
				var at := Vector3(lerpf(-x_side, x_side, float(j) / across), 0.0, z_row)
				var in_lane := false
				for axis: float in _axes:
					in_lane = in_lane or absf(at.x - axis) < lane
				if in_lane:
					row.append([at, false])
					continue
				row.append([at, _column(part, part["capital"], at, col_h, radius, 1.0)])
			var runs := _architraves(row, col_h, radius, beam, spacing * 1.6, 0.9)
			if roofed and ring == rows - 1:
				var z_wall := z0 if which == "f" else back
				for run: Array in runs:
					if _roof_luck.randf() >= ruin * 1.1:
						_beam("roof_slab", Vector3(run[0].x - radius, col_h + beam, minf(z_row + (radius if which == "b" else -radius), z_wall)), Vector3(run[1].x + radius, col_h + beam + slab, maxf(z_row + (radius if which == "b" else -radius), z_wall)))
	if part.get("altar", false):
		var half := maxf(1.6 * _k, 0.8)
		_p.fit("altar", Vector3(0.0, 0.0, z0 - deep * 0.5), Vector3(half * 2.0, maxf(1.3 * _k, 0.8), half * 2.0))
	if part.get("mosque", false):
		_mosque(wide, z0, deep, col_h)
	_prev_width = wide
	_prev_shade = 1.0
	_prev_top = 0.0
	return back


# The mosque of Abu el-Haggag, as it stood in the first court of Luxor on what
# had not been dug: a bank of earth to the tops of the columns, with steps up
# it, and on it a whitewashed building with a dome and a minaret. It is on the
# left as he comes in.
func _mosque(wide: float, z0: float, deep: float, col_h: float) -> void:
	var bank := maxf(col_h * 0.66, 2.0)
	var earth := TempleParts.tint(0.8, S.COURSED)
	var x0 := -wide * 0.5
	var x1 := -wide * 0.13
	var z1 := z0 - deep * 0.46
	_p.box(Vector3(x0, 0.0, z1), Vector3(x1, bank, z0), earth)
	# Steps up its side, towards the middle of the court.
	var steps := ceili(bank / 0.22)
	var each := bank / steps
	var tread := 0.36
	var broad := maxf(2.0 * _k, 1.4)
	for step in steps:
		_p.box(Vector3(x1, 0.0, z1 + step * tread), Vector3(x1 + broad, each * (step + 1), z1 + (step + 1) * tread + (0.0 if step < steps - 1 else broad)), earth)
	# The hall, its door towards the court, and the minaret at its corner.
	var size := Vector3((x1 - x0) * 0.6, 0.0, (z0 - z1) * 0.58)
	var hall := Vector3(x0 + (x1 - x0) * 0.42, bank, z1 + (z0 - z1) * 0.59)
	var model := TempleParts.bounds("mosque")
	size.y = model.size.y * maxf(_k, 0.5)
	_p.fit("mosque", hall, size)
	var tall := maxf(15.0 * _k, 7.0)
	var tower := TempleParts.bounds("minaret")
	var foot := Vector3(hall.x + size.x * 0.5 - tower.size.x * 0.5 * tall / tower.size.y, bank, hall.z - size.z * 0.5 - tower.size.z * 0.6 * tall / tower.size.y)
	_p.fit("minaret", foot, Vector3(0.0, tall, 0.0), 1.0, false)
	_p.solid_cylinder(foot, tower.size.x * 0.5 * tall / tower.size.y, tall * 0.76)
	_mark("Mosque", Vector3(hall.x + size.x * 0.5 + 1.5, bank, hall.z), &"temple_mosque")
	height = maxf(height, bank + tall)


# ---- A hall of columns (or, with no columns, a plain room). ----

# Where the columns of a hall stand across it: none on an axis, and a wider aisle there.
func _across(count: int, half: float, radius: float) -> Array[float]:
	var found: Array[float] = []
	if _axes.size() == 1:
		var pairs := maxi(count / 2, 1)
		var step := half / (pairs + 0.425)
		var aisle := maxf(1.35 * step, DOOR.x + radius * 2.0 + 0.6)
		step = (half - aisle * 0.5) / (pairs - 0.25)
		for i in pairs:
			found.append(aisle * 0.5 + i * step)
			found.append(-(aisle * 0.5 + i * step))
	else:
		found.append(0.0)
		var each := maxi((count - 1) / 2, 1)
		var step := (half - _twin) / (each - 0.25) if each > 1 else 0.0
		for i in each:
			found.append(_twin + i * step)
			found.append(-(_twin + i * step))
	found.sort()
	return found


func _hall(part: Dictionary, z0: float, doors_at: Array) -> float:
	var wide := float(part["w"]) * _k
	var deep := float(part["d"]) * _k
	var thick := _thick(part)
	var whole: float = part.get("standing", 1.0)
	var front: String = part.get("front", "wall")
	var has_columns := part.has("col_h")
	var col_h := float(part.get("col_h", 0.0)) * _k
	var radius := float(part.get("col_r", 0.0)) * _k
	var beam := maxf(0.09 * col_h, 0.45) if has_columns else 0.0
	var slab := maxf(0.05 * _reference, 0.35)
	var ceiling: float = col_h + beam if has_columns else float(part["h"]) * _k
	var wall_h: float = float(part["h"]) * _k if part.has("h") and has_columns else ceiling + slab
	var shade := _shade(part)
	var broken := ruin if whole > 0.99 else maxf(ruin, 0.3)
	var inside := TempleParts.tint(shade * 0.95, S.RELIEF)
	var outside := TempleParts.tint(1.0, S.RELIEF)
	var door := _door(part.get("door", [3.4, 7.0])[0], part.get("door", [3.4, 7.0])[1])
	door.y = minf(door.y, maxf(ceiling - 0.6, DOOR.y))
	var widest := maxf(_prev_width, wide)
	if front == "wall":
		var doors: Array = []
		for axis: float in _axes:
			doors.append([axis, door.x, door.y])
			doors_at.append([axis, z0 - thick * 0.5, door.y])
			_mark("Doorway", Vector3(axis, 0.0, z0 - thick * 0.5), &"temple_doorways", {"wide": door.x, "tall": door.y, "thick": thick})
		var front_h: float = maxf(maxf(float(part.get("front_h", 0.0)) * _k, wall_h), _prev_top)
		_p.wall(-widest * 0.5 - thick, widest * 0.5 + thick, z0 - thick, z0, front_h, true,
			{"doors": doors, "front": TempleParts.tint(_prev_shade * 0.97, S.RELIEF), "back": inside, "standing": whole, "ruin": broken, "random": _wall_luck, "course": _course()})
		if whole > 0.99 and ruin < 0.5:
			# The king's titles beside each doorway, on the side he comes to it from.
			var panel := Vector2(minf(1.3, door.x * 0.5), minf(door.y * 0.7, 4.0))
			for axis: float in _axes:
				for side: float in [-1.0, 1.0]:
					if _axes.size() > 1 and side * axis < 0.0:
						continue
					_carve(_king() if int(part["i"]) % 2 == 0 else "@offering", Vector3(axis + side * (door.x * 0.5 + 0.35 + panel.x * 0.5), 0.45 + panel.y * 0.5 + sand, z0 + 0.004), Vector3.BACK, panel, _prev_shade)
		if part.get("guards", false):
			for side: float in [-1.0, 1.0]:
				_p.fit("colossus_seated", Vector3(side * (door.x * 0.5 + 3.4 * _k + 1.0), 0.0, z0 + 2.6 * _k + 0.4), Vector3(0.0, 7.0 * _k, 0.0), _prev_shade)
		z0 -= thick
	elif absf(_prev_width - wide) > 1.0 and part.get("shoulders", true) and _prev_width > 0.0:
		var narrow := minf(_prev_width, wide) * 0.5
		for side: float in [-1.0, 1.0]:
			_p.wall(minf(side * narrow, side * (widest * 0.5 + thick)), maxf(side * narrow, side * (widest * 0.5 + thick)), z0 - thick, z0, wall_h, true,
				{"front": outside, "back": inside, "standing": whole, "ruin": broken, "random": _wall_luck, "course": _course()})
	var back := z0 - deep
	for side: float in [-1.0, 1.0]:
		_p.wall(back, z0, minf(side * wide * 0.5, side * (wide * 0.5 + thick)), maxf(side * wide * 0.5, side * (wide * 0.5 + thick)), wall_h, false,
			{"front": outside if side > 0.0 else inside, "back": inside if side > 0.0 else outside, "standing": whole, "ruin": broken, "random": _wall_luck, "course": _course()})
	height = maxf(height, wall_h)
	_drift_spots.append(Vector3(wide * 0.5 - 1.8, 0.0, back + 2.0))
	_drift_spots.append(Vector3(-wide * 0.5 + 1.8, 0.0, z0 - 2.0))
	if shade < 0.98:
		# Under a roof the floor is dark too.
		var dim := TempleParts.tint(shade, S.COURSED)
		_p.quad(Vector3(-wide * 0.5, 0.02, back), Vector3(wide * 0.5, 0.02, back), Vector3(wide * 0.5, 0.02, z0), Vector3(-wide * 0.5, 0.02, z0), Vector3.UP, dim)
	var has_roof: bool = float(part.get("roof", 0.0)) > 0.0 and whole > 0.99
	var under := TempleParts.tint(shade * 0.8, S.COURSED)
	var over := TempleParts.tint(1.0, S.COURSED)
	if not has_columns:
		if has_roof:
			_roof_cells([-wide * 0.5 - thick, 0.0, wide * 0.5 + thick], [z0, back], [], ceiling, slab, part)
		_prev_width = wide
		_prev_shade = shade
		_prev_top = ceiling + slab if has_roof else 0.0
		return back

	# The columns: so many across, so many deep.
	var count_x := int(part["across"])
	var count_z := int(part["deep"])
	var xs := _across(count_x, wide * 0.5, radius)
	var least := INF
	for i in xs.size() - 1:
		least = minf(least, xs[i + 1] - xs[i])
	least = minf(least, (wide * 0.5 - xs[-1]) * 2.0)
	radius = minf(radius, maxf((least - ROOM) * 0.5, 0.2))
	var zs: Array[float] = []
	for j in count_z:
		zs.append(z0 - (j * deep / count_z + maxf(radius, 0.3) if front == "screen" else (j + 0.5) * deep / count_z))
	# Which rows are the two beside the middle aisle, and stand taller, if it has a nave.
	var lift := float(part.get("nave", 0.0)) * _k if _axes.size() == 1 and xs.size() >= 4 else 0.0
	var mid := xs.size() / 2
	var grid: Array = []
	for i in xs.size():
		var tall := lift > 0.0 and (i == mid - 1 or i == mid)
		var line: Array = []
		for j in zs.size():
			var at := Vector3(xs[i], 0.0, zs[j])
			var kind: C = C.OPEN if tall and part["capital"] == C.BUD else part["capital"]
			line.append([at, _column(part, kind, at, col_h + (lift if tall else 0.0), radius * (1.12 if tall else 1.0), shade)])
		grid.append(line)
		_architraves(line, col_h + (lift if tall else 0.0), radius, beam, deep / count_z * 1.5, shade)
		if tall:
			# (the side roof rests on a beam of its own, and between the two is the grille)
			_architraves(line, col_h, radius, beam, deep / count_z * 1.5, shade)
			var bar := TempleParts.tint(1.0, S.SMOOTH)
			for j in zs.size() - 1:
				if not (line[j][1] and line[j + 1][1]):
					continue
				var from := zs[j + 1] + radius
				var to := zs[j] - radius
				for strip in 5:
					if strip % 2 == 0:
						_p.box(Vector3(xs[i] - 0.2, col_h + beam, lerpf(from, to, strip / 5.0)), Vector3(xs[i] + 0.2, col_h + lift, lerpf(from, to, (strip + 1) / 5.0)), bar)
				if i == mid and has_roof and shade < 0.8:
					# Light through the grille, falling across the aisle.
					var top := col_h + beam + lift * 0.5
					_p.light(Vector3(xs[i], col_h + lift, from), Vector3(xs[i], col_h + lift, to), Vector3(xs[i] - (top + lift) * 0.55, 0.0, to), Vector3(xs[i] - (top + lift) * 0.55, 0.0, from))
					var lit := TempleParts.tint(1.25, S.COURSED)
					_p.quad(Vector3(xs[mid - 1] + radius, 0.03, from), Vector3(xs[mid] - radius, 0.03, from), Vector3(xs[mid] - radius, 0.03, to), Vector3(xs[mid - 1] + radius, 0.03, to), Vector3.UP, lit)
	if front == "screen":
		_screens(part, xs, grid, z0, wide, col_h, radius, beam, shade, doors_at)
	if has_roof:
		var lines: Array[float] = [-wide * 0.5 - thick]
		lines.append_array(xs)
		lines.append(wide * 0.5 + thick)
		var rows: Array[float] = [z0]
		rows.append_array(zs)
		rows.append(back)
		_roof_cells(lines, rows, grid, ceiling, slab, part, lift, mid)
		if whole > 0.99 and ruin < 0.08 and float(part["roof"]) >= 1.0 and lift <= 0.0:
			var crown := clampf(0.08 * col_h, 0.5, 1.5)
			_p.cornice(Rect2(-wide * 0.5 - thick, back, wide + thick * 2.0, z0 - back), ceiling + slab, crown, 1.0)
			height = maxf(height, ceiling + slab + crown)
		# Light let down through the roof, on to the aisle.
		if shade < 0.8 and lift <= 0.0 and float(part["roof"]) >= 0.95:
			for j in range(1, zs.size(), 2):
				for axis: float in _axes:
					var zc := (zs[j - 1] + zs[j]) * 0.5
					var reach := maxf(0.5 * _k, 0.35)
					_p.light(Vector3(axis - reach * 0.6, ceiling, zc - reach), Vector3(axis - reach * 0.6, ceiling, zc + reach), Vector3(axis + ceiling * 0.22 - reach, 0.0, zc + reach * 1.3), Vector3(axis + ceiling * 0.22 - reach, 0.0, zc - reach * 1.3))
					_p.light(Vector3(axis - reach * 0.6, ceiling, zc - reach), Vector3(axis + reach * 0.6, ceiling, zc - reach), Vector3(axis + ceiling * 0.22 + reach * 0.4, 0.0, zc - reach * 1.3), Vector3(axis + ceiling * 0.22 - reach, 0.0, zc - reach * 1.3), 0.6)
					var x_lit := axis + ceiling * 0.22
					_p.quad(Vector3(x_lit - reach, 0.03, zc - reach * 1.3), Vector3(x_lit + reach * 0.4, 0.03, zc - reach * 1.3), Vector3(x_lit + reach * 0.4, 0.03, zc + reach * 1.3), Vector3(x_lit - reach, 0.03, zc + reach * 1.3), Vector3.UP, TempleParts.tint(1.3, S.COURSED))
	if part.get("falcon", false):
		_p.fit("falcon", Vector3(-(_twin * 0.5 + door.x * 0.5 + 1.6 * _k + 0.8), 0.0, z0 + 2.2 * _k + 0.6), Vector3(0.0, maxf(3.4 * _k, 1.6), 0.0))
	_prev_width = wide
	_prev_shade = shade
	_prev_top = ceiling + slab if has_roof else 0.0
	return back


# The half-height walls between the columns of a hall's front row, as the
# Ptolemies built them, with a doorway on each axis; and the beam and cornice over the row.
func _screens(part: Dictionary, xs: Array[float], grid: Array, z0: float, wide: float, col_h: float, radius: float, beam: float, shade: float, doors_at: Array) -> void:
	var whole: float = part.get("standing", 1.0)
	var high := maxf(0.46 * col_h, 2.0) * (1.0 if whole > 0.99 else whole)
	var half := maxf(0.3 * _k, 0.25)
	var z_row: float = grid[0][0][0].z
	var outside := TempleParts.tint(1.0, S.RELIEF)
	var inside := TempleParts.tint(shade, S.RELIEF)
	var colours := [outside, outside, outside, inside, outside]
	var row: Array = []
	var edges: Array[float] = [-wide * 0.5]
	edges.append_array(xs)
	edges.append(wide * 0.5)
	for i in xs.size():
		row.append(grid[i][0])
	for i in edges.size() - 1:
		var from := edges[i]
		var to := edges[i + 1]
		var is_door := false
		for axis: float in _axes:
			if axis > from and axis < to:
				is_door = true
				# The doorway: its jambs stand higher than the screens, and nothing joins them over it.
				var clear := maxf(minf(_door(4.4, 0.0).x, to - from - radius * 2.0 - 0.5), minf(DOOR.x, to - from - radius * 2.0))
				var jamb_h := minf(col_h * 0.74, col_h - 0.3) * (1.0 if whole > 0.99 else whole)
				_p.box(Vector3(from, 0.0, z_row - half * 1.3), Vector3(axis - clear * 0.5, jamb_h, z_row + half * 1.3), colours)
				_p.box(Vector3(axis + clear * 0.5, 0.0, z_row - half * 1.3), Vector3(to, jamb_h, z_row + half * 1.3), colours)
				doors_at.append([axis, z_row, col_h])
				_mark("Doorway", Vector3(axis, 0.0, z_row), &"temple_doorways", {"wide": clear, "tall": jamb_h, "thick": half * 2.6})
				if whole > 0.99 and ruin < 0.5:
					var panel := Vector2(minf((to - from - clear) * 0.5 - radius * 0.4, 1.3), minf(jamb_h * 0.5, 4.0))
					if panel.x > 0.5:
						for side: float in [-1.0, 1.0]:
							_carve(_king(), Vector3(axis + side * (clear * 0.5 + panel.x * 0.5 + 0.08), 0.45 + panel.y * 0.5 + sand, z_row + half * 1.3 + 0.004), Vector3.BACK, panel, 1.0)
		if not is_door:
			if whole > 0.99:
				_p.fit("screen_wall", Vector3((from + to) * 0.5, 0.0, z_row), Vector3(to - from, high, half * 2.0 * 1.63), 1.0)
			else:
				_p.box(Vector3(from, 0.0, z_row - half), Vector3(to, high, z_row + half), colours)
	if whole > 0.99:
		_architraves(row, col_h, radius, beam, wide, 1.0)


# The slabs of a roof: one to each space between the lines of beams (`lines`,
# across) and the rows of columns (`rows`, front to back), where what would
# carry it still stands and ruin has not had it.
func _roof_cells(lines: Array, rows: Array, grid: Array, ceiling: float, slab: float, part: Dictionary, lift := 0.0, mid := -1) -> void:
	var share: float = part.get("roof", 1.0)
	for i in lines.size() - 1:
		var high := ceiling + (lift if lift > 0.0 and i == mid else 0.0)
		var from := -1
		for j in rows.size():
			var kept := j < rows.size() - 1 and _roof_luck.randf() < share and _roof_luck.randf() >= ruin * 1.15
			if kept and not grid.is_empty():
				# (the columns at its corners must stand)
				for corner: Array in [[i - 1, j - 1], [i, j - 1], [i - 1, j], [i, j]]:
					if corner[0] >= 0 and corner[0] < grid.size() and corner[1] >= 0 and corner[1] < grid[corner[0]].size():
						kept = kept and grid[corner[0]][corner[1]][1]
			if kept and from < 0:
				from = j
			elif not kept and from >= 0:
				_beam("roof_slab", Vector3(lines[i], high, rows[j]), Vector3(lines[i + 1], high + slab, rows[from]))
				from = -1


# ---- The sanctuary. ----

func _shrine(part: Dictionary, z0: float, doors_at: Array, sanctuaries: Array[Vector3]) -> float:
	var wide := float(part["w"]) * _k
	var deep := float(part["d"]) * _k
	var thick := _thick(part)
	var whole: float = part.get("standing", 1.0)
	var ceiling := maxf(float(part["h"]) * _k, DOOR.y + 0.6)
	var slab := maxf(0.05 * _reference, 0.35)
	var shade := _shade(part, 0.32)
	var broken := ruin if whole > 0.99 else maxf(ruin, 0.3)
	var inside := TempleParts.tint(shade, S.RELIEF)
	var outside := TempleParts.tint(1.0, S.RELIEF)
	var door := _door(part["door"][0], part["door"][1])
	door.y = minf(door.y, ceiling - 0.5)
	var options := {"standing": whole, "ruin": broken, "random": _wall_luck, "course": _course()}
	var doors: Array = []
	for axis: float in _axes:
		doors.append([axis, door.x, door.y])
		doors_at.append([axis, z0 - thick * 0.5, door.y])
		_mark("Doorway", Vector3(axis, 0.0, z0 - thick * 0.5), &"temple_doorways", {"wide": door.x, "tall": door.y, "thick": thick})
	var widest := maxf(_prev_width, wide)
	_p.wall(-widest * 0.5 - thick, widest * 0.5 + thick, z0 - thick, z0, maxf(ceiling + slab, _prev_top), true, options.merged({"doors": doors, "front": TempleParts.tint(_prev_shade * 0.97, S.RELIEF), "back": inside}))
	z0 -= thick
	var back := z0 - deep
	for side: float in [-1.0, 1.0]:
		_p.wall(back, z0, minf(side * wide * 0.5, side * (wide * 0.5 + thick)), maxf(side * wide * 0.5, side * (wide * 0.5 + thick)), ceiling + slab, false,
			options.merged({"front": outside if side > 0.0 else inside, "back": inside if side > 0.0 else outside}))
	_p.wall(-wide * 0.5 - thick, wide * 0.5 + thick, back - thick, back, ceiling + slab, true, options.merged({"front": inside, "back": outside}))
	height = maxf(height, ceiling + slab)
	if shade < 0.98:
		_p.quad(Vector3(-wide * 0.5, 0.02, back), Vector3(wide * 0.5, 0.02, back), Vector3(wide * 0.5, 0.02, z0), Vector3(-wide * 0.5, 0.02, z0), Vector3.UP, TempleParts.tint(shade, S.COURSED))
	# The rooms: each a room inside the room, with a way round it.
	var inner := maxf(0.9 * _k, 0.5)
	var half := _twin * 0.5 - inner * 0.5 if _axes.size() > 1 else 0.0
	var around := maxf((wide * 0.5 - (_twin if _axes.size() > 1 else 0.0)) * (1.0 if _axes.size() > 1 else 0.3), ROOM + 0.5)
	if _axes.size() == 1:
		half = maxf(wide * 0.5 - around - inner, door.x * 0.5 + 0.6)
	var gap := maxf(minf(around, deep * 0.16), ROOM + 0.5)
	var room_front := z0 - gap
	var room_back := back + gap + inner
	var room_door := Vector2(minf(door.x, half * 2.0 - 0.8), door.y)
	var room_shade := shade * 0.85
	var room_in := TempleParts.tint(room_shade, S.RELIEF)
	for which in _axes.size():
		var axis := _axes[which]
		_p.wall(axis - half - inner, axis + half + inner, room_front - inner, room_front, ceiling, true, options.merged({"doors": [[axis, room_door.x, room_door.y]], "front": inside, "back": room_in}))
		_p.wall(axis - half - inner, axis + half + inner, room_back - inner, room_back, ceiling, true, options.merged({"front": room_in, "back": inside}))
		for side: float in [-1.0, 1.0]:
			if _axes.size() > 1 and side * axis < 0.0 and which == 1:
				continue
			_p.wall(room_back, room_front - inner, minf(axis + side * half, axis + side * (half + inner)), maxf(axis + side * half, axis + side * (half + inner)), ceiling, false,
				options.merged({"front": room_in if side < 0.0 else inside, "back": inside if side < 0.0 else room_in}))
		doors_at.append([axis, room_front - inner * 0.5, room_door.y])
		_mark("Doorway", Vector3(axis, 0.0, room_front - inner * 0.5), &"temple_doorways", {"wide": room_door.x, "tall": room_door.y, "thick": inner})
		# In it: the stand for the god's boat, and at the back the naos.
		var room_deep := room_front - inner - room_back
		var naos_h := float(part.get("naos", 0.0)) * _k
		var stand := Vector3(minf(maxf(1.6 * _k, 0.9), half * 0.8), maxf(1.1 * _k, 0.7), minf(maxf(2.2 * _k, 1.1), room_deep * 0.3))
		var stand_at := Vector3(axis, 0.0, room_front - inner - room_deep * (0.5 if naos_h > 0.0 else 0.6))
		if _axes.size() > 1:
			# (at Kom Ombo what is left of each is the black stone its boat stood on)
			_p.box(stand_at - Vector3(stand.x, 0.0, stand.z) * 0.5, stand_at + Vector3(stand.x * 0.5, stand.y, stand.z * 0.5), TempleParts.tint(1.0, S.SMOOTH, 0, S.GREY_GRANITE))
		else:
			_p.fit("barque_stand", stand_at, stand, room_shade * 1.3)
		if naos_h > 0.0:
			naos_h = clampf(naos_h, 1.8, ceiling - 0.4)
			_p.fit("naos", Vector3(axis, 0.0, room_back + naos_h * 0.3 + 0.3), Vector3(0.0, naos_h, 0.0), room_shade * 1.5)
			_carve("{Hr|Horus}" if plan == Plan.EDFU else _king(), Vector3(axis, naos_h * 0.74 + 0.06 * naos_h, room_back + 0.3 + naos_h * 0.3 + naos_h * 0.24 + 0.034 * naos_h), Vector3.BACK, Vector2(naos_h * 0.34, naos_h * 0.07), room_shade * 1.5)
		if whole > 0.99 and ruin < 0.5:
			for side: float in [-1.0, 1.0]:
				var panel := Vector2(minf(room_deep * 0.5, 4.0), minf(ceiling * 0.3, 1.6))
				_carve("@offering" if side < 0.0 else "@praise", Vector3(axis + side * (half - 0.004), 1.0 + panel.y * 0.5 + sand, room_back + room_deep * 0.5), Vector3(-side, 0.0, 0.0), panel, room_shade)
		sanctuaries.append(Vector3(axis, 0.0, room_front - inner - minf(room_deep * 0.28, 2.5)))
		_mark("Sanctuary", sanctuaries[-1], &"temple_sanctuary")
		if shade < 0.8:
			# One shaft of light, on to the stand.
			var reach := maxf(0.4 * _k, 0.3)
			_p.light(Vector3(axis - reach, ceiling, stand_at.z - reach), Vector3(axis + reach, ceiling, stand_at.z - reach), Vector3(axis + reach * 1.6, stand.y, stand_at.z + reach), Vector3(axis - reach * 1.6, stand.y, stand_at.z + reach), 0.8)
	# The doors of the chapels that open off the way round: dark, and shut.
	var dark := TempleParts.tint(0.0, S.SMOOTH, 0, S.DARK)
	var chapel := Vector2(maxf(1.5 * _k, 1.0), minf(maxf(3.4 * _k, 2.2), ceiling - 0.5))
	if whole > 0.99:
		var count := maxi(int(deep / maxf(6.0 * _k, 3.5)), 1)
		for i in count:
			var at := lerpf(z0, back, (i + 0.5) / count)
			for side: float in [-1.0, 1.0]:
				var x := side * (wide * 0.5 - 0.012)
				_p.quad(Vector3(x, 0.0, at - chapel.x * 0.5), Vector3(x, 0.0, at + chapel.x * 0.5), Vector3(x, chapel.y, at + chapel.x * 0.5), Vector3(x, chapel.y, at - chapel.x * 0.5), Vector3(-side, 0.0, 0.0), dark)
		for i in maxi(int(wide / maxf(8.0 * _k, 4.0)), 1):
			var at := lerpf(-wide * 0.5, wide * 0.5, (i + 0.5) / maxi(int(wide / maxf(8.0 * _k, 4.0)), 1))
			_p.quad(Vector3(at - chapel.x * 0.5, 0.0, back + 0.012), Vector3(at + chapel.x * 0.5, 0.0, back + 0.012), Vector3(at + chapel.x * 0.5, chapel.y, back + 0.012), Vector3(at - chapel.x * 0.5, chapel.y, back + 0.012), Vector3.BACK, dark)
	if float(part.get("roof", 0.0)) > 0.0 and whole > 0.99:
		var under := TempleParts.tint(shade * 0.8, S.COURSED)
		_roof_cells([-wide * 0.5 - thick, -wide * 0.17, wide * 0.17, wide * 0.5 + thick], [z0, z0 - deep * 0.33, z0 - deep * 0.66, back - thick], [], ceiling, slab, part)
		if ruin < 0.08:
			_p.cornice(Rect2(-wide * 0.5 - thick, back - thick, wide + thick * 2.0, deep + thick), ceiling + slab, clampf(0.1 * ceiling, 0.5, 1.2), 1.0)
	_drift_spots.append(Vector3(wide * 0.5 - 1.5, 0.0, back + 1.5))
	_prev_width = wide
	_prev_shade = shade
	return back - thick


# ---- Round it and before it. ----

# The wall round it all, from the back of the pylon: between it and the temple is a walk open to the sky.
func _enclosure(spec: Dictionary, from: float, to: float) -> void:
	var half := float(spec["w"]) * 0.5 * _k
	var thick := _thick(spec)
	var high := maxf(float(spec["h"]) * _k, 2.4)
	var whole: float = spec.get("standing", 1.0)
	var carved := TempleParts.tint(0.97, S.RELIEF)
	var options := {"standing": whole, "ruin": ruin if whole > 0.99 else maxf(ruin, 0.35), "random": _wall_luck, "course": _course(), "front": carved, "back": carved}
	for side: float in [-1.0, 1.0]:
		_p.wall(to, from, minf(side * half, side * (half + thick)), maxf(side * half, side * (half + thick)), high, false, options)
	_p.wall(-half - thick, half + thick, to, to + thick, high, true, options)
	height = maxf(height, high * whole)
	_drift_spots.append(Vector3(half - 2.0, 0.0, to + thick + 2.5))
	_drift_spots.append(Vector3(-half + 2.0, 0.0, (from + to) * 0.5))


# What stands before the pylon: falcons by the gate, colossi, obelisks; and the way up to it.
func _approach(set_out: Dictionary, first: Dictionary) -> void:
	var gate := _door(first.get("gate_w", 4.5), 0.0).x
	var beside := _twin * 0.5 + gate * 0.5 + maxf(1.7 * _k, 0.7)
	var falcon_h := maxf(float(set_out.get("falcon_h", 3.4)) * _k, 1.5)
	for i in int(set_out.get("falcons", 0)):
		var side := -1.0 if i == 0 else 1.0
		_p.fit("falcon", Vector3(side * (beside + falcon_h * 0.3 + 0.5), 0.0, falcon_h * 0.28 + 1.2), Vector3(0.0, falcon_h, 0.0))
	var seated := maxf(float(set_out.get("colossus_h", 12.0)) * _k, 2.5)
	var x_seated := beside + seated * 0.26 + 0.6
	for i in int(set_out.get("colossi", 0)):
		_p.fit("colossus_seated", Vector3((-1.0 if i == 0 else 1.0) * x_seated, 0.0, seated * 0.32 + 0.8), Vector3(0.0, seated, 0.0))
	for side: float in set_out.get("standing_colossi", []):
		var tall := seated * 0.8
		_p.fit("colossus_standing", Vector3(side * float(first["w"]) * 0.5 * _k * 0.66, 0.0, tall * 0.2 + 1.0), Vector3(0.0, tall, 0.0))
	var needle := maxf(float(set_out.get("obelisk_h", 22.0)) * _k, 4.0)
	var x_needle := x_seated + seated * 0.2 + needle * 0.09 + ROOM
	var z_needle := seated * 0.7 + needle * 0.08 + 1.5
	for side: float in set_out.get("obelisks", []):
		_p.fit("obelisk", Vector3(side * x_needle, 0.0, z_needle), Vector3(0.0, needle, 0.0))
		_carve(_king(), Vector3(side * x_needle, needle * 0.45, z_needle + needle * 0.048 - 0.016 * needle * 0.44 + 0.01), Vector3.BACK, Vector2(needle * 0.05, needle * 0.5), 1.0)
		height = maxf(height, needle)
	for side: float in set_out.get("pedestals", []):
		_p.fit("obelisk_pedestal", Vector3(side * x_needle, 0.0, z_needle), Vector3(0.0, needle * 0.07, 0.0))
	for pair in 6:
		for side: float in [-1.0, 1.0]:
			_mark("Avenue", Vector3(side * (beside + 3.0 * _k + 1.5), -_p.shift.y, z_needle + needle * 0.2 + (pair + 1) * maxf(7.0 * _k, 3.5)), &"temple_avenue")


# A sacred lake: a stone tank with a kerb to climb over, and water in it to wade in.
func _lake(at: Vector3, across: Vector2) -> void:
	var kerb := 1.0
	var thick := 0.7
	var stone := TempleParts.tint(1.0, S.COURSED)
	var half := across * 0.5
	_p.box(Vector3(at.x - half.x - thick, 0.0, at.z - half.y - thick), Vector3(at.x + half.x + thick, kerb, at.z - half.y), stone)
	_p.box(Vector3(at.x - half.x - thick, 0.0, at.z + half.y), Vector3(at.x + half.x + thick, kerb, at.z + half.y + thick), stone)
	_p.box(Vector3(at.x - half.x - thick, 0.0, at.z - half.y), Vector3(at.x - half.x, kerb, at.z + half.y), stone)
	_p.box(Vector3(at.x + half.x, 0.0, at.z - half.y), Vector3(at.x + half.x + thick, kerb, at.z + half.y), stone)
	# A step down into it on the side towards the temple.
	_p.box(Vector3(at.x - half.x, 0.0, at.z - 1.2), Vector3(at.x - half.x + 0.7, 0.5, at.z + 1.2), stone)
	_p.box(Vector3(at.x - half.x - thick - 0.7, 0.0, at.z - 1.2), Vector3(at.x - half.x - thick, 0.5, at.z + 1.2), stone)
	_pools.append([at + Vector3.UP * 0.8, Vector3(across.x, 0.8, across.y)])
	_mark("Lake", at, &"temple_lake")


# What ruin leaves lying about: blocks from the walls, the drums of fallen
# columns, and sand blown into the corners. None of it lies in the way in.
func _rubble(ground: Rect2, lanes: Array[Rect2]) -> void:
	var luck := _luck(53)
	var level := maxf(sand, 0.0)
	var size := clampf(_k, 0.6, 1.0)
	var clear := func(rect: Rect2) -> bool:
		for lane: Rect2 in lanes:
			if lane.intersects(rect):
				return false
		for taken: Rect2 in _p.standing:
			if taken.intersects(rect):
				return false
		return true
	for fallen: Array in _fallen:
		var radius: float = fallen[1]
		var long: float = fallen[2]
		for attempt in 5:
			var away := Vector3(luck.randf_range(-1.0, 1.0), 0.0, luck.randf_range(-1.0, 1.0)) * (radius * 2.0 + long + 2.0)
			var at: Vector3 = fallen[0] + away
			var reach := maxf(long * 0.5, radius) + 0.2
			if not clear.call(Rect2(at.x - reach - 0.8, at.z - reach - 0.8, (reach + 0.8) * 2.0, (reach + 0.8) * 2.0)):
				continue
			# (lying on its side)
			var lying := Basis(Vector3.UP, luck.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5)
			var where := Transform3D(lying, at + Vector3.UP * (level + radius * 0.92))
			_p.place("column_drum", where * Transform3D(Basis.from_scale(Vector3(radius, long, radius)), Vector3.ZERO), 1.0, false)
			var shape := CylinderShape3D.new()
			shape.radius = radius
			shape.height = long * 0.92
			_p.solid(shape, where)
			_p.standing.append(Rect2(at.x - reach, at.z - reach, reach * 2.0, reach * 2.0))
			break
	for b in int(ruin * 34.0):
		var block := Vector3(luck.randf_range(1.2, 2.4), luck.randf_range(0.6, 1.1), luck.randf_range(0.8, 1.3)) * size
		var at := Vector3(luck.randf_range(ground.position.x + 2.0, ground.end.x - 2.0), level + block.y * 0.46, luck.randf_range(ground.position.y + 2.0, ground.end.y - 2.0))
		var reach := block.x * 0.75 + 0.8
		if clear.call(Rect2(at.x - reach, at.z - reach, reach * 2.0, reach * 2.0)):
			_p.block(Transform3D(Basis(Vector3.UP, luck.randf() * TAU), at), block, TempleParts.tint(luck.randf_range(0.82, 1.0), S.SMOOTH))
	for d in mini(int(ruin * 16.0), _drift_spots.size() * 2):
		var spot := _drift_spots[d % _drift_spots.size()]
		var radius := Vector2(luck.randf_range(2.0, 4.5), luck.randf_range(2.0, 4.5)) * size
		_p.drift(Vector3(spot.x + luck.randf_range(-1.0, 1.0), level, spot.z + luck.randf_range(-1.0, 1.0)), radius, minf(radius.x, radius.y) * luck.randf_range(0.14, 0.24))


# Sand over everything to a height: level on top, and sloping away all round to the ground.
func _bury(ground: Rect2, floor_y: float) -> void:
	var out := (sand + floor_y) * 2.2 + 1.0
	var top := ground.grow(1.0)
	var foot := top.grow(out)
	var low := -floor_y - 0.4
	var upper: Array[Vector3] = [Vector3(top.position.x, sand, top.position.y), Vector3(top.end.x, sand, top.position.y), Vector3(top.end.x, sand, top.end.y), Vector3(top.position.x, sand, top.end.y)]
	var lower: Array[Vector3] = [Vector3(foot.position.x, low, foot.position.y), Vector3(foot.end.x, low, foot.position.y), Vector3(foot.end.x, low, foot.end.y), Vector3(foot.position.x, low, foot.end.y)]
	_p.sand(upper[0], upper[1], upper[2])
	_p.sand(upper[0], upper[2], upper[3])
	for side in 4:
		var next := (side + 1) % 4
		_p.sand(upper[side], upper[next], lower[next])
		_p.sand(upper[side], lower[next], lower[side])
	var hull := ConvexPolygonShape3D.new()
	var corners := PackedVector3Array(upper)
	corners.append_array(PackedVector3Array(lower))
	hull.points = corners
	_p.solid(hull, Transform3D.IDENTITY)


# ---- Making nodes of it all. ----

func _finish() -> void:
	var course := _course()
	var register := clampf(3.2 * _k, 1.4, 3.6)
	var wear := 0.3 + 0.5 * ruin
	var stone := S.surface(colour, course, register, wear, painted)
	var mesh := ArrayMesh.new()
	triangles = 0
	if not _p.points.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _p.stone_arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, stone)
		triangles += _p.points.size() / 3
	if not _p.sand_points.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _p.sand_points
		arrays[Mesh.ARRAY_NORMAL] = _p.sand_normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Sand.surface())
		triangles += _p.sand_points.size() / 3
	var model := MeshInstance3D.new()
	model.name = "Model"
	model.mesh = mesh
	add_child(model)
	if not _p.beam_points.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _p.beam_points
		arrays[Mesh.ARRAY_COLOR] = _p.beam_colours
		arrays[Mesh.ARRAY_TEX_UV] = _p.beam_uvs
		var beams := ArrayMesh.new()
		beams.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		beams.surface_set_material(0, S.beam())
		var light := MeshInstance3D.new()
		light.name = "Light"
		light.mesh = beams
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(light)
		triangles += _p.beam_points.size() / 3
	triangles_far = triangles

	_draw_models(stone)
	# The great figures cut in the pylon, and the winged discs over its gates.
	_cut_figures()
	# Real writing, where he comes close.
	for carving: Array in _carvings:
		var made := Inscription.new()
		var facing: Vector3 = carving[2]
		made.transform = Transform3D(Basis(Vector3.UP.cross(facing).normalized(), Vector3.UP, facing), carving[1] + _p.shift)
		made.size = carving[3]
		made.columns = carving[3].y > carving[3].x * 1.2
		made.colour = colour * float(carving[4])
		made.wear = clampf(0.15 + ruin * 0.5, 0.0, 0.8)
		made.painted = painted > 0.45
		made.draw_distance = 60.0
		made.text = carving[0]
		add_child(made)

	for solid: Array in _p.solids:
		var collider := CollisionShape3D.new()
		collider.shape = solid[0]
		collider.transform = solid[1]
		add_child(collider)
	shapes = _p.solids.size()
	for mark: Array in _marks:
		var marker := Marker3D.new()
		marker.name = mark[0]
		marker.position = mark[1] + _p.shift
		for key: String in mark[3]:
			marker.set_meta(key, mark[3][key])
		add_child(marker, true)
		marker.add_to_group(mark[2])
	for hook: Vector3 in _hooks:
		if hook.y > sand + 2.5:
			GrapplePoint.mark(self, hook + _p.shift)
	for pool: Array in _pools:
		if sand > 0.3:
			continue
		var water := Pool.new()
		water.name = "Lake"
		water.size = pool[1]
		water.position = pool[0] + _p.shift
		add_child(water)
	_p = null


func _cut_figures() -> void:
	var kinds := {"king": [S.SMITING, Vector2(100, 120)], "god": [S.GOD, Vector2(100, 120)]}
	for kind: String in kinds:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var tangents := PackedFloat32Array()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		var across := Vector2.ONE
		for decal: Array in _decals:
			if decal[0] != kind:
				continue
			var middle: Vector3 = decal[1] + _p.shift
			var right: Vector3 = decal[2]
			var up: Vector3 = decal[3]
			var normal := right.cross(up).normalized()
			var from := vertices.size()
			across = Vector2(right.length(), up.length()) * 2.0
			vertices.append_array(PackedVector3Array([middle - right + up, middle + right + up, middle + right - up, middle - right - up]))
			for i in 4:
				normals.append(normal)
				tangents.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
			var flipped: bool = decal[4]
			uv.append_array(PackedVector2Array([Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]) if flipped else PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
			indices.append_array(PackedInt32Array([from, from + 1, from + 2, from, from + 2, from + 3]))
		if vertices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var cut := MeshInstance3D.new()
		cut.name = "Figures"
		cut.mesh = mesh
		cut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var paint: Color = HieroglyphSigns.PAINTS["r"]
		cut.material_override = S.carved(S.figure(kinds[kind][0], kinds[kind][1], paint), across, colour, clampf(0.15 + ruin * 0.5, 0.0, 0.8), painted)
		add_child(cut, true)
		triangles += indices.size() / 3
		triangles_far += indices.size() / 3


# The models: all that were placed of one kind are drawn at once. Columns are
# kept apart by the part of the temple they stand in, and each lot is drawn
# from far off as a coarser model.
func _draw_models(stone: Material) -> void:
	for key: String in _p.placed:
		var lot: Dictionary = _p.placed[key]
		var places: Array = lot["at"]
		var middle := Vector3.ZERO
		for where: Transform3D in places:
			middle += where.origin / places.size()
		var reach := 0.0
		for where: Transform3D in places:
			reach = maxf(reach, (where.origin - middle).length())
		var has_far: bool = lot["far"] != ""
		var change := reach + 30.0 + 25.0 * _k
		for coarse: bool in ([false, true] if has_far else [false]):
			var mesh := TempleParts.model(lot["far"] if coarse else lot["model"])
			if mesh == null:
				push_warning("Temple: no model called %s in %s" % [lot["model"], TempleParts.MODELS])
				continue
			var many := MultiMesh.new()
			many.transform_format = MultiMesh.TRANSFORM_3D
			many.use_colors = true
			many.mesh = mesh
			many.instance_count = places.size()
			for i in places.size():
				var where: Transform3D = places[i]
				many.set_instance_transform(i, Transform3D(where.basis, where.origin - middle))
				many.set_instance_color(i, Color(lot["shade"][i], 1.0, 1.0, 1.0))
			var drawn := MultiMeshInstance3D.new()
			drawn.name = String(lot["model"]).to_pascal_case() + ("Far" if coarse else "")
			drawn.multimesh = many
			drawn.material_override = stone
			drawn.position = middle + _p.shift
			if coarse:
				drawn.visibility_range_begin = change
				# (and it is the coarse one that casts the shadows of the near ones, too)
				var shadow := MultiMeshInstance3D.new()
				shadow.name = String(lot["model"]).to_pascal_case() + "Shadow"
				shadow.multimesh = many
				shadow.material_override = stone
				shadow.position = middle + _p.shift
				shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				shadow.visibility_range_end = change
				add_child(shadow, true)
			elif has_far:
				drawn.visibility_range_end = change
				drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(drawn, true)
			var count: int = mesh.surface_get_array_len(0) / 3 * places.size()
			if coarse or not has_far:
				triangles_far += count
			if not coarse:
				triangles += count


# The nilometer: the model of the well, and what is solid of it: its kerb as a ring of boxes, and the water in it.
func _well(at: Vector3, radius: float) -> void:
	var model := TempleParts.bounds("well")
	var by := radius / (model.size.x * 0.5 * 1.3 / 1.8)
	_p.place("well", Transform3D(Basis.from_scale(Vector3.ONE * by), at), 1.0, false)
	var outer := model.size.x * 0.5 * by
	var kerb := model.size.y * by
	var thick := outer - radius
	var sides := 12
	for side in sides:
		var middle := TAU * (side + 0.5) / sides
		var shape := BoxShape3D.new()
		shape.size = Vector3(thick, kerb, 2.0 * outer * tan(PI / sides) + 0.02)
		_p.solid(shape, Transform3D(Basis(Vector3.UP, -middle), at + Vector3(cos(middle), 0.0, sin(middle)) * (radius + thick * 0.5) + Vector3.UP * kerb * 0.5))
	var water := CylinderShape3D.new()
	water.radius = radius + thick * 0.5
	water.height = kerb * 0.44
	_p.solid(water, Transform3D(Basis.IDENTITY, at + Vector3.UP * kerb * 0.22))
	_p.standing.append(Rect2(at.x - outer, at.z - outer, outer * 2.0, outer * 2.0))
