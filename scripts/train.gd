class_name Train
extends Node3D
## A train: a list of vehicles (`consist`: the names of scenes in `props/`
## that are a `TrainVehicle`), coupled buffer to buffer and run along a line.
##
## The node is where the front of the first vehicle stands to begin with, and
## the line runs along its +Z for `distance` metres; or, given a `path`, along
## that Path3D's curve from its beginning. `running` starts and stops it
## (`start`, `stop`, `toggle`): it gathers speed at `acceleration` up to
## `speed`, and slows in time to stop at the end of its run. `run` says what
## happens there: it stays (`ONCE`), it is put back at the beginning to come
## round again (`ROUND`: only while nobody is on it), or the next start takes
## it back the way it came (`THERE_AND_BACK`).
##
## As it goes each vehicle's wheels turn at the rate for the speed, the engine's
## rods work, the bodies rock a little (`TrainVehicle.roll`), and the chimney
## beats smoke four times to a turn of the driving wheels (`TrainSmoke`), with
## steam from the cylinders as it starts and, with `sparks`, sparks at night.
##
## There are two ways of staging a ride on it.
##
## The train really moves (`world_moves` off). Each vehicle is an
## AnimatableBody3D, so the boy standing on one is carried by it. In the air he
## would be left behind (the Player steers its speed over the ground, and on
## jumping would be braked towards a standstill), so while he is aboard and off
## his feet the train carries him itself, each step, by as far as the vehicle
## he left has gone: a jump on a moving train keeps the train's speed, and he
## comes down where he would have on one standing still. The same for a ledge
## he hangs from and the top of a ladder. What stands by the line and is too low
## (a bridge) stops him while the train goes on under him: he is knocked down.
## If he comes down on the ground he is thrown along it.
##
## Or the train stands still and the world goes by (`world_moves` on): the
## wheels turn, the smoke streams back, and `scenery` (a `TrainScenery`: the
## track, the poles, a bridge) is drawn back past it and comes round again.
## Nothing about the boy changes, because he is standing on something that is
## not moving. This is the way to stage a long ride: see PROPS.md.

signal started
signal stopped
## It has come to the end of its run.
signal arrived
## He was aboard while it was going, and is not any more: knocked off, or fallen.
signal lost(who: Player)

enum Run { ONCE, ROUND, THERE_AND_BACK }

## The vehicles, from the front: the names of scenes in `props/`.
@export var consist: PackedStringArray = ["loco", "tender", "carriage", "wagon_open", "van_goods", "van_brake"]
## Its speed, metres a second, and how quickly it gets there and stops.
@export var speed := 8.0
@export var acceleration := 1.2
## Whether it is going (or getting going, or wants to be).
@export var running := false
## How far its run is, metres (with a `path`, 0 is the length of the path).
@export var distance := 80.0
@export var run := Run.ONCE
## The train stands still and the world goes by.
@export var world_moves := false
## A curve to run along instead of a straight line.
@export var path: Path3D
## What goes by when the world moves.
@export var scenery: TrainScenery
## Sparks from the chimney, 0..1.
@export var sparks := 0.0

## How fast it is going now, and how far the front of it is along its run.
var pace := 0.0
var travelled := 0.0
var vehicles: Array[TrainVehicle] = []
## Who rides it. Found, if not given.
var player: Player
## The vehicle he is on, or was last on before he left his feet (none: he is not aboard).
var ridden: TrainVehicle

# Which way it is going along its run: 1 out, -1 back.
var _way := 1.0
# How far behind the front of the train the middle of each vehicle is, and where each was last put.
var _behind: Array[float] = []
var _put: Array[Transform3D] = []
var _moving := false
var _sought := false
# What the Player does on leaving a moving floor, when it is not riding this.
var _on_leave := CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
# Where he was on the vehicle he rides, a step ago.
var _rider_at := Vector3.INF
var _cocks := 0.0
var _plates: Array = []
var _find: Callable


## A train from an item of a level's layout (`LevelLayout.FIELDS`, "train").
## `find` gives the node an id was made into: the plates that start and stop it.
static func from_item(item: Dictionary, find := Callable()) -> Train:
	var train := Train.new()
	var names := PackedStringArray()
	if item.get("engine", true):
		names.append_array(["loco", "tender"])
	for i in int(item.get("carriages", 1)):
		names.append("carriage" if i % 2 == 0 else "carriage_third")
	var goods := ["wagon_open", "van_goods", "wagon_flat", "wagon_finds", "wagon_tank"]
	for i in int(item.get("wagons", 2)):
		names.append(goods[i % goods.size()])
	if item.get("brake", true):
		names.append("van_brake")
	train.consist = names
	train.speed = item.get("speed", 8.0)
	train.distance = item.get("run", 80.0)
	train.run = int(item.get("round", 0)) as Run
	train.world_moves = int(item.get("staging", 0)) == 1
	train.running = item.get("running", false)
	train._plates = item.get("links", [])
	train._find = find
	return train


func _ready() -> void:
	# (before the Player: he is moved by what the train has just done)
	process_physics_priority = -10
	var back := 0.0
	for what in consist:
		var path_to := "res://props/%s.tscn" % what
		if not ResourceLoader.exists(path_to):
			continue
		var vehicle := (load(path_to) as PackedScene).instantiate() as TrainVehicle
		if vehicle == null:
			continue
		back += vehicle.front
		_behind.append(back)
		back += vehicle.rear
		add_child(vehicle)
		vehicles.append(vehicle)
	_put.resize(vehicles.size())
	_place()


## How long it is, over its buffers.
func length() -> float:
	return 0.0 if vehicles.is_empty() else _behind[-1] + vehicles[-1].rear


func start() -> void:
	running = true


func stop() -> void:
	running = false


func toggle() -> void:
	running = not running


## The way it is pointing where its front is.
func forward() -> Vector3:
	return _where(travelled).basis.z


# How long the run is.
func _run_length() -> float:
	if path and path.curve and distance <= 0.0:
		return path.curve.get_baked_length()
	return distance


# Where something `along` metres down the run stands: on the path, or on the line this node points down.
func _where(along: float) -> Transform3D:
	if path == null or path.curve == null or path.curve.point_count < 2:
		return Transform3D(global_basis.orthonormalized(), global_position + global_basis.z.normalized() * along)
	var curve := path.curve
	var whole := curve.get_baked_length()
	var on := clampf(along, 0.0, whole)
	var at := path.global_transform * curve.sample_baked(on, true)
	var ahead := path.global_transform * curve.sample_baked(minf(on + 0.5, whole), true)
	var astern := path.global_transform * curve.sample_baked(maxf(on - 0.5, 0.0), true)
	var heading := (ahead - astern).normalized()
	# (what is not yet on the path, or has run off the end of it, stands on a straight line from there)
	at += heading * (along - on)
	return Transform3D(Basis.looking_at(heading, Vector3.UP, true), at)


func _place() -> void:
	for i in vehicles.size():
		_put[i] = _where(travelled - _behind[i])
		vehicles[i].global_transform = _put[i]


func _physics_process(delta: float) -> void:
	if vehicles.is_empty():
		return
	if player == null and not _sought:
		_sought = true
		player = TrainVehicle._find_player(get_tree().root)
		_join_plates()
	# How fast: up to speed, and down again in time for the end of the run (the world has no end)
	var whole := _run_length()
	var left := whole - travelled if _way > 0.0 else travelled
	var top := speed if running else 0.0
	if running and not world_moves and run != Run.ROUND:
		top = minf(top, sqrt(2.0 * acceleration * 0.8 * maxf(left, 0.0)) + 0.25)
	var was := pace
	pace = move_toward(pace, top, acceleration * delta)
	if pace > 0.0 and was == 0.0:
		started.emit()
	elif pace == 0.0 and was > 0.0:
		stopped.emit()
	var step := pace * delta * _way
	if not world_moves and running and run != Run.ROUND and absf(step) >= left:
		# The end of the run.
		step = left * _way
		pace = 0.0
		running = false
		if run == Run.THERE_AND_BACK:
			_way = -_way
		arrived.emit()
		stopped.emit()
	_set_moving(pace > 0.0 or step != 0.0)
	if player:
		_find_ride()
	if world_moves:
		if scenery:
			scenery.scroll(step, forward())
			var struck := scenery.strikes(player, absf(step)) if player and not player.is_limp else null
			if struck:
				_knock(-forward() * pace * 2.5 + Vector3.UP * 4.0)
	elif step != 0.0:
		travelled += step
		if run == Run.ROUND and travelled > whole and ridden == null:
			travelled -= whole
		var before := _put.duplicate()
		for i in vehicles.size():
			_put[i] = _where(travelled - _behind[i])
			vehicles[i].global_transform = _put[i]
		if ridden:
			var which := vehicles.find(ridden)
			_carry(before[which], _put[which], delta)
	for vehicle in vehicles:
		vehicle.roll(step, pace)
	_smoke(delta, pace - was)


# Vehicles follow the physics only while they move: at rest they are props like any other (the editor moves them about).
func _set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	for vehicle in vehicles:
		vehicle.sync_to_physics = moving and not world_moves


# Which vehicle he is on, if any: the one under his feet; or the one whose
# ladder or edge he has hold of; or, in the air, the one he was on last.
func _find_ride() -> void:
	var was := ridden
	if player.is_limp:
		ridden = null
	elif player.state == Player.State.LADDER:
		for vehicle in vehicles:
			for child in vehicle.get_children():
				if child is Ladder and (child as Ladder).stand(player.global_position.y).distance_to(player.global_position) < 0.8:
					ridden = vehicle
	elif player.state == Player.State.HANG or player.state == Player.State.CLIMB:
		if ridden == null:
			for vehicle in vehicles:
				if vehicle.holds(player.ledge_point):
					ridden = vehicle
	elif player.is_on_floor():
		var from := player.global_position + Vector3.UP * 0.3
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8, 1)
		var under := get_world_3d().direct_space_state.intersect_ray(query)
		var floor_is: Object = under.get("collider")
		# (nothing straight under him: he is on the very edge of something, and still on whatever he was on)
		if floor_is:
			ridden = floor_is as TrainVehicle if floor_is is TrainVehicle and vehicles.has(floor_is) else null
		if was and ridden == null and pace > 3.0:
			# Off it, and onto ground that is going by (or that he is going by): thrown along it.
			_knock((forward() * _way * (-1.0 if world_moves else 1.0)) * pace * 2.5 + Vector3.UP * 3.0)
	if ridden != was:
		_rider_at = Vector3.INF
		for vehicle in vehicles:
			vehicle.passenger = player
		if not world_moves:
			# (leaving its floor he is given nothing: the train carries him, see `_carry`)
			if ridden and was == null:
				_on_leave = player.platform_on_leave
				player.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
			elif ridden == null:
				player.platform_on_leave = _on_leave


# The vehicle he rides has gone from `before` to `after`. On his feet he has
# been taken with it already (it is the floor he stands on). Off them, he is
# taken with it here; and so is whatever of it he has hold of.
func _carry(before: Transform3D, after: Transform3D, delta: float) -> void:
	var here := player.global_position
	var moved := after * (before.affine_inverse() * here) - here
	match player.state:
		Player.State.HANG, Player.State.CLIMB:
			player.global_position += moved
			_shift_holds(moved)
		Player.State.LADDER:
			if player.ladder_off > 0.0:
				player.global_position += moved
				_shift_holds(moved)
		_:
			if not player.is_on_floor():
				var hit := player.move_and_collide(moved)
				if hit and not vehicles.has(hit.get_collider()) and hit.get_remainder().length() > moved.length() * 0.5 and pace > 3.0:
					_knock(Vector3.UP * 2.0 - forward() * _way * 2.0)
			elif pace > 3.0:
				# On his feet, but something that does not move has hold of him: the train is going on from under him.
				var at := after.affine_inverse() * player.global_position
				if _rider_at != Vector3.INF:
					var slipped := (at - _rider_at).z * _way / delta
					var own := player.velocity.dot(forward()) * _way
					if slipped < -pace * 0.6 and own > -pace * 0.3:
						_knock(Vector3.UP * 2.0 - forward() * _way * 2.0)
				_rider_at = at
	if player.state != Player.State.FREE or not player.is_on_floor():
		_rider_at = Vector3.INF


# The places the Player keeps, in the world, for a ledge he hangs from or climbs onto and for getting on and off the top
# of a ladder. They are its own business, and are moved here only because the train has moved what they are places on.
func _shift_holds(by: Vector3) -> void:
	for place: StringName in [&"_ledge_top", &"ledge_point", &"_climb_from", &"_ladder_from", &"_ladder_onto"]:
		var at: Variant = player.get(place)
		if at is Vector3:
			player.set(place, (at as Vector3) + by)
	var grips: Variant = player.get(&"_grips")
	if grips is PackedVector3Array:
		var held := grips as PackedVector3Array
		for i in held.size():
			held[i] += by
		player.set(&"_grips", held)


func _knock(impulse: Vector3) -> void:
	if player == null or player.is_limp:
		return
	player.platform_on_leave = _on_leave
	ridden = null
	player.ragdoll(impulse)
	lost.emit(player)


# Smoke, steam and sparks, by what the engine is doing.
func _smoke(delta: float, gained: float) -> void:
	var engine: TrainVehicle = null
	for vehicle in vehicles:
		if vehicle.smoke:
			engine = vehicle
			break
	if engine == null:
		return
	var smoke := engine.smoke
	var way := forward() * _way
	var driver := 0.72
	for radius: float in engine.wheels.values():
		driver = maxf(driver, radius)
	smoke.beat = 4.0 * pace / (TAU * driver)
	smoke.effort = clampf(0.45 + gained / maxf(delta, 0.001) / maxf(acceleration, 0.01) * 0.55, 0.3, 1.0)
	smoke.carried = Vector3.ZERO if world_moves else way * pace
	smoke.air = -way * pace if world_moves else Vector3.ZERO
	smoke.sparks = sparks
	# Getting away from a stand, the cylinder cocks are open: steam blows out sideways at the front.
	if gained > 0.0 and pace < 2.5:
		_cocks -= delta
		if _cocks <= 0.0:
			_cocks = 0.12
			for side: Array in [["SteamR", 1.0], ["SteamL", -1.0]]:
				var cock := engine.get_node_or_null(side[0] as String) as Node3D
				if cock:
					smoke.steam(cock.global_position, engine.global_basis.x * float(side[1]))


# The plates that start and stop it, in a level made from a layout.
func _join_plates() -> void:
	if not _find.is_valid():
		return
	for id: int in _plates:
		var plate: Node = _find.call(id)
		if plate and plate.has_signal(&"changed"):
			plate.connect(&"changed", func(pressed: bool) -> void:
				if pressed:
					toggle())
