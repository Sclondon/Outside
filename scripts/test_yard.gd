extends Node3D
## The test yard: a field of dunes with level ground in the middle of it,
## where everything in the game is set out, a station to each thing, with a
## sign over it. Everything the player can do; everything sand does (it
## glitters underfoot, takes his footprints and is thrown up by his feet, runs
## down the steep faces when he treads on them, blows in the wind, pours from a
## spout and from a slot into heaps that can be walked up, and lies about in
## two wet lumps that slump and can be waded through); water, as a tank to swim
## in and as a pond lying in the sand to wade into; fire; the guns and things
## to shoot; and everyone else: his brother, a cat, and a pen each for the
## hounds and the mummy, and two camels. Run `test_yard.tscn`. The camera orbits; drag to turn it.
##
## The ground is a `SandGround`, made here from `height_at`: dunes from
## `SandDunes` (small ones among the stations, big ones all round), pressed
## flat round each of `FLATS`, with a hollow for one of the lumps and a pit for
## the pool. He comes back to whichever part of the yard he was last in.

const Plate := TombParts.Plate
const Door := TombParts.Door

const PROP := Color(0.6, 0.54, 0.46)
const DARK := Color(0.4, 0.35, 0.3)
const MARK := Color(0.55, 0.4, 0.26)
const WOOD := Color(0.5, 0.38, 0.24)
const SKY := Color(0.62, 0.72, 0.8)
## Half the width of the yard, metres. The ground is squares a metre across.
const YARD := 128
## The way the wind blows, over the ground (x, z): the dunes are shaped by it.
const WIND := Vector2(0.96, 0.28)
## Level ground: the middle of each patch, and how far it runs each way (x, z).
## Round each, the dunes rise over `EASE` metres.
const FLATS: Array[Rect2] = [
	Rect2(0, 0, 9, 9), Rect2(15, -12, 9, 6), Rect2(29.5, 6, 10, 9), Rect2(2, 25, 15, 9),
	Rect2(-16, 8, 5, 5), Rect2(-26, -8, 9, 8), Rect2(-2, -25, 16, 8), Rect2(32, -26, 7, 7),
	Rect2(-9, -8, 5, 5), Rect2(-36, 30, 12, 9), Rect2(-42, -32, 9, 9), Rect2(40, 36, 8, 14),
	Rect2(-44, 6, 7, 6), Rect2(24.5, 27, 7, 6), Rect2(17, -47, 14, 6),
	Rect2(-18, -46, 6, 5),
]
const EASE := 9.0
## The kinds of ground, laid in a row to walk along: the middle of the row, how
## far it runs each way (it is level, like a patch of `FLATS`), and how far it
## is from the middle of one kind to the middle of the next.
const KINDS := Rect2(1.0, 12.5, 16.0, 3.0)
const KIND_GAP := 5.0
## The hollow one lump of sand lies in: where, how wide, how deep.
const HOLLOW := Vector3(32.0, 0.0, -26.0)
const HOLLOW_WIDE := 5.5
const HOLLOW_DEEP := 1.1
## The pool: the middle of its surface, and how wide, deep and long the water is.
const POOL := Vector3(-26.0, -0.3, -8.0)
const POOL_SIZE := Vector3(8.0, 3.2, 6.0)
## The pond: the middle of its surface, how far it reaches, and how deep its middle is.
const POND := Vector3(50.0, -0.35, -12.0)
const POND_WIDE := 7.0
const POND_DEEP := 1.0
## How high the four decks to drop from stand.
const DECKS: Array[float] = [1.5, 2.5, 3.2, 5.0]
## How much of the sun is left on in the web's renderer (see `_build_light`).
const WEB_SUN := 0.3

## The ground, and the wind over it.
var ground: SandGround
var wind: SandWind

var _dunes: SandDunes
var _player: Player
var _marks: Array[Vector3] = []
var _mark := -1
var _loose: Array[RigidBody3D] = []
var _loose_starts: Array[Transform3D] = []
var _hounds: Array[Hound] = []
var _mummy: Mummy


func _ready() -> void:
	_build_light()
	_build_ground()
	_mark_here(Vector3.ZERO, "TEST YARD\nthe plate changes the weather", 3.4)
	for z: float in [-0.6, 0.0, 0.6]:
		_rock(Vector3(3.0, 0.15, 3.0 + z))
	_build_push(Vector3(12.0, 0.0, -12.0))
	_build_low(Vector3(24.0, 0.0, 6.0))
	_build_decks(Vector3(-8.0, 0.0, 24.0))
	_build_wall(Vector3(-16.0, 0.0, 8.0))
	_build_pool()
	_build_falls()
	_build_lumps()
	_build_pond()
	_build_kick(Vector3(-5.5, 0.0, 6.0))
	_build_fire(Vector3(6.5, 0.0, 6.5))
	_build_hounds(Vector3(-36.0, 0.0, 30.0))
	_build_mummy(Vector3(-42.0, 0.0, -32.0))
	_build_range(Vector3(40.0, 0.0, 36.0))
	_build_camels(Vector3(-44.0, 0.0, 6.0))
	_build_dig(Vector3(24.5, 0.0, 27.0))
	_build_grapple(Vector3(6.0, 0.0, -47.0))
	_build_scarabs(Vector3(-18.0, 0.0, -46.0))
	_build_kinds()
	_settle_in.call_deferred()


func _build_light() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.66, 0.7, 0.78)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = SKY
	environment.fog_density = 0.0022
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	# On the web a sun that casts shadows comes out much too bright (see
	# `Sand.sky`). There it is turned down, and the sand is told, so that the
	# sand at least is lit just as it is everywhere else.
	Sand.sun_gain = 1.0
	Sand.sky = Color.BLACK
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy *= WEB_SUN
		Sand.sun_gain = 1.0 / WEB_SUN
		Sand.sky = environment.ambient_light_color.srgb_to_linear() * environment.ambient_light_energy
		# (the haze suffers the same way, only worse, and is left off)
		environment.fog_enabled = false
	add_child(sun)


## How high the ground stands at a place in the yard.
func height_at(x: float, z: float) -> float:
	if ground and ground.is_built():
		return ground.height_at(x, z)
	return _shaped(_dunes.height_at(x, z), x, z)


# What the yard does to the dunes at a place: level ground round the
# stations, the hollow, the pit, and a rise all round to close it in.
func _shaped(dunes: float, x: float, z: float) -> float:
	# The pit the pool is built in. Its sides are steeper than sand would
	# stand, and are hidden behind the pool's walls.
	if absf(x - POOL.x) <= POOL_SIZE.x * 0.5 + 0.01 and absf(z - POOL.z) <= POOL_SIZE.z * 0.5 + 0.01:
		return POOL.y - POOL_SIZE.y - 0.2
	var level := 1.0
	var hollow := 0.0
	if absf(x) < 62.0 and absf(z) < 62.0:
		var at := Vector2(x, z)
		for flat in FLATS:
			var outside := (at - flat.position).abs() - flat.size
			level = minf(level, smoothstep(0.0, EASE, Vector2(maxf(outside.x, 0.0), maxf(outside.y, 0.0)).length()))
		var beside := (at - KINDS.position).abs() - KINDS.size
		level = minf(level, smoothstep(0.0, EASE, Vector2(maxf(beside.x, 0.0), maxf(beside.y, 0.0)).length()))
		hollow = HOLLOW_DEEP * (1.0 - smoothstep(0.0, HOLLOW_WIDE, at.distance_to(Vector2(HOLLOW.x, HOLLOW.z))))
	var rim := 5.0 * smoothstep(YARD - 30.0, YARD, maxf(absf(x), absf(z)))
	var open := dunes * level + rim - hollow
	# The pond: a dish in the sand, its rim at the level of the water.
	var out := Vector2(x - POND.x, z - POND.z).length()
	if out < POND_WIDE:
		return POND.y - POND_DEEP * (1.0 - out * out / (POND_WIDE * POND_WIDE))
	return lerpf(POND.y, open, smoothstep(0.0, 6.0, out - POND_WIDE))


func _build_ground() -> void:
	# The dunes: small ones among the stations, where there is room for them,
	# and a field of big ones all round, shaped by the same wind.
	_dunes = SandDunes.new()
	_dunes.wind = WIND
	_dunes.seed = 4
	var among := func(at: Vector2, room: float) -> bool:
		for flat in FLATS:
			if Rect2(flat.position - flat.size, flat.size * 2.0).grow(room * 0.45 + 1.0).has_point(at):
				return true
		return false
	_dunes.scatter(Rect2(-48.0, -48.0, 96.0, 96.0), 8, Vector2(1.5, 2.8), among, 0.0)
	var beyond := func(at: Vector2, room: float) -> bool:
		return maxf(absf(at.x), absf(at.y)) < 44.0 + room * 0.55 or maxf(absf(at.x), absf(at.y)) > YARD - 12.0
	# (two long ridges across the wind, up and down wind of the yard, and barchans between)
	_dunes.add_ridge(Vector2(-88.0, -70.0), Vector2(-104.0, 60.0), 9.0, 0.05, 3)
	_dunes.add_ridge(Vector2(96.0, -96.0), Vector2(78.0, 40.0), 7.5, 0.06, 8)
	_dunes.scatter(Rect2(-YARD, -YARD, YARD * 2.0, YARD * 2.0), 22, Vector2(3.5, 9.0), beyond, 0.2)
	var side := YARD * 2 + 1
	var heights := _dunes.bake(Vector2(-YARD, -YARD), 1.0, side, side)
	for row in side:
		for column in side:
			heights[row * side + column] = _shaped(heights[row * side + column], column - YARD, row - YARD)
	ground = SandGround.new()
	ground.name = "Ground"
	ground.half = Vector2(YARD, YARD)
	ground.cell = 1.0
	add_child(ground)
	ground.build(heights)
	# Damp sand round the pool, and paths trodden hard from the start to each station.
	ground.paint(Sand.Kind.DAMP, Vector2(POOL.x, POOL.z), 7.5, 1.0, 3.5)
	for to: Vector2 in [Vector2(8.0, -12.0), Vector2(20.0, 6.0), Vector2(-11.0, 24.0), Vector2(-16.0, 3.0), Vector2(-18.0, -8.0), Vector2(-2.0, -20.0), Vector2(25.0, -23.0)]:
		ground.paint_line(Sand.Kind.PACKED, Vector2.ZERO, to, 0.5, 0.85, 1.2)
	wind = SandWind.new()
	wind.name = "Wind"
	wind.direction = WIND
	add_child(wind)
	# A plate by the start: each press, the next weather.
	_switch(Vector3(-3.0, 0.0, 3.5), func() -> void: wind.weather = (wind.weather + 1) % 3 as SandWind.Weather)
	# A wall nothing can see, short of the edge.
	var edge := YARD - 10.0
	for way: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var along := Vector3(absf(way.z), 0.0, absf(way.x))
		_barrier(way * (edge + 0.5) + Vector3.UP * 12.0, along * edge * 2.0 + (Vector3.ONE - along) * Vector3(1.0, 40.0, 1.0))


## Push: the block runs between two rails onto a plate that holds the gate up.
func _build_push(at: Vector3) -> void:
	_mark_here(at + Vector3(-4.0, 0.0, 0.0), "PUSH\nwalk into the block")
	_block(at + Vector3(-2.0, 0.45, 0.0))
	for z: float in [-0.75, 0.75]:
		_solid(at + Vector3(1.0, 0.1, z), Vector3(7.6, 0.2, 0.2), DARK)
	_solid(at + Vector3(4.9, 0.125, 0.0), Vector3(0.24, 0.25, 1.7), DARK)
	var plate := _plate(at + Vector3(3.85, 0.0, 0.0), Vector3(1.5, 0.5, 1.3), false)
	var gate := Door.new(Vector3(0.4, 2.4, 3.0), DARK.lightened(0.1))
	gate.position = at + Vector3(7.0, 1.2, 0.0)
	add_child(gate)
	for z: float in [-3.5, 3.5]:
		_solid(at + Vector3(7.0, 1.6, z), Vector3(0.6, 3.2, 4.0), PROP)
	_solid(at + Vector3(7.0, 2.9, 0.0), Vector3(0.6, 1.0, 3.0), PROP)
	plate.changed.connect(func(pressed: bool) -> void: gate.is_open = pressed)


## Three bars, each lower than the last: to duck under, to slide under, and to
## crawl under on hands and knees.
func _build_low(at: Vector3) -> void:
	_mark_here(at + Vector3(-4.0, 0.0, 0.0), "DUCK, SLIDE, CRAWL\nhold duck  ·  run, then duck\nduck and keep on under the lowest", 3.4)
	for step: Array in [[0.0, 3.0, 0.95], [6.5, 1.6, 0.7], [11.5, 1.4, 0.64]]:
		var middle: Vector3 = at + Vector3(step[0], 0.0, 0.0)
		_solid(middle + Vector3(0.0, step[2] + 0.6, 0.0), Vector3(step[1], 1.2, 6.0), PROP)
		# Closed off at the sides, so the only way on is under
		for z: float in [-5.0, 5.0]:
			_solid(middle + Vector3(0.0, 1.1, z), Vector3(step[1], 2.2, 4.0), DARK)


## Stairs up to the first of four decks, each higher than the last, and a ramp
## back down. Every deck is open on one side to drop from. The next two are
## reached by their ledges, or by the rope; the last by its ladder.
func _build_decks(at: Vector3) -> void:
	_mark_here(at + Vector3(-3.0, 0.0, 0.0), "STAIRS, DROPS, ROPE, LADDER\neach deck is higher: drop off them\nact picks up a rock, act again throws\non the rope: the stick swings it, act climbs, duck lets down", 3.9)
	var rise := DECKS[0] / 8.0
	for i in 8:
		_solid(at + Vector3(i * 0.45, rise * (i + 1) * 0.5, 0.0), Vector3(0.45, rise * (i + 1), 4.0), PROP)
	var edge := 8 * 0.45 - 0.225
	for i in DECKS.size():
		_solid(at + Vector3(edge + 2.0 + i * 4.0, DECKS[i] * 0.5, 0.0), Vector3(4.0, DECKS[i], 4.0), PROP.darkened(0.06 * (i % 2)))
	var ramp := _solid(at + Vector3(edge + 2.0, DECKS[0] * 0.5 - 0.19, 4.5), Vector3(4.0, 0.4, 5.4), PROP)
	ramp.rotation.x = atan2(DECKS[0], 5.0)
	# Rocks to throw down from the first deck
	for z: float in [-1.0, 0.0, 1.0]:
		_rock(at + Vector3(edge + 2.6, DECKS[0] + 0.15, z))
	# A rope beside the third deck, hung from a post
	var third := edge + 10.0
	var rope := Rope.new()
	rope.length = 5.7
	rope.position = at + Vector3(third, 6.5, 3.5)
	add_child(rope)
	_prop(at + Vector3(third, 6.6, 4.1), Vector3(0.25, 0.25, 1.6), DARK)
	_prop(at + Vector3(third, 3.35, 4.8), Vector3(0.3, 6.7, 0.3), DARK)
	# A ladder up the end of the last
	var ladder := Ladder.new()
	ladder.height = DECKS[3]
	ladder.position = at + Vector3(edge + 16.0 + 0.06, 0.0, 0.0)
	ladder.rotation.y = PI * 0.5
	add_child(ladder)


## A wall to catch the top of: too high to jump onto, not too high to reach.
func _build_wall(at: Vector3) -> void:
	_mark_here(at + Vector3(0.0, 0.0, -5.0), "LEDGE\njump at the wall, jump again to climb", 3.6)
	_solid(at + Vector3(0.0, 1.05, 0.0), Vector3(4.0, 2.1, 4.0), PROP)


## The pool, in its pit: walls to hold the sand back, a floor, and a ramp up out
## of it along one side (he cannot swim up steps, nor take hold of a ladder from
## the water; he can also heave himself out over the kerb). Beside it, a bat and
## things to hit.
func _build_pool() -> void:
	_mark_here(POOL + Vector3(POOL_SIZE.x * 0.5 + 4.0, -POOL.y, 0.0), "SWIM  ·  BAT\na gentle push is breast stroke, a full one a crawl\nduck dives  ·  jump comes up, and out at the side\nact picks the bat up, act again swings", 3.6)
	var bottom := POOL.y - POOL_SIZE.y
	var half := POOL_SIZE * 0.5
	var kerb := 0.1
	_solid(Vector3(POOL.x, bottom - 0.15, POOL.z), Vector3(POOL_SIZE.x, 0.3, POOL_SIZE.z), DARK)
	var tall := kerb - bottom + 0.3
	for way: float in [-1.0, 1.0]:
		_solid(Vector3(POOL.x + way * (half.x + 0.5), kerb - tall * 0.5, POOL.z), Vector3(1.0, tall, POOL_SIZE.z + 2.0), PROP)
		_solid(Vector3(POOL.x, kerb - tall * 0.5, POOL.z + way * (half.z + 0.5)), Vector3(POOL_SIZE.x, tall, 1.0), PROP)
	var pool := Pool.new()
	pool.size = POOL_SIZE
	pool.position = POOL
	add_child(pool)
	# The ramp, from the floor at one end up to the kerb at the other
	var run := POOL_SIZE.x - 0.5
	var climb := kerb - bottom
	var facing := Vector3(climb, run, 0.0).normalized()
	var ramp := _solid(Vector3(POOL.x - half.x + run * 0.5, bottom + climb * 0.5, POOL.z - half.z + 0.9) - facing * 0.2,
			Vector3(sqrt(run * run + climb * climb), 0.4, 1.8), DARK.lightened(0.08))
	ramp.rotation.z = -atan2(climb, run)

	var by := Vector3(POOL.x + half.x + 5.0, 0.0, POOL.z + 5.5)
	_bat(by + Vector3(0.0, 0.05, 0.0))
	_solid(by + Vector3(1.5, 0.4, 1.5), Vector3(2.4, 0.8, 0.5), PROP)
	for x: float in [-0.8, 0.0, 0.8]:
		_rock(by + Vector3(1.5 + x, 0.95, 1.5))


## Sand pouring: from a spout on a tower, and from a slot along the top of a
## wall. A plate by each turns it off and on.
func _build_falls() -> void:
	_mark_here(Vector3(-2.0, 0.0, -20.0), "SAND FALLS\nthe plates turn them off and on")
	var tower := Vector3(6.0, 0.0, -28.0)
	_solid(tower + Vector3(0.0, 3.25, 0.0), Vector3(2.4, 6.5, 2.4), PROP)
	_prop(tower + Vector3(0.0, 6.0, 1.8), Vector3(0.5, 0.3, 1.6), DARK)
	var spout := SandFall.new()
	spout.name = "Spout"
	spout.position = tower + Vector3(0.0, 5.85, 2.5)
	add_child(spout)
	_switch(tower + Vector3(4.5, 0.0, 6.0), func() -> void: spout.running = not spout.running)

	var wall := Vector3(-10.0, 0.0, -28.5)
	_solid(wall + Vector3(0.0, 2.1, 0.0), Vector3(7.0, 4.2, 1.4), PROP)
	_solid(wall + Vector3(0.0, 4.2, 1.2), Vector3(3.6, 0.25, 1.4), DARK)
	var slot := SandFall.new()
	slot.name = "Slot"
	slot.width = 3.0
	slot.pile_cap = 2.0
	slot.rate = 0.3
	slot.position = wall + Vector3(0.0, 4.05, 2.0)
	add_child(slot)
	_switch(wall + Vector3(5.0, 0.0, 6.0), func() -> void: slot.running = not slot.running)


## Two lumps of wet sand: one let fall into the hollow among the dunes, one
## into a low-walled pit on the level. The plate by each puts it back.
func _build_lumps() -> void:
	var loose := SandBlob.new()
	loose.count = 96
	loose.reach = Vector2(12.0, 12.0)
	loose.position = HOLLOW + Vector3(1.5, height_at(HOLLOW.x + 1.5, HOLLOW.z) + 0.6, 0.0)
	add_child(loose)
	_mark_here(HOLLOW + Vector3(-7.0, 0.0, 3.0), "WET SAND\nwade through it  ·  the plate puts it back")
	_switch(HOLLOW + Vector3(-7.0, height_at(HOLLOW.x - 7.0, HOLLOW.z), 0.0), loose.reset)

	var pit := Vector3(-9.0, 0.0, -8.0)
	for way: float in [-1.0, 1.0]:
		_solid(pit + Vector3(way * 2.75, 0.25, 0.0), Vector3(0.5, 0.5, 6.0), PROP)
		_solid(pit + Vector3(0.0, 0.25, way * 2.75), Vector3(5.0, 0.5, 0.5), PROP)
	var penned := SandBlob.new()
	penned.count = 64
	penned.reach = Vector2(7.0, 7.0)
	penned.position = pit + Vector3(0.0, 0.4, 0.0)
	add_child(penned)
	_switch(pit + Vector3(0.0, 0.0, 4.5), penned.reset)


## A pond lying in the sand, to wade into: shallow at its edge, over his head in the middle.
func _build_pond() -> void:
	var pond := Pool.new()
	pond.size = Vector3(POND_WIDE * 2.0 + 2.0, POND_DEEP + 0.6, POND_WIDE * 2.0 + 2.0)
	pond.position = POND
	add_child(pond)
	# (it lies in the ground, not in a tank: there are no sides to it to draw)
	pond.water.sides = false
	ground.paint(Sand.Kind.DAMP, Vector2(POND.x, POND.z), POND_WIDE + 2.5, 1.0, 3.0)
	ground.paint_line(Sand.Kind.PACKED, Vector2(29.5, 0.0), Vector2(POND.x - POND_WIDE - 3.0, POND.z), 0.5, 0.85, 1.2)
	var by := Vector3(POND.x - POND_WIDE - 4.0, 0.0, POND.z)
	_mark_here(Vector3(by.x, height_at(by.x, by.z), by.z), "WADE\nwalk in: slowed in the shallows,\nswimming when it is over his chest", 3.2)


## The kinds of ground, side by side in a row north of the start, each fading
## into the next, with plain sand at either end to compare them with: walk the
## length of it. Hard dirt and sandstone take no prints and he does not sink
## into them; the three coloured sands are sand; and the snow keeps the print
## of his boot.
func _build_kinds() -> void:
	var kinds := [
		[Sand.Kind.DIRT, "HARD DIRT\nno prints, no sinking"],
		[Sand.Kind.SANDSTONE, "SANDSTONE\nrock: nothing marks it"],
		[Sand.Kind.WHITE, "WHITE SAND"],
		[Sand.Kind.RED, "RED SAND"],
		[Sand.Kind.BLACK, "BLACK SAND"],
		[Sand.Kind.SNOW, "SNOW\ncrisp prints"],
	]
	var first := KINDS.position.x - KIND_GAP * (kinds.size() - 1) * 0.5
	for i in kinds.size():
		var at := Vector2(first + i * KIND_GAP, KINDS.position.y)
		ground.paint_line(kinds[i][0], at + Vector2(0.0, -1.0), at + Vector2(0.0, 1.0), 1.7, 1.0, 1.4)
		_sign(Vector3(at.x, 2.3, at.y), kinds[i][1])
	_mark_here(Vector3(KINDS.position.x, 0.0, KINDS.position.y - 3.5), "KINDS OF GROUND\nwalk along the row", 3.4)


## Two walls to go up between: jump at one, and jump again against each in turn.
func _build_kick(at: Vector3) -> void:
	_sign(at + Vector3(0.0, 6.2, 0.0), "WALL KICK\njump again in the air against a wall")
	for way: float in [-1.0, 1.0]:
		_solid(at + Vector3(way * 1.0, 2.6, 0.0), Vector3(0.6, 5.2, 3.0), PROP.darkened(0.05))


## A fire to stand by.
func _build_fire(at: Vector3) -> void:
	var hearth := (load("res://props/campfire.tscn") as PackedScene).instantiate() as Node3D
	hearth.position = at
	add_child(hearth)
	var flame := hearth.find_child("Flame*", true, false) as Node3D
	(flame if flame else hearth).add_child(Fire.brazier())
	_sign(at + Vector3(0.0, 2.6, 0.0), "FIRE
act picks the torch up: it lights his way")
	# A torch to carry, stuck in the sand beside it
	var torch := HandTorch.new()
	torch.position = at + Vector3(1.6, 0.02, 0.4)
	torch.rotation.z = 0.12
	torch.freeze = true
	add_child(torch)
	_keep(torch)


## A grappling hook, and things to throw it at: a beam over the gap between two
## decks, to swing across on; and two gallows of different heights to swing from.
func _build_grapple(at: Vector3) -> void:
	_mark_here(at, "GRAPPLING HOOK
act picks it up  ·  the ring shows what it will catch
act throws it: the stick swings, act climbs,
duck lets down, jump lets go", 3.8)
	var hook := GrappleHook.new()
	hook.position = at + Vector3(1.4, 0.16, 0.8)
	hook.rotation.x = PI * 0.5
	hook.freeze = true
	add_child(hook)
	_keep(hook)
	# Two decks a metre high (a step up to the first), five and a half metres apart
	_solid(at + Vector3(3.6, 0.25, 0.0), Vector3(0.8, 0.5, 3.0), PROP.darkened(0.06))
	_solid(at + Vector3(6.0, 0.5, 0.0), Vector3(4.0, 1.0, 3.0), PROP)
	_solid(at + Vector3(15.5, 0.5, 0.0), Vector3(4.0, 1.0, 3.0), PROP)
	# A beam across over the middle of the gap, on two posts, with a ring under it
	for z: float in [-2.4, 2.4]:
		_solid(at + Vector3(10.75, 3.6, z), Vector3(0.3, 7.2, 0.3), DARK)
	_prop(at + Vector3(10.75, 7.3, 0.0), Vector3(0.3, 0.3, 5.4), DARK)
	var ring := GrapplePoint.mark(self, at + Vector3(10.75, 7.1, 0.0), true)
	ring.name = "GrappleBeam"
	# Two gallows on the level beyond, a low one and a high one: a hook holds on the end of each arm
	for gallows: Array in [[Vector3(21.5, 0.0, -3.0), 4.6], [Vector3(25.0, 0.0, 3.2), 8.0]]:
		var foot: Vector3 = at + gallows[0]
		var tall: float = gallows[1]
		_solid(foot + Vector3(0.0, tall * 0.5, 0.0), Vector3(0.3, tall, 0.3), DARK)
		_prop(foot + Vector3(-1.0, tall - 0.15, 0.0), Vector3(2.3, 0.25, 0.25), DARK)
		GrapplePoint.mark(self, foot + Vector3(-2.0, tall - 0.3, 0.0), true)


## Hounds: the plate lets them loose, and calls them off again.
func _build_hounds(at: Vector3) -> void:
	_mark_here(at + Vector3(7.0, 0.0, 0.0), "HOUNDS\nthe plate lets them loose,\nand calls them off", 3.6)
	_switch(at + Vector3(4.0, 0.0, 0.0), _toggle_hounds)
	# Somewhere to climb out of their reach
	_solid(at + Vector3(8.0, 1.05, -5.0), Vector3(3.0, 2.1, 3.0), PROP)
	for kennel: Vector3 in [Vector3(-7.0, 0.1, -1.5), Vector3(-8.5, 0.1, 1.5)]:
		var hound := Hound.new()
		hound.position = at + kennel
		add_child(hound)
		hound.caught.connect(_on_caught.bind(hound))
		_hounds.append(hound)


## The mummies, one of each kind in a row: the plate wakes them all, and puts them back.
func _build_mummy(at: Vector3) -> void:
	_mark_here(at + Vector3(6.0, 0.0, 0.0), "MUMMIES\none of each kind:\nthe plate wakes them,\nand puts them back", 3.6)
	_block(at + Vector3(0.0, 0.45, 3.0))
	_solid(at + Vector3(-2.0, 0.125, 0.0), Vector3(0.24, 0.25, 8.0), DARK)
	_mummy = Mummy.new()
	_mummy.position = at + Vector3(-5.0, 0.05, 0.0)
	add_child(_mummy)
	_mummy.caught.connect(_on_caught.bind(_mummy))
	# The other kinds stand in a row either side of the first.
	var others: Array[Mummy] = []
	var places: Array[float] = [-2.2, 2.2, -4.4, 4.4, -6.6]
	for kind: Mummy.Kind in [Mummy.Kind.PRIEST, Mummy.Kind.BRUTE, Mummy.Kind.CRAWLER, Mummy.Kind.CHILD, Mummy.Kind.ROYAL]:
		var other := Mummy.new()
		other.kind = kind
		other.position = at + Vector3(-5.0, 0.05, places[others.size()])
		add_child(other)
		other.caught.connect(_on_caught.bind(other))
		others.append(other)
	# (the first is woken, put back and called off as it always was; the rest do whatever it has just done)
	var put_back := func() -> void:
		for other in others:
			other.reset()
	_switch(at + Vector3(3.0, 0.0, 0.0), func() -> void:
		_toggle_mummy()
		for other in others:
			other.target = _mummy.target
			if _mummy.is_awake():
				other.wake()
			else:
				other.reset()
		if _player and not _player.respawned.is_connected(put_back):
			_player.respawned.connect(put_back))


## Camels: one saddled and tethered to a peg, and one couched with its packs on.
func _build_camels(at: Vector3) -> void:
	_mark_here(at + Vector3(5.0, 0.0, 0.0), "CAMELS", 3.6)
	var saddled := Camel.new()
	saddled.saddled = true
	saddled.position = at + Vector3(-2.0, 0.1, -2.5)
	saddled.tether = at + Vector3(-3.5, 0.0, -3.0)
	add_child(saddled)
	var resting := Camel.new()
	resting.packed = true
	resting.haltered = true
	resting.couched = true
	resting.rest_for = 100000.0
	resting.position = at + Vector3(0.5, 0.1, 2.5)
	resting.rotation.y = 1.2
	add_child(resting)


## The guns, laid out on a bench, a box of cartridges, and things to shoot at.
func _build_range(at: Vector3) -> void:
	_mark_here(at + Vector3(0.0, 0.0, -12.0), "GUNS\nact picks one up, act again fires\nduck and act puts it down", 3.4)
	_solid(at + Vector3(0.0, 0.4, -8.0), Vector3(4.4, 0.8, 0.9), WOOD)
	var along := -1.5
	for gun: String in ["revolver", "rifle", "shotgun", "flare_pistol"]:
		_set_down("res://guns/%s.tscn" % gun, at + Vector3(along, 0.9, -8.0), PI * 0.5)
		along += 1.0
	_set_down("res://guns/ammo_box.tscn", at + Vector3(3.2, 0.0, -8.0))
	_set_down("res://guns/target_board.tscn", at + Vector3(-4.5, 0.0, 4.0), PI)
	_set_down("res://guns/target_board.tscn", at + Vector3(-1.5, 0.0, 7.0), PI)
	_set_down("res://guns/target_gong.tscn", at + Vector3(2.0, 0.0, 6.0), PI)
	_solid(at + Vector3(4.6, 0.5, 3.0), Vector3(3.0, 1.0, 0.6), PROP)
	var shelf := -1.1
	for thing: String in ["target_pot", "target_jar", "target_jackal", "bottle", "tin_can"]:
		var set := _set_down("res://guns/%s.tscn" % thing, at + Vector3(4.6 + shelf, 1.02, 3.0))
		if &"comes_back" in set:
			set.set(&"comes_back", 6.0)
		shelf += 0.55
	# Something behind it all to stop what misses
	_solid(at + Vector3(0.0, 1.6, 12.5), Vector3(15.0, 3.2, 1.0), DARK)


## A dig: the tools of one set out to pick up (the pick, the shovel, the turia
## and the khopesh are swung as the bat is), what a site is dressed with, the
## helmets on their stands, and somebody wearing one and a pack (see Worn).
func _build_dig(at: Vector3) -> void:
	_mark_here(at + Vector3(0.0, 0.0, -5.0), "THE DIG
act picks a tool up, act again swings it
helmets and the backpack: the notebook, Me", 3.4)
	# What he can pick up, lying in a row: the long things on their sides
	var along := -3.0
	for tool: String in ["khopesh", "pickaxe", "shovel", "turia"]:
		var lying := _set_down("res://props/%s.tscn" % tool, at + Vector3(along, 0.06, -2.6)) as RigidBody3D
		lying.rotation.z = PI * 0.5
		_keep(lying)
		along += 1.5
	along = -2.6
	for thing: String in ["trowel", "brush", "tape_measure", "lantern", "dig_basket"]:
		_keep(_set_down("res://props/%s.tscn" % thing, at + Vector3(along, 0.2, -1.4), along) as RigidBody3D)
		along += 1.1
	# The site
	_set_down("res://props/camp_table.tscn", at + Vector3(-4.6, 0.0, 1.0), PI * 0.5)
	_set_down("res://props/backpack.tscn", at + Vector3(-4.4, 0.0, 2.6), 2.2)
	_set_down("res://props/bedroll.tscn", at + Vector3(-5.2, 0.0, 3.3), 0.4)
	_set_down("res://props/crate_finds.tscn", at + Vector3(-4.8, 0.0, -1.6), 0.3)
	_set_down("res://props/khopesh_stand.tscn", at + Vector3(-5.6, 0.0, -3.4), 0.7)
	_set_down("res://props/sieve.tscn", at + Vector3(4.6, 0.0, -1.0), -0.5)
	_set_down("res://props/dig_baskets.tscn", at + Vector3(5.4, 0.0, 1.4), 0.8)
	_set_down("res://props/wheelbarrow.tscn", at + Vector3(3.4, 0.0, 2.0), 2.4)
	_set_down("res://props/dig_tools.tscn", at + Vector3(5.6, 0.0, -3.6), -0.7)
	_set_down("res://props/brushes.tscn", at + Vector3(2.6, 0.0, -0.2), 0.3)
	_set_down("res://props/surveyor_level.tscn", at + Vector3(0.0, 0.0, 1.6), 0.0)
	_set_down("res://props/measuring_staff.tscn", at + Vector3(0.0, 0.0, 6.4), PI)
	_set_down("res://props/plumb_tripod.tscn", at + Vector3(-2.0, 0.0, 2.6))
	for x: float in [-6.4, 6.4]:
		_set_down("res://props/ranging_pole.tscn", at + Vector3(x, 0.0, 5.6))
	# The helmets, and someone to show how they are worn
	along = -3.75
	for god: String in ["anubis", "horus", "sobek", "bastet", "thoth", "khnum"]:
		_set_down("res://props/helmet_%s.tscn" % god, at + Vector3(along, 0.0, 4.6), PI)
		along += 1.5
	var digger := Townsperson.new()
	digger.seed = 12
	digger.wander = 1.5
	digger.position = at + Vector3(2.0, 0.1, 3.0)
	add_child(digger)
	Worn.put_on(digger, &"helmet_horus")
	Worn.put_on(digger, &"backpack")


## Scarabs and cobwebs. A nest of scarabs that the plate lets out and calls
## home: a torch to hold them off with and a brazier they will not come near, a
## step they pour over, and a block to get up onto out of their reach. A few
## harmless ones, one rolling its ball; a gold scarab to carry, and the stone it
## is laid in, which also lets them out. And a short stone passage hung with
## cobwebs, to walk through and to burn.
func _build_scarabs(at: Vector3) -> void:
	_mark_here(at + Vector3(5.0, 0.0, 0.8), "SCARABS  ·  COBWEBS
the plate lets them out, and calls them home
a torch holds them off  ·  climb the block, or run
walk through the webs, or hold the torch to them", 3.8)
	var swarm := ScarabSwarm.new()
	swarm.count = 140
	swarm.chase_distance = 26.0
	swarm.position = at + Vector3(-4.6, 0.0, -3.0)
	add_child(swarm)
	swarm.caught.connect(_on_caught.bind(swarm.front))
	_switch(at + Vector3(3.0, 0.0, -0.6), func() -> void: swarm.chasing = not swarm.chasing)
	# A step for them to pour over, a block too high for them, and fire
	_solid(at + Vector3(-2.6, 0.2, -2.6), Vector3(0.8, 0.4, 4.4), PROP.darkened(0.06))
	_solid(at + Vector3(4.6, 0.6, -3.6), Vector3(2.0, 1.2, 2.0), PROP)
	var brazier := _set_down("res://props/brazier.tscn", at + Vector3(0.6, 0.0, -3.4))
	var flame := brazier.find_child("Flame*", true, false) as Node3D
	(flame if flame else brazier).add_child(Fire.brazier())
	var torch := HandTorch.new()
	torch.position = at + Vector3(1.4, 0.02, 0.4)
	torch.rotation.z = 0.12
	torch.freeze = true
	add_child(torch)
	_keep(torch)
	# The harmless ones, the gold one, and its stone
	var few := ScarabSwarm.new()
	few.harmless = true
	few.dung_ball = true
	few.count = 6
	few.roam = 1.6
	few.position = at + Vector3(3.6, 0.0, 3.4)
	add_child(few)
	var amulet := ScarabAmulet.new()
	amulet.position = at + Vector3(2.4, 0.08, 2.2)
	add_child(amulet)
	_keep(amulet)
	var socket := ScarabSocket.new()
	socket.position = at + Vector3(4.6, 0.0, 2.2)
	add_child(socket)
	socket.changed.connect(func(filled: bool) -> void:
		if filled:
			swarm.chasing = true)
	# The passage: two walls and a roof, six metres long and two wide, running east and west
	var passage := at + Vector3(-2.5, 0.0, 3.4)
	for z: float in [-1.15, 1.15]:
		_solid(passage + Vector3(0.0, 1.3, z), Vector3(6.0, 2.6, 0.3), PROP.darkened(0.25))
	_solid(passage + Vector3(0.0, 2.75, 0.0), Vector3(6.0, 0.3, 2.6), PROP.darkened(0.3))
	var hang := func(kind: Cobweb.Kind, where: Vector3, yaw: float, tip := 0.0) -> Cobweb:
		var web := Cobweb.new()
		web.kind = kind
		web.wide = 2.0
		web.tall = 2.6
		web.seed = get_child_count()
		web.position = passage + where
		web.rotation = Vector3(tip, yaw, 0.0)
		add_child(web)
		return web
	hang.call(Cobweb.Kind.SHEET, Vector3(-1.2, 0.0, 0.0), PI * 0.5)
	hang.call(Cobweb.Kind.SHEET, Vector3(1.6, 0.0, 0.0), PI * 0.5)
	for corner: Array in [[-2.98, -1.0, PI], [-2.98, 1.0, 0.0], [2.98, 1.0, 0.0], [0.3, -1.0, PI]]:
		# (in the angle of the roof and a wall, across the passage)
		var web: Cobweb = hang.call(Cobweb.Kind.CORNER, Vector3(corner[0], 2.6, corner[1]), PI * 0.5 + corner[2])
		web.size = 0.8
	var strands: Cobweb = hang.call(Cobweb.Kind.HANGING, Vector3(0.2, 2.6, 0.0), PI * 0.5)
	strands.size = 0.9
	strands.wide = 1.8
	var more: Cobweb = hang.call(Cobweb.Kind.HANGING, Vector3(-2.4, 2.6, 0.0), PI * 0.5)
	more.size = 0.6
	more.wide = 1.6
	# (and a jar at its west end, under old webbing)
	_set_down("res://props/pot_large.tscn", passage + Vector3(-4.2, 0.0, 0.0))
	var drape: Cobweb = hang.call(Cobweb.Kind.DRAPE, Vector3(-4.2, 0.0, 0.0), 0.0)
	drape.over = Vector3(0.95, 1.15, 0.95)
	drape.dust = 0.7


func _set_down(scene: String, at: Vector3, yaw := 0.0) -> Node3D:
	var made := (load(scene) as PackedScene).instantiate() as Node3D
	made.position = at
	made.rotation.y = yaw
	add_child(made)
	return made


func _settle_in() -> void:
	_player = get_parent().get_node_or_null("Player") as Player
	if _player == null:
		return
	_player.respawned.connect(_restore_loose)
	_player.respawned.connect(_call_off)
	_mummy.target = _player
	for hound in _hounds:
		hound.target = _player
	# His older brother tags along, and there is a cat about.
	var brother := Brother.new()
	brother.position = _player.position + Vector3(-2.0, 0.0, 1.0)
	add_child(brother)
	brother.follow(_player)
	var cat := Cat.new()
	cat.position = Vector3(4.0, 0.2, -4.0)
	add_child(cat)


func _toggle_hounds() -> void:
	var loose := not _hounds[0].chasing
	for hound in _hounds:
		if loose:
			hound.chasing = true
		else:
			hound.reset()


func _toggle_mummy() -> void:
	if _mummy.is_awake():
		_mummy.reset()
	else:
		_mummy.wake()


## Caught: he goes down, then starts again from where he last was.
func _on_caught(by: Node3D) -> void:
	if _player == null or _player.is_limp:
		return
	_player.ragdoll((_player.global_position - by.global_position).normalized() * 24.0 + Vector3.UP * 12.0)
	for hound in _hounds:
		hound.chasing = false
	await get_tree().create_timer(2.2).timeout
	if _player.is_limp:
		_player.respawn()


func _call_off() -> void:
	for hound in _hounds:
		hound.reset()
	_mummy.reset()


func _physics_process(_delta: float) -> void:
	if _player == null or not _player.is_on_floor():
		return
	var at := _player.global_position
	for i in _marks.size():
		if i != _mark and at.distance_to(_marks[i]) < 4.0:
			_mark = i
			_player.set_spawn(_marks[i] + Vector3.UP * 0.05)


## Puts back whatever can be carried off that he is not carrying.
func _restore_loose() -> void:
	for i in _loose.size():
		if _loose[i] == _player.carried:
			continue
		_loose[i].linear_velocity = Vector3.ZERO
		_loose[i].angular_velocity = Vector3.ZERO
		_loose[i].global_transform = _loose_starts[i]


## Somewhere to come back to, and a sign over it saying what is here.
func _mark_here(at: Vector3, text := "", height := 3.0) -> void:
	_marks.append(at)
	if text != "":
		_sign(at + Vector3.UP * height, text)


func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 1.0, 1.0, 0.85)
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.5)
	label.position = at
	add_child(label)


## A plate that only he can press, and what pressing it does.
func _switch(at: Vector3, press: Callable) -> void:
	var plate := _plate(at, Vector3(1.6, 0.5, 1.6), false)
	plate.collision_mask = 2
	plate.changed.connect(func(pressed: bool) -> void:
		if pressed:
			press.call())


func _plate(at: Vector3, span: Vector3, latches: bool) -> Plate:
	var plate := Plate.new()
	plate.span = span
	plate.latches = latches
	plate.position = at
	add_child(plate)
	return plate


func _block(at: Vector3) -> void:
	var block := RigidBody3D.new()
	block.add_to_group(&"interest")
	# (it furrows the sand it is pushed over)
	block.add_to_group(&"sand_denting")
	block.mass = 20.0
	block.lock_rotation = true
	var surface := PhysicsMaterial.new()
	surface.friction = 0.6
	block.physics_material_override = surface
	_shape(block, at, Vector3(0.9, 0.9, 0.9), MARK)


## Something to pick up and throw: any RigidBody3D in the group "throwable".
func _rock(at: Vector3) -> void:
	var rock := RigidBody3D.new()
	rock.add_to_group(&"interest")
	rock.add_to_group(&"throwable")
	rock.mass = 2.0
	# Falls briskly, to match how the player jumps.
	rock.gravity_scale = 2.0
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	var collider := CollisionShape3D.new()
	collider.shape = shape
	rock.add_child(collider)
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 8
	mesh.rings = 4
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(DARK.lightened(0.1))
	rock.add_child(visual)
	rock.position = at
	add_child(rock)
	_keep(rock)


## A bat, lying on the ground: its handle is at its origin and it runs along
## its own Y. He swings it at whatever else can be thrown.
func _bat(at: Vector3) -> void:
	var bat := RigidBody3D.new()
	bat.add_to_group(&"interest")
	bat.add_to_group(&"throwable")
	bat.add_to_group(&"bats")
	bat.mass = 1.0
	bat.gravity_scale = 2.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.07, 0.75, 0.07)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.375
	bat.add_child(collider)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.034
	mesh.bottom_radius = 0.017
	mesh.height = 0.75
	mesh.radial_segments = 8
	mesh.rings = 1
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(WOOD)
	visual.position.y = 0.375
	bat.add_child(visual)
	bat.position = at
	bat.rotation.z = PI * 0.5
	add_child(bat)
	_keep(bat)


## Remembers where something loose started, to put it back there.
func _keep(body: RigidBody3D) -> void:
	_loose.append(body)
	_loose_starts.append(body.transform)


## A fixed solid box.
func _solid(at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	return _shape(StaticBody3D.new(), at, size, color) as StaticBody3D


## Scenery with no collision.
func _prop(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(color)
	visual.position = at
	add_child(visual)


## A wall nothing can see.
func _barrier(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	add_child(body)


func _shape(body: PhysicsBody3D, at: Vector3, size: Vector3, color: Color) -> PhysicsBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(color)
	body.add_child(visual)
	body.position = at
	add_child(body)
	return body
