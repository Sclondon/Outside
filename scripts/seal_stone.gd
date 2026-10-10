class_name SealStone
extends TombParts.Plate
## A seal stone: a slab in the floor with a square of gold let into it, that
## only he presses, and that stays down once it has been trodden on (unless
## `latches` is turned off). It is the tomb's seal stone (what `TombBuilder`
## makes for a `TombPlan.Switch.LEVER`), for a level laid out by hand: a
## `TombParts.Plate` (`changed`, `pressed`), wired up as any plate is.
## `SealStone.new()` is a whole one.


func _init() -> void:
	latches = true
	span = Vector3(1.1, 0.5, 1.6)


func _ready() -> void:
	super()
	# (blocks and whatever is after him do not press it)
	collision_mask = 2
	PuzzleKit.box(_slab, Vector3(0.0, 0.055, 0.0), Vector3(minf(span.x, span.z) * 0.46, 0.03, minf(span.x, span.z) * 0.46), Toon.gold())


## Up again, as it was when it was made.
func reset() -> void:
	if pressed:
		pressed = false
		changed.emit(false)
