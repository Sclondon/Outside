extends SceneTree
## Not part of the game. Checks the guns without drawing anything: each one fires, runs
## dry, clicks, reloads, knocks a target down, pushes a loose thing and smashes a pot;
## the flare flies, strikes and burns out; an ammunition box fills a gun. Prints a line
## for each check and a count of what failed.
## godot --headless --path . --fixed-fps 60 --script tools/gun_test.gd

var stage: Node3D
var failed := 0
var counts := {}


class Holder extends Node3D:
	var gun: Gun
	var carried: RigidBody3D
	var hold := Transform3D.IDENTITY

	func take(what: Gun) -> void:
		gun = what
		carried = what
		gun.freeze = true
		gun.collision_layer = 0
		gun.collision_mask = 0

	func _process(_delta: float) -> void:
		if gun:
			gun.global_transform = hold


## Something that only counts what it is told.
class Dummy extends StaticBody3D:
	var shots: Array = []

	func shot(by: Node3D, at: Vector3, direction: Vector3, damage: float) -> void:
		shots.append([by, at, direction, damage])


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	run.call_deferred()


func check(what: String, passed: bool, note := "") -> void:
	if not passed:
		failed += 1
	print("%s  %s%s" % ["ok  " if passed else "FAIL", what, ("   (" + note + ")") if note != "" else ""])


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func box(at: Vector3, size: Vector3, body: PhysicsBody3D = null) -> PhysicsBody3D:
	if body == null:
		body = StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	stage.add_child(body)
	return body


func count(gun: Gun, what: StringName) -> void:
	counts[what] = 0
	gun.connect(what, func() -> void: counts[what] += 1)


func run() -> void:
	box(Vector3(0, -0.5, 0), Vector3(60, 1, 60))
	for name: String in ["revolver", "rifle", "shotgun", "flare_pistol"]:
		await try(name)
	await try_box()
	print("GUN TEST: %s" % ("all passed" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed else 0)


func try(name: String) -> void:
	print("--- ", name)
	var gun: Gun = load("res://guns/%s.tscn" % name).instantiate()
	stage.add_child(gun)
	check("in the groups throwable, interest, guns", gun.is_in_group(&"throwable") and gun.is_in_group(&"interest") and gun.is_in_group(&"guns"))
	var holder := Holder.new()
	stage.add_child(holder)
	# Fired along +X, a metre and a bit up.
	holder.hold = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 1.2, 0))
	holder.take(gun)
	await frames(2)
	var out := gun.muzzle()
	check("muzzle ahead of the grip, along -Z of the gun", (out.origin - gun.global_position).dot(Vector3.RIGHT) > 0.1 and (-out.basis.z).dot(Vector3.RIGHT) > 0.99,
			"%.3f m ahead, %.3f up" % [(out.origin - gun.global_position).x, (out.origin - gun.global_position).y])
	if gun.two_handed:
		var support := gun.support_point() - gun.global_position
		check("support point on the fore-end", support.x > 0.15 and support.x < 0.6, "%.2f m ahead of the grip" % support.x)
	for what: StringName in [&"fired", &"cycled", &"reloaded", &"dry_fired", &"reload_started"]:
		count(gun, what)

	# What it is shot at: a thing that counts, eight metres off.
	var dummy := Dummy.new()
	box(Vector3(8.5, 1.5, 0), Vector3(1, 3, 6), dummy)
	await frames(2)
	var capacity := gun.capacity
	var shots := 0
	var refused_while_cycling := false
	for i in capacity:
		if i == 0:
			check("can_fire with %d in it" % gun.rounds, gun.can_fire())
		if gun.fire(holder, Vector3.RIGHT):
			shots += 1
		if i == 0:
			refused_while_cycling = not gun.fire(holder, Vector3.RIGHT) and gun.state == Gun.State.CYCLING
		await frames(int(gun.cycle_time * 60.0) + 3)
	check("fired %d of %d" % [shots, capacity], shots == capacity and counts[&"fired"] == capacity)
	check("refused while cycling", refused_while_cycling)
	check("cycled after each", counts[&"cycled"] == capacity, "%d" % counts[&"cycled"])
	check("empty", gun.rounds == 0 and not gun.can_fire())
	if gun.fires_flare:
		var flares := get_nodes_in_group(&"flares")
		check("a flare is burning", flares.size() == 1)
		await frames(90)
		check("the flare struck what it was fired at", dummy.shots.size() == 1 and dummy.shots[0][0] == holder, "%d" % dummy.shots.size())
		if not flares.is_empty():
			var flare: Flare = flares[0]
			check("the flare came to rest on the ground", flare._resting and flare.global_position.y < 0.3, "at %s" % flare.global_position)
			flare.burn_time = 1.0
			await frames(180)
			check("the flare burnt out", not is_instance_valid(flare))
	else:
		check("the target was told once a shot", dummy.shots.size() == capacity and dummy.shots[0][0] == holder and is_equal_approx(dummy.shots[0][3], gun.damage * gun.pellets)
				and (dummy.shots[0][2] as Vector3).dot(Vector3.RIGHT) > 0.9, "%d calls, damage %s" % [dummy.shots.size(), dummy.shots[0][3] if dummy.shots.size() else 0.0])
	# Dry: it clicks, and starts loading itself.
	var reserve := gun.reserve
	check("fire on empty is refused", not gun.fire(holder, Vector3.RIGHT))
	check("it clicked, and began to reload", counts[&"dry_fired"] == 1 and counts[&"reload_started"] == 1 and gun.state == Gun.State.RELOADING)
	check("refused while reloading", not gun.fire(holder, Vector3.RIGHT))
	await frames(int(gun.reload_time * 60.0) + 4)
	check("reloaded", counts[&"reloaded"] == 1 and gun.rounds == capacity and gun.reserve == reserve - capacity and gun.can_fire(),
			"%d in it, %d spare" % [gun.rounds, gun.reserve])
	dummy.free()

	if not gun.fires_flare:
		# A board to knock over.
		var board: ShootTarget = load("res://guns/target_board.tscn").instantiate()
		board.position = Vector3(5, 0, 0)
		board.rotation.y = -PI * 0.5
		stage.add_child(board)
		await frames(3)
		var middle: Vector3 = board.get_node(^"Hinge/Middle").global_position
		holder.hold.origin.y = middle.y - (gun.muzzle().origin.y - gun.global_position.y)
		await frames(2)
		gun.spread = 0.0 if gun.pellets == 1 else gun.spread
		var scores: Array = []
		board.hit.connect(func(_by: Node3D, _at: Vector3, score: float) -> void: scores.append(score))
		gun.fire(holder, Vector3.RIGHT)
		await frames(40)
		check("the board went down", board.is_down and scores.size() == 1 and scores[0] > (0.8 if gun.pellets == 1 else 0.0), "score %s" % [scores])
		await frames(int(board.stays_down * 60.0) + 60)
		check("and stood up again", not board.is_down and absf(board.get_node(^"Hinge").rotation.x) < 0.01)
		board.free()
		holder.hold.origin.y = 1.2
		gun.spread = minf(gun.spread, 1.0)
		await frames(int(gun.cycle_time * 60.0) + 3)

		# A loose rock on a block: it is pushed.
		var stand := box(Vector3(5, 0.5, 0), Vector3(0.5, 1.0, 0.5))
		var rock := RigidBody3D.new()
		rock.mass = 2.0
		var ball := SphereShape3D.new()
		ball.radius = 0.2
		var collider := CollisionShape3D.new()
		collider.shape = ball
		rock.add_child(collider)
		rock.position = Vector3(5, 1.2, 0)
		stage.add_child(rock)
		await frames(30)
		holder.hold.origin.y = rock.global_position.y - (gun.muzzle().origin.y - gun.global_position.y)
		await frames(2)
		gun.fire(holder, Vector3.RIGHT)
		await frames(3)
		check("a loose rock is pushed", rock.linear_velocity.x > 0.5, "%.2f m/s" % rock.linear_velocity.x)
		rock.free()
		await frames(int(gun.cycle_time * 60.0) + 3)

		# A pot: it smashes.
		if gun.rounds == 0:
			gun.reload()
			await frames(int(gun.reload_time * 60.0) + 4)
		var pot: Breakable = load("res://guns/target_pot.tscn").instantiate()
		pot.position = Vector3(5, 1.2, 0)
		stage.add_child(pot)
		await frames(30)
		holder.hold.origin.y = pot.global_position.y - (gun.muzzle().origin.y - gun.global_position.y)
		await frames(2)
		var before := stage.get_child_count()
		gun.fire(holder, Vector3.RIGHT)
		await frames(3)
		check("a pot is smashed", pot.is_broken and stage.get_child_count() > before + 2, "%d pieces" % (stage.get_child_count() - before))
		await frames(int((pot.pieces_last + 2.0) * 60.0))
		check("and its pieces are cleared away", not is_instance_valid(pot) and stage.get_child_count() <= before)
		stand.free()
	gun.free()
	holder.free()
	for fx in get_nodes_in_group(&"gun_fx"):
		fx.free()
	await frames(2)


func try_box() -> void:
	print("--- ammo_box")
	var crate: AmmoBox = load("res://guns/ammo_box.tscn").instantiate()
	crate.position = Vector3(0, 0, 0)
	stage.add_child(crate)
	# Somebody on the player's layer, with a `carried`, walks up with an empty revolver.
	var gun: Gun = load("res://guns/revolver.tscn").instantiate()
	stage.add_child(gun)
	gun.rounds = 0
	gun.reserve = 0
	var body := CharacterBody3D.new()
	body.set_script(load("res://tools/gun_test_carrier.gd"))
	body.collision_layer = 2
	var shape := CapsuleShape3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector3(5, 1.0, 0)
	stage.add_child(body)
	body.set(&"carried", gun)
	gun.freeze = true
	gun.collision_layer = 0
	gun.collision_mask = 0
	await frames(30)
	check("far from the box, nothing", gun.reserve == 0)
	body.position = Vector3(0.5, 1.0, 0)
	gun.global_position = Vector3(0.5, 1.0, 0)
	await frames(30)
	check("at the box it is given rounds, and loads", gun.reserve > 0 and gun.state == Gun.State.RELOADING, "%d spare" % gun.reserve)
	await frames(int(gun.reload_time * 60.0) + 4)
	check("and is full", gun.rounds == gun.capacity and gun.reserve == 18, "%d in it, %d spare" % [gun.rounds, gun.reserve])
