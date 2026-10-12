class_name GateGuardian
extends StaticBody3D
## A keeper of one of the gates of the underworld: a demon seated on a block,
## wrapped like a mummy (or in a kilt), with the head of a beast and a long
## knife upright in each fist. It breathes, its head follows him, and its
## knives twitch when he comes near.
##
## It keeps a gateway, which is `gate_at` metres to its left (0: it sits in the
## gateway itself). When he steps onto the threshold, or comes up to it and
## acts (it is in the group `workable`), it asks its name: three names come up
## in signs (`GuardianPanel`), its own and two that are not.
##
##   - The right name: it bows its head, lowers its knives, and is ON, for
##     good. It is on or off as a pressure plate is (`changed`), so a door, a
##     bridge or anything else is linked to it in the level editor.
##   - A wrong name: it rises and strikes, and he is `caught` (wired as the
##     mummy's is). Then three names are dealt afresh.
##   - "Step back": nothing is said, and nothing happens.
##
## Which names come up is settled by `seed` and by how many wrong answers it
## has had, never by the clock: a level is the same every time. The English of
## a name is written under it only if he has found the leaf of the Book of the
## Dead that carries it (`BookPage`), and only under the right one: with the
## leaf he reads the answer, and without it he guesses, one chance in three,
## or tells the signs from a leaf he has read somewhere else.
##
## With `bars_way` it is its own gate: two great knives are crossed in the
## gateway and nothing passes until it is named. `GateGuardian.new()` is a
## whole one; its plinth's foot is at this node and it looks along +Z.

signal changed(on: bool)
signal caught
## It has asked (the names are up).
signal asked

enum Dress { WRAPPINGS, KILT }

## How long a strike takes: until the knives come down, and until it is seated again.
const STRIKE_LANDS := 0.5
const STRIKE_OVER := 2.3
## Where its hips are, seated and risen, and how long its thighs and shins are.
const SEATED := Vector3(0.0, 0.87, -0.15)
const RISEN := Vector3(0.0, 1.14, 0.16)
const ANKLE := Vector3(0.0, 0.33, 0.36)
const THIGH := 0.48
const SHIN := 0.54

## Which keeper it is: its place in `BookOfTheDead.NAMES`.
@export var who := 0
## The head it has (`BookOfTheDead.Head`), or -1 for the one that goes with its name.
@export var head := -1
@export var dress := Dress.WRAPPINGS
## A knife in each fist, or only in the right.
@export_range(1, 2) var knives := 2
## It is its own gate: the gateway is barred until it is named.
@export var bars_way := false
## How far to its left the middle of the gateway is (to its right, if less
## than nothing). 0: it sits in the middle of the gateway.
@export var gate_at := 1.9
## How wide and tall the gateway is.
@export var wide := 2.2
@export var tall := 2.6
## Whether stepping onto the threshold is enough to be asked (if not, only the act button).
@export var asks_at_threshold := true
## How big it is: 1 is 1.9 m to the top of its head, seated on its plinth.
@export var size := 1.0
## How near he comes before its knives twitch.
@export var notice := 5.0
## What settles which names it offers (0: where it stands and who it is).
@export var seed := 0
## Whether it has been named.
@export var on := false

## The names it last offered, and how many wrong answers it has had.
var dealt: Array[int] = []
var wrong := 0
## What is on the screen while it asks, if it is asking.
var panel: GuardianPanel

var _figure: Node3D
var _trunk: Node3D
var _head: Node3D
var _thighs: Node3D
var _shins: Node3D
var _arms: Array[Node3D] = []
var _blades: Array[Node3D] = []
var _bars: Array[Node3D] = []
var _bar_shape: CollisionShape3D
var _voice: AudioStreamPlayer3D
var _time := 0.0
var _striking := -1.0
var _struck := false
var _armed := true
var _rise := 0.0
var _lean := 0.0
var _arm := 0.0
var _knife := 0.0
var _bow := 0.0
var _near := 0.0
var _look := Vector2.ZERO
var _open := 0.0
var _starts_on := false

static var _sounds := {}


func _ready() -> void:
	add_to_group(&"interest")
	add_to_group(&"workable")
	add_to_group(&"gate_guardians")
	set_meta(&"surface", "stone")
	_starts_on = on
	who = clampi(who, 0, BookOfTheDead.NAMES.size() - 1)
	_build()
	_voice = AudioStreamPlayer3D.new()
	_voice.position = Vector3(0.0, 1.5, 0.0) * size
	_voice.unit_size = 6.0
	_voice.max_distance = 40.0
	add_child(_voice)
	if on:
		_bow = 0.45
		_knife = 1.45
		_open = 1.0
	_pose(0.0)


## The head it has.
func beast() -> int:
	return head if head >= 0 and head < BookOfTheDead.HEADS.size() else int(BookOfTheDead.NAMES[who]["head"])


## The middle of its gateway's threshold, in the world.
func threshold() -> Vector3:
	return global_transform * Vector3(gate_at, 0.0, _line())


## Come up to with the act button: it asks its name.
func work(_by: Node3D = null) -> void:
	challenge()


## Where his hand goes: it is held up before it.
func work_point() -> Vector3:
	return global_transform * (Vector3(0.0, 1.1, 0.75) * size)


## Asks its name: puts the three names up. Says whether it did.
func challenge() -> bool:
	if on or _striking >= 0.0 or is_instance_valid(panel) or not is_inside_tree():
		return false
	var book := BookOfTheDead.of(self)
	dealt = BookOfTheDead.deal(who, _seed(), wrong)
	panel = GuardianPanel.ask(self, dealt, who, book != null and book.has(who), beast())
	if panel == null:
		return false
	_armed = false
	panel.answered.connect(answer)
	_say(&"growl")
	asked.emit()
	return true


## What he says: the place of a name in `BookOfTheDead.NAMES`, or -1 for nothing.
func answer(choice: int) -> void:
	panel = null
	if on or choice < 0:
		return
	if choice == who:
		on = true
		_say(&"yield")
		changed.emit(true)
	else:
		wrong += 1
		_striking = 0.0
		_struck = false
		_say(&"roar")


## As it was when it was made: not named, and its count of wrong answers forgotten.
func reset() -> void:
	wrong = 0
	_striking = -1.0
	_armed = true
	if on != _starts_on:
		on = _starts_on
		changed.emit(on)


func _exit_tree() -> void:
	if is_instance_valid(panel):
		panel.put_away()


func _seed() -> int:
	if seed != 0:
		return seed
	return hash([who, roundi(global_position.x * 2.0), roundi(global_position.y * 2.0), roundi(global_position.z * 2.0)])


# How far behind it the line of its gateway is: it sits with its back to the
# wall beside the opening, or, in the gateway itself, on the line.
func _line() -> float:
	return -0.75 * size if not is_zero_approx(gate_at) else 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	var boy := Nearby.player(get_tree())
	var far := INF
	if boy:
		far = boy.global_position.distance_to(global_position)
		# Whether he stands on the threshold: asked once each time he comes onto it.
		var at := global_transform.affine_inverse() * boy.global_position - Vector3(gate_at, 0.0, _line())
		var reach := 1.2 if not is_zero_approx(gate_at) else 1.7 * size
		var inside := absf(at.x) < wide * 0.5 and absf(at.z) < reach and at.y > -0.6 and at.y < 2.0
		if not inside:
			_armed = true
		elif _armed and asks_at_threshold and not on and _striking < 0.0 and not boy.is_limp:
			challenge()
	# The strike: up off its seat with the knives over its head, and down with them.
	var rise := 0.0
	var lean := 0.0
	var arm := 0.0
	var knife := 0.0
	var quick := 5.0
	if _striking >= 0.0:
		_striking += delta
		quick = 16.0
		if _striking < STRIKE_LANDS - 0.1:
			rise = 1.0
			lean = -0.12
			arm = -2.2
			knife = -0.5
		elif _striking < STRIKE_OVER - 0.8:
			rise = 1.0
			lean = 0.5
			arm = -0.55
			knife = 1.5
			quick = 30.0
		else:
			quick = 3.5
		if not _struck and _striking >= STRIKE_LANDS:
			_struck = true
			_say(&"slash")
			caught.emit()
		if _striking >= STRIKE_OVER:
			_striking = -1.0
	elif on:
		knife = 1.45
		quick = 2.5
	_rise = lerpf(_rise, rise, minf(1.0, delta * quick))
	_lean = lerpf(_lean, lean, minf(1.0, delta * quick))
	_arm = lerpf(_arm, arm, minf(1.0, delta * quick))
	_knife = lerpf(_knife, knife, minf(1.0, delta * quick))
	_bow = move_toward(_bow, 0.45 if on else 0.0, delta * 0.7)
	_near = move_toward(_near, 1.0 if far < notice and not on else 0.0, delta * 2.0)
	_open = move_toward(_open, 1.0 if on else 0.0, delta * 0.8)
	# Its head follows him (not once it has bowed it).
	var look := Vector2.ZERO
	if boy and far < notice * 2.5 and not on:
		var to := _trunk.global_transform.affine_inverse() * (boy.global_position + Vector3.UP * 1.0) - _head.position
		look = Vector2(clampf(atan2(-to.y, Vector2(to.x, to.z).length()), -0.45, 0.6), clampf(atan2(to.x, to.z), -1.15, 1.15))
	_look = _look.lerp(look, minf(1.0, delta * 3.5))
	_pose(delta)


# Sets every part of it where it should be.
func _pose(_delta: float) -> void:
	var breath := sin(_time * 1.5)
	var hip := SEATED.lerp(RISEN, _rise)
	_trunk.position = hip
	_trunk.rotation.x = _lean + breath * 0.008
	# (risen, it turns on him)
	_trunk.rotation.y = _look.y * 0.8 * _rise
	_trunk.scale = Vector3(1.0 + breath * 0.012, 1.0 + breath * 0.008, 1.0 + breath * 0.03)
	# Its legs: the knee is found from where the hip is and where the foot stays.
	var to := ANKLE - hip
	var span := minf(to.length(), THIGH + SHIN - 0.001)
	var along := to.normalized()
	var bend := acos(clampf((THIGH * THIGH + span * span - SHIN * SHIN) / (2.0 * THIGH * span), -1.0, 1.0))
	var forward := Vector3(0.0, along.z, -along.y)
	var knee := hip + (along * cos(bend) + forward * sin(bend)) * THIGH
	_thighs.position = hip
	_thighs.basis = _along((knee - hip).normalized())
	_shins.position = knee
	_shins.basis = _along((ANKLE - knee).normalized())
	_head.rotation = Vector3(_look.x + _bow, _look.y, 0.0)
	# A twitch of the knives: now and then, when he is near.
	var twitch := pow(maxf(sin(_time * 2.3), 0.0), 10.0) * sin(_time * 41.0) * 0.16 * _near
	for n in _arms.size():
		var side := 1.0 if n == 0 else -1.0
		_arms[n].rotation = Vector3(_arm + breath * 0.01, 0.0, -side * 0.12 * clampf(-_arm, 0.0, 1.0))
		_blades[n].rotation = Vector3(_knife + twitch * (1.0 if n == 0 else -0.7), 0.0, side * (0.1 * _near + twitch * 0.5))
	# The knives across the gateway swing up against its sides as it is named.
	for n in _bars.size():
		var side := 1.0 if n == 0 else -1.0
		var crossed := atan2(wide, tall) * 0.92
		_bars[n].rotation.z = -side * lerpf(crossed, 0.0, smoothstep(0.0, 1.0, _open)) + sin(_time * 1.3 + n) * 0.012 * (1.0 - _open)
		_bars[n].position.y = -_open * tall * 0.9
		_bars[n].visible = _open < 0.999
	if _bar_shape and _bar_shape.disabled != (_open > 0.5):
		_bar_shape.set_deferred(&"disabled", _open > 0.5)


# A way of standing a limb that is modelled along +Z so that it points along `way`.
func _along(way: Vector3) -> Basis:
	return Basis(Vector3.RIGHT, way.cross(Vector3.RIGHT).normalized(), way)


func _say(what: StringName) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_voice.stream = _sound(what)
	_voice.pitch_scale = 1.0 / clampf(size, 0.7, 1.5)
	_voice.play()


# --- How it is made ---

# It is put together from the things in the model (`GuardianMesh`): one thing
# to draw for each part of it that moves.
func _build() -> void:
	var kind := beast()
	var worn := "wrapped" if dress == Dress.WRAPPINGS else "kilt"
	_figure = Node3D.new()
	_figure.scale = Vector3.ONE * size
	add_child(_figure)
	# The plinth, the block it sits on, and its feet (which stay where they are).
	_part(_figure, ["plinth", "seat", "feet_" + worn], kind)
	# Thighs and shins, each pair one piece, modelled along +Z from the hip and from the knee.
	_thighs = _part(_figure, ["thighs_" + worn], kind)
	_shins = _part(_figure, ["shins_" + worn], kind)
	# The trunk: from the hips up, and what turns with it (the wig down its back, if its head has one).
	_trunk = _part(_figure, ["trunk_" + worn, "wig"] if GuardianMesh.has_wig(kind) else ["trunk_" + worn], kind)
	_head = _part(_trunk, ["head_" + GuardianMesh.HEADS[kind]])
	_head.position = GuardianMesh.at("neck")
	# Its arms, each hung from the shoulder, and the knife that turns in each fist.
	for side: float in [1.0, -1.0]:
		var which := "left" if side > 0.0 else "right"
		var hung := _part(_trunk, ["arm_%s_%s" % [worn, which]], kind)
		hung.position = GuardianMesh.at("arm_%s_%s" % [worn, which])
		_arms.append(hung)
		var held: Node3D
		if side > 0.0 or knives > 1:
			held = _part(hung, ["knife_" + which])
		else:
			held = Node3D.new()
			hung.add_child(held)
		held.position = GuardianMesh.at("knife_" + which)
		_blades.append(held)
	# What is solid: the plinth, and him on it.
	PuzzleKit.shape(self, Vector3(0.0, 0.125, 0.1) * size, Vector3(1.0, 0.25, 1.2) * size)
	PuzzleKit.shape(self, Vector3(0.0, 1.0, -0.05) * size, Vector3(0.66, 1.5, 0.8) * size)
	if bars_way:
		_build_bars()


# The gateway barred: two great knives crossed in it, each turning on its hilt
# at the foot of one side, and something solid across it. The knife is
# modelled for a gateway of one size, and is made as much bigger or smaller as
# this gateway needs.
func _build_bars() -> void:
	var middle := Vector3(gate_at, 0.0, _line())
	var long := Vector2(wide, tall).length() * 0.98
	for side: float in [1.0, -1.0]:
		var foot := Node3D.new()
		foot.position = middle + Vector3(-side * wide * 0.5, 0.0, 0.0)
		add_child(foot)
		var blade := _part(foot, ["great_knife"])
		blade.scale = Vector3.ONE * (long / GuardianMesh.tall("great_knife"))
		# (one lies in front of the other where they cross)
		blade.position.z = 0.03 * side
		_bars.append(blade)
	_bar_shape = PuzzleKit.shape(self, middle + Vector3(0.0, tall * 0.5, 0.0), Vector3(wide, tall, 0.3))
	_bar_shape.disabled = on


func _part(under: Node3D, things: Array, kind := -1) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = GuardianMesh.piece(things, kind)
	under.add_child(part)
	return part


# --- Its voice: made here, not recorded ---

# A growl as it asks, a roar as it rises, the knives coming down, and a low note as it gives way.
static func _sound(what: StringName) -> AudioStreamWAV:
	if _sounds.has(what):
		return _sounds[what]
	var rate := 16000
	var long: float = {&"growl": 0.9, &"roar": 0.7, &"slash": 0.3, &"yield": 1.2}.get(what, 0.5)
	var count := int(rate * long)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(what)
	var hiss := 0.0
	var phase := 0.0
	for n in count:
		var t := float(n) / rate
		var part := t / long
		var swell := sin(part * PI)
		var value := 0.0
		hiss = lerpf(hiss, dice.randf_range(-1.0, 1.0), 0.25)
		match what:
			&"growl":
				phase += (58.0 + 10.0 * sin(t * 9.0)) / rate
				value = (fposmod(phase, 1.0) * 2.0 - 1.0) * 0.5 * swell * (0.6 + 0.4 * sin(t * 61.0)) + hiss * 0.2 * swell
			&"roar":
				phase += (95.0 - 40.0 * part + 14.0 * sin(t * 23.0)) / rate
				value = (fposmod(phase, 1.0) * 2.0 - 1.0) * 0.6 * swell * (0.5 + 0.5 * sin(t * 83.0)) + hiss * 0.45 * swell
			&"slash":
				hiss = lerpf(hiss, dice.randf_range(-1.0, 1.0), 0.5 * (1.0 - part) + 0.2)
				value = hiss * pow(1.0 - part, 1.5) * 0.9 + sin(t * TAU * (2600.0 - 900.0 * part)) * 0.15 * pow(1.0 - part, 3.0)
			_:
				value = (sin(t * TAU * 82.0) * 0.5 + sin(t * TAU * 123.0) * 0.3) * pow(1.0 - part, 1.2) * minf(1.0, t * 20.0)
		bytes.encode_s16(n * 2, int(clampf(value, -1.0, 1.0) * 30000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = rate
	made.data = bytes
	_sounds[what] = made
	return made
