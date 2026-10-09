class_name Camel
extends CharacterBody3D
## A dromedary: the one-humped camel of Egypt.
##
## Left alone it stands about, shifting its weight and chewing the cud, wanders
## a little way from where it was put (`roam`), puts its head down to browse,
## and when it has been on its feet long enough (`rest_after`) kneels, couches
## and rests for a while (`rest_for`), dozing if nothing is near. It turns its
## head to the boy when he comes within `notice_distance`. Anything in the
## group `pursuers` that comes within `fear_distance` it shies from: up on its
## feet, groaning, and away from it, head high.
##
## Tethered (`tether`, a place, and `tether_length`) it does all of that
## within reach of the peg, and a rope runs from its halter to it.
##
## `follow(who)` has it led: it walks after whoever has its rope, at their
## pace up to a walk, hurrying only when it is left behind. If `who` is
## another camel it goes in a string, nose to that camel's tail, which is how
## a caravan is made: lead the first, and have each of the others follow the
## one in front.
##
## It is not ridden yet. Where riding joins on: `seat()` is where a rider
## sits (on the hump, in the saddle if it has one, and it goes with every roll
## of its walk), `rider` is who is up there, and `mount()` and `dismount()`
## are the two calls a rider would make. They do nothing yet.
##
## Everything it needs (collider, model, voice) is made here, so `Camel.new()`
## is a complete camel. Its voice is recordings of a camel (audio/camels/, and
## CREDITS.md there for where they came from). There are few of them, and it
## uses them sparingly; without them, or with `voice` off, it is silent.

## It opened its mouth to complain.
signal voiced

## How it is holding itself. The rig (CamelRig) works out the rest.
enum Posture { UP, COUCH }
enum State { STAND, WANDER, BROWSE, REST, FOLLOW, SHY }

## Its tack: a riding saddle on a blanket, a rope halter, and packs. Set before
## it enters the tree, or call `dress()` after changing any. A camel that is
## tethered or led is given its halter whether it was asked for or not.
@export var saddled := false
@export var haltered := false
@export var packed := false
## It starts couched, and stays so for `rest_for`.
@export var couched := false
@export var walk_speed := 1.2
@export var pace_speed := 3.2
@export var run_speed := 6.2
@export var acceleration := 3.5
## How fast it comes round, radians a second.
@export var turn_rate := 1.9
@export var gravity := 24.0
## How far it will stray from where it was put, while nothing is asked of it.
@export var roam := 6.0
## Where it is tethered (Vector3.INF: it is not), and how much rope it has.
@export var tether := Vector3.INF
@export var tether_length := 3.5
## How long it is on its feet before it couches to rest, and how long it rests (seconds).
@export var rest_after := 45.0
@export var rest_for := 35.0
## It looks at the boy when he is nearer than this (m), and shies from a pursuer nearer than this.
@export var notice_distance := 7.0
@export var fear_distance := 6.5
## Led, how far behind a person it walks, and how far behind another camel (m, middle to middle).
@export var lead_gap := 2.5
@export var string_gap := 3.4
@export var voice := true

var target: Player
var state := State.STAND
var posture := Posture.UP
## What its head is turned to: a thing, or else a place (Vector3.INF: nothing).
var gaze: Node3D
var gaze_at := Vector3.INF
## Its head is down to feed, on something this far off the ground (m).
var browsing := false
var browse_height := 0.1
var chewing := false
var dozing := false
## How frightened it is, 0..1.
var afraid := 0.0
## Whoever has its rope (see `follow`).
var leader: Node3D
## Whoever is on its back (see `mount`). No one, yet.
var rider: Node3D
## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := 0.0
## Render-rate position; the rig follows this.
var visual_position := Vector3.ZERO
## How much faster than it was recorded its voice is being played, how long what
## it is saying lasts, and how loud that is sixty times a second, 0..1 (empty:
## not known). Its jaw keeps time with these.
var voice_rate := 1.0
var voice_length := 1.0
var voice_envelope := PackedFloat32Array()
## Somewhere to go, and how fast, instead of thinking for itself (the test
## stage uses this). Vector3.INF: nowhere.
var bidden := Vector3.INF
var bidden_speed := 1.2

var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _rig: CamelRig
var _voice: AudioStreamPlayer3D
var _rope: MeshInstance3D
var _peg: MeshInstance3D
var _state_time := 0.0
var _timer := 3.0
## Where it is wandering to, and which way to stand facing while it is not going anywhere.
var _goal := Vector3.ZERO
var _face := Vector3.ZERO
## How long it has been on its feet, how much longer it will chew before it
## swallows, how many more mouthfuls it will take, and how long since anything frightened it.
var _up_time := 0.0
var _chew_left := 0.0
var _chew_pause := 3.0
var _bites := 0
var _calm := 0.0
var _find_timer := 0.0
var _say_timer := 20.0

## The recordings, by kind; which of each kind was played last; and how loud each is through its length.
static var _bank := {}
static var _last_said := {}
static var _envelopes := {}
static var _searched := false

const VOICE_LEVEL := -13.0
const KINDS: Array[String] = ["groan", "grunt"]
const ROPE := Color(0.76, 0.69, 0.52)


func _ready() -> void:
	add_to_group(&"camels")
	# Like the hounds and the cat, it and the player pass through each other; only the world stops it.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(42.0)

	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.radius
	add_child(collider)

	_load_voice()
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 9.0
	_voice.max_distance = 60.0
	_voice.volume_db = VOICE_LEVEL
	_voice.max_db = 0.0
	_voice.position.y = 2.0
	add_child(_voice)

	if tether != Vector3.INF:
		haltered = true
	if couched:
		posture = Posture.COUCH
		state = State.REST
	_rig = CamelRig.new()
	_rig.low_poly = low_poly
	_rig.saddled = saddled
	_rig.haltered = haltered
	_rig.packed = packed
	add_child(_rig)
	_rig.top_level = true

	_rope = MeshInstance3D.new()
	_rope.mesh = ImmediateMesh.new()
	_rope.material_override = Toon.surface(ROPE)
	_rope.top_level = true
	add_child(_rope)
	facing_yaw = global_rotation.y
	_spawn = global_transform
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position
	_timer = randf_range(2.0, 6.0)
	_say_timer = randf_range(15.0, 50.0)
	_up_time = randf_range(0.0, rest_after * 0.5)
	_chew_left = randf_range(4.0, 12.0)


## Shows the tack it is wearing (`saddled`, `haltered`, `packed`), after any of them is changed.
func dress() -> void:
	_rig.saddled = saddled
	_rig.haltered = haltered
	_rig.packed = packed
	_rig.dress()


## Has it led by `who` (null: let go). It walks after them on its rope; after
## another camel, in a string behind it.
func follow(who: Node3D) -> void:
	leader = who
	if who:
		haltered = true
		state = State.FOLLOW
		_state_time = 0.0
		if posture == Posture.COUCH:
			_say("groan")
		posture = Posture.UP
	elif state == State.FOLLOW:
		_stand()
	if _rig:
		dress()


## Where a rider sits, in the world: on top of its hump, facing the way it faces.
func seat() -> Transform3D:
	return _rig.seat()


## Riding is not made yet. When it is: this is where `who` gets up (it must be
## couched to be got onto: `posture`), is set as `rider`, and is thereafter put
## at `seat()` every frame; and `leader` gives way to the rider's own steering.
func mount(_who: Node3D) -> bool:
	return false


func dismount() -> void:
	rider = null


## How far down it is: 0 on its feet, 1 couched.
func couch() -> float:
	return _rig.couch()


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var want := _think(delta)
	# It cannot go anywhere until it is on its feet.
	if posture == Posture.COUCH or _rig.couch() > 0.0:
		want = Vector3.ZERO
	want = _held(want)
	var speed := want.length()
	if speed > 0.05:
		# It goes the way it is facing, and comes round to where it is going as it goes: slowly, if that is far round.
		var off := angle_difference(facing_yaw, atan2(want.x, want.z))
		facing_yaw += clampf(off, -turn_rate * delta, turn_rate * delta)
		want = Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)) * speed * clampf(1.3 - absf(off), 0.12, 1.0)
	elif _face.length_squared() > 0.01 and _rig.couch() <= 0.0:
		var off := angle_difference(facing_yaw, atan2(_face.x, _face.z))
		if absf(off) > 0.5:
			facing_yaw += clampf(off, -turn_rate * 0.5 * delta, turn_rate * 0.5 * delta)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	if global_position.y < -40.0:
		global_transform = _spawn
		velocity = Vector3.ZERO
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(_delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)
	_draw_rope()


## What it is about. Returns where it wants to go, and how fast.
func _think(delta: float) -> Vector3:
	_state_time += delta
	_timer -= delta
	_find_timer -= delta
	if target == null and _find_timer <= 0.0:
		_find_timer = 2.0
		var found := get_tree().root.find_children("*", "Player", true, false)
		if not found.is_empty():
			target = found[0]
	gaze = null
	gaze_at = Vector3.INF
	_face = Vector3.ZERO
	if target and target.global_position.distance_to(global_position) < notice_distance:
		gaze = target
	if bidden != Vector3.INF:
		var to := bidden - global_position
		to.y = 0.0
		posture = Posture.UP
		browsing = false
		return to.normalized() * bidden_speed if to.length() > 0.3 else Vector3.ZERO

	var threat := _nearest_threat()
	if threat and state != State.SHY:
		if posture == Posture.COUCH:
			_say("groan")
		state = State.SHY
		_state_time = 0.0
	afraid = move_toward(afraid, 1.0 if state == State.SHY else 0.0, delta * (3.0 if state == State.SHY else 0.4))
	if posture == Posture.UP:
		_up_time += delta
	_mutter(delta)

	match state:
		State.SHY:
			return _shy(delta, threat)
		State.FOLLOW:
			return _led()
		State.WANDER:
			_ruminate(delta, false)
			var to := _goal - global_position
			to.y = 0.0
			if to.length() < 0.5 or _state_time > 20.0:
				if randf() < 0.6:
					_browse()
				else:
					_stand()
				return Vector3.ZERO
			return to.normalized() * walk_speed * 0.85
		State.BROWSE:
			# Head down for a mouthful, up to chew it, and down again.
			if _timer <= 0.0:
				browsing = not browsing
				_timer = randf_range(3.0, 5.5) if browsing else randf_range(2.5, 4.0)
				if browsing:
					_bites -= 1
					if _bites < 0:
						browsing = false
						_stand()
			chewing = not browsing
		State.REST:
			posture = Posture.COUCH
			_ruminate(delta, true)
			# It does not doze with him standing over it.
			dozing = _state_time > 14.0 and gaze == null and not chewing
			if _state_time > rest_for:
				_say("grunt")
				_up_time = 0.0
				_stand()
		_:
			_ruminate(delta, true)
			if gaze:
				_face = gaze.global_position - global_position
			if _up_time > rest_after and gaze == null:
				state = State.REST
				_state_time = 0.0
				browsing = false
				if randf() < 0.5:
					_say("grunt")
			elif _timer <= 0.0:
				if randf() < 0.55 and _pick_goal():
					state = State.WANDER
					_state_time = 0.0
					chewing = false
				else:
					_browse()
	return Vector3.ZERO


func _stand() -> void:
	state = State.STAND
	_state_time = 0.0
	_timer = randf_range(4.0, 10.0)
	posture = Posture.UP
	browsing = false
	dozing = false


func _browse() -> void:
	state = State.BROWSE
	_state_time = 0.0
	_bites = randi_range(1, 3)
	browsing = true
	_timer = randf_range(3.0, 5.5)
	# Something to eat within reach of where it stands (anything in the group `fodder`), or else what grows at its feet.
	browse_height = 0.1
	for plant: Node in get_tree().get_nodes_in_group(&"fodder"):
		var bush := plant as Node3D
		if bush and bush.global_position.distance_to(global_position) < 2.6:
			browse_height = clampf(bush.global_position.y - global_position.y + 0.6, 0.1, 2.4)
			_face = bush.global_position - global_position
			gaze_at = bush.global_position


## The cud: it chews for a while, swallows, waits, and brings up the next.
func _ruminate(delta: float, may: bool) -> void:
	_chew_left -= delta
	if _chew_left <= -_chew_pause:
		_chew_left = randf_range(9.0, 22.0)
		_chew_pause = randf_range(2.0, 5.0)
	chewing = may and _chew_left > 0.0 and not dozing


## Somewhere to wander to: within `roam` of where it was put, within reach of its tether, with ground under it.
func _pick_goal() -> bool:
	for attempt in 6:
		var away := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(1.5, maxf(roam, 1.5))
		var goal := _spawn.origin + away
		if tether != Vector3.INF:
			var off := goal - tether
			off.y = 0.0
			goal = tether + off.limit_length(maxf(tether_length - 1.2, 0.5))
		goal.y = global_position.y
		if goal.distance_to(global_position) > 1.2 and _ground_under(goal):
			_goal = goal
			return true
	return false


## Frightened: up, and away from it, with its head high; it settles when it has been left alone a while.
func _shy(delta: float, threat: Node3D) -> Vector3:
	posture = Posture.UP
	browsing = false
	chewing = false
	dozing = false
	if threat == null:
		_calm += delta
		if _calm > 3.0:
			_up_time = minf(_up_time, rest_after * 0.5)
			_stand()
		return Vector3.ZERO
	_calm = 0.0
	gaze = threat
	var away := global_position - threat.global_position
	away.y = 0.0
	var distance := away.length()
	_face = -away
	if distance > fear_distance * 0.9:
		return Vector3.ZERO
	return away.normalized() * (run_speed if distance < 2.5 else pace_speed)


## Led: after whoever has its rope, no faster than a walk unless it has been left behind.
func _led() -> Vector3:
	if not is_instance_valid(leader):
		leader = null
		_stand()
		return Vector3.ZERO
	posture = Posture.UP
	browsing = false
	_ruminate(0.0, false)
	var to := leader.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var gap := string_gap if leader is Camel else lead_gap
	_face = to
	if gaze == null:
		gaze = leader
	if distance < gap + 0.15:
		return Vector3.ZERO
	if distance > gap + 5.0:
		return to.normalized() * pace_speed
	return to.normalized() * minf((distance - gap) * 1.4 + 0.25, walk_speed * 1.25)


## What its tether and the ground allow of where it wants to go.
func _held(want: Vector3) -> Vector3:
	if tether != Vector3.INF:
		var off := global_position - tether
		off.y = 0.0
		var out := off.length()
		if out > tether_length - 0.9:
			# At the end of its rope: nothing of what it wants that would take it further, and back if it is past it.
			var along := off / maxf(out, 0.01)
			want -= along * maxf(want.dot(along), 0.0)
			if out > tether_length - 0.6:
				want -= along * walk_speed * clampf((out - tether_length + 0.6) * 2.0, 0.0, 1.0)
	if want.length_squared() > 0.01 and not _ground_under(global_position + want.normalized() * 1.4):
		return Vector3.ZERO
	return want


func _ground_under(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.0, point + Vector3.DOWN * 1.6, 1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The nearest thing that hunts, if it is near enough to matter.
func _nearest_threat() -> Node3D:
	var nearest := fear_distance
	var found: Node3D = null
	for thing: Node in get_tree().get_nodes_in_group(&"pursuers"):
		var other := thing as Node3D
		if other == null:
			continue
		var distance := other.global_position.distance_to(global_position)
		if distance < nearest:
			nearest = distance
			found = other
	return found


## The rope: from its halter to whoever leads it, or to its peg. It hangs in a
## curve, lies along the ground where it would go under it, and is drawn only
## while there is something at the other end of it.
func _draw_rope() -> void:
	var mesh := _rope.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var end := Vector3.INF
	var length := 0.0
	if state == State.FOLLOW and is_instance_valid(leader):
		if leader is Camel:
			end = (leader as Camel)._rig.hitch_point()
			length = string_gap - 1.6
		else:
			end = leader.global_position + Vector3.UP * 0.62
			length = lead_gap - 0.9
	elif tether != Vector3.INF:
		end = tether + Vector3.UP * 0.3
		length = tether_length
		if not haltered:
			haltered = true
			dress()
	_stake()
	var held := end != Vector3.INF and haltered
	if _rig.lead_stowed == held:
		_rig.lead_stowed = not held
		_rig.dress()
	if not held:
		return
	var from := _rig.halter_point()
	var span := from.distance_to(end)
	var slack := sqrt(maxf(length * length - span * span, 0.0)) * 0.55
	var floor_height := visual_position.y + 0.025
	var points: Array[Vector3] = []
	for i in 13:
		var t := i / 12.0
		var at := from.lerp(end, t) + Vector3.DOWN * slack * 4.0 * t * (1.0 - t)
		at.y = maxf(at.y, minf(floor_height, minf(from.y, end.y)))
		points.append(at)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var along := (points[i + 1] - points[i]).normalized()
		var side := along.cross(Vector3.UP)
		side = side.normalized() if side.length_squared() > 0.001 else Vector3.RIGHT
		var up := side.cross(along)
		for k in 5:
			var a := TAU * k / 5.0
			var b := TAU * (k + 1) / 5.0
			var n0 := side * cos(a) + up * sin(a)
			var n1 := side * cos(b) + up * sin(b)
			for corner: Array in [[points[i], n0], [points[i + 1], n0], [points[i + 1], n1], [points[i], n0], [points[i + 1], n1], [points[i], n1]]:
				mesh.surface_set_normal(corner[1])
				mesh.surface_add_vertex(corner[0] + corner[1] * 0.012)
	mesh.surface_end()


## The peg it is tethered to: there while it is tethered, wherever that is.
func _stake() -> void:
	if tether == Vector3.INF:
		if _peg:
			_peg.visible = false
		return
	if _peg == null:
		var stake := CylinderMesh.new()
		stake.top_radius = 0.03
		stake.bottom_radius = 0.02
		stake.height = 0.45
		_peg = MeshInstance3D.new()
		_peg.mesh = stake
		_peg.material_override = Toon.surface(Color(0.44, 0.31, 0.19))
		_peg.top_level = true
		add_child(_peg)
	_peg.visible = true
	_peg.global_position = tether + Vector3.UP * 0.12


## Now and then, for no reason, a grunt.
func _mutter(delta: float) -> void:
	_say_timer -= delta
	if _say_timer > 0.0:
		return
	_say_timer = randf_range(25.0, 70.0)
	if state != State.SHY and not dozing and randf() < 0.6:
		_say("grunt")


## Plays one of the recordings of a kind, not the one that was played last.
func _say(kind: String) -> void:
	var takes: Array = _bank.get(kind, [])
	if takes.is_empty() or not voice or _voice == null or _voice.playing:
		return
	var pick := randi() % takes.size()
	if takes.size() > 1 and pick == _last_said.get(kind, -1):
		pick = (pick + 1 + randi() % (takes.size() - 1)) % takes.size()
	_last_said[kind] = pick
	var stream: AudioStream = takes[pick]
	voice_rate = randf_range(0.9, 1.08)
	voice_length = stream.get_length()
	voice_envelope = _envelopes.get(stream, PackedFloat32Array())
	_voice.stream = stream
	_voice.pitch_scale = voice_rate
	_voice.volume_db = VOICE_LEVEL + randf_range(-2.0, 1.0)
	_voice.play()
	_say_timer = maxf(_say_timer, 12.0)
	voiced.emit()


## Finds the recordings (audio/camels/<kind>_<number>.wav), and measures how
## loud each is through its length. Without them it has no voice.
static func _load_voice() -> void:
	if _searched:
		return
	_searched = true
	for kind in KINDS:
		var takes: Array = []
		for number in range(1, 20):
			var path := "res://audio/camels/%s_%d.wav" % [kind, number]
			if not ResourceLoader.exists(path):
				break
			var stream := load(path) as AudioStream
			if stream == null:
				break
			takes.append(stream)
			_envelopes[stream] = Hound._loudness(stream as AudioStreamWAV)
		if not takes.is_empty():
			_bank[kind] = takes
