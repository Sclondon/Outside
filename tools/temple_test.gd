extends SceneTree
## Not part of the game. Builds temples (scripts/temple.gd) with nothing drawn, at full size, and says
## whether each thing holds: every plan builds from `new()` and as an item of a level; the same numbers
## give the same temple; the boy can walk from before the gate to each sanctuary; run and jumped at its
## columns and walls from every side he never ends up inside stone or stuck fast; and ruined, and
## buried in sand, he still gets in, or the temple says that he cannot and why.
## godot --headless --path . --fixed-fps 60 --script tools/temple_test.gd [-- quick]
## Ends with PASSED or FAILED (and exits 0 or 1). `quick` throws him at fewer things.

const PLANS := ["edfu", "luxor", "kom_ombo", "custom"]

var stage: Node3D
var failed := 0
var boy: Player
var touch: TouchControls
var quick := false


func _initialize() -> void:
	quick = "quick" in OS.get_cmdline_user_args()
	stage = Node3D.new()
	root.add_child(stage)
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1200, 2, 1200)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	ground.add_child(collider)
	ground.position = Vector3(0, -1, 0)
	stage.add_child(ground)
	run.call_deferred()


func check(what: String, passed: bool, detail := "") -> void:
	print("PASS " if passed else "FAIL ", what, "  ", detail)
	if not passed:
		failed += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func put(at: Vector3) -> void:
	touch.move = Vector2.ZERO
	touch.jump_held = false
	boy.state = Player.State.FREE
	boy.global_position = at
	boy.velocity = Vector3.ZERO
	boy._spawn = Transform3D(Basis.IDENTITY, at)
	boy.respawn()
	boy._reset_visuals()


## With no camera, the stick's right is +X and its down is +Z.
func steer(way: Vector3) -> void:
	touch.move = Vector2(way.x, way.z)


func stand(numbers: Dictionary) -> Temple:
	for old in stage.get_children():
		if old is Temple:
			stage.remove_child(old)
			old.free()
	var item := LevelLayout.new_item({"items": []}, "temple", numbers.get("what", "custom"), Vector2.ZERO)
	item.merge(numbers, true)
	var temple := Temple.from_item(item)
	stage.add_child(temple)
	return temple


## A number that is the same for two temples only if they are built alike.
func print_of(temple: Temple) -> int:
	var parts: Array = [temple.triangles, temple.shapes, temple.columns]
	for child in temple.get_children():
		if child is CollisionShape3D or child is Marker3D:
			parts.append(child.position.snappedf(0.001))
	return hash(parts)


## Whether any of him is inside something solid.
func in_stone() -> bool:
	var space := boy.get_world_3d().direct_space_state
	for up: float in [0.35, 0.65, 0.95]:
		var query := PhysicsPointQueryParameters3D.new()
		query.position = boy.global_position + Vector3.UP * up
		query.collision_mask = 1
		query.exclude = [boy.get_rid()]
		if not space.intersect_point(query, 1).is_empty():
			return true
	return false


## Whether there is room to stand him at a place.
func free_at(at: Vector3) -> bool:
	var space := boy.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 1.3
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.75)
	query.collision_mask = 1
	return space.intersect_shape(query, 1).is_empty()


## The ground under a place, looking down from `from` above it.
func floor_at(at: Vector3, from := 3.0) -> float:
	var space := boy.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * from, at + Vector3.DOWN * 60.0, 1)
	var hit := space.intersect_ray(query)
	return hit["position"].y if not hit.is_empty() else at.y


## Walks him along a way. Says how far from its end he got.
func walk(temple: Temple, way: PackedVector3Array) -> float:
	var start := temple.to_global(way[0])
	start.y = floor_at(start, 80.0) + 0.05
	put(start)
	await frames(20)
	var long := 0.0
	for i in way.size() - 1:
		long += (way[i + 1] - way[i]).length()
	var left := int((long / 2.5 + 25.0) * 60.0)
	var still := 0
	var last := boy.global_position
	for i in range(1, way.size()):
		var to := temple.to_global(way[i])
		while left > 0:
			var toward := Vector3(to.x - boy.global_position.x, 0.0, to.z - boy.global_position.z)
			if toward.length() < 0.8:
				break
			steer(toward.normalized())
			await physics_frame
			left -= 1
			if left % 30 == 0:
				still = still + 1 if boy.global_position.distance_to(last) < 0.3 else 0
				last = boy.global_position
				if still >= 2:
					# (held up: jump, and climb whatever he catches)
					boy._queue_jump()
					still = 0
			if boy.state == Player.State.HANG:
				boy._queue_jump()
	touch.move = Vector2.ZERO
	var end := temple.to_global(way[way.size() - 1])
	return Vector2(end.x - boy.global_position.x, end.z - boy.global_position.z).length()


## Runs him at solid things from four sides, and then again jumping; counts what went wrong.
func throw_at(temple: Temple, many: int, label: String) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var targets: Array[Vector3] = []
	var solids: Array = temple.get_children().filter(func(node: Node) -> bool: return node is CollisionShape3D)
	var tries := 0
	while targets.size() < many and tries < many * 40:
		tries += 1
		var solid: CollisionShape3D = solids[random.randi() % solids.size()]
		var at := solid.global_position
		var reach := 0.0
		if solid.shape is CylinderShape3D:
			reach = solid.shape.radius
		elif solid.shape is BoxShape3D:
			reach = minf(solid.shape.size.x, solid.shape.size.z) * 0.5
			# (somewhere along a wall, not always its middle)
			at += solid.global_basis * Vector3(random.randf_range(-0.45, 0.45) * solid.shape.size.x, 0.0, random.randf_range(-0.45, 0.45) * solid.shape.size.z)
		else:
			continue
		var low := floor_at(at + Vector3(reach + 2.5, 0.0, 0.0), 2.0)
		if absf(at.y - low) > 14.0 or reach > 8.0:
			continue
		targets.append(Vector3(at.x, 0.0, at.z))
	var inside := 0
	var wedged := 0
	var thrown := 0
	var worst := ""
	for target: Vector3 in targets:
		for side in 4:
			var way := Vector3(cos(side * PI * 0.5 + 0.3), 0.0, sin(side * PI * 0.5 + 0.3))
			var found := false
			var from := Vector3.ZERO
			for off: float in [3.0, 4.5, 6.5, 9.0]:
				from = target - way * off
				from.y = floor_at(from + Vector3.UP * (temple.sand + 0.2), 2.0)
				if free_at(from):
					found = true
					break
			if not found:
				continue
			for jumping: bool in [false, true]:
				put(from + Vector3.UP * 0.05)
				await frames(8)
				thrown += 1
				for i in 110:
					steer(way)
					if jumping and i % 28 == 12:
						boy._queue_jump()
					await physics_frame
				touch.move = Vector2.ZERO
				if boy.state == Player.State.HANG:
					continue
				if in_stone():
					inside += 1
					worst = "inside stone at %s (thrown from %s)" % [boy.global_position, from]
					continue
				# Can he get away again, some way or other?
				var before := boy.global_position
				var moved := 0.0
				for back: Vector3 in [-way, Vector3(way.z, 0.0, -way.x), Vector3(-way.z, 0.0, way.x), way]:
					for i in 40:
						steer(back)
						await physics_frame
					moved = maxf(moved, Vector2(boy.global_position.x - before.x, boy.global_position.z - before.z).length())
					if moved > 0.6:
						break
				touch.move = Vector2.ZERO
				if moved <= 0.6 and boy.state != Player.State.HANG:
					wedged += 1
					worst = "stuck at %s (thrown from %s)" % [before, from]
	check("%s: thrown at its stone %d times, he is never inside it nor stuck" % [label, thrown], inside == 0 and wedged == 0 and thrown > many, "inside %d, stuck %d  %s" % [inside, wedged, worst])


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(0, 0.05, 400)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await frames(20)

	for what: String in PLANS:
		# Whole from new().
		var bare := Temple.new()
		bare.plan = {"edfu": Temple.Plan.EDFU, "luxor": Temple.Plan.LUXOR, "kom_ombo": Temple.Plan.KOM_OMBO, "custom": Temple.Plan.CUSTOM}[what]
		stage.add_child(bare)
		await frames(2)
		check("%s builds from new()" % what, bare.triangles > 500 and bare.shapes > 20 and bare.get_child_count() > 20,
				"%.0f x %.0f m, %d triangles (%d far off), %d shapes, %d columns, %.0f ms" % [bare.length, bare.breadth, bare.triangles, bare.triangles_far, bare.shapes, bare.columns, bare.build_ms])
		stage.remove_child(bare)
		bare.free()
		# As an item of a level; and the same again.
		var one := stand({"what": what, "ruin": 0.4, "seed": 5})
		var first := print_of(one)
		var same := print_of(stand({"what": what, "ruin": 0.4, "seed": 5}))
		var other := print_of(stand({"what": what, "ruin": 0.4, "seed": 6}))
		var temple := stand({"what": what})
		await frames(2)
		check("%s: the same numbers give the same temple, and another seed another ruin" % what, same == first and other != first)
		var began := Time.get_ticks_usec()
		temple.build()
		var again := (Time.get_ticks_usec() - began) / 1000.0
		check("%s: built again in well under a second" % what, again < 500.0, "%.0f ms" % again)
		var doubled := what == "kom_ombo"
		var sanctuaries := temple.get_children().filter(func(node: Node) -> bool: return node.is_in_group(&"temple_sanctuary")).size()
		var doorways := temple.get_children().filter(func(node: Node) -> bool: return node.is_in_group(&"temple_doorways")).size()
		check("%s: its places are marked" % what, sanctuaries == (2 if doubled else 1) and doorways >= 4 and temple.ways.size() == sanctuaries, "%d sanctuaries, %d doorways" % [sanctuaries, doorways])
		await frames(4)
		for which in temple.ways.size():
			var short := await walk(temple, temple.ways[which])
			check("%s: he walks from before the gate to the sanctuary%s" % [what, " (axis %d)" % which if doubled else ""], short < 1.5, "ended %.1f m from it, at %s" % [short, boy.global_position])
		await throw_at(temple, 6 if quick else 22, what)

	# Ruined and buried.
	for what: String in ["edfu", "luxor", "kom_ombo"]:
		for numbers: Dictionary in [{"ruin": 0.3}, {"ruin": 0.6, "seed": 4}, {"ruin": 0.95, "seed": 2}, {"buried": 0.2}, {"buried": 0.5, "ruin": 0.2}, {"buried": 0.9, "ruin": 0.4}]:
			var temple := stand(numbers.merged({"what": what}))
			await frames(4)
			var label := "%s %s" % [what, str(numbers).replace("\"", "")]
			if not temple.open:
				print("SAID %s: he cannot get in: %s" % [label, temple.shut_by])
				continue
			var worst := 0.0
			for way: PackedVector3Array in temple.ways:
				worst = maxf(worst, await walk(temple, way))
			check("%s: he still walks in to the sanctuary" % label, worst < 1.5, "ended %.1f m from it, at %s" % [worst, boy.global_position])
			if not quick and (numbers.get("ruin", 0.0) >= 0.6 or numbers.get("buried", 0.0) >= 0.5):
				await throw_at(temple, 10, label)

	# In a level: put in as the editor puts it in, and kept with the level as text.
	LevelLayout.saved_at = "user://temple_test_layout.json"
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	await frames(10)
	var level: Desert = scene.get_node("Level")
	var labels: Array = LevelLayout.PALETTE["Stone"].map(func(entry: Array) -> String: return entry[0])
	check("the Stone page offers the four temples", "Temple: Edfu" in labels and "Temple: Luxor" in labels and "Temple: Kom Ombo" in labels and "Temple (your own)" in labels)
	var item := LevelLayout.new_item(level.layout, "temple", "kom_ombo", Vector2(150, 40))
	item["ruin"] = 0.5
	level.layout["items"].append(item)
	var made := level.make(item) as Temple
	await frames(4)
	var kept: Dictionary = LevelLayout.from_text(LevelLayout.to_text(level.layout))["items"][-1]
	check("a level makes a temple of its item, and keeps it as text", made != null and made.plan == Temple.Plan.KOM_OMBO and is_equal_approx(made.ruin, 0.5) and made.shapes > 50
			and kept["kind"] == "temple" and kept["what"] == "kom_ombo" and is_equal_approx(kept["ruin"], 0.5) and is_equal_approx(kept["size"], 1.0), "%s" % [kept])
	scene.queue_free()
	await frames(4)

	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(0 if failed == 0 else 1)
