extends SceneTree
## Not part of the game. Runs Medjed with nothing drawn and says whether each thing happened: he sweeps from side to
## side and waits at each end; the boy standing in his gaze in the open is smitten after the warning and not before;
## behind a block he is not, nor ducked behind a low one, though standing behind it he is; out of sight in time, it
## dies down; he runs from one block to another while Medjed looks away; a mirror turned to face him shuts his eyes;
## one that is unseen shows only when he fires; one that follows comes a little way, slowly, no further than he may
## roam and not over a kerb, and goes home. Then in the desert, made from items as the level editor makes them: a
## plate linked to him shuts his eyes, and off it the boy is caught as the mummy catches him.
## It counts the rays he casts all the while: never more than two in a step of the game.
## godot --headless --path . --fixed-fps 60 --script tools/medjed_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
var touch: TouchControls
var caught := 0
var most_rays := 0
var watched: Array[Medjed] = []


func _initialize() -> void:
	LevelLayout.saved_at = "user://medjed_test_layout.json"
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(160, 2, 160))
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


## Lets `seconds` go by, or fewer if `until` comes true first. Returns whether it did.
func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		await process_frame
		for one in watched:
			if is_instance_valid(one):
				most_rays = maxi(most_rays, one.rays_cast)
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func put(at: Vector3) -> void:
	touch.move = Vector2.ZERO
	boy.global_position = at
	boy.velocity = Vector3.ZERO


## A Medjed at a place, facing +Z, counting whom he smites.
func medjed_at(at: Vector3, sweep := 90.0) -> Medjed:
	var one := Medjed.new()
	one.voice = false
	one.sweep = sweep
	one.position = at
	stage.add_child(one)
	one.caught.connect(func() -> void: caught += 1)
	watched.append(one)
	return one


func swing_of(one: Medjed) -> float:
	return rad_to_deg(angle_difference(one.global_basis.get_euler().y, one.facing_yaw))


func away(one: Medjed) -> float:
	return Vector2(one.global_position.x - one.post().x, one.global_position.z - one.post().z).length()


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(40, 0.05, 40)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await wait(0.5)

	await sweeping()
	await in_the_open()
	await cover()
	await crossing()
	await mirrors()
	await unseen()
	await following()
	check("he never casts more than two rays in a step of the game", most_rays <= 2 and most_rays > 0, "most %d" % most_rays)
	boy.set_physics_process(false)
	stage.queue_free()
	watched.clear()
	await wait(0.2)
	await in_the_desert()
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


func sweeping() -> void:
	var one := medjed_at(Vector3.ZERO)
	await wait(0.5)
	check("he comes to stand on the floor", absf(one.global_position.y) < 0.05, "y %.3f" % one.global_position.y)
	var ends := [0.0, 0.0]
	var still := [0]
	var last := [swing_of(one)]
	await wait(12.0, func() -> bool:
		var now := swing_of(one)
		ends[0] = minf(ends[0], now)
		ends[1] = maxf(ends[1], now)
		if absf(now - last[0]) < 0.001:
			still[0] += 1
		last[0] = now
		return false)
	check("he looks from side to side through his sweep", absf(ends[0] + 45.0) < 1.0 and absf(ends[1] - 45.0) < 1.0, "%.1f to %.1f degrees" % [ends[0], ends[1]])
	check("and waits at each end", still[0] > 100 and still[0] < 400, "%d steps still in 12 s" % still[0])
	check("with nobody in his gaze nobody is caught", caught == 0 and one.charge == 0.0 and one.state == Medjed.State.SWEEP)
	one.sweep = 360.0
	one.reset()
	var turned := [0.0]
	last[0] = one.facing_yaw
	await wait(13.0, func() -> bool:
		turned[0] += angle_difference(last[0], one.facing_yaw)
		last[0] = one.facing_yaw
		return false)
	check("set to 360 he turns all the way round", absf(rad_to_deg(turned[0])) > 370.0, "%.0f degrees in 13 s" % rad_to_deg(turned[0]))
	one.queue_free()
	await wait(0.1)


func in_the_open() -> void:
	caught = 0
	var one := medjed_at(Vector3.ZERO)
	put(Vector3(0, 0.05, 5))
	var seen_at := [-1, -1]
	var steps := [0]
	var got := await wait(10.0, func() -> bool:
		steps[0] += 1
		if one.sees and seen_at[0] < 0:
			seen_at[0] = steps[0]
		if caught > 0 and seen_at[1] < 0:
			seen_at[1] = steps[0]
		return caught > 0)
	var took: float = (seen_at[1] - seen_at[0]) / 60.0
	check("standing in his gaze in the open, the boy is smitten", got and caught == 1 and one.smitten == 1)
	check("after the warning, and not before", absf(took - one.warning) < 0.1, "%.2f s from seen to smitten" % took)
	check("then he rests", one.state == Medjed.State.FIRED)
	# Too far off, and he sees nothing.
	caught = 0
	one.reset()
	put(Vector3(0, 0.05, one.reach + 1.0))
	await wait(8.0)
	check("beyond his reach the boy is not seen", caught == 0 and one.charge == 0.0)
	# Out of sight in time.
	one.reset()
	put(Vector3(0, 0.05, 5))
	var charging := await wait(8.0, func() -> bool: return one.charge > 0.5)
	put(Vector3(30, 0.05, -30))
	var high := one.charge
	var died := await wait(4.0, func() -> bool: return one.charge == 0.0 and one.state == Medjed.State.SWEEP)
	check("out of sight in time, it dies down and he goes back to looking", charging and died and caught == 0, "it had got to %.2f" % high)
	one.queue_free()
	await wait(0.1)


func cover() -> void:
	caught = 0
	var one := medjed_at(Vector3.ZERO)
	var pillar := box(Vector3(0, 0.8, 3.5), Vector3(1.0, 1.6, 1.0))
	put(Vector3(0, 0.05, 4.4))
	var saw := [false]
	await wait(9.0, func() -> bool:
		saw[0] = saw[0] or one.sees
		return false)
	check("behind a block he is not seen", caught == 0 and not saw[0] and one.charge == 0.0)
	pillar.queue_free()
	# Something low: it hides him ducked, and not standing.
	var low := box(Vector3(0, 0.3, 5.5), Vector3(1.6, 0.6, 0.6))
	put(Vector3(0, 0.05, 6.1))
	touch.duck_held = true
	await wait(0.5)
	saw[0] = false
	await wait(9.0, func() -> bool:
		saw[0] = saw[0] or one.sees
		return false)
	check("ducked behind something low he is not seen", boy.is_ducking and caught == 0 and not saw[0], "ducking %s, caught %d" % [boy.is_ducking, caught])
	touch.duck_held = false
	var got := await wait(9.0, func() -> bool: return caught > 0)
	check("standing up behind it he is", got)
	low.queue_free()
	one.queue_free()
	put(Vector3(40, 0.05, 40))
	await wait(0.1)


func crossing() -> void:
	caught = 0
	var one := medjed_at(Vector3.ZERO, 120.0)
	for x: float in [-2.5, 2.5]:
		box(Vector3(x, 0.8, 4.0), Vector3(1.0, 1.6, 1.0))
	put(Vector3(2.5, 0.05, 5.0))
	# He waits behind the block on the side Medjed is looking, and goes as the gaze comes to rest past him.
	var saw := [false]
	var ready := await wait(15.0, func() -> bool: return swing_of(one) > 59.5)
	touch.move = Vector2(-1.0, 0.0)
	await wait(4.0, func() -> bool:
		saw[0] = saw[0] or one.sees
		if boy.global_position.x < -2.5:
			touch.move = Vector2.ZERO
		return boy.global_position.x < -2.5 and boy.velocity.length() < 0.1)
	touch.move = Vector2.ZERO
	put(Vector3(-2.5, 0.05, 5.0))
	await wait(8.0, func() -> bool:
		saw[0] = saw[0] or one.sees
		return false)
	check("he crosses from block to block while Medjed looks away", ready and caught == 0 and not saw[0], "caught %d, seen %s" % [caught, saw[0]])
	# And crossing under the gaze, walking, he does not get there.
	await wait(15.0, func() -> bool: return absf(swing_of(one)) < 8.0)
	var got := [false]
	for i in 240:
		boy.global_position.x += 5.0 / 240.0
		await wait(1.0 / 60.0)
		got[0] = got[0] or caught > 0
	check("crossing under his gaze he is caught", got[0])
	one.queue_free()
	put(Vector3(40, 0.05, 40))
	await wait(0.1)


func mirrors() -> void:
	caught = 0
	var one := medjed_at(Vector3(20, 0, 0), 0.0)
	var mirror := Mirror.new()
	mirror.turned = 2
	mirror.position = Vector3(20, 0, 4)
	stage.add_child(mirror)
	await wait(2.0)
	check("a mirror edge on to him does nothing", not one.is_shut())
	mirror.work()
	mirror.work()
	var shut := await wait(3.0, func() -> bool: return one.is_shut())
	check("turned to face him, it shuts his eyes", shut)
	put(Vector3(20.6, 0.05, 3))
	await wait(one.dazzle - 0.5)
	check("and the boy can stand before him while they are shut", caught == 0 and one.is_shut())
	mirror.queue_free()
	var got := await wait(4.0, func() -> bool: return caught > 0)
	check("they open again, and with the mirror gone he sees", got)
	one.queue_free()
	put(Vector3(40, 0.05, 40))
	await wait(0.1)


func unseen() -> void:
	caught = 0
	var one := medjed_at(Vector3(20, 0, 0), 0.0)
	one.unseen = true
	await wait(0.3)
	check("one that is unseen has no shroud to see", not one._shroud.visible and one._feet[0].visible)
	put(Vector3(20, 0.05, 4))
	var got := await wait(3.0, func() -> bool: return caught > 0)
	await wait(0.1)
	check("until he fires", got and one._shroud.visible)
	put(Vector3(40, 0.05, 40))
	await wait(4.0)
	check("and then it is gone again", not one._shroud.visible)
	# Shut until it is worked, and the other way about.
	one.wakes_when_worked = true
	put(Vector3(20, 0.05, 4))
	caught = 0
	await wait(2.0)
	check("set to wake when worked, his eyes are shut until then", one.is_shut() and caught == 0)
	one.worked = true
	got = await wait(3.0, func() -> bool: return caught > 0)
	check("and open when it is", got)
	one.queue_free()
	put(Vector3(40, 0.05, 40))
	await wait(0.1)


func following() -> void:
	caught = 0
	var one := medjed_at(Vector3(-20, 0, 0), 0.0)
	one.follows = true
	one.roam = 3.0
	await wait(0.3)
	put(Vector3(-20, 0.05, 6))
	var charging := await wait(3.0, func() -> bool: return one.charge > 0.4)
	put(Vector3(40, 0.05, 40))
	var furthest := [0.0]
	var fastest := [0.0]
	var last := [one.global_position]
	var track := func() -> void:
		furthest[0] = maxf(furthest[0], away(one))
		fastest[0] = maxf(fastest[0], last[0].distance_to(one.global_position) * 60.0)
		last[0] = one.global_position
	var went := await wait(12.0, func() -> bool:
		track.call()
		return one.state == Medjed.State.LOOK)
	check("having lost him, he comes to look where he last saw him", charging and went and furthest[0] > 2.0, "%.2f m from his post" % furthest[0])
	var back := await wait(20.0, func() -> bool:
		track.call()
		return one.state == Medjed.State.SWEEP)
	var round := await wait(10.0, func() -> bool: return absf(swing_of(one)) < 1.0)
	check("and goes home, and turns to look the way he did", back and round and away(one) < 0.05, "%.2f m from his post, turned %.1f" % [away(one), swing_of(one)])
	check("no further than he may roam", furthest[0] <= one.roam + 0.05, "%.2f of %.1f m" % [furthest[0], one.roam])
	check("and never fast", fastest[0] <= one.shuffle_speed * 1.05 and fastest[0] > 0.3, "%.2f m/s" % fastest[0])
	check("nobody was caught by it", caught == 0)
	# A kerb across his way.
	var kerb := box(Vector3(-20, 0.1, 1.6), Vector3(6.0, 0.2, 0.3))
	put(Vector3(-20, 0.05, 6))
	await wait(3.0, func() -> bool: return one.charge > 0.4)
	put(Vector3(40, 0.05, 40))
	furthest[0] = 0.0
	var high := [0.0]
	await wait(14.0, func() -> bool:
		track.call()
		high[0] = maxf(high[0], one.global_position.y)
		return one.state == Medjed.State.HOME)
	back = await wait(20.0, func() -> bool: return one.state == Medjed.State.SWEEP)
	check("a kerb stops him", furthest[0] > 0.5 and furthest[0] < 1.3 and high[0] < 0.05 and back, "%.2f m from his post, highest %.2f" % [furthest[0], high[0]])
	# Seen again as he comes, the boy is caught there.
	kerb.queue_free()
	await wait(10.0, func() -> bool: return absf(swing_of(one)) < 1.0)
	put(Vector3(-20, 0.05, 6))
	await wait(3.0, func() -> bool: return one.charge > 0.4)
	put(Vector3(40, 0.05, 40))
	await wait(6.0, func() -> bool: return one.state == Medjed.State.SEEK and away(one) > 1.0)
	put(Vector3(-20, 0.05, 6))
	var got := await wait(3.0, func() -> bool: return caught > 0)
	check("he sees as he comes", got and away(one) > 1.0)
	one.reset()
	check("put back, he is at his post", away(one) < 0.01 and one.state == Medjed.State.SWEEP and one.charge == 0.0)
	one.queue_free()
	put(Vector3(40, 0.05, 40))
	await wait(0.1)


# --- In the desert, made from items ---

func in_the_desert() -> void:
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	await wait(0.6)
	var level: Desert = scene.get_node("Level")
	var him := scene.get_node("Player") as Player
	him.set_physics_process(false)
	var found := false
	for entry: Array in LevelLayout.PALETTE["People"]:
		found = found or (entry[0] == "Medjed" and entry[1] == "person" and entry[2] == "medjed")
	var add := func(kind: String, what: String, at: Vector2, more := {}) -> Dictionary:
		var item := LevelLayout.new_item(level.layout, kind, what, at)
		item.merge(more, true)
		level.layout["items"].append(item)
		level.make(item)
		return item
	# (on a patch of ground of their own, so that no dune is in the way)
	var middle := Vector2(60.0, 100.0)
	level.layout["items"].append(LevelLayout.new_item(level.layout, "pad", "", middle).merged({"y": level.height_at(middle.x, middle.y), "half_x": 9.0, "half_z": 9.0}, true))
	level.reshape()
	await wait(0.3)
	var plate := add.call("plate", "", middle + Vector2(-5.0, 0.0), {"only_him": true}) as Dictionary
	var item := add.call("person", "medjed", middle, {"sweep": 0.0, "reach": 7.0, "warning": 0.5, "unseen": true, "follows": true, "roam": 2.5, "links": [plate["id"]]}) as Dictionary
	var one := level.nodes.get(item["id"]) as Medjed
	check("the editor's Medjed makes one, with its settings", found and one != null and one.sweep == 0.0 and one.reach == 7.0 and one.warning == 0.5 and one.unseen and one.follows and one.roam == 2.5
			and LevelLayout.label(item) == "Medjed" and LevelLayout.fields(item).size() == 9)
	if one == null:
		return
	watched.append(one)
	one.voice = false
	await wait(1.0)
	check("he stands on the ground there", one._grounded, "y %.2f, the ground %.2f" % [one.global_position.y, level.height_at(middle.x, middle.y)])
	# On the plate: his eyes are shut, and the boy's place in front of him is safe.
	him.global_position = level.nodes[plate["id"]].global_position + Vector3.UP * 0.1
	var shut := await wait(1.0, func() -> bool: return one.is_shut())
	check("the plate linked to him shuts his eyes", shut and one.worked)
	him.global_position = one.global_position + Vector3(0.0, 0.05, 4.0)
	var opened := await wait(1.0, func() -> bool: return not one.is_shut())
	check("and off it they open", opened)
	var down := await wait(3.0, func() -> bool: return him.is_limp)
	check("in his gaze the boy is caught, as the mummy catches him", down and one.smitten == 1)
	var up := await wait(5.0, func() -> bool: return not him.is_limp)
	await wait(0.2)
	check("and when the boy starts again he is as he was", up and one.state == Medjed.State.SWEEP and one.smitten == 1)
	# Changed in the editor, he is made again; taken out, he is gone.
	item["wakes"] = true
	one = level.make(item) as Medjed
	await wait(0.5)
	check("set to be shut until then, he is", one.wakes_when_worked and one.is_shut())
	level.forget(item["id"])
	level.layout["items"].erase(item)
	await wait(0.2)
	check("taken out of the level, he is gone", not is_instance_valid(one) or not one.is_inside_tree())
	check("still no more than two rays", most_rays <= 2, "most %d" % most_rays)
