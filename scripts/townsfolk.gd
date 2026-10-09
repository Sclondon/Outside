class_name Townsperson
extends Figure
## Somebody in the street: a Figure on the boy's model, turned out at random
## (see CharacterLook.random) and stood up at the size of that look, who idles
## where they are put and now and then strolls somewhere near.
##
## In a level:
##     var someone := Townsperson.new()
##     someone.position = Vector3(4, 0, 2)
##     add_child(someone)
## and for a particular person, before the `add_child`:
##     someone.seed = 7                          # the same person every time
##     someone.sex = CharacterLook.Sex.FEMALE
##     someone.face_kind = "full"                    # one kind of face for a whole street
##     someone.wander = 0.0                      # stands where they are
##     someone.look = CharacterLook.random(3)    # or a look made up beforehand, or by hand
## Like any Figure it walks straight at where it is going and is stopped by the
## world, so give it open ground: it gives up on a stroll it cannot finish.

## Which person this is: the same number is the same person. -1 is anyone.
@export var seed := -1
@export var sex := CharacterLook.Sex.ANY
## The kind of face (one of CharacterLook.FACES, by name), or "" for any.
@export var face_kind := ""
## How far from where they were put they will stroll, in metres. 0: they stand.
@export var wander := 3.5
## How long they stand between strolls, in seconds: (least, most).
@export var linger := Vector2(2.5, 9.0)
## How they are turned out. Left empty, they are made up from `seed` and `sex`.
var look := {}

var _home := Vector3.ZERO
var _wait := 0.0
var _stuck := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if look.is_empty():
		look = CharacterLook.random(seed, sex, face_kind)
	var tall: float = look.get("size", 1.0)
	var broad: float = tall * look.get("build", 1.0)
	size = tall
	height = 1.25 * tall
	radius = minf(0.24 * broad, height * 0.4)
	# (the grown stride out; a child's walk is quicker for its size)
	walk_speed = 1.15 * lerpf(1.0, tall, 0.7)
	run_speed = 4.0 * lerpf(1.0, tall, 0.7)
	looseness = 0.75 if tall < 1.2 else 0.55
	super._ready()
	CharacterLook.apply(rig, look)
	rig.scale = Vector3(broad, tall, broad)
	_rng.seed = hash(seed) if seed >= 0 else randi()
	_home = global_position
	_wait = _rng.randf_range(0.5, linger.y)
	arrived.connect(func() -> void: _wait = _rng.randf_range(linger.x, linger.y))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if wander <= 0.0:
		return
	if is_going():
		# Walked into something: turn it up, and think of somewhere else in a moment.
		_stuck = _stuck + delta if Vector2(velocity.x, velocity.z).length() < 0.15 else 0.0
		if _stuck > 0.8:
			stop()
			_wait = _rng.randf_range(0.5, 2.0)
		return
	_wait -= delta
	if _wait <= 0.0:
		_stuck = 0.0
		var away := _rng.randf_range(0.3, 1.0) * wander
		var angle := _rng.randf() * TAU
		go_to(_home + Vector3(sin(angle) * away, 0.0, cos(angle) * away))
