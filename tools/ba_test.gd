extends SceneTree
## Not part of the game. Runs the Ba with nothing drawn and says whether each thing happened: it waits; it
## flies when he comes near, and lands ahead where he can see it; round a wall it touches nothing; it calls
## and comes back when he hangs back or goes the wrong way; it ends at the last place and stays (or goes);
## it is never inside anything solid or under the ground; it comes when it is turned on and goes when it is
## turned off; where there is no way to fly it goes as a spirit; shy, it flits from post to post; it shows a
## way and comes back; and in the desert, made from an item as the editor makes it, a lever calls it.
## godot --headless --path . --fixed-fps 60 --script tools/ba_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
# Every Ba being watched, and how often one was found inside something or under the ground.
var watched: Array[Ba] = []
var buried := 0
var buried_where := ""
# How high the ground is at (x, z), where it is not flat at 0.
var ground := Callable()


func _initialize() -> void:
	LevelLayout.saved_at = "user://ba_test_layout.json"
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(300, 2, 300))
	run.call_deferred()


func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	stage.add_child(body)
	return body


func check(what: String, passed: bool, detail := "") -> void:
	print("PASS " if passed else "FAIL ", what, "  ", detail)
	if not passed:
		failed += 1


## Lets `seconds` go by, or fewer if `until` comes true first. Returns whether it did. Every step, every Ba
## that is there is looked at: its middle must be in the open, and its feet not under the floor.
func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		await process_frame
		look_for_burial()
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func look_for_burial() -> void:
	var space := root.find_world_3d().direct_space_state
	var point := PhysicsPointQueryParameters3D.new()
	point.collision_mask = 1
	for ba in watched:
		if not is_instance_valid(ba) or ba.is_away() or ba._blink_to != Vector3.INF:
			continue
		point.position = ba.global_position + Vector3.UP * Ba.BODY
		var floor_there: float = ground.call(ba.global_position.x, ba.global_position.z) if ground.is_valid() else 0.0
		if not space.intersect_point(point, 1).is_empty() or ba.global_position.y < floor_there - 0.05:
			buried += 1
			buried_where = "%s (errand %d)" % [ba.global_position, ba.errand()]


func put(at: Vector3) -> void:
	boy.global_position = at
	boy.velocity = Vector3.ZERO


func ba_at(at: Vector3, route: Array[Vector3] = []) -> Ba:
	var ba := Ba.new()
	ba.voice = false
	ba.route = route
	ba.position = at
	stage.add_child(ba)
	ba.target = boy
	watched.append(ba)
	return ba


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(-20, 0.05, 0)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await wait(0.5)

	await leading()
	await hanging_back()
	await switched()
	await shut_in()
	await shy()
	await showing()
	await in_the_desert()
	check("it was never inside anything, nor under the ground", buried == 0, "%d times; last at %s" % [buried, buried_where])
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


## A way of three places, the second leg of it behind a wall, the last on top of a block.
func leading() -> void:
	var wall := box(Vector3(6, 1.5, 0), Vector3(0.6, 3.0, 9.0))
	var block := box(Vector3(14, 0.6, -4), Vector3(1.2, 1.2, 1.2))
	var places: Array[Vector3] = [Vector3(3, 0, 6.5), Vector3(9, 0, 6.5), Vector3(14, 1.3, -4)]
	var ba := ba_at(Vector3(0, 0, 0), places)
	var landed: Array[Vector3] = []
	var ended := [0]
	ba.arrived.connect(func(at: Vector3) -> void: landed.append(at))
	ba.finished.connect(func() -> void: ended[0] += 1)
	put(Vector3(-14, 0.05, 0))
	await wait(3.0)
	check("it waits while he is far off", ba.is_perched() and flat(ba.global_position, Vector3.ZERO) < 0.1 and landed.is_empty(), "at %s" % ba.global_position)
	check("it is not a body, a fire or a pursuer", ba.find_children("*", "CollisionObject3D", true, false).is_empty() and not Nearby.fires(stage.get_tree()).has(ba)
			and not ba.is_in_group(&"pursuers") and Nearby.fires(stage.get_tree()).is_empty())
	check("its head is turned to him", absf(angle_difference(ba._heading + ba._gaze.x, atan2(boy.global_position.x - ba.global_position.x, boy.global_position.z - ba.global_position.z))) < 0.5,
			"gaze %.2f" % ba._gaze.x)
	# He comes up to it.
	put(Vector3(-2.5, 0.05, 0))
	var up := await wait(1.5, func() -> bool: return ba.is_flying())
	check("it takes off when he comes near", up)
	var highest := [0.0]
	var most_roll := [0.0]
	var down := await wait(8.0, func() -> bool:
		highest[0] = maxf(highest[0], ba.global_position.y)
		most_roll[0] = maxf(most_roll[0], absf(ba._roll))
		return ba.is_perched())
	check("and lands ahead of him, at the first place", down and landed.size() == 1 and flat(ba.global_position, places[0]) < 0.3 and absf(ba.global_position.y) < 0.05,
			"at %s, highest %.2f" % [ba.global_position, highest[0]])
	check("it flew: it went up off the ground and came down", highest[0] > 0.5 and highest[0] < 6.0)
	var eye := boy.global_position + Vector3.UP * 1.3
	check("he can see it there", ba._sees(eye, ba.global_position + Vector3.UP * 0.4))
	await wait(1.2)
	check("it has turned to look back at him", absf(angle_difference(ba._heading + ba._gaze.x, atan2(boy.global_position.x - ba.global_position.x, boy.global_position.z - ba.global_position.z))) < 0.5)
	# On: to each place as he comes to the one before.
	var stops := 0
	while not ba._ended and stops < 8:
		stops += 1
		put(ba.global_position + Vector3(-1.5, 0.05, 0.5))
		await wait(1.5, func() -> bool: return ba.is_flying())
		await wait(8.0, func() -> bool:
			most_roll[0] = maxf(most_roll[0], absf(ba._roll))
			return ba.is_perched())
	check("it goes on from place to place to the last", ba._ended and ba.place() == 3 and landed.size() >= 3, "place %d, landings %d" % [ba.place(), landed.size()])
	check("which is on top of the block", ba.global_position.distance_to(Vector3(14, 1.2, -4)) < 0.3, "at %s" % ba.global_position)
	check("it found a way round the wall and over to the block without going as a spirit", ba.spirited == 0)
	check("it banked in its turns", most_roll[0] > 0.08, "most %.2f" % most_roll[0])
	put(Vector3(12.5, 0.05, -3.0))
	var done := await wait(2.0, func() -> bool: return ended[0] > 0)
	await wait(3.0)
	check("when he comes to the last place it says so, once, and stays", done and ended[0] == 1 and ba.is_perched() and ba.is_finished() and ba.global_position.distance_to(Vector3(14, 1.2, -4)) < 0.3)
	ba.queue_free()

	# The same, but it goes when it has brought him.
	ba = ba_at(Vector3(0, 0, 0), [Vector3(3, 0, 6.5)] as Array[Vector3])
	ba.leaves_at_end = true
	put(Vector3(-2, 0.05, 0))
	await wait(6.0, func() -> bool: return ba._ended)
	put(Vector3(2, 0.05, 5.5))
	var went := await wait(8.0, func() -> bool: return ba.is_away())
	check("with leaves_at_end it goes when he has come", went and not ba.visible and ba.is_finished(), "away %s, seen %s, finished %s, ended %s, at %s" % [ba.is_away(), ba.visible, ba.is_finished(), ba._ended, ba.global_position])
	ba.queue_free()

	# One thing to lead him to, a long way off: by hops, none longer than it is allowed.
	ba = ba_at(Vector3(0, 0, -20))
	landed.clear()
	ba.arrived.connect(func(at: Vector3) -> void: landed.append(at))
	put(Vector3(-10, 0.05, -20))
	await wait(0.5)
	var mark := Marker3D.new()
	mark.position = Vector3(26, 0, -20)
	stage.add_child(mark)
	ba.lead_to(mark)
	var longest := 0.0
	stops = 0
	while not ba._ended and stops < 10:
		stops += 1
		var from := ba.global_position
		put(ba.global_position + Vector3(-1.5, 0.05, 0.0))
		await wait(1.5, func() -> bool: return ba.is_flying())
		await wait(8.0, func() -> bool: return ba.is_perched())
		longest = maxf(longest, ba.global_position.distance_to(from))
	check("lead_to takes him to a thing by hops", ba._ended and flat(ba.global_position, mark.position) < 0.3 and stops >= 3 and longest < ba.hop + 0.5, "%d hops, the longest %.1f m" % [stops, longest])
	ba.queue_free()
	mark.queue_free()
	wall.queue_free()
	block.queue_free()
	await wait(0.2)


## He does not follow: it calls, comes back for him, and goes ahead again.
func hanging_back() -> void:
	var ba := ba_at(Vector3(0, 0, 40), [Vector3(9, 0, 40), Vector3(18, 0, 40)] as Array[Vector3])
	ba.patience = 4.0
	var calls := [0]
	var landed := [0]
	ba.called.connect(func() -> void: calls[0] += 1)
	ba.arrived.connect(func(_at: Vector3) -> void: landed[0] += 1)
	put(Vector3(-2.5, 0.05, 40))
	await wait(1.5, func() -> bool: return ba.is_flying())
	await wait(6.0, func() -> bool: return ba.is_perched())
	var stop := ba.global_position
	# He stands where he is.
	var called := await wait(3.5, func() -> bool: return calls[0] > 0)
	check("he hangs back: it calls to him", called and ba.is_perched() and ba.fetched == 0, "calls %d" % calls[0])
	var coming := await wait(4.0, func() -> bool: return ba.errand() == Ba.Errand.FETCH)
	var by_him := await wait(6.0, func() -> bool: return ba.is_perched())
	check("then it comes back and lands by him", coming and by_him and ba.fetched == 1 and flat(ba.global_position, boy.global_position) < 3.2 and flat(ba.global_position, boy.global_position) > 1.0,
			"%.1f m from him" % flat(ba.global_position, boy.global_position))
	check("on the side it wants him to go", ba.global_position.x > boy.global_position.x + 0.5)
	await wait(2.5, func() -> bool: return ba.is_flying())
	var back := await wait(6.0, func() -> bool: return ba.is_perched())
	check("and goes ahead again to where it was", back and ba.global_position.distance_to(stop) < 0.3 and landed[0] == 1, "at %s, landings told %d" % [ba.global_position, landed[0]])
	# He walks off the wrong way.
	calls[0] = 0
	await wait(0.5)
	var was := ba.fetched
	for i in 700:
		boy.global_position.x -= 0.04
		boy.velocity = Vector3.ZERO
		await physics_frame
		await process_frame
		look_for_burial()
		if ba.fetched > was:
			break
	check("he goes the wrong way: it calls, and comes after him", calls[0] > 0 and ba.fetched > was, "calls %d, he is at x %.1f" % [calls[0], boy.global_position.x])
	await wait(6.0, func() -> bool: return ba.is_perched())
	check("and finds him", flat(ba.global_position, boy.global_position) < 3.2, "%.1f m from him" % flat(ba.global_position, boy.global_position))
	# Then he follows after all.
	await wait(2.5, func() -> bool: return ba.is_flying())
	await wait(8.0, func() -> bool: return ba.is_perched())
	put(stop + Vector3(-1.5, 0.05, 0))
	await wait(1.5, func() -> bool: return ba.is_flying())
	await wait(8.0, func() -> bool: return ba.is_perched())
	check("and when he follows, it goes on", ba._ended and flat(ba.global_position, Vector3(18, 0, 40)) < 0.3)
	ba.queue_free()
	await wait(0.2)


## Turned on and off.
func switched() -> void:
	put(Vector3(-5, 0.05, 70))
	var ba := Ba.new()
	ba.voice = false
	ba.on = false
	ba.position = Vector3(0, 0, 70)
	stage.add_child(ba)
	ba.target = boy
	watched.append(ba)
	await wait(1.0)
	check("turned off, it is not there", ba.is_away() and not ba.visible)
	ba.on = true
	var seen := await wait(0.5, func() -> bool: return ba.visible and ba.is_flying())
	var faint: float = ba._fade
	var from := ba.global_position
	var down := await wait(6.0, func() -> bool: return ba.is_perched())
	check("turned on, it flies in out of the air, faint at first", seen and down and faint < 0.5 and from.y > 1.0 and from.distance_to(Vector3(0, 0, 70)) > 2.5, "from %s, %.2f there" % [from, faint])
	await wait(1.0)
	check("and is there, where it was put, whole", flat(ba.global_position, Vector3(0, 0, 70)) < 0.1 and absf(ba.global_position.y) < 0.05 and ba._fade > 0.99)
	ba.on = false
	var gone := await wait(6.0, func() -> bool: return ba.is_away())
	await wait(0.5)
	check("turned off, it goes", gone and not ba.visible)
	ba.queue_free()
	await wait(0.2)


## A room with no way out of it: it cannot fly to the place beyond the wall, and goes as a spirit. And a
## passage with a roof: it flies along under it.
func shut_in() -> void:
	var built: Array[Node] = []
	var middle := Vector3(60, 0, 0)
	for side: Vector3 in [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]:
		built.append(box(middle + side + Vector3.UP * 1.5, Vector3(0.4 if side.x != 0.0 else 6.4, 3.0, 0.4 if side.z != 0.0 else 6.4)))
	built.append(box(middle + Vector3(0, 3.2, 0), Vector3(6.4, 0.4, 6.4)))
	put(middle + Vector3(-1.5, 0.05, 0))
	var ba := ba_at(middle + Vector3(1.0, 0, 0), [middle + Vector3(8, 0, 0)] as Array[Vector3])
	await wait(0.4)
	put(middle + Vector3(-0.5, 0.05, 0))
	var out := await wait(6.0, func() -> bool: return ba.is_perched() and ba.global_position.x > middle.x + 5.0)
	check("shut in, with no way to fly, it goes as a spirit and is there beyond the wall", out and ba.spirited == 1 and flat(ba.global_position, middle + Vector3(8, 0, 0)) < 0.3, "at %s, spirited %d" % [ba.global_position, ba.spirited])
	ba.queue_free()
	for thing in built:
		thing.queue_free()
	await wait(0.2)
	# The passage: 2 m wide, 2.4 m high, 14 m long, with a turn in it.
	built.clear()
	middle = Vector3(60, 0, 40)
	for z: float in [-1.2, 1.2]:
		built.append(box(middle + Vector3(0, 1.2, z), Vector3(14, 2.4, 0.4)))
	built.append(box(middle + Vector3(0, 2.6, 0), Vector3(14, 0.4, 2.8)))
	put(middle + Vector3(-6.5, 0.05, 0))
	ba = ba_at(middle + Vector3(-5, 0, 0), [middle + Vector3(5, 0, 0.3)] as Array[Vector3])
	await wait(0.4)
	var top := [0.0]
	put(middle + Vector3(-6.0, 0.05, 0))
	await wait(8.0, func() -> bool:
		top[0] = maxf(top[0], ba.global_position.y + Ba.BODY)
		return ba.is_perched() and ba.global_position.x > middle.x + 4.0)
	check("in a passage it flies under the roof", ba.spirited == 0 and flat(ba.global_position, middle + Vector3(5, 0, 0.3)) < 0.3 and top[0] < 2.3 and top[0] > 0.5, "highest %.2f under a roof at 2.4" % top[0])
	ba.queue_free()
	for thing in built:
		thing.queue_free()
	await wait(0.2)


## With no way to lead and `shy`: on the posts, and off to another when he comes.
func shy() -> void:
	var posts: Array[Node] = []
	var tops: Array[Vector3] = [Vector3(100, 1.4, 0), Vector3(105, 2.0, 3), Vector3(97, 1.0, 5)]
	for at in tops:
		posts.append(box(Vector3(at.x, at.y * 0.5, at.z), Vector3(0.5, at.y, 0.5)))
	put(Vector3(100, 0.05, 20))
	var ba := Ba.new()
	ba.voice = false
	ba.shy = true
	ba.position = Vector3(100, 0, 1)
	stage.add_child(ba)
	ba.target = boy
	watched.append(ba)
	await wait(1.0)
	var on_top := func() -> bool:
		for at in tops:
			if ba.global_position.distance_to(at) < 0.3:
				return true
		return false
	check("shy, it sits on something high near where it was put", ba.is_perched() and on_top.call(), "at %s, perches %d" % [ba.global_position, ba._perches.size()])
	var was := ba.global_position
	put(Vector3(was.x + 1.5, 0.05, was.z + 1.0))
	await wait(1.5, func() -> bool: return ba.is_flying())
	var moved := await wait(6.0, func() -> bool: return ba.is_perched())
	check("and flits to another perch when he comes near", moved and on_top.call() and ba.global_position.distance_to(was) > 1.0 and flat(ba.global_position, boy.global_position) > ba.near,
			"now at %s" % ba.global_position)
	ba.queue_free()
	# Not shy, and nowhere to lead: it only sits and watches.
	ba = ba_at(Vector3(100, 0, -20))
	put(Vector3(101, 0.05, -19))
	await wait(3.0)
	check("with nowhere to lead and not shy, it stays where it is", ba.is_perched() and flat(ba.global_position, Vector3(100, 0, -20)) < 0.1)
	ba.queue_free()
	for post in posts:
		post.queue_free()
	await wait(0.2)


## A way shown: there, a look back, and back again. From a perch, and from nowhere.
func showing() -> void:
	var wall := box(Vector3(106, 1.5, 60), Vector3(0.6, 3.0, 8.0))
	var way := PackedVector3Array([Vector3(103, 0, 65.5), Vector3(109, 0, 65.5), Vector3(111, 0, 60)])
	put(Vector3(98, 0.05, 60))
	var ba := ba_at(Vector3(100, 0, 60))
	var there := [Vector3.INF]
	var back := [0]
	ba.arrived.connect(func(at: Vector3) -> void: there[0] = at)
	ba.came_back.connect(func() -> void: back[0] += 1)
	await wait(0.5)
	ba.show_way(way)
	var got := await wait(10.0, func() -> bool: return there[0] != Vector3.INF)
	check("asked to show a way, it flies it and lands at the end", got and flat(there[0], way[2]) < 0.3 and ba.spirited == 0, "at %s" % there[0])
	var home := await wait(12.0, func() -> bool: return back[0] > 0)
	check("and comes back to where it was", home and flat(ba.global_position, Vector3(100, 0, 60)) < 0.3 and ba.is_perched() and not ba.is_away())
	ba.queue_free()
	ba = Ba.new()
	ba.voice = false
	ba.on = false
	ba.position = Vector3(80, 0, 80)
	stage.add_child(ba)
	ba.target = boy
	watched.append(ba)
	there[0] = Vector3.INF
	back[0] = 0
	ba.arrived.connect(func(at: Vector3) -> void: there[0] = at)
	ba.came_back.connect(func() -> void: back[0] += 1)
	await wait(0.5)
	ba.show_way(way)
	var near_him := await wait(1.0, func() -> bool: return ba.visible)
	var began := ba.global_position
	got = await wait(10.0, func() -> bool: return there[0] != Vector3.INF)
	home = await wait(12.0, func() -> bool: return back[0] > 0)
	var gone := await wait(3.0, func() -> bool: return ba.is_away())
	check("one that was not there comes out of the air by him, shows the way, comes back and is gone", near_him and flat(began, boy.global_position) < 3.2 and got and flat(there[0], way[2]) < 0.3 and home and gone,
			"began %.1f m from him" % flat(began, boy.global_position))
	ba.queue_free()
	wall.queue_free()
	await wait(0.2)


## In the desert, made from an item as the editor makes it: its line of points is its way, and a lever calls it.
func in_the_desert() -> void:
	watched.clear()
	stage.queue_free()
	await wait(0.2)
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	stage = scene
	await wait(0.6)
	var level: Desert = scene.get_node("Level")
	boy = scene.get_node("Player") as Player
	boy.set_physics_process(false)
	ground = level.height_at
	var entry: Array = []
	for one: Array in LevelLayout.PALETTE["People"]:
		if one[2] == "ba":
			entry = one
	check("it is on the People page", not entry.is_empty() and entry[0] == "Ba (spirit bird)")
	# Somewhere open: the first place found with level enough ground and nothing standing on it.
	var at := Vector2(60, 100)
	var item := LevelLayout.new_item(level.layout, "person", "ba", at)
	check("a new one has a way of two points, the first where it sits", (item.get("points", []) as Array).size() == 2 and item["points"][0] == item["at"])
	item["points"] = [[at.x, at.y], [at.x + 7.0, at.y], [at.x + 12.0, at.y + 5.0]]
	level.layout["items"].append(item)
	level.make(item)
	var ba := level.nodes.get(item["id"]) as Ba
	watched.append(ba)
	boy.global_position = Vector3(at.x - 12.0, level.height_at(at.x - 12.0, at.y) + 0.1, at.y)
	await wait(1.0)
	check("made from an item it is a Ba, there from the start, with the rest of its points for its way", ba != null and ba.is_perched() and ba.route.size() == 2
			and absf(ba.global_position.y - level.height_at(at.x, at.y)) < 0.3, "at %s, ground %.2f" % [ba.global_position if ba else Vector3.ZERO, level.height_at(at.x, at.y)])
	boy.global_position = Vector3(at.x - 2.0, level.height_at(at.x - 2.0, at.y) + 0.1, at.y)
	await wait(1.5, func() -> bool: return ba.is_flying())
	var down := await wait(8.0, func() -> bool: return ba.is_perched())
	check("and leads him over the sand", down and flat(ba.global_position, Vector3(at.x + 7.0, 0, at.y)) < 0.4 and absf(ba.global_position.y - level.height_at(at.x + 7.0, at.y)) < 0.15,
			"at %s, ground %.2f, spirited %d" % [ba.global_position, level.height_at(at.x + 7.0, at.y), ba.spirited])
	# Text and back: it is kept with the level.
	var again := LevelLayout.from_text(LevelLayout.to_text(level.layout))
	var kept := {}
	for other: Dictionary in again["items"]:
		if int(other["id"]) == int(item["id"]):
			kept = other
	check("its way is kept with the level", kept.get("what", "") == "ba" and (kept.get("points", []) as Array).size() == 3 and kept.has("links"))
	# One that a lever calls.
	var lever := LevelLayout.new_item(level.layout, "lever", "", Vector2(at.x, at.y + 12.0))
	level.layout["items"].append(lever)
	level.make(lever)
	var called := LevelLayout.new_item(level.layout, "person", "ba", Vector2(at.x + 3.0, at.y + 12.0))
	called["links"] = [lever["id"]]
	called["points"] = [called["at"]]
	level.layout["items"].append(called)
	level.make(called)
	var second := level.nodes.get(called["id"]) as Ba
	watched.append(second)
	await wait(1.0)
	check("linked to a lever, it is not there until the lever is pulled", second != null and second.is_away() and not second.visible)
	(level.nodes.get(lever["id"]) as Lever).work()
	var came := await wait(8.0, func() -> bool: return second.is_perched())
	check("the lever is pulled: it appears", came and second.visible and flat(second.global_position, Vector3(at.x + 3.0, 0, at.y + 12.0)) < 0.3)
	(level.nodes.get(lever["id"]) as Lever).work()
	await wait(2.0)
	check("and stays when the lever is put back, as it is set to", second.is_perched())
	called["stays"] = false
	var went := await wait(8.0, func() -> bool: return second.is_away())
	check("or goes with it, if it is not", went)
	# Moved in the editor: it is made again where it is put.
	item["at"] = [at.x + 1.0, at.y + 1.0]
	item["points"][0] = item["at"]
	level.put(item)
	await wait(0.5)
	var moved := level.nodes.get(item["id"]) as Ba
	watched = [moved]
	check("moved, it is made again at its new place", moved != null and moved != ba and flat(moved.global_position, Vector3(at.x + 1.0, 0, at.y + 1.0)) < 0.3)
