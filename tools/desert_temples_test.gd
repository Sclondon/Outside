extends "res://tools/desert_walk.gd"
## Not part of the game. Checks, with nothing drawn, the three temples that stand in the shipped desert (Edfu, Kom
## Ombo and Abu Simbel) and the river they stand by, and does the small thing there is to do at each, as he
## would: walking, and touching the names on the screen.
##
##   - each temple is there at its true size, on level ground, with no dune on it, no doorway shut by sand, and
##     nothing of the old level inside it; a checkpoint is near each;
##   - the river's water lies in its bed and nowhere else, and clear of every temple;
##   - Edfu: knives bar the sanctuary; a wrong name lays him out and he starts again at the checkpoint inside the
##     temple; the leaf by the well gives the name, the right name lets him in to the naos;
##   - Kom Ombo: the same, at the sanctuary of Sobek;
##   - Abu Simbel: a slab shuts the inner halls and the sun stops at it; he pulls the lever in the store-room, the
##     slab goes up, the sun reaches the gods, and the store-room opposite opens and stays open, whatever stands
##     in the light afterwards and whether or not the lever is put back.
## godot --headless --path . --fixed-fps 60 --script tools/desert_temples_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1). The desert is the one the game came with.

var failed := 0


func check(what: String, passed: bool, detail := "") -> void:
	print("PASS " if passed else "FAIL ", what, "  ", detail)
	if not passed:
		failed += 1


func run() -> void:
	touch.set_process_input(false)
	player.set_process_unhandled_input(false)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	await frames(60)
	# (his brother would follow him about, and may stand where he is not wanted: he is tried without him)
	for child in level.get_node("Items").get_children():
		if child is Brother:
			child.queue_free()
	var edfu := named("Edfu") as Temple
	var kom := named("KomOmbo") as Temple
	var abu := named("AbuSimbel") as AbuSimbel
	check("Edfu, Kom Ombo and Abu Simbel are in the shipped desert", edfu != null and kom != null and abu != null)
	if edfu == null or kom == null or abu == null:
		print("FAILED (%d)" % failed)
		quit(1)
		return
	await the_ground(edfu, kom, abu)
	await at_edfu(edfu)
	await at_kom_ombo(kom)
	await at_abu_simbel(abu)
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


# --- Where they stand ---

func the_ground(edfu: Temple, kom: Temple, abu: AbuSimbel) -> void:
	check("each is its true size", is_equal_approx(edfu.size, 1.0) and is_equal_approx(kom.size, 1.0) and is_equal_approx(abu.size, 1.0),
			"Edfu %.0f by %.0f m, its pylon %.0f m; Kom Ombo %.0f by %.0f m; Abu Simbel's hill %.0f m" % [edfu.length, edfu.breadth, edfu.height, kom.length, kom.breadth, abu.height])
	check("no doorway of Edfu or Kom Ombo is shut by sand", edfu.open and kom.open, edfu.shut_by + kom.shut_by)
	check("Abu Simbel has its sand as the 1910s had it, and the sun on its axis", is_equal_approx(abu.drift, 0.35) and abu.sun_on_axis and abu.beam != null, "drift %.2f" % abu.drift)
	# Level ground under each, and for a way round it: no dune has been left on it.
	var grounds := [[edfu, Rect2(-edfu.breadth * 0.5 - 6.0, -edfu.length * 0.5 - 6.0, edfu.breadth + 12.0, edfu.length + 26.0)],
		[kom, Rect2(-kom.breadth * 0.5 - 12.0, -kom.length * 0.5 - 6.0, kom.breadth + 30.0, kom.length + 30.0)],
		[abu, Rect2(-66.0, -120.0, 208.0, 150.0)]]
	for entry: Array in grounds:
		var temple: Node3D = entry[0]
		var rect: Rect2 = entry[1]
		var worst := 0.0
		for i in 400:
			var local := Vector3(rect.position.x + rect.size.x * ((i * 37) % 400) / 400.0, 0.0, rect.position.y + rect.size.y * ((i * 91) % 397) / 397.0)
			var at := temple.global_transform * local
			worst = maxf(worst, absf(level.height_at(at.x, at.z) - temple.global_position.y))
		check("the ground under %s is level, and no dune lies on it" % temple.name, worst < 0.12, "%.2f m off at the worst of 400 places" % worst)
	# Nothing of the old level stands inside a temple (what was put there for it has a name, or stands on its floor).
	var inside := 0
	for item: Dictionary in level.layout["items"]:
		if item["kind"] != "prop" or String(item.get("what", "")).begins_with("helmet") or item.get("what", "") in ["torch_stand", "khopesh_stand", "statue_anubis"]:
			continue
		var at := Vector3(item["at"][0], 0.0, item["at"][1])
		for entry: Array in grounds:
			var local: Vector3 = (entry[0] as Node3D).to_local(Vector3(at.x, (entry[0] as Node3D).global_position.y, at.z))
			var body := Rect2(-41.0, -80.0, 180.0, 102.0) if entry[0] == abu else Rect2(-(entry[0] as Temple).breadth * 0.5, -(entry[0] as Temple).length * 0.5, (entry[0] as Temple).breadth, (entry[0] as Temple).length)
			if body.has_point(Vector2(local.x, local.z)):
				inside += 1
				print("  %s stands inside %s at %s" % [item.get("what", ""), (entry[0] as Node3D).name, at])
	check("no palm, stone or camp thing stands inside a temple", inside == 0, "%d" % inside)
	# The river: its water is in its bed and nowhere else, and no temple stands in it.
	var rivers := 0
	for water: Dictionary in level.terrain.waters():
		var points: PackedVector2Array = water["points"]
		if points.size() < 3:
			continue
		rivers += 1
		var rect: Rect2 = water["rect"]
		var flooded := 0
		# (beside its bed the bank comes up from the water's edge to the ground: beyond the bank is what must be dry)
		var bank := 8.0
		for item: Dictionary in level.layout["items"]:
			if int(item["id"]) == int(water["id"]):
				bank = float(item.get("bank", 8.0))
		var lowest_dry := 100.0
		var wall := level.terrain.size * 0.5 - DesertTerrain.JOIN
		for row in int(rect.size.y / 4.0):
			for column in int(rect.size.x / 4.0):
				var at := rect.position + Vector2(column * 4.0 + 2.0, row * 4.0 + 2.0)
				if absf(at.x) > wall or absf(at.y) > wall:
					continue
				var away := 1000.0
				for i in points.size() - 1:
					away = minf(away, at.distance_to(Geometry2D.get_closest_point_to_segment(at, points[i], points[i + 1])))
				if away > float(water["half"]) + bank:
					var ground := level.height_at(at.x, at.y)
					lowest_dry = minf(lowest_dry, ground)
					if ground < float(water["level"]) + 0.05:
						flooded += 1
		check("the river's water lies in its bed and nowhere else", flooded == 0, "%d places flooded; the lowest ground beyond its banks is %.2f m and the water %.2f m" % [flooded, lowest_dry, float(water["level"])])
		var nearest := 1000.0
		for entry: Array in grounds:
			var temple: Node3D = entry[0]
			for i in (points.size() - 1) * 20:
				var at := points[i / 20].lerp(points[i / 20 + 1], (i % 20) / 20.0)
				var local := temple.to_local(Vector3(at.x, temple.global_position.y, at.y))
				var body := Rect2(-37.0, -80.0, 180.0, 102.0) if temple == abu else Rect2(-(temple as Temple).breadth * 0.5 - 12.0, -(temple as Temple).length * 0.5, (temple as Temple).breadth + 24.0, (temple as Temple).length)
				var off := Vector2(maxf(maxf(body.position.x - local.x, local.x - body.end.x), 0.0), maxf(maxf(body.position.y - local.z, local.z - body.end.y), 0.0)).length()
				nearest = minf(nearest, off - float(water["half"]))
		check("and comes no nearer a temple's stone than a few metres", nearest > 3.0, "%.1f m at the nearest" % nearest)
	check("there is a river", rivers == 1)
	# A checkpoint by each, and one inside.
	var marks := get_nodes_in_group(&"checkpoints")
	for entry: Array in [[edfu, edfu.ways[0][0]], [kom, kom.ways[0][0]], [abu, Vector3(0.0, 0.0, 22.0)]]:
		var gate := (entry[0] as Node3D).global_transform * (entry[1] as Vector3)
		var near := 1000.0
		for mark: Node3D in marks:
			near = minf(near, Vector2(mark.global_position.x - gate.x, mark.global_position.z - gate.z).length())
		check("a checkpoint is near the way in to %s" % (entry[0] as Node3D).name, near < 25.0, "%.0f m" % near)
	await frames(1)


# --- Edfu ---

func at_edfu(temple: Temple) -> void:
	print("EDFU")
	var keeper := named("EdfuKeeper") as GateGuardian
	var leaf := named("EdfuLeaf") as BookPage
	var sanctuary := temple.global_transform * mark_in(temple, &"temple_sanctuary")
	check("a keeper sits by the sanctuary of Edfu and bars it, and its leaf is elsewhere in the temple", keeper != null and leaf != null and keeper.bars_way and not keeper.on
			and keeper.global_position.distance_to(sanctuary) < 9.0 and leaf.global_position.distance_to(keeper.global_position) > 20.0 and leaf.name_on_it() == keeper.who,
			"the leaf is %.0f m from the keeper" % leaf.global_position.distance_to(keeper.global_position))
	check("the knives stand in the doorway of the sanctuary", Vector2(keeper.threshold().x - sanctuary.x, keeper.threshold().z - sanctuary.z).length() < 5.0
			and absf(temple.to_local(keeper.threshold()).x) < 0.2, "%s" % temple.to_local(keeper.threshold()))
	await barred_then_named(temple, keeper, leaf, sanctuary, "InEdfu", 0)
	var helmet := named_prop("helmet_horus")
	check("and in the sanctuary is the helmet of Horus", helmet != null and helmet.global_position.distance_to(sanctuary) < 8.0)


# --- Kom Ombo ---

func at_kom_ombo(temple: Temple) -> void:
	print("KOM OMBO")
	var keeper := named("KomOmboKeeper") as GateGuardian
	var leaf := named("KomOmboLeaf") as BookPage
	var sanctuary := temple.global_transform * mark_in(temple, &"temple_sanctuary")
	check("a keeper with a crocodile's head bars the sanctuary of Sobek, and its leaf is by the well", keeper != null and leaf != null and keeper.bars_way and not keeper.on
			and keeper.beast() == BookOfTheDead.Head.CROCODILE and leaf.name_on_it() == keeper.who
			and leaf.global_position.distance_to(temple.global_transform * mark_in(temple, &"temple_well")) < 6.0)
	await barred_then_named(temple, keeper, leaf, sanctuary, "InKomOmbo", 0)
	var helmet := named_prop("helmet_sobek")
	check("and in the sanctuary is the helmet of Sobek", helmet != null and helmet.global_position.distance_to(sanctuary) < 8.0)


## What both keepers are put through. `which` is the way in (`Temple.ways`) that leads to the keeper's door.
func barred_then_named(temple: Temple, keeper: GateGuardian, leaf: BookPage, sanctuary: Vector3, checkpoint: String, which: int) -> void:
	var way_in: PackedVector3Array = temple.ways[which]
	var mark := named(checkpoint)
	# From the checkpoint inside the temple, on along the way in: the knives stop him short of the sanctuary.
	keeper.asks_at_threshold = false
	place(mark.global_position + Vector3.UP * 0.1)
	await frames(30)
	var before := temple.global_transform * way_in[way_in.size() - 3]
	await leg("to the door before the sanctuary", Vector3.INF, before)
	await push_on(sanctuary, 4.0)
	check("the knives stop him: he cannot walk in", Vector2(player.global_position.x - sanctuary.x, player.global_position.z - sanctuary.z).length() > 2.0,
			"%.1f m short of it" % Vector2(player.global_position.x - sanctuary.x, player.global_position.z - sanctuary.z).length())
	keeper.asks_at_threshold = true
	# A wrong name: he is laid out, and starts again at the checkpoint inside the temple.
	place(mark.global_position + Vector3.UP * 0.1)
	await frames(40)
	await leg("on to the keeper's threshold", Vector3.INF, before)
	await push_on(keeper.threshold(), 3.0)
	var asked := await wait_for(2.0, func() -> bool: return panel() != null)
	check("on the threshold it asks its name, and without the leaf gives no English", asked and panel() != null and not panel().known and paused)
	if panel() == null:
		return
	var wrong: int = keeper.dealt[0] if keeper.dealt[0] != keeper.who else keeper.dealt[1]
	await say(wrong)
	var down := await wait_for(2.0, func() -> bool: return player.is_limp)
	check("a wrong name: he is laid out", down and not keeper.on)
	var up := await wait_for(5.0, func() -> bool: return not player.is_limp)
	await frames(30)
	check("and starts again at the checkpoint inside the temple, not back where the level starts", up and player.global_position.distance_to(mark.global_position) < 2.0,
			"%.1f m from it" % player.global_position.distance_to(mark.global_position))
	# The leaf: he walks onto it, and it comes up to read.
	place(leaf.global_position + Vector3(2.5, 0.1, 0.0))
	await frames(30)
	await push_on(leaf.global_position, 3.0)
	var read := await wait_for(2.0, func() -> bool: return panel() != null)
	check("he finds the leaf, and it comes up to be read", read and leaf.is_taken and BookOfTheDead.of(keeper).has(keeper.who))
	await frames(40)
	await tap(Vector2(640, 360))
	await frames(20)
	check("a touch puts it away", panel() == null and not paused)
	# Back to the keeper: now the English is under the right name.
	place(mark.global_position + Vector3.UP * 0.1)
	await frames(40)
	await leg("back to the keeper", Vector3.INF, before)
	await push_on(keeper.threshold(), 3.0)
	asked = await wait_for(2.0, func() -> bool: return panel() != null)
	check("asked again, the English is under the right name", asked and panel() != null and panel().known)
	if panel() == null:
		return
	await say(keeper.who)
	await frames(120)
	check("the right name: it is on for good, and the knives swing out of the way", keeper.on and panel() == null and not paused)
	await leg("in to the sanctuary", Vector3.INF, sanctuary)
	check("and he walks in", Vector2(player.global_position.x - sanctuary.x, player.global_position.z - sanctuary.z).length() < 1.7)
	await leg("and out again", Vector3.INF, before)
	check("and out again", player.global_position.distance_to(before) < 2.0)


# --- Abu Simbel ---

func at_abu_simbel(abu: AbuSimbel) -> void:
	print("ABU SIMBEL")
	var lever := named("AbuLever") as Lever
	var slab := named("AbuSlab") as TombParts.Door
	var store := named("AbuStoreDoor") as TombParts.Door
	var disc := named("AbuSunDisc") as SunDisc
	var marks := {}
	for group: StringName in [&"abu_simbel_door", &"abu_simbel_hall", &"abu_simbel_sanctuary"]:
		for mark in get_nodes_in_group(group):
			marks[String(mark.name)] = (mark as Node3D).global_position
	check("a slab, a lever, a sun disc and a store-room door are in the Great Temple", lever != null and slab != null and store != null and disc != null)
	check("at first the slab is down, the sun stops at it, and the store-room is shut", not slab.is_open and not store.is_open and not abu.on and not disc.on and not lever.on
			and abu.beam.path.size() >= 2 and abu.to_local(abu.beam.path[abu.beam.path.size() - 1]).z > -23.5, "the light ends %.1f m in" % -abu.to_local(abu.beam.path[abu.beam.path.size() - 1]).z)
	# He can walk in at the door, but not past the slab.
	place(abu.global_transform * Vector3(0.0, 0.1, 27.0))
	await frames(30)
	await way("up the terrace and in", [Vector3.INF, marks["GreatDoor"], marks["GreatHall"]])
	check("he walks in at the door of the Great Temple", player.global_position.distance_to(marks["GreatHall"]) < 2.0)
	await push_on(marks["GreatSanctuary"], 6.0)
	check("the slab stops him", abu.to_local(player.global_position).z > -22.0, "he is %.1f m in" % -abu.to_local(player.global_position).z)
	# The lever is at the end of the first store-room on his left.
	var mouth := abu.global_transform * Vector3(-7.4, 1.2, -8.7)
	await way("to the lever", [Vector3.INF, marks["GreatHall"], mouth, lever.global_position + (mouth - lever.global_position).normalized() * 2.0])
	await push_on(lever.global_position + (mouth - lever.global_position).normalized() * 0.7, 3.0)
	player.facing_yaw = atan2(lever.global_position.x - player.global_position.x, lever.global_position.z - player.global_position.z)
	await frames(20)
	player._act()
	await frames(30)
	check("he pulls the lever with the act button", lever.on)
	var lit := await wait_for(8.0, func() -> bool: return abu.on and store.is_open)
	check("the slab goes up, the sun reaches the gods, the disc at their knees is lit, and the store-room opposite opens", lit and slab.is_open and disc.on and abu.on and store.is_open)
	await way("out of the store-room and on to the gods", [Vector3.INF, mouth, marks["GreatHall"], marks["GreatSanctuary"]])
	check("he walks on to the sanctuary", player.global_position.distance_to(marks["GreatSanctuary"]) < 2.0)
	# Standing in the light puts the temple out, but the store-room stays open: he cannot be shut in it.
	place(abu.global_transform * Vector3(0.75, 1.25, -26.0))
	await frames(60)
	check("standing in the light, he stops it", not abu.on)
	check("but the store-room stays open (the disc stays lit)", disc.on and store.is_open)
	place(marks["GreatHall"] + Vector3.UP * 0.1)
	await frames(30)
	await way("into the store-room that opened", [Vector3.INF, abu.global_transform * Vector3(7.4, 1.2, -8.7), abu.global_transform * Vector3(17.5, 1.2, -8.7)])
	check("he walks into it", abu.to_local(player.global_position).x > 15.0)
	var prize := named_prop("khopesh_stand")
	check("and the khopesh on its rack is there", prize != null and prize.global_position.distance_to(player.global_position) < 4.0)
	# The lever put back while he is in there: the slab comes down, the store-room does not shut.
	lever.work(player)
	await frames(360)
	check("the lever put back: the slab is down again, and the store-room is still open", not slab.is_open and store.is_open and not abu.on)
	await way("and out to the terrace", [Vector3.INF, abu.global_transform * Vector3(7.4, 1.2, -8.7), marks["GreatHall"], marks["GreatDoor"], abu.global_transform * Vector3(0.0, 0.0, 27.0)])
	check("he walks out again", abu.to_local(player.global_position).z > 24.0)


# --- Helping ---

## The place a temple marks (the first in the group), in the temple's own space.
func mark_in(temple: Node3D, group: StringName) -> Vector3:
	for mark in get_nodes_in_group(group):
		if temple.is_ancestor_of(mark):
			return (mark as Node3D).position
	return Vector3.ZERO


## The node of the first prop of a kind.
func named_prop(what: String) -> Node3D:
	for item: Dictionary in level.layout["items"]:
		if item["kind"] == "prop" and item.get("what", "") == what:
			return level.nodes.get(item["id"])
	return null


## Walks straight at a place for so many seconds, whatever is in the way.
func push_on(to: Vector3, seconds: float) -> void:
	for i in int(seconds * 60.0):
		var toward := Vector3(to.x - player.global_position.x, 0.0, to.z - player.global_position.z)
		if toward.length() < 0.5:
			break
		await frames(1, toward.normalized())
	touch.move = Vector2.ZERO
	await frames(10)


## Lets `seconds` go by, or fewer if `until` comes true first. Says whether it did.
func wait_for(seconds: float, until: Callable) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		await process_frame
		if until.call():
			return true
	return false


func panel() -> GuardianPanel:
	return GuardianPanel.current if is_instance_valid(GuardianPanel.current) else null


## A finger down and up at a place on the screen.
func tap(at: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = down
		root.push_input(event, true)
		await process_frame


## Touches the button of a name on the panel that is up.
func say(name: int) -> void:
	var up := panel()
	up.lay_out()
	await tap(up.get_global_transform() * up.buttons[up.dealt.find(name)].get_center())
