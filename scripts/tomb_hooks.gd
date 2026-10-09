class_name TombHooks
extends RefCounted
## Where a tomb takes what others are making, if it is there: scarab swarms,
## cobwebs, jackal mummies, inscriptions in real hieroglyphs, and the notebook.
## Nothing here names any of their classes outright: each is looked for by its
## file (`ResourceLoader.exists`) and used only by the properties it turns out
## to have, and where it is missing a plain stand-in is made and a `Marker3D`
## is left in the group `tomb_hooks` (with the metadata `hook` and what the
## hook was given), so that the place is there to be found when it arrives.
##
##   scarabs      res://scripts/scarab_swarm.gd   a nest in a dark room: `ScarabSwarm.new()`, put at the
##                                                foot of the back wall. Expects it to keep off fire by
##                                                itself (`fears_fire`), and to say `caught`; `reset()`
##                                                is called when he starts the room again.
##   cobweb       res://scripts/cobweb.gd         across a crawl and across a loft: `.new()`, at the middle
##                                                of the opening, facing along the passage; given `size`
##                                                (Vector2: across, high) if it has one.
##   jackal       res://scripts/jackal_mummy.gd   a guard at the burial chamber, in place of nothing: `.new()`,
##                (or `Mummy.Kind.JACKAL`)        given `target`; expects `wake()`, `reset()`, `caught`.
##   inscription  res://scripts/inscription.gd    over each locked door: `.new()`, on the back wall, facing
##                                                +Z; given `meaning` (the hint in English), `text` (the
##                                                same) and `hint` (its key in HINTS) where it has them.
##   notebook     res://scripts/notebook.gd       `translation(signs, meaning, where)` when he has stood
##                                                under an inscription, `note(text, heading)` for a result.

## What is written over a door, by what opens it (`TombPlan.Link.hint`).
const HINTS := {
	"weight": "Stone answers to stone: lay a weight where the floor gives.",
	"weight_from_afar": "The weight this floor wants lies in the room behind you.",
	"two_weights": "Two gifts open the way: a stone for the floor, a jar for the table.",
	"lever_above": "The seal is over your head. Leap, and take hold.",
	"lever_below": "The seal lies at the foot of the well.",
	"fire": "Bring fire to the cold bowl, and the dark will give way.",
	"hook": "No one leaps the gulf. Cast iron at the ring, and swing.",
	"over_the_wall": "This door opens only from within. Others have come in over it.",
	"treasure": "Take what is here, and what sleeps here wakes.",
}

## What has been read this run and could not be given to a notebook: [meaning, where].
static var unread: Array = []


## A scarab nest. Returns what was made (a swarm, or the marker left for one).
static func scarabs(parent: Node3D, at: Vector3) -> Node3D:
	var made := _make("res://scripts/scarab_swarm.gd")
	if made == null:
		return _mark(parent, at, "scarabs", {})
	made.position = at
	parent.add_child(made)
	return made


static func cobweb(parent: Node3D, at: Vector3, size: Vector2) -> Node3D:
	var made := _make("res://scripts/cobweb.gd")
	if made == null:
		return _mark(parent, at, "cobweb", {"size": size})
	made.position = at
	made.rotation.y = PI * 0.5
	if &"size" in made:
		made.set(&"size", size)
	parent.add_child(made)
	return made


## A jackal mummy, or null if there is none yet (a marker is left).
static func jackal(parent: Node3D, at: Vector3) -> Node3D:
	var made := _make("res://scripts/jackal_mummy.gd")
	# (asked of the enum as a Dictionary, so that this reads whether or not it has the name yet)
	var kinds: Dictionary = Mummy.Kind
	if made == null and kinds.has("JACKAL"):
		var mummy := Mummy.new()
		mummy.set(&"kind", kinds["JACKAL"])
		made = mummy
	if made == null:
		_mark(parent, at, "jackal", {})
		return null
	made.position = at
	parent.add_child(made)
	return made


## An inscription on the back wall. With none to be had, a panel of plain
## signs is put there, so that there is something over the door to stand under.
static func inscription(parent: Node3D, at: Vector3, hint: String, seed_value: int) -> Node3D:
	var meaning: String = HINTS.get(hint, "")
	var made := _make("res://scripts/inscription.gd")
	if made == null:
		var mark := _mark(parent, at, "inscription", {"hint": hint, "meaning": meaning})
		mark.add_child(_plain_signs(seed_value))
		return mark
	for key: StringName in [&"meaning", &"text", &"translation"]:
		if key in made:
			made.set(key, meaning)
	if &"hint" in made:
		made.set(&"hint", hint)
	made.position = at
	parent.add_child(made)
	return made


## He has stood under an inscription: its meaning goes into the notebook, if there is one.
static func read(hint: String, where: String) -> String:
	var meaning: String = HINTS.get(hint, "")
	if meaning == "":
		return ""
	var notebook := _script("res://scripts/notebook.gd")
	if notebook and notebook.has_method(&"translation"):
		notebook.call(&"translation", hint, meaning, where)
	else:
		for entry: Array in unread:
			if entry[0] == meaning:
				return meaning
		unread.append([meaning, where])
	return meaning


## A line for the journal (a finished tomb).
static func note(text: String, heading: String) -> void:
	var notebook := _script("res://scripts/notebook.gd")
	if notebook and notebook.has_method(&"note"):
		notebook.call(&"note", text, heading)


static func _script(path: String) -> Script:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Script


static func _make(path: String) -> Node3D:
	var script := _script(path)
	if script == null or not script.can_instantiate():
		return null
	return script.new() as Node3D


static func _mark(parent: Node3D, at: Vector3, hook: String, given: Dictionary) -> Marker3D:
	var mark := Marker3D.new()
	mark.name = "Hook_" + hook
	mark.position = at
	mark.add_to_group(&"tomb_hooks")
	mark.set_meta(&"hook", hook)
	mark.set_meta(&"given", given)
	parent.add_child(mark)
	return mark


# A panel of made-up signs in three rows, cut into the wall and picked out in dark paint.
static func _plain_signs(seed_value: int) -> Node3D:
	var rng := TombRandom.new(seed_value)
	var signs := MultiMesh.new()
	signs.transform_format = MultiMesh.TRANSFORM_3D
	signs.mesh = BoxMesh.new()
	signs.instance_count = 18
	for i in 18:
		var size := Vector3(rng.spread(0.08, 0.26), rng.spread(0.1, 0.24), 0.03)
		var at := Vector3(-0.9 + (i % 6) * 0.36 + rng.spread(-0.04, 0.04), 0.3 - (i / 6) * 0.32, 0.0)
		signs.set_instance_transform(i, Transform3D(Basis.from_scale(size), at))
	var panel := MultiMeshInstance3D.new()
	panel.multimesh = signs
	panel.material_override = Toon.surface(Color(0.62, 0.2, 0.12))
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return panel
