class_name GuardianMesh
## What a gate guardian is modelled from (`GateGuardian`): the head of each
## beast, and the lumps of clay they and the rest of him are made of. Nothing
## is loaded: a head is a few balls, tubes and flat pieces put together in
## code, some three hundred triangles, and one draw for each of its colours.
##
##     var clay := GuardianMesh.Clay.new()
##     GuardianMesh.head(clay, BookOfTheDead.Head.JACKAL)
##     mesh_instance.mesh = clay.mesh()
##
## A head is built facing +Z, with the top of the neck at its origin.

const GOLD := &"gold"
const BLADE := &"blade"
const STONE := &"stone"
const EYE := &"eye"

static var _materials := {}


## Clay: shapes are pressed into it, each in a colour, and `mesh` gives all of
## them back as one mesh with a surface for each colour used. A colour is a
## `Color`, or one of the names above (gold, a bronze blade, stone, a lit eye).
class Clay:
	var _tools := {}

	func _tool(colour: Variant) -> SurfaceTool:
		if not _tools.has(colour):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[colour] = tool
		return _tools[colour]

	# A triangle, wound whichever way faces its normals.
	func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
		if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
			var held := b
			b = c
			c = held
			var held_n := nb
			nb = nc
			nc = held_n
		tool.set_normal(na)
		tool.add_vertex(a)
		tool.set_normal(nb)
		tool.add_vertex(b)
		tool.set_normal(nc)
		tool.add_vertex(c)

	func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
		_tri(tool, a, b, c, normal, normal, normal)
		_tri(tool, a, c, d, normal, normal, normal)

	## A round limb from `a` to `b`, `ra` thick at one end and `rb` at the
	## other (0 for a point), `flat` times as thick across as it is deep.
	func tube(colour: Variant, a: Vector3, b: Vector3, ra: float, rb: float, sides := 7, flat := 1.0) -> void:
		var tool := _tool(colour)
		var along := (b - a).normalized()
		# (across is from side to side of him, wherever the limb points)
		var across := Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.BACK
		var side := (across - along * along.dot(across)).normalized()
		var other := along.cross(side).normalized()
		side *= flat
		var ring_a: Array[Vector3] = []
		var ring_b: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for n in sides:
			var turn := TAU * n / sides
			var out := side * cos(turn) + other * sin(turn)
			ring_a.append(a + out * ra)
			ring_b.append(b + out * rb)
			normals.append((side / (flat * flat) * cos(turn) + other * sin(turn)).normalized())
		for n in sides:
			var m := (n + 1) % sides
			if rb > 0.0:
				_tri(tool, ring_a[n], ring_b[n], ring_b[m], normals[n], normals[n], normals[m])
			if ra > 0.0:
				_tri(tool, ring_a[n], ring_b[m], ring_a[m], normals[n], normals[m], normals[m])
			# (and its ends are closed)
			if ra > 0.0:
				_tri(tool, a, ring_a[n], ring_a[m], -along, -along, -along)
			if rb > 0.0:
				_tri(tool, b, ring_b[n], ring_b[m], along, along, along)

	## A ball, or an egg: `radii` each way, turned by `turn`.
	func ball(colour: Variant, at: Vector3, radii: Vector3, turn := Basis.IDENTITY, sides := 8, rings := 5) -> void:
		var tool := _tool(colour)
		var points: Array = []
		var normals: Array = []
		for ring in rings + 1:
			var down := PI * ring / rings
			var row: Array[Vector3] = []
			var row_n: Array[Vector3] = []
			for n in sides:
				var round := TAU * n / sides
				var unit := Vector3(sin(down) * cos(round), cos(down), sin(down) * sin(round))
				row.append(at + turn * (unit * radii))
				row_n.append((turn * (unit / radii)).normalized())
			points.append(row)
			normals.append(row_n)
		for ring in rings:
			for n in sides:
				var m := (n + 1) % sides
				if ring > 0:
					_tri(tool, points[ring][n], points[ring][m], points[ring + 1][m], normals[ring][n], normals[ring][m], normals[ring + 1][m])
				if ring < rings - 1:
					_tri(tool, points[ring][n], points[ring + 1][m], points[ring + 1][n], normals[ring][n], normals[ring + 1][m], normals[ring + 1][n])

	## A box, `size` each way, its middle at `at`.
	func box(colour: Variant, at: Vector3, size: Vector3, turn := Basis.IDENTITY) -> void:
		var tool := _tool(colour)
		var half := size * 0.5
		for axis in 3:
			for way: float in [-1.0, 1.0]:
				var normal := Vector3.ZERO
				normal[axis] = way
				var u := Vector3.ZERO
				u[(axis + 1) % 3] = 1.0
				var v := Vector3.ZERO
				v[(axis + 2) % 3] = 1.0
				var corners: Array[Vector3] = []
				for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					corners.append(at + turn * ((normal + u * corner.x + v * corner.y) * half))
				_quad(tool, corners[0], corners[1], corners[2], corners[3], turn * normal)

	## A flat piece cut to an outline: `outline` is drawn on the plane of `place`
	## (its x and y) and the piece is `thick` through (along its z). The outline
	## must bulge outwards all the way round.
	func slab(colour: Variant, outline: PackedVector2Array, thick: float, place: Transform3D) -> void:
		var tool := _tool(colour)
		var count := outline.size()
		var front: Array[Vector3] = []
		var back: Array[Vector3] = []
		var middle := Vector2.ZERO
		for point in outline:
			front.append(place * Vector3(point.x, point.y, thick * 0.5))
			back.append(place * Vector3(point.x, point.y, -thick * 0.5))
			middle += point / count
		var face := place.basis.z.normalized()
		for n in range(1, count - 1):
			_tri(tool, front[0], front[n], front[n + 1], face, face, face)
			_tri(tool, back[0], back[n], back[n + 1], -face, -face, -face)
		for n in count:
			var m := (n + 1) % count
			var edge := outline[m] - outline[n]
			var out := Vector2(edge.y, -edge.x).normalized()
			if out.dot((outline[n] + outline[m]) * 0.5 - middle) < 0.0:
				out = -out
			_quad(tool, front[n], front[m], back[m], back[n], (place.basis * Vector3(out.x, out.y, 0.0)).normalized())

	## A horn, or anything that curves: tubes from each point to the next, thinning from `thick` to `tip`.
	func horn(colour: Variant, points: Array, thick: float, tip: float, sides := 5) -> void:
		for n in points.size() - 1:
			var from := lerpf(thick, tip, float(n) / (points.size() - 1))
			var to := lerpf(thick, tip, float(n + 1) / (points.size() - 1))
			tube(colour, points[n], points[n + 1], from, to, sides)

	## All of it, as one mesh: a surface for each colour.
	func mesh() -> ArrayMesh:
		var made := ArrayMesh.new()
		for colour: Variant in _tools:
			var tool: SurfaceTool = _tools[colour]
			tool.commit(made)
			made.surface_set_material(made.get_surface_count() - 1, GuardianMesh.material(colour))
		return made

	## How many triangles are in it.
	func triangles() -> int:
		var count := 0
		for colour: Variant in _tools:
			count += (_tools[colour] as SurfaceTool).commit_to_arrays()[Mesh.ARRAY_VERTEX].size() / 3
		return count


## The material of a colour of clay.
static func material(colour: Variant) -> Material:
	var key := "%s|%s" % [colour, Settings.world_banded]
	if _materials.has(key):
		return _materials[key]
	var made: Material
	if colour is Color:
		made = Toon.surface(colour)
	elif colour == GOLD:
		made = Toon.gold()
	elif colour == BLADE:
		made = Toon.gold(Color(0.78, 0.6, 0.34))
	elif colour == STONE:
		made = Toon.sandstone(Sandstone.COLOUR.darkened(0.3))
	else:
		# (an eye: it is seen in the dark)
		var lit := StandardMaterial3D.new()
		lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lit.albedo_color = Color(1.0, 0.78, 0.2)
		made = lit
	_materials[key] = made
	return made


## Presses the head of a beast into `clay`: facing +Z, the top of the neck at
## the origin. `wig` is the colour of the cloth that hangs behind it.
static func head(clay: Clay, kind: int, wig := BookOfTheDead.LAPIS) -> void:
	var hide: Color = BookOfTheDead.HIDES[kind]
	var dark := hide.darkened(0.45)
	var pale := Color(0.93, 0.9, 0.8)
	# Where its eyes are: how high, how far forward, how far apart, and how big.
	var eyes := Vector3(0.085, 0.17, 0.1)
	var eye_size := 0.024
	match kind:
		BookOfTheDead.Head.JACKAL:
			clay.ball(hide, Vector3(0, 0.13, 0.0), Vector3(0.12, 0.13, 0.14))
			clay.tube(hide, Vector3(0, 0.12, 0.08), Vector3(0, 0.07, 0.4), 0.075, 0.035, 7)
			clay.ball(dark, Vector3(0, 0.075, 0.41), Vector3(0.03, 0.028, 0.03), Basis.IDENTITY, 6, 4)
			for x: float in [-1.0, 1.0]:
				clay.tube(hide, Vector3(0.075 * x, 0.2, -0.04), Vector3(0.1 * x, 0.52, -0.06), 0.06, 0.0, 5, 0.55)
			eyes = Vector3(0.09, 0.17, 0.11)
		BookOfTheDead.Head.CROCODILE:
			clay.ball(hide, Vector3(0, 0.11, 0.0), Vector3(0.14, 0.11, 0.15))
			clay.tube(hide, Vector3(0, 0.1, 0.08), Vector3(0, 0.07, 0.56), 0.062, 0.05, 7, 1.7)
			clay.ball(hide, Vector3(0, 0.085, 0.57), Vector3(0.09, 0.05, 0.05), Basis.IDENTITY, 7, 4)
			for x: float in [-1.0, 1.0]:
				clay.ball(hide, Vector3(0.075 * x, 0.2, 0.06), Vector3(0.045, 0.05, 0.055), Basis.IDENTITY, 6, 4)
				# (teeth, down each side of the jaw)
				for n in 6:
					clay.tube(pale, Vector3(0.088 * x, 0.06, 0.2 + n * 0.065), Vector3(0.088 * x, 0.015, 0.2 + n * 0.065), 0.014, 0.0, 4)
			eyes = Vector3(0.1, 0.215, 0.085)
		BookOfTheDead.Head.SNAKE:
			# (a cobra: the hood spread behind, the head small at the top of it)
			clay.ball(hide, Vector3(0, 0.2, -0.03), Vector3(0.22, 0.24, 0.05))
			clay.ball(dark, Vector3(0, 0.2, 0.005), Vector3(0.13, 0.18, 0.035))
			clay.tube(hide, Vector3(0, 0.0, 0.0), Vector3(0, 0.38, 0.02), 0.07, 0.06, 7)
			clay.ball(hide, Vector3(0, 0.4, 0.1), Vector3(0.075, 0.055, 0.13))
			clay.tube(Color(0.7, 0.12, 0.1), Vector3(0, 0.385, 0.2), Vector3(0, 0.36, 0.33), 0.012, 0.004, 4)
			eyes = Vector3(0.062, 0.425, 0.16)
			eye_size = 0.02
		BookOfTheDead.Head.VULTURE:
			clay.tube(hide, Vector3(0, 0.0, 0.0), Vector3(0, 0.22, 0.03), 0.06, 0.055, 7)
			clay.ball(pale, Vector3(0, 0.04, 0.0), Vector3(0.17, 0.08, 0.16))
			clay.ball(hide, Vector3(0, 0.28, 0.05), Vector3(0.115, 0.11, 0.135))
			var beak := Color(0.3, 0.26, 0.22)
			clay.tube(beak, Vector3(0, 0.28, 0.13), Vector3(0, 0.25, 0.34), 0.06, 0.04, 6)
			clay.tube(beak, Vector3(0, 0.255, 0.33), Vector3(0, 0.12, 0.36), 0.04, 0.0, 6)
			eyes = Vector3(0.09, 0.31, 0.11)
			eye_size = 0.02
		BookOfTheDead.Head.HIPPOPOTAMUS:
			clay.ball(hide, Vector3(0, 0.14, -0.02), Vector3(0.17, 0.15, 0.17))
			clay.ball(hide, Vector3(0, 0.1, 0.24), Vector3(0.19, 0.13, 0.2))
			for x: float in [-1.0, 1.0]:
				clay.ball(hide, Vector3(0.13 * x, 0.29, -0.06), Vector3(0.04, 0.05, 0.03), Basis.IDENTITY, 6, 4)
				clay.ball(dark, Vector3(0.07 * x, 0.2, 0.4), Vector3(0.03, 0.025, 0.03), Basis.IDENTITY, 6, 4)
				clay.tube(pale, Vector3(0.1 * x, 0.02, 0.37), Vector3(0.11 * x, 0.14, 0.4), 0.028, 0.0, 5)
			eyes = Vector3(0.115, 0.24, 0.09)
		BookOfTheDead.Head.RAM:
			clay.ball(hide, Vector3(0, 0.13, 0.0), Vector3(0.12, 0.13, 0.14))
			clay.tube(hide, Vector3(0, 0.13, 0.06), Vector3(0, 0.05, 0.3), 0.085, 0.05, 7)
			clay.ball(dark, Vector3(0, 0.04, 0.31), Vector3(0.04, 0.03, 0.03), Basis.IDENTITY, 6, 4)
			var horn_colour := Color(0.5, 0.4, 0.26)
			for x: float in [-1.0, 1.0]:
				# (each horn curls back, down and forward again round the ear)
				var curl: Array = []
				for n in 8:
					var turn := -0.5 + n * 0.62
					curl.append(Vector3((0.1 + n * 0.014) * x, 0.14 + cos(turn) * 0.1, -0.02 - sin(turn) * 0.1))
				clay.horn(horn_colour, curl, 0.045, 0.012, 5)
			eyes = Vector3(0.085, 0.16, 0.12)
		BookOfTheDead.Head.HARE:
			clay.ball(hide, Vector3(0, 0.12, 0.0), Vector3(0.11, 0.12, 0.13))
			clay.ball(hide, Vector3(0, 0.09, 0.14), Vector3(0.075, 0.07, 0.1))
			clay.ball(dark, Vector3(0, 0.1, 0.24), Vector3(0.022, 0.018, 0.015), Basis.IDENTITY, 5, 3)
			for x: float in [-1.0, 1.0]:
				clay.ball(hide, Vector3(0.055 * x, 0.45, -0.05), Vector3(0.04, 0.26, 0.025), Basis.from_euler(Vector3(-0.1, 0.0, -0.08 * x)))
				clay.ball(Color(0.86, 0.66, 0.58), Vector3(0.055 * x, 0.45, -0.035), Vector3(0.022, 0.2, 0.016), Basis.from_euler(Vector3(-0.1, 0.0, -0.08 * x)), 6, 4)
			eyes = Vector3(0.09, 0.15, 0.07)
			eye_size = 0.028
		BookOfTheDead.Head.LION:
			clay.ball(dark, Vector3(0, 0.12, -0.06), Vector3(0.21, 0.23, 0.17))
			clay.ball(hide, Vector3(0, 0.14, 0.04), Vector3(0.125, 0.13, 0.13))
			clay.ball(hide, Vector3(0, 0.09, 0.17), Vector3(0.085, 0.07, 0.08))
			clay.ball(dark, Vector3(0, 0.115, 0.245), Vector3(0.03, 0.022, 0.018), Basis.IDENTITY, 5, 3)
			for x: float in [-1.0, 1.0]:
				clay.ball(hide, Vector3(0.12 * x, 0.3, -0.02), Vector3(0.045, 0.045, 0.025), Basis.IDENTITY, 6, 4)
			eyes = Vector3(0.105, 0.185, 0.13)
		BookOfTheDead.Head.BULL:
			clay.ball(hide, Vector3(0, 0.14, 0.0), Vector3(0.13, 0.14, 0.14))
			clay.tube(hide, Vector3(0, 0.13, 0.06), Vector3(0, 0.04, 0.29), 0.1, 0.075, 7)
			clay.ball(pale, Vector3(0, 0.035, 0.3), Vector3(0.08, 0.055, 0.04), Basis.IDENTITY, 7, 4)
			for x: float in [-1.0, 1.0]:
				clay.horn(pale, [Vector3(0.09 * x, 0.24, -0.02), Vector3(0.24 * x, 0.3, -0.02), Vector3(0.33 * x, 0.46, -0.01), Vector3(0.31 * x, 0.66, 0.02)], 0.038, 0.008, 5)
				clay.ball(hide, Vector3(0.17 * x, 0.17, -0.04), Vector3(0.06, 0.03, 0.035), Basis.IDENTITY, 6, 4)
			eyes = Vector3(0.1, 0.17, 0.115)
	for x: float in [-1.0, 1.0]:
		clay.ball(EYE, Vector3(eyes.x * x, eyes.y, eyes.z), Vector3.ONE * eye_size, Basis.IDENTITY, 6, 4)
	# The cloth of the wig, over the back of the head (a lion has its mane, a cobra its hood).
	if kind != BookOfTheDead.Head.LION and kind != BookOfTheDead.Head.SNAKE and kind != BookOfTheDead.Head.VULTURE:
		clay.ball(wig, Vector3(0, 0.12, -0.07), Vector3(0.15, 0.16, 0.13))
