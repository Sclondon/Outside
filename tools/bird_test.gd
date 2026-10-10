extends SceneTree
## Not part of the game. Runs the birds (scripts/birds.gd) through what they do, with nothing drawn, and says
## whether each thing happened: a flock settles on the ground, goes up when the boy runs at it and when a gun
## goes off, comes down on what is high, and goes back to the ground when it is quiet; waders, geese, the
## hoverers and the soarers each do as they should; and all the while every bird stays within its range, above
## the ground and out of what is solid.
## godot --headless --path . --fixed-fps 60 --script tools/bird_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

const BLOCK := AABB(Vector3(5, 0, -5), Vector3(2, 1.5, 2))

var stage: Node3D
var failed := 0
var boy: Player
## Every flock there is, and the worst it has been seen to do: how far below the ground, how far out of its range, and whether inside the block.
var watched: Array[Birds] = []
var lowest := {}
var furthest := {}
var inside := {}


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	run.call_deferred()


func box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	stage.add_child(body)


func check(what: String, passed: bool, detail := "") -> void:
	print("PASS " if passed else "FAIL ", what, "  ", detail)
	if not passed:
		failed += 1


## How high the ground of the stage is at a place: level, but for the hollow the pond lies in (see `run`).
func ground_at(x: float, z: float) -> float:
	var out := maxf(absf(x - 40.0), absf(z))
	if out >= 8.0:
		return 0.0
	return [-0.75, -0.75, -0.6, -0.46, -0.34, -0.24, -0.16, -0.1][mini(int(out), 7)]


## Lets `seconds` go by, or fewer if `until` comes true first. Returns whether it did. Every bird is looked at every frame.
func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		await process_frame
		for birds in watched:
			if not is_instance_valid(birds) or not birds._placed:
				continue
			for b in birds.birds:
				if b.hidden > 0.0:
					continue
				# (a goose sits in the water, and a wader stands in it: the bed of the pond is the ground)
				# (and where the ground goes up in a step, it is not under it for being a finger's width past the edge)
				var ground := minf(minf(ground_at(b.at.x - 0.06, b.at.z), ground_at(b.at.x + 0.06, b.at.z)), minf(ground_at(b.at.x, b.at.z - 0.06), ground_at(b.at.x, b.at.z + 0.06)))
				lowest[birds] = minf(lowest.get(birds, 0.0), b.at.y - ground)
				furthest[birds] = maxf(furthest.get(birds, 0.0), Vector2(b.at.x - birds._home.x, b.at.z - birds._home.z).length())
				if BLOCK.grow(-0.05).has_point(b.at):
					inside[birds] = true
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func flock(kind: Birds.Kind, count: int, at: Vector3, roam: float) -> Birds:
	var birds := Birds.new()
	birds.kind = kind
	birds.count = count
	birds.roam = roam
	birds.position = at
	stage.add_child(birds)
	birds.target = boy
	watched.append(birds)
	return birds


## Walks the boy (who is not being run by his own script) to a place at a speed.
func send(to: Vector3, speed: float) -> void:
	while boy.global_position.distance_to(to) > 0.2:
		var way := (to - boy.global_position).normalized()
		boy.velocity = way * speed
		boy.global_position += way * minf(speed / 60.0, boy.global_position.distance_to(to))
		await wait(1.0 / 60.0)
	boy.velocity = Vector3.ZERO


func sound(birds: Birds, what: String, margin := 3.0) -> void:
	var low: float = lowest.get(birds, 0.0)
	var far: float = furthest.get(birds, 0.0)
	var finite := true
	for b in birds.birds:
		finite = finite and b.at.is_finite()
	check("%s: never under the ground, never out of range, never inside the block" % what, finite and low > -0.03 and far < birds.roam + margin and not inside.has(birds),
		"lowest %.2f m, furthest %.1f of %.0f m" % [low, far, birds.roam])


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	# The ground: level, with a hollow at (40, 0) for a pond, made as square frames one inside another.
	var tops: Array[float] = [0.0, -0.1, -0.16, -0.24, -0.34, -0.46, -0.6, -0.75]
	for ring in tops.size():
		var outer := 150.0 if ring == 0 else 9.0 - ring
		var inner := 8.0 - ring
		if ring == tops.size() - 1:
			box(Vector3(40, tops[ring] - 1.0, 0), Vector3(outer * 2.0, 2.0, outer * 2.0))
			break
		var across := (outer + inner) * 0.5
		var deep := outer - inner
		for side: Array in [[Vector3(across, 0, 0), Vector3(deep, 2.0, outer * 2.0)], [Vector3(-across, 0, 0), Vector3(deep, 2.0, outer * 2.0)],
				[Vector3(0, 0, across), Vector3(inner * 2.0, 2.0, deep)], [Vector3(0, 0, -across), Vector3(inner * 2.0, 2.0, deep)]]:
			box(side[0] + Vector3(40, tops[ring] - 1.0, 0), side[1])
	var pond := Pool.new()
	pond.size = Vector3(16.0, 1.2, 16.0)
	pond.position = Vector3(40, -0.07, 0)
	stage.add_child(pond)
	# Things to perch on: a block, three posts, and a marked place on a fourth.
	box(BLOCK.get_center(), BLOCK.size)
	for i in 3:
		box(Vector3(-5.0 + i * 2.0, 1.2, -6.0), Vector3(0.3, 2.4, 0.3))
	box(Vector3(47.5, 0.8, 9.5), Vector3(0.2, 1.6, 0.2))
	var mark := Marker3D.new()
	mark.position = Vector3(-8, 3.0, 2)
	mark.add_to_group(&"bird_perches")
	stage.add_child(mark)
	box(Vector3(-8, 1.5, 2), Vector3(0.3, 3.0, 0.3))

	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(0, 0.05, 30)
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	boy.set_physics_process(false)

	# ---- a flock
	var doves := flock(Birds.Kind.DOVE, 12, Vector3.ZERO, 25.0)
	var went_up := [0]
	doves.flushed.connect(func(how_many: int) -> void: went_up[0] += how_many)
	await wait(1.0)
	var tops_found := 0
	for spot in doves.spots:
		if spot.where == Birds.Where.TOP:
			tops_found += 1
	check("finds perches by itself", tops_found >= 5, "%d high places, %d places in all" % [tops_found, doves.spots.size()])
	check("settles on the ground", doves.settled() == 12, "%d of 12 down" % doves.settled())
	await wait(8.0)
	check("stays down, feeding, while nobody is near", doves.settled() == 12 and went_up[0] == 0, "%d down" % doves.settled())
	# He walks up slowly: they watch him. He runs at them: up.
	await send(Vector3(0, 0.05, 12), 5.0)
	check("is not put up by someone a long way off", went_up[0] == 0 and doves.settled() == 12, "%d went up" % went_up[0])
	await send(doves._area + Vector3(0, 0.05, 1.0), 6.0)
	var all_up := await wait(3.0, func() -> bool: return doves.settled() == 0)
	check("goes up when he runs at it", all_up and went_up[0] >= 12, "%d went up, %d still down" % [went_up[0], doves.settled()])
	var high := [0.0]
	await wait(3.0, func() -> bool:
		for b in doves.birds:
			high[0] = maxf(high[0], b.at.y)
		return false)
	check("wheels about overhead", high[0] > 2.5 and doves.settled() == 0, "as high as %.1f m" % high[0])
	# He stands where they were: they come down on what is high.
	var perched := await wait(40.0, func() -> bool: return doves.settled() == 12)
	var up_high := 0
	for b in doves.birds:
		if b.at.y > 1.0:
			up_high += 1
	check("comes down on the high things while he is there", perched and up_high >= 6, "%d down, %d of them up on something" % [doves.settled(), up_high])
	var nearest := [100.0]
	await wait(25.0, func() -> bool:
		for b in doves.birds:
			if b.state == Birds.State.STAND and b.time > 1.0:
				nearest[0] = minf(nearest[0], b.at.distance_to(boy.global_position))
		return false)
	check("and none of them settles beside him while he stands on their ground", nearest[0] > 2.5, "the nearest %.1f m from him" % nearest[0])
	# He goes away: back to the ground.
	await send(Vector3(0, 0.05, 40), 6.0)
	var back := await wait(60.0, func() -> bool:
		var low := 0
		for b in doves.birds:
			if b.at.y < 0.1 and (b.state == Birds.State.STAND or b.state == Birds.State.WALK):
				low += 1
		return low >= 10)
	check("goes back to the ground when it is quiet", back, "%d down" % doves.settled())
	# A gun.
	var gun := Node3D.new()
	gun.add_user_signal("fired")
	gun.add_to_group(&"guns")
	gun.position = Vector3(0, 1, 40)
	stage.add_child(gun)
	await wait(2.5)
	went_up[0] = 0
	gun.emit_signal("fired")
	var shot_up := await wait(2.0, func() -> bool: return doves.settled() == 0)
	check("goes up when a gun is fired", shot_up and went_up[0] >= 10, "%d went up" % went_up[0])
	var down_again := await wait(90.0, func() -> bool: return doves.settled() == 12)
	check("and comes down again", down_again, "%d down" % doves.settled())
	sound(doves, "doves")
	doves.queue_free()
	watched.erase(doves)

	# ---- sparrows, thirty of them, and what they cost
	var sparrows := flock(Birds.Kind.SPARROW, 30, Vector3.ZERO, 25.0)
	await wait(6.0)
	var cost_down := sparrows.cost
	sparrows.flush(Vector3(0, 0, 3))
	var costs := [0.0]
	await wait(5.0, func() -> bool:
		costs[0] = maxf(costs[0], sparrows.cost)
		return false)
	var cost_up: float = costs[0]
	var settled := await wait(90.0, func() -> bool: return sparrows.settled() == 30)
	check("thirty sparrows go up and all come down again", settled, "%d down" % sparrows.settled())
	print("COST thirty sparrows: %.0f us a frame on the ground, %.0f in the air (the script, with nothing drawn)" % [cost_down, cost_up])
	check("thirty sparrows cost under half a millisecond a frame", cost_up < 500.0, "%.0f us" % cost_up)
	sound(sparrows, "sparrows")
	sparrows.queue_free()
	watched.erase(sparrows)

	# ---- a hoopoe
	var hoopoes := flock(Birds.Kind.HOOPOE, 2, Vector3(-3, 0, 3), 25.0)
	await wait(4.0)
	var was := hoopoes.birds[0].at
	hoopoes.flush(was + Vector3(1, 0, 1))
	await wait(1.0)
	var moved := await wait(30.0, func() -> bool: return hoopoes.settled() == 2)
	check("a hoopoe flies off to other ground and lands", moved and hoopoes.birds[0].at.distance_to(was) > 5.0, "%.1f m from where it was" % hoopoes.birds[0].at.distance_to(was))
	sound(hoopoes, "hoopoes")
	hoopoes.queue_free()
	watched.erase(hoopoes)

	# ---- at the pond
	boy.global_position = Vector3(0, 0.05, 60)
	var at_pond := Vector3(40, 0, 0)
	var ibis := flock(Birds.Kind.IBIS, 3, at_pond + Vector3(-7, 0, 3), 22.0)
	var heron := flock(Birds.Kind.HERON, 1, at_pond + Vector3(6, 0, -6), 22.0)
	var geese := flock(Birds.Kind.GOOSE, 4, at_pond, 22.0)
	var fisher := flock(Birds.Kind.KINGFISHER, 1, at_pond + Vector3(7.5, 0, 9.5), 22.0)
	var swallows := flock(Birds.Kind.SWALLOW, 6, at_pond, 22.0)
	await wait(2.0)
	var wading := 0
	for b in ibis.birds:
		var deep := pond.surface_y() - b.at.y
		if deep > 0.0 and deep < 0.3:
			wading += 1
	check("ibis stand in the shallows", wading == 3, "%d of 3 in the water, to %.2f m" % [wading, pond.surface_y() - ibis.birds[0].at.y])
	var afloat := 0
	for b in geese.birds:
		if b.afloat == pond and absf(b.at.y - pond.surface_y()) < 0.01:
			afloat += 1
	check("geese are on the water", afloat == 4, "%d of 4 afloat" % afloat)
	check("the kingfisher is on its post", fisher.birds[0].at.y > 1.0, "at %s" % fisher.birds[0].at)
	var acts := {}
	var walked := [false, false]
	# (the kingfisher may go fishing at any time: it is watched from now on)
	var f := fisher.birds[0]
	var seen := {}
	var wet := [false]
	await wait(40.0, func() -> bool:
		seen[f.state] = true
		wet[0] = wet[0] or f.hidden > 0.0
		acts[ibis.birds[0].act] = true
		acts[heron.birds[0].act] = true
		walked[0] = walked[0] or ibis.birds[0].state == Birds.State.WALK or ibis.birds[1].state == Birds.State.WALK
		walked[1] = walked[1] or geese.birds[0].state == Birds.State.WALK
		return false)
	check("waders wade, peck, and stand on one leg; geese swim", walked[0] and walked[1] and acts.has(Birds.Act.PECK) and acts.has(Birds.Act.ONE_LEG), "acts seen %s" % str(acts.keys()))
	wading = 0
	for b in ibis.birds:
		if pond.surface_y() - b.at.y < 0.31:
			wading += 1
	check("and no ibis has walked out of its depth", wading == 3, "%d of 3" % wading)
	# The kingfisher: out over the water, hangs there, and goes in.
	var dived := await wait(240.0, func() -> bool:
		seen[f.state] = true
		wet[0] = wet[0] or f.hidden > 0.0
		if f.state == Birds.State.STAND and f.pause > 0.5 and not seen.has(Birds.State.HOVER):
			f.pause = 0.0
			fisher._quiet = 100.0
			f.time = 10.0
		return wet[0])
	check("the kingfisher hovers over the water and dives into it", dived and seen.has(Birds.State.HOVER) and seen.has(Birds.State.STOOP), "states seen %s" % str(seen.keys()))
	var home_again := await wait(30.0, func() -> bool: return f.state == Birds.State.STAND and f.hidden <= 0.0)
	check("and comes out and lands again", home_again and f.at.y > -0.1, "at %s" % f.at)
	# Swallows never land, and keep low.
	var heights := [100.0, 0.0]
	await wait(10.0, func() -> bool:
		for b in swallows.birds:
			heights[1] = maxf(heights[1], b.at.y)
			heights[0] = minf(heights[0], b.at.y - ground_at(b.at.x, b.at.z))
		return false)
	check("swallows stay on the wing, low", swallows.settled() == 0 and heights[0] > 0.0 and heights[0] < 1.0, "between %.2f and %.1f m up" % heights)
	# He walks down to the water: the geese and the ibis go, and come down again somewhere.
	boy.global_position = Vector3(25, 0.05, 2)
	await send(Vector3(37, 0.05, 0), 5.0)
	var gone := await wait(4.0, func() -> bool: return geese.settled() <= 1 and ibis.settled() < 3)
	check("geese and ibis go up when he comes to the water", gone, "geese down %d, ibis down %d" % [geese.settled(), ibis.settled()])
	boy.global_position = Vector3(0, 0.05, 60)
	var returned := await wait(80.0, func() -> bool: return geese.settled() == 4 and ibis.settled() == 3)
	afloat = 0
	for b in geese.birds:
		if b.afloat:
			afloat += 1
	check("and come down again when he has gone, the geese on the water", returned and afloat >= 3, "geese down %d (%d afloat), ibis down %d" % [geese.settled(), afloat, ibis.settled()])
	for birds: Birds in [ibis, heron, geese, fisher, swallows]:
		sound(birds, String(Birds.Kind.keys()[birds.kind]).to_lower())
		birds.queue_free()
		watched.erase(birds)

	# ---- a kestrel
	var kestrel := flock(Birds.Kind.KESTREL, 1, Vector3.ZERO, 30.0)
	await wait(2.0)
	var k := kestrel.birds[0]
	check("the kestrel sits on something high", k.at.y > 1.4, "at %.1f m" % k.at.y)
	seen = {}
	var stooped := await wait(300.0, func() -> bool:
		seen[k.state] = true
		if k.state == Birds.State.STAND and k.pause > 0.5 and not seen.has(Birds.State.STOOP):
			k.pause = 0.0
			k.time = 10.0
			kestrel._quiet = 100.0
		return seen.has(Birds.State.STOOP) and k.state == Birds.State.STAND)
	check("hovers, stoops, and lands", stooped and seen.has(Birds.State.HOVER), "states seen %s" % str(seen.keys()))
	var up_again := await wait(30.0, func() -> bool: return k.state == Birds.State.STAND and k.at.y > 1.4)
	check("and goes back up to a perch", up_again, "at %.1f m" % k.at.y)
	sound(kestrel, "kestrel")
	kestrel.queue_free()
	watched.erase(kestrel)

	# ---- soarers
	var vultures := flock(Birds.Kind.VULTURE, 4, Vector3.ZERO, 40.0)
	await wait(20.0)
	var low := 1000.0
	for b in vultures.birds:
		low = minf(low, b.at.y)
	check("vultures circle high up", vultures.settled() == 0 and low > 20.0, "lowest %.0f m" % low)
	# Something dead.
	var dead := Marker3D.new()
	dead.position = Vector3(10, 0, 10)
	dead.add_to_group(&"carrion")
	stage.add_child(dead)
	var came := await wait(150.0, func() -> bool: return vultures.settled() >= 2)
	var near := 100.0
	for b in vultures.birds:
		if b.state == Birds.State.STAND or b.state == Birds.State.WALK:
			near = minf(near, b.at.distance_to(dead.position))
	check("and come down to something dead", came and near < 8.0, "%d down, the nearest %.1f m from it" % [vultures.settled(), near])
	dead.queue_free()
	var left := await wait(40.0, func() -> bool: return vultures.settled() == 0)
	await wait(40.0)
	low = 1000.0
	for b in vultures.birds:
		low = minf(low, b.at.y)
	check("and go back up when it is gone", left and low > 20.0, "%d down, lowest %.0f m" % [vultures.settled(), low])
	# (what is dead draws them out of their range: so much is allowed them)
	sound(vultures, "vultures", 15.0)
	vultures.queue_free()
	watched.erase(vultures)
	# He is knocked down, and lies there.
	var griffons := flock(Birds.Kind.GRIFFON, 3, Vector3.ZERO, 40.0)
	await wait(3.0)
	boy.global_position = Vector3(5, 0.05, 5)
	boy.visual_position = boy.global_position
	boy.is_limp = true
	var gathered := await wait(150.0, func() -> bool: return griffons.settled() >= 1)
	check("griffons come down to the boy when he lies knocked down", gathered, "%d down" % griffons.settled())
	boy.is_limp = false
	left = await wait(40.0, func() -> bool: return griffons.settled() == 0)
	check("and leave when he gets up", left, "%d down" % griffons.settled())
	sound(griffons, "griffons", 15.0)

	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)
