class_name Sphinx
extends StaticBody3D
## A sphinx: a lion of sandstone lying on its base with its forepaws out in
## front, and on its shoulders a king's head in the striped headcloth, a ram's,
## or a falcon's (`head`). It is a statue, solid all over and to be climbed on,
## from one small enough to line an avenue (`size` 2.5, its length in metres)
## to a great one that is a landmark (12 and more). It faces +Z and the middle
## of its foot is at this node. `Sphinx.new()` is a whole one.
##
## IT IS ALIVE WHEN IT WANTS TO BE. Between its forepaws lies a low offering
## slab, and behind that, against its chest, a stele with its riddle on it in
## hieroglyphs. When he comes between the paws its eyes open and glow, its head
## turns a little to look down at him, dust falls from its neck, and the riddle
## comes up in words. The answer is a thing he can carry (`wants`: see `THINGS`),
## put down on the slab or thrown onto it.
##
## - The right thing: the eyes blaze, the thing stays on the slab, and the
##   sphinx is on for good (`changed`, `on`), so it works a door, a bridge, or
##   anything else a pressure plate works. With `opens_itself` the stele sinks
##   into the ground and there is a way in behind it, through its chest and
##   out under its tail.
## - A wrong thing: it growls, shakes its head, and a forepaw sweeps the slab
##   clear: the thing is put down unharmed on the ground a few metres off, to
##   be picked up again. With `wrathful`, the third wrong thing is one too
##   many: it emits `caught`, as a mummy does.
##
## BURIED (`buried`, 0..1) it lies in sand to its neck, asleep, as the Great
## Sphinx lay for most of its life, and the paws and slab cannot be reached.
## While `uncovering` is set (the level sets it while what it is linked to is
## on) the sand goes down, and is gone in `uncover_time` seconds.
##
## `riddle` puts other words in its mouth; `Sphinx.what_is(thing)` is the name
## it knows a thing by.

signal changed(on: bool)
## It has struck him (only if `wrathful`).
signal caught

enum Head { KING, RAM, FALCON }

## What it can ask for: [the name of the thing (see `what_is`), what the level editor calls it, its riddle].
const THINGS: Array = [
	[&"torch", "A burning torch", "I eat wood and am never full. I drink water and I die. Bring me, living, on a stick."],
	[&"cold_torch", "A torch that is out", "Yesterday I was a sun in the hand. Today I am black and cold. Bring me the stick that waits for fire."],
	[&"amulet", "The scarab amulet", "Khepri rolls the sun up out of the night, as a beetle rolls its ball. Bring me Khepri, in gold and blue stone."],
	[&"key_iron", "The iron key", "I have teeth and bite nothing. I open what is shut. Bring me the black one, of iron."],
	[&"key_bronze", "The bronze key", "I have teeth and bite nothing. I open what is shut. Bring me the brown one, of bronze."],
	[&"key_gold", "The gold key", "I have teeth and bite nothing. I open what is shut. Bring me the one that shines like the sun."],
	[&"jar", "A canopic jar", "I wear a head for a lid. I keep safe what a dead man will want again."],
	[&"oil", "A jar of oil", "The lamp drinks me. Poured out, I am a black road for fire to run along. Bring me in my jar, unbroken."],
	[&"stone", "A stone to throw", "I am older than the kings. I have no wings, yet a boy's arm makes me fly."],
	[&"pot", "A pot", "I was river mud until the fire made me hard. I am all mouth and belly, and my belly is empty."],
	[&"shovel", "A shovel", "I have one iron tongue and a long wooden neck. I eat sand all day and am never fed."],
	[&"pickaxe", "A pickaxe", "I have two horns of iron and one leg of wood. Where I strike, stone opens."],
	[&"brush", "A hand brush", "I have a hundred hairs and no head. I wake old kings gently, a grain at a time."],
	[&"lantern", "A lantern", "I am a house of glass with a roof of tin. A flame lives in me and the wind cannot find it."],
	[&"basket", "A basket of spoil", "I was the leaves of a palm. Now I carry the desert away, one load at a time."],
	[&"khopesh", "A khopesh", "I am bronze, and bent like the new moon. The king holds me over his enemies."],
	[&"hook", "The grappling hook", "I have iron claws and a tail of rope. I climb first, and you come after."],
]
## What the level editor calls each, in the same order.
const TITLES: Array = ["A burning torch", "A torch that is out", "The scarab amulet", "The iron key", "The bronze key", "The gold key", "A canopic jar", "A jar of oil",
		"A stone to throw", "A pot", "A shovel", "A pickaxe", "A hand brush", "A lantern", "A basket of spoil", "A khopesh", "The grappling hook"]
## The props it knows, by the name of their scene.
const PROPS := {"rock_small": &"stone", "pot": &"pot", "target_pot": &"pot", "shovel": &"shovel", "pickaxe": &"pickaxe", "brush": &"brush", "lantern": &"lantern",
		"dig_basket": &"basket", "khopesh": &"khopesh"}

const AMBER := Color(1.0, 0.7, 0.22)
const BLAZE := Color(1.0, 0.93, 0.62)
const ANGER := Color(1.0, 0.16, 0.07)

## How long it is, nose of its paws to rump, in metres. It is 0.47 as wide and 0.46 as high.
@export_range(2.0, 30.0) var size := 6.0
## Whose head it has.
@export var head := Head.KING
## How weathered, 0..1: lumpy, stained and cracked; past a third the cobra is gone from its brow, past a half its
## beard, and past six tenths its nose.
@export_range(0.0, 1.0) var wear := 0.3
## Painted as it was when it was new: the headcloth blue and yellow, the face red, the eyes lined in black.
@export var painted := false
## The colour of its stone.
@export var colour := Sandstone.COLOUR
## Which thing it asks for: its place in `THINGS`.
@export var wants := 0
## Its riddle, if it is to say something other than the one that goes with what it wants.
@export_multiline var riddle := ""
## In sand to its neck (1), or not at all (0).
@export_range(0.0, 1.0) var buried := 0.0
## Given what it wants, its stele sinks and there is a way through it, from its chest to under its tail. (It is a tenth of its length
## wide and 0.16 of it high: room for him in one of 9 m or more.)
@export var opens_itself := false
## The third wrong thing, and it strikes him.
@export var wrathful := false
## Whether it has what it wants.
@export var on := false
## How long the sand takes to go, in seconds, once something is clearing it.
@export var uncover_time := 8.0
## Whether it makes a sound.
@export var voice := true

## Set while the sand is to be cleared from it (the level does this, from what it is linked to).
var uncovering := false
## How many wrong things it has been given since it last struck.
var strikes := 0
## Whether its eyes are open.
var awake := false
## The thing it was given and has kept, if it has one.
var kept: RigidBody3D
## How much of its sand is left, 1..0.
var sand := 0.0

## Where a thing it refuses is put down, in the world; with none said, out beyond its paw. (For a level that has
## only one place such a thing can lie: a tomb seen from the side, where everything is on one line.)
var sweep_to := Vector3.INF

enum Stage { NONE, TAKING, WEIGHING, REFUSING }

var _stone: SphinxMesh.Carved
var _foot := 0.1
var _slab_top := 0.2
var _head: Node3D
var _paw: Node3D
var _eyes: Array[MeshInstance3D] = []
var _eye_material: StandardMaterial3D
var _light: OmniLight3D
var _stele: AnimatableBody3D
var _carved: Inscription
var _pile: SandPile
var _dust: Dust
var _speaker: AudioStreamPlayer3D
var _caption: Label
var _caption_time := 0.0
var _said := ""
var _starts_on := false
var _awake_for := 0.0
var _stage := Stage.NONE
var _clock := 0.0
var _held: RigidBody3D
var _from := Transform3D.IDENTITY
var _flung: RigidBody3D
var _flung_from := Vector3.ZERO
var _flung_to := Vector3.ZERO
var _flung_for := 0.0
var _flung_about := Vector3.RIGHT
var _sweep := -1.0
var _slam := false
var _shake := 0.0
var _flash := 0.0
var _wrath := 0.0
var _wrath_due := false
var _glow := 0.0
var _tint := AMBER
var _open := 0.0
var _look := Vector2.ZERO
var _sunk := 0.0
var _time := 0.0
var _groups: Array[StringName] = []

static var _sounds := {}


## The name it knows a thing by (one of the names in `THINGS`), or nothing if it is not a thing it knows.
## Anything can say what it is with the meta `sphinx_thing`.
static func what_is(thing: Node) -> StringName:
	if thing == null:
		return &""
	if thing.has_meta(&"sphinx_thing"):
		return StringName(thing.get_meta(&"sphinx_thing"))
	if thing is HandTorch:
		return &"torch" if (thing as HandTorch).lit else &"cold_torch"
	if thing is DoorKey:
		return [&"key_iron", &"key_bronze", &"key_gold"][clampi(int((thing as DoorKey).which), 0, 2)]
	if thing is OilJar:
		return &"" if (thing as OilJar).is_broken else &"oil"
	if thing.is_in_group(&"scarab_amulets"):
		return &"amulet"
	if thing.is_in_group(&"grapples"):
		return &"hook"
	if OfferingTable.is_offering(thing):
		return &"jar"
	return PROPS.get(thing.scene_file_path.get_file().get_basename(), &"")


## A sphinx as an item of a level's layout says (see `LevelLayout.FIELDS`).
static func from_item(item: Dictionary) -> Sphinx:
	var made := Sphinx.new()
	made.size = item.get("size", 6.0)
	made.head = int(item.get("head", 0)) as Head
	made.wear = item.get("wear", 0.3)
	made.painted = item.get("painted", false)
	made.colour = Pyramid.STONES[clampi(int(item.get("stone", 0)), 0, Pyramid.STONES.size() - 1)]
	made.wants = clampi(int(item.get("wants", 0)), 0, THINGS.size() - 1)
	made.riddle = item.get("riddle", "")
	made.buried = item.get("buried", 0.0)
	made.opens_itself = item.get("opens", false)
	made.wrathful = item.get("wrathful", false)
	return made


func _ready() -> void:
	add_to_group(&"interest")
	set_meta(&"surface", "stone")
	_starts_on = on
	wants = clampi(wants, 0, THINGS.size() - 1)
	_build()


## The words of its riddle.
func riddle_text() -> String:
	return riddle.strip_edges() if riddle.strip_edges() != "" else String(THINGS[wants][2])


## Whether a thing is what it asks for.
func is_answer(thing: Node) -> bool:
	return what_is(thing) == (THINGS[wants][0] as StringName)


## Where the middle of the top of its slab is, in the world.
func slab_place() -> Vector3:
	return global_transform * Vector3(0.0, _slab_top, SphinxMesh.SLAB * size)


## Whether its paws and slab are under the sand.
func is_covered() -> bool:
	return buried * sand > 0.14


## Gives it a thing, as if it had been set down on the slab.
func offer(thing: RigidBody3D) -> void:
	if on or is_covered() or _stage != Stage.NONE or thing == null:
		return
	_held = thing
	_from = thing.global_transform
	thing.freeze = true
	thing.linear_velocity = Vector3.ZERO
	thing.angular_velocity = Vector3.ZERO
	thing.set_meta(&"offered", true)
	_stage = Stage.TAKING
	_clock = 0.0
	_awake_for = 6.0


## As it was when it was made: asleep, off, in its sand, and what it had kept put down on the ground beside it.
func reset() -> void:
	_drop_held()
	if kept and is_instance_valid(kept):
		_give_back(kept)
		kept.global_position = _landing(kept)
	kept = null
	strikes = 0
	_wrath = 0.0
	_wrath_due = false
	_sunk = 0.0
	sand = 1.0 if buried > 0.0 else 0.0
	_heap()
	_place_stele()
	if on != _starts_on:
		on = _starts_on
		changed.emit(on)


func _exit_tree() -> void:
	if is_instance_valid(_caption) and _caption.text == _said:
		_caption.visible = false
	# (taken out of the level with a thing on its slab: the thing is let fall)
	_drop_held()
	if kept and is_instance_valid(kept):
		_give_back(kept)
	kept = null


# --- Making it

func _build() -> void:
	# (kept hold of: another sphinx that is the same in every way shares it)
	_stone = SphinxMesh.carve(size, int(head), wear, painted, colour, opens_itself)
	_foot = _stone.foot
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _stone.body
	add_child(body)
	for solid: Array in _stone.solids:
		var collider := CollisionShape3D.new()
		collider.shape = solid[0]
		collider.position = solid[1]
		add_child(collider)
	_paw = Node3D.new()
	_paw.name = "Paw"
	_paw.position = _stone.paw_at
	var paw := MeshInstance3D.new()
	paw.mesh = _stone.paw
	_paw.add_child(paw)
	add_child(_paw)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = _stone.head_at
	var skull := MeshInstance3D.new()
	skull.mesh = _stone.head
	_head.add_child(skull)
	add_child(_head)
	# Its eyes: dark stone until they open, and then lit from inside.
	_eye_material = StandardMaterial3D.new()
	_eye_material.roughness = 1.0
	_eye_material.metallic_specular = 0.0
	_eye_material.emission_enabled = true
	var between := Vector3.ZERO
	for eye: Array in _stone.eyes:
		var lid := MeshInstance3D.new()
		lid.mesh = eye[2]
		lid.material_override = _eye_material
		lid.transform = Transform3D(eye[1], eye[0])
		lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head.add_child(lid)
		_eyes.append(lid)
		between += (eye[0] as Vector3) / maxf(_stone.eyes.size(), 1.0)
	_light = OmniLight3D.new()
	_light.position = between + Vector3(0.0, -0.02, 0.16) * size
	_light.omni_range = size * 0.55 + 2.0
	_light.shadow_enabled = false
	_light.light_energy = 0.0
	_head.add_child(_light)
	_slab()
	_stand_stele()
	_dust = Dust.new()
	add_child(_dust)
	_speaker = AudioStreamPlayer3D.new()
	_speaker.position = _stone.head_at
	_speaker.unit_size = 5.0 + size
	_speaker.max_distance = 60.0 + size * 3.0
	add_child(_speaker)
	if buried > 0.0:
		# The sand it lies in: a ridge along it, as high as its neck when it is buried altogether.
		_pile = SandPile.new()
		_pile.length = size * 0.7
		_pile.cap = maxf(size * 0.3 * buried / (tan(SandPile.SLOPE) * 0.9), 0.3)
		_pile.rotation.y = PI * 0.5
		add_child(_pile)
		sand = 1.0
		_heap()
	_show_eyes()


# The offering slab between its paws: low, with the mat and the loaf of the sign for an offering cut in the top of it.
# (It is the model's `slab`, made as long and wide as the sphinx wants and as tall as suits him.)
func _slab() -> void:
	var tall := clampf(size * 0.03, 0.08, 0.3)
	var across := Vector3(SphinxMesh.SLAB_HALF.x * 2.0 * size, tall, SphinxMesh.SLAB_HALF.y * 2.0 * size)
	var at := Vector3(0.0, _foot + tall * 0.5, SphinxMesh.SLAB * size)
	_slab_top = _foot + tall
	PuzzleKit.shape(self, at, across)
	var slab := MeshInstance3D.new()
	slab.name = "Slab"
	slab.mesh = SphinxMesh.piece("slab", Vector3(size, tall / SphinxMesh.SLAB_TALL, size),
			{"slab_stone": PuzzleKit.stone(colour.darkened(0.18)), "slab_mat": PuzzleKit.stone(colour.darkened(0.55)), "gold": Toon.gold()})
	slab.position = Vector3(0.0, _foot, at.z)
	add_child(slab)


# The stele against its chest: a slab with a round top, the sun's disc in the round, and the riddle under it.
# (The model's `stele`, made as wide and tall as the sphinx wants and as thick as will stand.)
func _stand_stele() -> void:
	var wide := 0.104 * size
	var tall := 0.165 * size
	var thick := clampf(size * 0.02, 0.06, 0.25)
	_stele = AnimatableBody3D.new()
	_stele.name = "Stele"
	_stele.sync_to_physics = false
	_stele.set_meta(&"surface", "stone")
	var box := Vector3(wide, tall, thick)
	PuzzleKit.shape(_stele, Vector3(0.0, tall * 0.5, 0.0), box)
	var stone := MeshInstance3D.new()
	stone.mesh = SphinxMesh.piece("stele", Vector3(size, size, thick / SphinxMesh.STELE_THICK), {"stele_stone": PuzzleKit.stone(colour.lightened(0.06)), "gold": Toon.gold()})
	_stele.add_child(stone)
	# (the riddle is written on the flat of it, below the round)
	var flat := Node3D.new()
	flat.position.y = tall * 0.5
	_stele.add_child(flat)
	_carved = Inscription.on_box(flat, box, Vector3.BACK, riddle_text(), {"colour": colour.lightened(0.06), "wear": wear * 0.6, "painted": painted}, wide * 0.07)
	add_child(_stele)
	_place_stele()


func _place_stele() -> void:
	if _stele == null:
		return
	var thick := clampf(size * 0.02, 0.06, 0.25)
	# (sunk, it is under the base altogether)
	_stele.position = Vector3(0.0, _foot - _sunk * (0.165 + 0.06) * size - _sunk * _foot, (SphinxMesh.CHEST + 0.023) * size + thick * 0.5)


func _heap() -> void:
	if _pile == null:
		return
	_pile.volume = _pile._holds(_pile.cap * sand)


# --- What it does

func _physics_process(delta: float) -> void:
	_time += delta
	var player := Nearby.player(get_tree())
	var local := Vector3(0.0, 0.0, 1000.0)
	if player:
		local = to_local(player.global_position)
	# The sand going.
	if _pile and uncovering and sand > 0.0:
		sand = maxf(sand - delta / maxf(uncover_time, 0.1), 0.0)
		_heap()
		if Engine.get_physics_frames() % 9 == 0:
			var where := Vector3(randf_range(-0.3, 0.3) * size, _pile.height * randf_range(0.2, 0.9), randf_range(-0.45, 0.5) * size)
			_dust.puff(global_transform * where, global_basis.x * randf_range(1.0, 2.2), size * 0.12)
	var covered := is_covered()
	# Awake while he is between its paws, while it has something to weigh, and for a little after.
	var near := not covered and player != null and _between(local)
	if near or _stage != Stage.NONE or _wrath > 0.0:
		_awake_for = 4.0
	else:
		_awake_for = maxf(_awake_for - delta, 0.0)
	if _awake_for > 0.0 and not covered and not awake:
		_wake()
	elif awake and (_awake_for <= 0.0 or covered) and not on:
		awake = false
	if not on and not covered and _stage == Stage.NONE and _flung == null:
		_look_for_offering(player)
	_weigh(delta, player)
	_fly(delta, player)
	if _wrath_due and player and not player.is_limp and player.global_position.distance_to(slab_place()) < size * 0.5 + 4.0:
		_wrath_due = false
		strikes = 0
		_wrath = 2.2
		_slam = true
		_sweep = 0.0
		_sound(&"strike")
		caught.emit()
	_wrath = maxf(_wrath - delta, 0.0)
	# The stele going down.
	if on and opens_itself and _sunk < 1.0:
		if _sunk == 0.0:
			_sound(&"sink")
		_sunk = minf(_sunk + delta / 3.2, 1.0)
		_place_stele()
		if Engine.get_physics_frames() % 6 == 0:
			_dust.puff(_stele.global_position + global_basis.y * (0.05 + _sunk * _foot), global_basis.z * 0.4, size * 0.05, 2, 1.2)
	_pose(delta, local, near)
	if is_instance_valid(_caption) and _caption.visible and _caption.text == _said:
		_caption_time -= delta
		if _caption_time <= 0.0:
			_caption.visible = false


# Whether a place (in its own space) is between its paws, or just in front of them.
func _between(local: Vector3) -> bool:
	return absf(local.x) < maxf(SphinxMesh.PAW_OUT * size, 0.8) and local.z > SphinxMesh.CHEST * size and local.z < 0.5 * size + maxf(1.5, size * 0.1) \
			and local.y > -1.0 and local.y < size * 0.2 + 1.0


func _wake() -> void:
	awake = true
	_sound(&"stir")
	# Dust comes down from its neck, where the stone has moved.
	for i in 7:
		var round := TAU * i / 7.0
		var where := _head.position + Vector3(sin(round) * 0.07, 0.01, cos(round) * 0.06 + 0.01) * size
		_dust.puff(global_transform * where, Vector3(sin(round) * 0.25, -1.5 - size * 0.08, cos(round) * 0.25), size * 0.06, 2, 0.6)
	if not on:
		_say("\"%s\"" % riddle_text(), 9.0)
		if not Notebook.has(riddle_text()):
			Notebook.translation("eye", riddle_text(), "The sphinx")


# Finds a thing put down on the slab, or between the paws, or thrown there.
func _look_for_offering(player: Player) -> void:
	var top := Vector3(0.0, _slab_top, SphinxMesh.SLAB * size)
	for found: Node in get_tree().get_nodes_in_group(&"throwable"):
		var thing := found as RigidBody3D
		if thing == null or thing.has_meta(&"offered") or (player and player.carried == thing):
			continue
		var from := to_local(thing.global_position) - top
		var slow := thing.linear_velocity.length() < 1.5 and not thing.freeze
		# (lying between the paws, or in the air just over the slab)
		var lying := slow and absf(from.x) < maxf((SphinxMesh.GAP + 0.02) * size, 0.8) and from.z > (SphinxMesh.CHEST - SphinxMesh.SLAB) * size \
				and from.z < (0.5 - SphinxMesh.SLAB) * size + maxf(0.6, size * 0.05) and absf(from.y) < size * 0.2 + 0.8
		var over := not thing.freeze and Vector2(from.x, from.z).length() < maxf(SphinxMesh.SLAB_HALF.y * size, 0.45) and from.y > -0.2 and from.y < 0.9 + size * 0.04
		if lying or over:
			offer(thing)
			return


# Carries a thing it has been given through being taken, weighed, and kept or refused.
func _weigh(delta: float, player: Player) -> void:
	if _stage == Stage.NONE:
		return
	if _stage != Stage.REFUSING or _held:
		if _held == null or not is_instance_valid(_held) or (player and player.carried == _held):
			# (gone, or taken up again before it was weighed)
			if _held and is_instance_valid(_held):
				_held.remove_meta(&"offered")
			_held = null
			if _stage != Stage.REFUSING:
				_stage = Stage.NONE
				return
	_clock += delta
	match _stage:
		Stage.TAKING:
			var seat := Transform3D(global_basis.orthonormalized(), slab_place() + global_basis.y.normalized() * _foot_of(_held))
			_held.global_transform = _from.interpolate_with(seat, smoothstep(0.0, 1.0, _clock / 0.3))
			if _clock >= 0.3:
				_stage = Stage.WEIGHING
				_clock = 0.0
		Stage.WEIGHING:
			if _clock >= 0.7:
				if is_answer(_held):
					_accept()
				else:
					_stage = Stage.REFUSING
					_clock = 0.0
					_shake = 1.0
					_sweep = 0.0
					_slam = false
					_sound(&"growl")
		Stage.REFUSING:
			# The paw comes across at about half a second, and takes the thing with it.
			if _held and _clock >= 0.42:
				_fling(_held)
				_held = null
				_sound(&"sweep")
			if _clock >= 1.3:
				_stage = Stage.NONE
				strikes += 1
				if wrathful and strikes >= 3:
					_wrath_due = true
				elif not on:
					_say("\"%s\"" % riddle_text(), 6.0)


func _accept() -> void:
	kept = _held
	_held = null
	_stage = Stage.NONE
	_flash = 1.0
	# It is the sphinx's now: he cannot take it up again.
	_groups.clear()
	if kept is DoorKey:
		(kept as DoorKey).taken_into(self)
	else:
		for group: StringName in [&"throwable", &"interest"]:
			if kept.is_in_group(group):
				_groups.append(group)
				kept.remove_from_group(group)
	_sound(&"blaze")
	if is_instance_valid(_caption) and _caption.text == _said:
		_caption.visible = false
	on = true
	changed.emit(true)


func _give_back(thing: RigidBody3D) -> void:
	if thing is DoorKey:
		(thing as DoorKey).taken_into(null)
	else:
		for group in _groups:
			thing.add_to_group(group)
		var player := Nearby.player(get_tree()) if is_inside_tree() else null
		if player == null or player.carried != thing:
			thing.freeze = false
	if thing.has_meta(&"offered"):
		thing.remove_meta(&"offered")


func _drop_held() -> void:
	for thing: RigidBody3D in [_held, _flung]:
		if thing and is_instance_valid(thing):
			if thing.has_meta(&"offered"):
				thing.remove_meta(&"offered")
			var player := Nearby.player(get_tree()) if is_inside_tree() else null
			if player == null or player.carried != thing:
				thing.freeze = false
	_held = null
	_flung = null
	_stage = Stage.NONE


# How far under its own origin a thing's foot is: what to stand it on.
func _foot_of(thing: RigidBody3D) -> float:
	for child in thing.get_children():
		var collider := child as CollisionShape3D
		if collider == null or collider.shape == null:
			continue
		var half := 0.1
		if collider.shape is BoxShape3D:
			half = (collider.shape as BoxShape3D).size.y * 0.5
		elif collider.shape is CylinderShape3D:
			half = (collider.shape as CylinderShape3D).height * 0.5
		elif collider.shape is CapsuleShape3D:
			half = (collider.shape as CapsuleShape3D).height * 0.5
		elif collider.shape is SphereShape3D:
			half = (collider.shape as SphereShape3D).radius
		return half - collider.position.y
	return 0.1


# Where a thing knocked off the slab comes down: on the ground out beyond its left paw, clear of everything of its own.
func _landing(thing: RigidBody3D) -> Vector3:
	var at := global_transform * Vector3(-(SphinxMesh.BASE.x * size + 1.3), 0.0, 0.5 * size + 0.9)
	if sweep_to != Vector3.INF:
		at = sweep_to
	var up := global_basis.y.normalized()
	var query := PhysicsRayQueryParameters3D.create(at + up * (size * 0.3 + 2.0), at - up * (size * 0.5 + 6.0))
	query.exclude = [get_rid(), thing.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		at = hit["position"]
	return at + up * (_foot_of(thing) + 0.04)


# Knocks a thing off the slab. It is carried over in an arc, not thrown: so nothing breaks, and it lands where it can be found.
func _fling(thing: RigidBody3D) -> void:
	_flung = thing
	_flung_from = thing.global_position
	_flung_to = _landing(thing)
	_flung_for = 0.0
	_flung_about = global_basis.z.normalized()
	_from = thing.global_transform


func _fly(delta: float, player: Player) -> void:
	if _flung == null:
		return
	if not is_instance_valid(_flung) or (player and player.carried == _flung):
		if is_instance_valid(_flung):
			_flung.remove_meta(&"offered")
		_flung = null
		return
	_flung_for = minf(_flung_for + delta / 0.75, 1.0)
	var t := _flung_for
	var high := size * 0.14 + 0.9
	var at := _flung_from.lerp(_flung_to, t) + global_basis.y.normalized() * 4.0 * high * t * (1.0 - t)
	_flung.global_transform = Transform3D(Basis(_flung_about, TAU * t) * _from.basis, at)
	if t >= 1.0:
		_flung.remove_meta(&"offered")
		_flung.linear_velocity = Vector3.ZERO
		_flung.angular_velocity = Vector3.ZERO
		_flung.freeze = false
		_dust.puff(_flung_to, Vector3.ZERO, 0.5, 3, 1.0)
		_flung = null


# --- How it looks: the eyes, the head, the paw

func _pose(delta: float, local: Vector3, near: bool) -> void:
	# The eyes: shut and dark; open and amber; blazing pale gold once it is content; red when it is not.
	var glow := 0.0
	var tint := AMBER
	if _wrath > 0.0:
		glow = 3.0
		tint = ANGER
	elif _stage == Stage.REFUSING:
		glow = 1.9
		tint = ANGER
	elif on:
		glow = 2.3 + 2.0 * _flash
		tint = BLAZE
	elif _stage == Stage.WEIGHING:
		glow = 1.2 + 0.5 * sin(_time * 14.0)
	elif awake:
		glow = 1.0 + 0.08 * sin(_time * 2.3)
	_flash = maxf(_flash - delta / 1.5, 0.0)
	_glow = lerpf(_glow, glow, 1.0 - exp(-7.0 * delta))
	_tint = _tint.lerp(tint, 1.0 - exp(-9.0 * delta))
	_open = move_toward(_open, 1.0 if (awake or on or _wrath > 0.0) else 0.0, delta / 0.6)
	_show_eyes()
	# The head: a very little towards him, and down; shaken when it is displeased.
	var want := Vector2.ZERO
	if near and (awake or on):
		var from := local - _head.position
		want.y = clampf(atan2(from.x, maxf(from.z, 0.1)), -0.16, 0.16)
		want.x = clampf(atan2(-from.y - 1.0, Vector2(from.x, from.z).length()) * 0.3, 0.0, 0.15)
	_look = _look.lerp(want, 1.0 - exp(-1.8 * delta))
	_shake = maxf(_shake - delta / 1.1, 0.0)
	_head.rotation = Vector3(_look.x, _look.y + sin((1.0 - _shake) * 21.0) * 0.1 * _shake, 0.0)
	# The paw: drawn back and lifted, across the slab, and laid down again. (Striking, it is lifted high and brought down.)
	if _sweep >= 0.0:
		_sweep += delta
		var across := atan2(SphinxMesh.PAW_OUT, SphinxMesh.SLAB) * 1.55
		var yaw := 0.0
		var lift := 0.0
		if _slam:
			lift = _curve([Vector2(0.0, 0.0), Vector2(0.35, -0.5), Vector2(0.5, 0.0), Vector2(0.6, -0.05), Vector2(0.7, 0.0)], _sweep)
			yaw = _curve([Vector2(0.0, 0.0), Vector2(0.35, -across * 0.5), Vector2(0.9, -across * 0.5), Vector2(1.6, 0.0)], _sweep)
		else:
			yaw = _curve([Vector2(0.0, 0.0), Vector2(0.24, 0.1), Vector2(0.52, -across), Vector2(0.7, -across), Vector2(1.4, 0.0)], _sweep)
			lift = _curve([Vector2(0.0, 0.0), Vector2(0.22, -0.13), Vector2(0.7, -0.1), Vector2(1.4, 0.0)], _sweep)
		_paw.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lift)
		if _sweep >= 1.6:
			_sweep = -1.0
			_paw.basis = Basis.IDENTITY


func _curve(points: Array, at: float) -> float:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if at >= a.x and at <= b.x:
			return lerpf(a.y, b.y, smoothstep(0.0, 1.0, (at - a.x) / (b.x - a.x)))
	return (points[points.size() - 1] as Vector2).y


func _show_eyes() -> void:
	var lit := clampf(_glow, 0.0, 1.0)
	_eye_material.albedo_color = colour.darkened(0.55).lerp(_tint, lit)
	_eye_material.emission = _tint
	_eye_material.emission_energy_multiplier = _glow * 1.7
	for eye in _eyes:
		eye.scale = Vector3(1.0, lerpf(0.22, 1.0, _open), 1.0)
	_light.light_color = _tint
	_light.light_energy = _glow * 0.22
	_light.visible = _glow > 0.02


# --- Its words, and its voice

func _say(text: String, seconds: float) -> void:
	if not is_inside_tree():
		return
	# One line of words for every sphinx in the level: the last to speak has it.
	_caption = get_tree().get_first_node_in_group(&"sphinx_caption") as Label
	if _caption == null:
		var layer := CanvasLayer.new()
		layer.layer = 4
		get_parent().add_child(layer)
		_caption = Label.new()
		_caption.add_to_group(&"sphinx_caption")
		_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_caption.offset_left = 150.0
		_caption.offset_right = -150.0
		_caption.offset_top = 64.0
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption.add_theme_font_size_override("font_size", 28)
		_caption.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
		_caption.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		_caption.add_theme_constant_override("outline_size", 9)
		layer.add_child(_caption)
	_said = text
	_caption.text = text
	_caption.visible = true
	_caption_time = seconds


func _sound(kind: StringName) -> void:
	if not voice or _speaker == null or DisplayServer.get_name() == "headless":
		return
	if not _sounds.has(kind):
		_sounds[kind] = _made_sound(kind)
	_speaker.stream = _sounds[kind]
	_speaker.pitch_scale = clampf(1.35 - size * 0.035, 0.7, 1.3)
	_speaker.play()


# Its voice is made here, not recorded: low tones that waver, and noise with the top taken off, for stone moving on stone.
# Each layer: [starts at, cutoff of its noise (0: a tone), pitch of its tone, dies away in, how loud, pitch it slides to, how fast it wavers].
static func _made_sound(kind: StringName) -> AudioStreamWAV:
	const RATE := 22050
	var length := 1.0
	var layers: Array = []
	match kind:
		&"stir":
			length = 1.9
			layers = [[0.0, 170.0, 0.0, 0.8, 1.0, 0.0, 9.0], [0.05, 0.0, 46.0, 0.7, 0.8, 38.0, 0.0], [0.35, 520.0, 0.0, 0.3, 0.3, 0.0, 17.0]]
		&"growl":
			length = 1.3
			layers = [[0.0, 0.0, 64.0, 0.6, 1.0, 47.0, 23.0], [0.0, 0.0, 97.0, 0.5, 0.45, 70.0, 23.0], [0.0, 260.0, 0.0, 0.5, 0.6, 0.0, 23.0]]
		&"sweep":
			length = 0.7
			layers = [[0.0, 700.0, 0.0, 0.16, 0.9, 0.0, 0.0], [0.1, 0.0, 72.0, 0.16, 1.0, 50.0, 0.0], [0.1, 1500.0, 0.0, 0.03, 0.5, 0.0, 0.0]]
		&"blaze":
			length = 2.4
			layers = [[0.0, 0.0, 98.0, 1.3, 0.8, 98.0, 0.0], [0.06, 0.0, 147.0, 1.2, 0.6, 147.0, 0.0], [0.12, 0.0, 196.0, 1.1, 0.5, 196.0, 0.0], [0.18, 0.0, 294.0, 0.9, 0.3, 294.0, 5.0],
					[0.0, 300.0, 0.0, 0.5, 0.5, 0.0, 0.0]]
		&"sink":
			length = 3.3
			layers = [[0.0, 150.0, 0.0, 30.0, 1.0, 0.0, 11.0], [0.0, 600.0, 0.0, 30.0, 0.25, 0.0, 29.0], [0.0, 0.0, 41.0, 30.0, 0.5, 39.0, 0.0]]
		&"strike":
			length = 1.6
			layers = [[0.0, 0.0, 58.0, 0.5, 1.0, 34.0, 0.0], [0.0, 900.0, 0.0, 0.12, 0.9, 0.0, 0.0], [0.05, 200.0, 0.0, 0.7, 0.6, 0.0, 19.0]]
	var random := RandomNumberGenerator.new()
	random.seed = hash(kind)
	var count := int(length * RATE)
	var wave := PackedFloat32Array()
	wave.resize(count)
	for layer: Array in layers:
		var begin := int(float(layer[0]) * RATE)
		var cutoff: float = layer[1]
		var keep := 1.0 - exp(-TAU * cutoff / RATE)
		var held := 0.0
		var phase := 0.0
		for n in range(begin, count):
			var t := float(n - begin) / RATE
			var loud: float = float(layer[4]) * exp(-t / float(layer[3])) * minf(t / 0.03, 1.0)
			if float(layer[6]) > 0.0:
				loud *= 0.6 + 0.4 * sin(TAU * float(layer[6]) * t)
			if cutoff > 0.0:
				held += (random.randf_range(-1.0, 1.0) - held) * keep
				wave[n] += held * loud * 3.0
			else:
				phase += TAU * lerpf(layer[2], layer[5], minf(t / (float(layer[3]) * 2.0), 1.0)) / RATE
				# (a rough edge on the tone: stone, not a flute)
				wave[n] += (sin(phase) + 0.3 * sin(phase * 2.0) + 0.15 * sin(phase * 3.0)) * loud
	var peak := 0.001
	for value in wave:
		peak = maxf(peak, absf(value))
	var fade := int(0.08 * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for n in count:
		var value := wave[n] / peak * 0.8 * minf(float(count - n) / fade, 1.0)
		data.encode_s16(n * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
