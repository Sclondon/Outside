@tool
class_name SandDunes
extends RefCounted
## Dunes as the wind makes them, as a height any level can ask for:
##
##     var dunes := SandDunes.new()
##     dunes.wind = Vector2(1.0, 0.3)            # the way it blows, over the ground (x, z)
##     dunes.add_barchan(Vector2(40, 10), 46.0, 6.0)
##     dunes.add_ridge(Vector2(-80, -60), Vector2(-60, 70), 8.0)
##     dunes.scatter(Rect2(-120, -120, 240, 240), 14)      # or let it place them
##     var y := dunes.height_at(x, z)
##
## Every dune is one line on the ground, its brink: the edge the sand is blown
## up to and falls from. Upwind of it the back of the dune rises gently, an S
## in outline; downwind the slip face falls away at the angle sand lies at
## (`REPOSE`), exactly, because it is the heap you get by pouring sand along
## that line. A barchan is a brink bent into a crescent, its horns downwind
## and running out to nothing; a transverse ridge is a long one lying across
## the wind and wandering a little. Between dunes the floor is nearly level.
##
## `height_at` is a plain function of place: the same answer every time, no
## state, so a level can call it for its mesh, its collider and anything it
## sets down. `bake` fills a whole grid at once and is much quicker than
## asking point by point.

## The angle a slip face stands at.
const REPOSE := deg_to_rad(32.0)
## The back of a dune is this many times as long as the dune is high (its
## steepest part is then about 12 degrees).
const BACK := 7.0
## A dune is no higher than this share of half its width, so that its ends
## can run out to nothing without standing steeper than sand does.
const SQUAT := 0.36

## The way the wind blows, over the ground (x, z). Set it before adding dunes.
var wind := Vector2(1.0, 0.0):
	set(value):
		wind = value.normalized() if value.length() > 0.001 else Vector2(1.0, 0.0)
## How far the floor between the dunes rolls, up and down, metres; and across
## what distance.
var floor_roll := 0.18
var floor_span := 23.0
## A different number gives a different floor, and different dunes from `scatter`.
var seed := 1

# Each dune: [frame, brink, heights, bounds]. It is measured in a frame of its
# own: `along` the wind and `across` it, from a point of its own. The brink is
# how far downwind it lies at each of a row of places evenly spaced across the
# wind, and `heights` how high it stands at each. `frame` is the point (x, z),
# the wind (x, z), where across the wind the row starts, how far apart its
# places are, and how far a slip face can reach from the brink.
var _dunes: Array = []


## A crescent dune with the middle of its brink at `at`: `width` from horn to
## horn across the wind, `height` at the middle. `horns` is how far downwind
## the tips reach, as a share of the width; `lean` makes one longer than the
## other. Says how high it really is (it is made lower if it would be too
## squat to stand).
func add_barchan(at: Vector2, width: float, height: float, horns := 0.55, lean := 0.0) -> float:
	var brink := PackedFloat32Array()
	var heights := PackedFloat32Array()
	var count := 16
	height = minf(height, SQUAT * width * 0.5)
	for i in count + 1:
		var out := float(i) / count * 2.0 - 1.0
		# (an arc: nearly straight across the wind in the middle, and swept
		# round to run with it at the horns)
		brink.append(horns * width * 1.4 * (1.0 - sqrt(1.0 - 0.92 * out * out)) * (1.0 + lean * out))
		heights.append(height * pow(1.0 - out * out, 1.4))
	_add(at, -width * 0.5, width / count, brink, heights)
	return height


## A long dune across the wind, its brink running from `from` to `to` (which
## should lie more or less across the wind) and wandering up and down wind by
## `sway`, as a share of its length. It is highest in its middle part and
## runs out at each end. `wobble` is any number: another gives another line.
func add_ridge(from: Vector2, to: Vector2, height: float, sway := 0.05, wobble := 0) -> float:
	var across := Vector2(-wind.y, wind.x)
	if (to - from).dot(across) < 0.0:
		var swap := from
		from = to
		to = swap
	var width := (to - from).dot(across)
	var slant := (to - from).dot(wind)
	var count := maxi(int(width / 5.0), 6)
	var brink := PackedFloat32Array()
	var heights := PackedFloat32Array()
	height = minf(height, SQUAT * width * 0.5)
	var taper := clampf(height / 0.34 / width, 0.08, 0.5)
	for i in count + 1:
		var share := float(i) / count
		var wander := _noise(share * 3.1 + wobble * 7.3, wobble * 1.7 + 0.5) - 0.5 + 0.5 * (_noise(share * 7.7 + wobble * 3.1, wobble * 5.1) - 0.5)
		brink.append(slant * share + wander * sway * width * 2.0)
		var ends := smoothstep(0.0, taper, share) * smoothstep(0.0, taper, 1.0 - share)
		heights.append(height * ends * (0.78 + 0.44 * _noise(share * 4.3 + wobble * 2.3, 9.0 + wobble)))
	_add(from, 0.0, width / count, brink, heights)
	return height


## Places `count` dunes in `area` by chance: barchans, big and small, and (a
## share `ridges` of them) ridges. `keep_clear`, given a place (Vector2) and a
## reach, says whether a dune may not stand there. `heights` is the lowest and
## the highest. Says how many it found room for.
func scatter(area: Rect2, count: int, heights := Vector2(2.5, 8.0), keep_clear := Callable(), ridges := 0.3) -> int:
	var random := RandomNumberGenerator.new()
	random.seed = seed * 7919 + 13 + _dunes.size()
	var across := Vector2(-wind.y, wind.x)
	var placed := 0
	for attempt in count * 60:
		if placed >= count:
			break
		var at := area.position + Vector2(random.randf(), random.randf()) * area.size
		var height := lerpf(heights.x, heights.y, random.randf())
		var ridge := random.randf() < ridges
		var width := height * (random.randf_range(11.0, 18.0) if ridge else random.randf_range(7.0, 10.0))
		var horns := random.randf_range(0.42, 0.65)
		# (the ground it stands on: its back upwind, its horns and slip face downwind)
		var back := height * BACK
		var front := height / tan(REPOSE) + (0.0 if ridge else horns * width)
		var middle := at + wind * (front - back) * 0.5
		var room := maxf(width, back + front) * 0.5
		if keep_clear.is_valid() and keep_clear.call(middle, room):
			continue
		var crowded := false
		var wanted := Rect2(middle - Vector2.ONE * room * 0.62, Vector2.ONE * room * 1.24)
		for dune: Array in _dunes:
			var bounds: Rect2 = dune[3]
			if bounds.grow(-minf(bounds.size.x, bounds.size.y) * 0.19).intersects(wanted):
				crowded = true
				break
		if crowded:
			continue
		if ridge:
			var lie := across.rotated(random.randf_range(-0.25, 0.25))
			add_ridge(at - lie * width * 0.5, at + lie * width * 0.5, height, 0.05, placed + seed + _dunes.size())
		else:
			add_barchan(at, width, height, horns, random.randf_range(-0.3, 0.3))
		placed += 1
	return placed


## How high the sand stands at a place.
func height_at(x: float, z: float) -> float:
	var height := 0.0
	var at := Vector2(x, z)
	for dune: Array in _dunes:
		if (dune[3] as Rect2).has_point(at):
			height = maxf(height, _dune_height(dune[0], dune[1], dune[2], x, z))
	return height + floor_at(x, z)


## The floor between the dunes alone.
func floor_at(x: float, z: float) -> float:
	if floor_roll <= 0.0:
		return 0.0
	return floor_roll * (_noise(x / floor_span + seed * 3.7, z / floor_span - seed * 1.3) * 2.0 - 1.0)


## The heights of a whole grid at once, row by row: `columns` by `rows`
## corners, `cell` apart, the first at `origin`.
func bake(origin: Vector2, cell: float, columns: int, rows: int) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(columns * rows)
	for dune: Array in _dunes:
		var bounds: Rect2 = dune[3]
		var frame: PackedFloat32Array = dune[0]
		var brink: PackedFloat32Array = dune[1]
		var tall: PackedFloat32Array = dune[2]
		var first_column := maxi(int(ceil((bounds.position.x - origin.x) / cell)), 0)
		var last_column := mini(int(floor((bounds.end.x - origin.x) / cell)), columns - 1)
		var first_row := maxi(int(ceil((bounds.position.y - origin.y) / cell)), 0)
		var last_row := mini(int(floor((bounds.end.y - origin.y) / cell)), rows - 1)
		for row in range(first_row, last_row + 1):
			var z := origin.y + row * cell
			for column in range(first_column, last_column + 1):
				var height := _dune_height(frame, brink, tall, origin.x + column * cell, z)
				if height > heights[row * columns + column]:
					heights[row * columns + column] = height
	if floor_roll > 0.0:
		for row in rows:
			for column in columns:
				heights[row * columns + column] += floor_at(origin.x + column * cell, origin.y + row * cell)
	return heights


## The same dunes, less those `drop` says yes to: it is given the ground each
## covers (a Rect2). For keeping dunes off places without disturbing the rest.
func without(drop: Callable) -> SandDunes:
	var kept := SandDunes.new()
	kept.wind = wind
	kept.floor_roll = floor_roll
	kept.floor_span = floor_span
	kept.seed = seed
	for dune: Array in _dunes:
		if not drop.call(dune[3]):
			kept._dunes.append(dune)
	return kept


## The ground each dune covers.
func bounds() -> Array[Rect2]:
	var all: Array[Rect2] = []
	for dune: Array in _dunes:
		all.append(dune[3])
	return all


func _add(at: Vector2, first: float, gap: float, brink: PackedFloat32Array, heights: PackedFloat32Array) -> void:
	var across := Vector2(-wind.y, wind.x)
	var highest := 0.0
	var upwind := 1.0e9
	var downwind := -1.0e9
	for i in brink.size():
		highest = maxf(highest, heights[i])
		upwind = minf(upwind, brink[i] - heights[i] * BACK - 1.5)
		downwind = maxf(downwind, brink[i] + heights[i] / tan(REPOSE))
	var reach := highest / tan(REPOSE)
	var last := first + gap * (brink.size() - 1)
	var bounds := Rect2(at + across * first + wind * upwind, Vector2.ZERO)
	for corner: Vector2 in [Vector2(first, downwind), Vector2(last, upwind), Vector2(last, downwind)]:
		bounds = bounds.expand(at + across * corner.x + wind * corner.y)
	_dunes.append([PackedFloat32Array([at.x, at.y, wind.x, wind.y, first, gap, reach]), brink, heights, bounds.grow(1.0)])


# One dune's height at a place. Upwind of the brink it is the dune's back;
# downwind, the highest of the heaps that would stand if sand were poured
# along each stretch of the brink.
static func _dune_height(frame: PackedFloat32Array, brink: PackedFloat32Array, heights: PackedFloat32Array, x: float, z: float) -> float:
	var from_x := x - frame[0]
	var from_z := z - frame[1]
	var along := from_x * frame[2] + from_z * frame[3]
	var gap := frame[5]
	var place := (from_z * frame[2] - from_x * frame[3] - frame[4]) / gap
	var last := brink.size() - 1
	if place <= 0.0 or place >= last:
		return 0.0
	var index := int(place)
	var part := place - index
	var edge := brink[index] + (brink[index + 1] - brink[index]) * part
	if along <= edge:
		var height := heights[index] + (heights[index + 1] - heights[index]) * part
		var out := (edge - along) / (height * BACK + 1.5)
		if out >= 1.0:
			return 0.0
		return height * (1.0 - out * out * (3.0 - 2.0 * out))
	var steep := tan(REPOSE)
	var span := int(frame[6] / gap) + 1
	var best := 0.0
	var across := place * gap
	for i in range(maxi(index - span, 0), mini(index + span, last - 1) + 1):
		# (the nearest point of this stretch of the brink)
		var run := brink[i + 1] - brink[i]
		var off_across := across - i * gap
		var off_along := along - brink[i]
		var share := clampf((off_across * gap + off_along * run) / (gap * gap + run * run), 0.0, 1.0)
		off_across -= gap * share
		off_along -= run * share
		var heap := heights[i] + (heights[i + 1] - heights[i]) * share - steep * sqrt(off_across * off_across + off_along * off_along)
		if heap > best:
			best = heap
	return best


static func _hash(x: int, z: int) -> float:
	var n := (x * 374761393 + z * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


# Smooth noise, 0..1.
static func _noise(x: float, z: float) -> float:
	var whole_x := floori(x)
	var whole_z := floori(z)
	var part_x := x - whole_x
	var part_z := z - whole_z
	part_x = part_x * part_x * (3.0 - 2.0 * part_x)
	part_z = part_z * part_z * (3.0 - 2.0 * part_z)
	return lerpf(lerpf(_hash(whole_x, whole_z), _hash(whole_x + 1, whole_z), part_x),
			lerpf(_hash(whole_x, whole_z + 1), _hash(whole_x + 1, whole_z + 1), part_x), part_z)
