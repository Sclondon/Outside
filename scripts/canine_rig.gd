class_name CanineRig
extends HoundRig
## What the rigs of the mummified jackal (JackalMummyRig) and the hyena
## (HyenaRig) have in common. Neither is used by itself.
##
## Both are built on the hound's rig, as the cat's and the camel's are, and use
## what they share with a hound from it unchanged: the three-bone leg solver
## (`_solve_leg`), the path of a paw through a stride (`_foot_cycle`), the
## springs the tail and the ears hang on (`Link`, `_swing`), the reading of
## joints from the skeleton (`_joint`, `_link`, `_rest`), where a dog puts
## itself to sit and to lie (`_measure`), and the curve and easing helpers.
## The hound's `_ready`, `_process` and `_build` are replaced outright by each
## of them; what is here is the part of those that the two would otherwise
## each have to repeat:
##
## - `_build_on`: the model, its skeleton, and a pose node for every bone a
##   hound has.
## - `_stride_of`: where each paw is in a stride whose footfalls, time on the
##   ground, length and lift are given, and what that asks of the body.
## - `_place_legs`: the legs, solved onto those paws.
##
## Whatever it is put under must be a CharacterBody3D.

## What a stride comes to this frame: where each paw should be (in the rig's
## own space) and how its toes are tipped; how hard the fore end, the hind end
## and the left side are bearing down on their legs; how far the body must
## come down for a planted leg to reach both ends of its ground; and which
## paws are on the ground.
class Stride:
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var load_fore := 0.0
	var load_hind := 0.0
	var load_side := 0.0
	var drop := 0.0
	var planted: Array[bool] = []


var _beast: CharacterBody3D
var _model: Node
## How long the forelegs are beside the hind legs' (the hyena's are the longer).
var _fore_size := 1.0


## Instantiates `scene` and reads from its skeleton everything a hound's rig
## reads from a hound's. `hip_height` is how high the hips of the animal it was
## all tuned for stand (the bloodhound's are 0.52 m), which sets `_size`.
## The ears, the tail and the coat are left to whoever calls this.
func _build_on(scene: PackedScene, hip_height := 0.52) -> void:
	_model = scene.instantiate()
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_neck_1 = _joint(_neck, &"neck_1")
	_head = _joint(_neck_1, &"head")
	_jaw = _joint(_head, &"jaw")
	for i in 4:
		var fore := i < 2
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock", "paw"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_paws.append(at[3])
		_lengths.append(Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(at[3])))
		# How it stands, measured the way `_solve_leg` builds a leg.
		var line := (at[3] - at[0]).normalized()
		var pole := BEHIND if fore else AHEAD
		var aside := (pole - line * pole.dot(line)).normalized()
		var normal := aside.cross(line).normalized()
		var last := (at[3] - at[2]).normalized()
		_spans.append(at[0].distance_to(at[3]))
		_bends.append(atan2(last.dot(aside), last.dot(line)))
		_frames.append([
			_frame(normal, (at[1] - at[0]).normalized()).inverse(), _frame(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame(normal, last).inverse(),
		])
	_paw_height = _paws[0].y
	_size = _hips[2].y / hip_height
	_fore_size = (_lengths[0].x + _lengths[0].y + _lengths[0].z) / (_lengths[2].x + _lengths[2].y + _lengths[2].z)


## The tail, as four links each hanging from the one before: how stiff it is at
## its root and at its end, how the swing of each is damped, how heavy it is,
## and how far each may swing from where it is held (radians).
func _hang_tail(stiffness: Vector2, damping: Vector2, gravity: float, limit: float) -> void:
	var from := _pelvis
	var names: Array[String] = ["tail", "tail_1", "tail_2", "tail_3", "tail_end"]
	for i in 4:
		var link := _link(from, names[i], _rest(names[i + 1]))
		link.stiffness = lerpf(stiffness.x, stiffness.y, i / 3.0)
		link.damping = lerpf(damping.x, damping.y, i / 3.0)
		link.gravity = gravity
		link.limit = limit
		_tail.append(link)
		from = link.joint


## Ears that stand: held where they are put, and only quivering.
func _stand_ears() -> void:
	_pricked = true
	for side in 2:
		var suffix := "_l" if side == 0 else "_r"
		var root := _link(_head, "ear" + suffix, _rest("ear_tip" + suffix))
		var flap := _link(root.joint, "ear_tip" + suffix, _rest("ear_end" + suffix))
		for link: Link in [root, flap]:
			link.stiffness = 900.0 if link == root else 520.0
			link.damping = 20.0 if link == root else 11.0
			link.gravity = 0.0
			link.drag = 0.5
			link.limit = 0.5
		_ears[side] = [root, flap]


## Where each paw is in the stride, at `_phase`. `phases`: where in the stride
## each paw lands (fore left, fore right, hind left, hind right). `duty`: the
## share of the stride a fore paw and a hind paw are down. `stride`: its length
## (m). `lift`: how high a fore paw and a hind paw are picked up (m). `middle`:
## how far forward of where they stand the fore and the hind paws' ground is
## (m). `gait`: how much of all this there is, 0 standing to 1. `travel`: how
## much of the pace is going anywhere (turning on the spot it steps without
## reaching). `narrow`: how far the paws come in under it. `rise`: how far the
## whole of it is off the ground (m), which paws in the air go up with.
## `reach`: the furthest a planted paw may travel under it (m, at `_size` 1).
## `cycle`: the path of a paw, as `_foot_cycle` (which it is if none is given).
func _stride_of(phases: Array[float], duty: Vector2, stride: float, lift: Vector2, middle: Vector2, gait: float, travel: float,
		narrow: float, rise: float, reach: float, cycle := Callable()) -> Stride:
	var made := Stride.new()
	for i in 4:
		var fore := i < 2
		var on := duty.x if fore else duty.y
		var span := minf(on * stride, reach * _size) * travel
		var centre := (middle.x if fore else middle.y) * travel
		# (the other side leads in one that goes the other way round)
		var at := fposmod(_phase - phases[i ^ 1 if _mirrored else i], 1.0)
		var up := lift.x if fore else lift.y
		var path: Vector3 = cycle.call(at, on, span * 0.5, up) if cycle.is_valid() else _foot_cycle(at, on, span * 0.5, up)
		var rest := _paws[i]
		# Off the ground, a paw goes up with the rest of it.
		var carried := 0.0
		if at >= on:
			var swing := (at - on) / (1.0 - on)
			carried = clampf(minf(swing, 1.0 - swing) * 6.0, 0.0, 1.0) * maxf(rise, 0.0)
		made.targets.append(Vector3(rest.x * lerpf(1.0, narrow, gait), _paw_height + (path.y + carried) * gait, rest.z + (centre + path.z) * gait))
		made.pitches.append(path.x * gait)
		made.planted.append(at < on)
		if at < on:
			var bearing := sin(PI * at / on)
			if fore:
				made.load_fore += bearing
			else:
				made.load_hind += bearing
			made.load_side += bearing * signf(rest.x)
		# Low enough that a planted leg reaches both ends of its ground.
		var from_hip := rest.z - _hips[i].z + centre * gait
		var furthest := (absf(from_hip) + span * 0.5 * gait) * (1.0 - GLIDE)
		var total := _lengths[i].x + _lengths[i].y + _lengths[i].z - 0.012
		made.drop = maxf(made.drop, _hips[i].y - _paw_height - sqrt(maxf(total * total - furthest * furthest, 0.01)))
	return made


## Solves each leg onto its paw, as the hound's `_pose_legs` does. `fold`: how
## much of a hound's folding up of a leg that is picked up there is (a dead
## thing's legs hardly fold). In the air (`_air`) they are stretched out going
## up and reach for the ground coming down.
func _place_legs(targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3], flat: Array[float], vertical_speed: float, fold := 1.0) -> void:
	var to_body := _body.transform.affine_inverse()
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 4:
		var fore := i < 2
		var rest := _paws[i]
		var stretched := rest + Vector3(0.0, 0.13, 0.24 if fore else -0.26) * _size
		var landing := rest + Vector3(0.0, 0.07 if fore else 0.17, 0.16 if fore else -0.04) * _size
		var target := targets[i].lerp(landing.lerp(stretched, rising), _air)
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var paw := to_body * target
		# The shoulder blade slides over the ribs, and the hip swings, with the leg.
		var under := hip.z + rest.z - _hips[i].z
		hip.z += clampf((paw.z - under) * GLIDE, -0.07, 0.07)
		var lifted := maxf(_air, clampf((target.y - _paw_height) / (0.05 * _size), 0.0, 1.0)) * fold
		_solve_leg(i, hip, paw, to_body.basis * Basis(Vector3.RIGHT, lerpf(pitches[i], 0.5, _air)), to_body.basis * poles[i], to_body.basis * AHEAD,
				flat[i] * (1.0 - _air), lifted)
