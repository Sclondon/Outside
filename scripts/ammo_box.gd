class_name AmmoBox
extends Area3D
## A box of cartridges. Whoever comes up to it with a gun in his hands (anything
## with a `carried` that is a `Gun`, as the Player has) has the gun's spare
## rounds made up, and an empty gun loaded; a gun put down or thrown against it
## is filled too. The scene is `guns/ammo_box.tscn`.

## A gun was given `count` rounds.
signal taken(gun: Gun, count: int)

## What it holds: only guns that take this are filled (none: any gun).
@export var ammo: StringName = &""
## How many rounds each visit gives (0: the gun's full allowance).
@export var count := 0
## How many times it can be drawn on (-1: without end). Used up, it is shut.
@export var uses := -1

var _look := 0.0
var _lid: Node3D
var _lid_rest := Transform3D.IDENTITY
var _nod := 0.0


func _ready() -> void:
	add_to_group(&"interest")
	# (the world's loose things, and the player)
	collision_mask = 1 | 2
	monitoring = true
	var model := get_node_or_null(^"Model")
	if model:
		Gun.dress(model)
		_lid = model.get_node_or_null(^"Lid")
		if _lid:
			_lid_rest = _lid.transform


func _physics_process(delta: float) -> void:
	if _nod > 0.0:
		# The lid jumps as a hand goes in.
		_nod = maxf(_nod - delta * 3.0, 0.0)
		if _lid:
			_lid.transform = _lid_rest * Transform3D(Basis(Vector3.RIGHT, -0.35 * sin(_nod * PI) if uses != 0 else 1.15 * (1.0 - _nod)), Vector3.ZERO)
	if uses == 0:
		return
	_look -= delta
	if _look > 0.0:
		return
	_look = 0.2
	for body in get_overlapping_bodies():
		var gun := body as Gun
		if gun == null and &"carried" in body:
			gun = body.get(&"carried") as Gun
		if gun == null or (ammo != &"" and gun.ammo != ammo):
			continue
		var given := gun.take_ammo(count)
		if given > 0:
			GunFX.of(self).play(&"pickup", global_position, -4.0, 0.95, 1.08, 4.0)
			_nod = 1.0
			if uses > 0:
				uses -= 1
			taken.emit(gun, given)
			if uses == 0:
				break
