extends SceneTree
## Not part of the game. Checks that the Brother (scripts/brother.gd) follows
## someone who moves: that he walks after a walker, runs after one who gets away,
## and stops short of him, facing him, when he stands still.
##
## godot --headless --path . --fixed-fps 60 --script tools/brother_follow_test.gd
##
## Prints a line for each thing checked and ends PASS or FAIL (exit code 1).

var brother: CharacterBody3D
var leader: Node3D
var failed := false
var top_speed := 0.0
var nearest := INF


func _initialize() -> void:
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400, 2, 400)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	ground.add_child(collider)
	ground.position = Vector3(0, -1, 0)
	root.add_child(ground)

	leader = Node3D.new()
	root.add_child(leader)
	leader.position = Vector3(1.0, 0, 0)

	# (loaded by path, so this works before the editor has learnt the class's name)
	brother = load("res://scripts/brother.gd").new()
	brother.position = Vector3(0, 0.02, 0)
	root.add_child(brother)
	brother.follow(leader)
	run.call_deferred()


func check(what: String, ok: bool, detail := "") -> void:
	print("  ", "ok  " if ok else "BAD ", what, "  ", detail)
	failed = failed or not ok


func apart() -> float:
	var to := leader.global_position - brother.global_position
	return Vector2(to.x, to.z).length()


func speed() -> float:
	return Vector2(brother.velocity.x, brother.velocity.z).length()


## Moves the leader at `velocity` for `seconds`, the brother doing as he will.
func lead(velocity: Vector3, seconds: float) -> void:
	top_speed = 0.0
	for i in int(seconds * 60.0):
		leader.global_position += velocity / 60.0
		await physics_frame
		await process_frame
		top_speed = maxf(top_speed, speed())
		nearest = minf(nearest, apart())


func run() -> void:
	await lead(Vector3.ZERO, 1.0)
	check("stands by someone already beside him", speed() < 0.05 and not brother.following, "%.2f m apart" % apart())

	# The leader walks off at the boy's walking pace.
	await lead(Vector3(1.6, 0, 0), 8.0)
	check("walks after a walker", top_speed > 1.0 and top_speed <= brother.walk_speed + 0.05, "top speed %.2f m/s" % top_speed)
	check("keeps up with him", apart() < brother.slack + 0.5, "%.2f m apart" % apart())

	# ...then sprints away, and round a corner.
	await lead(Vector3(5.6, 0, 0), 2.5)
	await lead(Vector3(0, 0, 5.6), 2.5)
	check("runs after one who gets away", top_speed > brother.walk_speed + 1.0, "top speed %.2f m/s" % top_speed)
	check("is not left behind", apart() < brother.far + 2.0, "%.2f m apart" % apart())

	# ...and stops.
	await lead(Vector3.ZERO, 5.0)
	var to: Vector3 = leader.global_position - brother.global_position
	var turned := absf(angle_difference(brother.facing_yaw, atan2(to.x, to.z)))
	check("comes up and stops", speed() < 0.05 and not brother.following, "speed %.2f m/s" % speed())
	check("stops a few paces short", apart() > 1.2 and apart() <= brother.near + 0.05, "%.2f m apart" % apart())
	check("faces him", turned < 0.15, "%.2f rad off" % turned)
	check("never walked into him", nearest > 0.8, "nearest %.2f m" % nearest)
	check("is still on the ground", absf(brother.global_position.y) < 0.1, "y %.3f" % brother.global_position.y)

	# With nobody to follow he stays put.
	brother.follow(null)
	await lead(Vector3(3, 0, 0), 2.0)
	check("stays when told to follow nobody", speed() < 0.05)

	print("FAIL" if failed else "PASS")
	quit(1 if failed else 0)
