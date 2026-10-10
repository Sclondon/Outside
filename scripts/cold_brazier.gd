class_name ColdBrazier
extends Node3D
## A brazier that is not burning: the same bowl on its stand as any other
## (`props/brazier.tscn`), cold. A burning torch brought near it (a
## `HandTorch`, or anything in the group `torches` that is `lit`) lights it,
## and it stays lit and is on (`changed`): so it works a door, or anything
## else a pressure plate works. Once it burns, a torch that has gone out is
## lit again at it. Its foot is at this node. `ColdBrazier.new()` is a whole one.
##
## A tomb's braziers (`TombLevel`) are lit the same way, by `torch_near` and `kindle`.

signal changed(on: bool)

## How near the bowl a burning torch must be brought.
const WITHIN := 1.8
## How high the bowl is.
const BOWL := 0.9

## Whether it is burning.
@export var on := false

## Its fire (none while it is cold).
var fire: Fire

var _bowl: Node3D
var _starts_on := false


## Whether a burning torch is within `within` of a place.
static func torch_near(tree: SceneTree, at: Vector3, within: float) -> bool:
	for torch: Node3D in tree.get_nodes_in_group(&"torches"):
		if torch.get(&"lit") and torch.global_position.distance_to(at) < within:
			return true
	return false


## Lights a brazier (the prop): a fire where its flame goes.
static func kindle(bowl: Node3D) -> Fire:
	var flame := bowl.find_child("Flame*", true, false) as Node3D
	var made := Fire.brazier()
	(flame if flame else bowl).add_child(made)
	return made


func _ready() -> void:
	add_to_group(&"interest")
	_starts_on = on
	_bowl = (load("res://props/brazier.tscn") as PackedScene).instantiate() as Node3D
	add_child(_bowl)
	if on:
		fire = kindle(_bowl)


## As it was when it was made.
func reset() -> void:
	_switch(_starts_on)


func _switch(to: bool) -> void:
	if to == on:
		return
	on = to
	if on and fire == null:
		fire = kindle(_bowl)
	elif not on and fire:
		fire.queue_free()
		fire = null
	changed.emit(on)


func _physics_process(_delta: float) -> void:
	var bowl := global_position + Vector3.UP * BOWL
	if not on:
		# (a torch brought to it, or oil burning at its foot)
		if torch_near(get_tree(), bowl, WITHIN) or Oil.is_burning_at(global_position, 0.8):
			_switch(true)
		return
	# (and a torch that is out takes fire from it)
	for torch: Node3D in get_tree().get_nodes_in_group(&"torches"):
		if torch is HandTorch and not (torch as HandTorch).lit and torch.global_position.distance_to(bowl) < WITHIN * 0.6:
			(torch as HandTorch).lit = true
