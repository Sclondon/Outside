class_name TombDoor
extends StaticBody3D
## The mouth of a rock-cut tomb, as they are in the Valley of the Kings: a
## square-cut doorway under a lintel in the foot of a cliff, a ramp of
## chippings up to its sill between two dry-stone walls that hold the spoil
## back, and a short stair down inside to the door itself. It looks out along
## its own +z; the cliff is at its back. The model is `tomb_door` in
## `tools/rocks.blend` (`RockModels`).
##
## Shut, the door is walled up with rough stones and plastered over, as the
## necropolis guards left them. `open`, it is dark, and the stair goes on down.
## With a `number` it has a board on a post beside it: "KV 9".
##
## It is a place a level's maker can do something with. Every one is in the
## group `tomb_doors`; `entered` is sent when he walks in at one that is open;
## and `leads_to` says what then happens:
##     0   nothing: it is a way in that goes nowhere yet
##     1   today's tomb (`tomb.tscn`, walked through)
##     2   a tomb of its own, made from `tomb_seed` at `difficulty`
##     3   the same, of the kind that branches
## When the tomb is done its card has "Back outside", which brings him back to
## the level he came from, standing before this door (`TombLevel.back_to`).
## The level itself starts afresh: nothing of it is kept while he is below.

signal entered

const LEADS: Array[String] = ["Nowhere yet", "Today's tomb", "A tomb of its own", "A tomb that branches"]
const WOOD := Color(0.45, 0.33, 0.2)

## The number on its board (as KV 62 is Tutankhamun's). 0: no board.
@export var number := 0
## Whether it has been opened.
@export var open := false
## What walking in leads to (see above, and `LEADS`).
@export var leads_to := 0
## Which tomb, and how hard (0..2), for a tomb of its own.
@export var tomb_seed := 1
@export var difficulty := 1
@export var colour := Rock.LIMESTONE
## Whether it draws itself. (`KingsValley` draws all its doorways in one mesh, and turns this off.)
var drawn := true

var _made: Array[Node] = []
var _gone := false


## A doorway as an item of a level's layout says (see `LevelLayout.FIELDS`).
static func from_item(item: Dictionary) -> TombDoor:
	var made := TombDoor.new()
	made.number = int(item.get("number", 9))
	made.open = item.get("open", false)
	made.leads_to = int(item.get("leads", 0))
	made.tomb_seed = int(item.get("tomb_seed", 1))
	made.difficulty = int(item.get("difficulty", 1))
	made.colour = Rock.stone(int(item.get("stone", 1)))
	return made


## Puts a doorway's models into a builder, where its `place` is. Says what is solid of it.
static func add_to(builder: Rock.Builder, is_open: bool, with_board: bool) -> Array:
	var solid := builder.add("tomb_door")
	if is_open:
		builder.add("tomb_door_open")
	else:
		solid.append_array(builder.add("tomb_door_shut"))
	if with_board:
		var was := builder.place
		builder.place = was * board_place()
		builder.add("number_board")
		builder.place = was
	return solid


## Where the board stands, measured from the doorway.
static func board_place() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, 0.35), Vector3(2.75, 0.0, 6.3))


## The materials a doorway's models wear besides rock, by name.
static func materials(stone: Color) -> Dictionary:
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.02, 0.02, 0.025)
	return {"dressed": Sandstone.surface(stone.lightened(0.1), 0.5, 1.4, 0.35, 0.25), "dark": dark, "wood": Toon.surface(WOOD)}


func _ready() -> void:
	add_to_group(&"tomb_doors")
	build()


## Makes it (again) from its numbers.
func build() -> void:
	for old in _made:
		old.queue_free()
	_made.clear()
	var builder := Rock.Builder.new()
	var solid := add_to(builder, open, number > 0)
	if drawn:
		var visual := MeshInstance3D.new()
		visual.mesh = builder.mesh(Rock.material(colour, 3, 0.8), null, materials(colour))
		_keep(visual)
	for hull: PackedVector3Array in solid:
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		var collider := CollisionShape3D.new()
		collider.shape = shape
		_keep(collider)
	if number > 0:
		var words := Label3D.new()
		words.text = "KV %d" % number
		words.font_size = 96
		words.pixel_size = 0.0022
		words.modulate = Color(0.1, 0.08, 0.06)
		words.outline_size = 0
		words.transform = board_place() * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.95, 0.056))
		_keep(words)
	if open:
		# Walking in at the door: the last of the stair, under the lintel.
		var way_in := Area3D.new()
		way_in.collision_layer = 0
		way_in.collision_mask = 2
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 2.0, 0.7)
		var within := CollisionShape3D.new()
		within.shape = box
		within.position = Vector3(0.0, 1.3, 0.5)
		way_in.add_child(within)
		way_in.body_entered.connect(_on_walked_in)
		_keep(way_in)


func _keep(node: Node) -> void:
	add_child(node)
	_made.append(node)


func _on_walked_in(body: Node3D) -> void:
	if body is Player and not _gone and not get_tree().paused:
		enter()


## What `TombLevel.play` is given for this door, or nothing if it leads nowhere.
func tomb() -> Dictionary:
	match leads_to:
		1:
			return {"mode": "daily", "view": "3d"}
		2:
			return {"mode": "random", "seed": tomb_seed, "difficulty": difficulty, "view": "3d"}
		3:
			return {"mode": "random", "seed": tomb_seed, "difficulty": difficulty, "view": "3d", "shape": "branching"}
	return {}


## Goes in: says so, and if it leads to a tomb, opens it.
func enter() -> void:
	entered.emit()
	var chosen := tomb()
	if chosen.is_empty() or not is_inside_tree():
		return
	_gone = true
	TombLevel.play = chosen
	# (and the way back: this level, and the ground before this door)
	var scene := get_tree().current_scene
	TombLevel.back_to = scene.scene_file_path if scene else ""
	TombLevel.back_at = global_transform * Vector3(0.0, 0.3, 7.5)
	Loading.go("res://tomb.tscn")
