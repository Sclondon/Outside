class_name LevelLayout
## What is in a level, as plain data: its ground, and a list of items (props,
## water, people, puzzles...). The desert is made from one of these
## (`scripts/desert.gd`), and the level editor (`scripts/level_editor.gd`)
## changes one and saves it.
##
## There are two copies. The one the game ships with is `BUILT_IN`. Whatever is
## changed in the editor is saved on the device, at `SAVED`, and is used
## instead from then on, until it is thrown away ("Back to the original").
## `to_text` and `from_text` turn one into text and back, to copy a level off
## a phone: pasted into `levels/desert.json`, it becomes the one that ships.
##
## A layout is a Dictionary:
##     version   1
##     terrain   size, cell, dune_height, seed, scatter, rim_height, rim_width, wind [x, z]
##     weather   0 calm, 1 a breeze, 2 a storm
##     mirage    how much the heat makes the distance swim, 0..1 (0: not at all)
##     items     a list of Dictionaries
## and every item has
##     id        a number of its own (what links are made to)
##     kind      one of KINDS
##     at        [x, z], where it stands
##     lift      how far above the ground there (the ground may change under it)
##     yaw       which way it faces, degrees
## and whatever else its kind keeps: see FIELDS. Pads and pools keep `y`, a
## height of their own, and no lift: they are what the ground is made from.

const BUILT_IN := "res://levels/desert.json"
const SAVED := "user://desert_layout.json"
const VERSION := 1

## What can be put in a level, page by page as the editor offers it:
## [what it is called, kind, what].
const PALETTE := {
	"Ground": [
		["Level ground", "pad", ""], ["Dune", "dune", ""], ["Ridge", "ridge", ""],
	],
	"Water": [
		["Pond", "pond", ""], ["River", "river", ""], ["Tank of water", "pool", ""], ["Well", "prop", "well"], ["Oasis kerb", "prop", "oasis_rim"],
	],
	"Stone": [
		["Sphinx", "prop", "sphinx"], ["Great pyramid", "prop", "pyramid_great"], ["Ruined pyramid", "prop", "pyramid_ruined"],
		["Pyramid door", "prop", "pyramid_entrance"], ["Obelisk", "prop", "obelisk"], ["Column", "prop", "column"],
		["Stepped pyramid", "pyramid", ""], ["Finished pyramid", "pyramid", "finished"], ["Fallen pyramid", "pyramid", "fallen"],
		["Broken column", "prop", "column_broken"], ["Column stump", "prop", "column_stump"], ["Fallen column", "prop", "column_fallen"],
		["Lintel", "prop", "lintel"], ["Pharaoh", "prop", "statue_pharaoh"], ["Anubis", "prop", "statue_anubis"],
		["Sarcophagus", "prop", "sarcophagus"], ["Carved wall", "prop", "wall_glyphs"], ["Ruined wall", "prop", "wall_ruin"],
		["Block", "prop", "block"], ["Stack of blocks", "prop", "block_stack"], ["Rubble", "prop", "rubble"],
		["Boulder", "prop", "rock_a"], ["Rock", "prop", "rock_b"],
	],
	"Camp": [
		["Palm", "prop", "palm_a"], ["Bent palm", "prop", "palm_b"], ["Small palm", "prop", "palm_c"],
		["Tent", "prop", "tent"], ["Awning", "prop", "awning"], ["Scaffold", "prop", "scaffold"], ["Crate", "prop", "crate"],
		["Big jar", "prop", "pot_large"], ["Brazier", "prop", "brazier"], ["Torch", "prop", "torch_stand"], ["Campfire", "prop", "campfire"],
		["Pot", "prop", "pot"], ["Canopic jar", "prop", "jar_canopic"], ["Jackal jar", "prop", "jar_canopic_jackal"], ["Stone to throw", "prop", "rock_small"],
	],
	"People": [
		["Townsperson", "person", "townsperson"], ["Brother", "person", "brother"], ["Cat", "person", "cat"],
		["Hound", "person", "hound"], ["Mummy", "person", "mummy"],
	],
	"Puzzle": [
		["Pressure plate", "plate", ""], ["Door", "door", ""], ["Bridge or lift", "mover", ""], ["Block to push", "prop", "block_push"],
		["Rope", "rope", ""], ["Ladder", "ladder", ""], ["Sand fall", "sandfall", ""], ["Checkpoint", "checkpoint", ""], ["Where he starts", "start", ""], ["Sign", "sign", ""],
	],
	"Guns": [
		["Revolver", "thing", "revolver"], ["Rifle", "thing", "rifle"], ["Shotgun", "thing", "shotgun"], ["Flare pistol", "thing", "flare_pistol"],
		["Cartridges", "thing", "ammo_box"], ["Target board", "thing", "target_board"], ["Gong", "thing", "target_gong"],
		["Pot to shoot", "thing", "target_pot"], ["Bottle", "thing", "bottle"], ["Tin can", "thing", "tin_can"],
	],
}

## What each kind keeps besides where it is, and how the editor lets it be
## changed: [key, what it is called, type, ...]. The types:
##     "n"       a number: least, most, step, what it starts at
##     "b"       yes or no: what it starts at
##     "c"       one of a list: the list, what it starts at (as its place in the list)
##     "t"       a line of text: what it starts at
##     "links"   the triggers that work it (a list of ids)
## Looked up by "kind:what" first, then by kind.
const FIELDS := {
	"prop": [["scale", "Size", "n", 0.2, 4.0, 0.05, 1.0], ["tilt_x", "Tip forward", "n", -180.0, 180.0, 1.0, 0.0], ["tilt_z", "Tip sideways", "n", -180.0, 180.0, 1.0, 0.0]],
	"thing": [],
	# A pyramid made from numbers (`scripts/pyramid.gd`). The three on the palette differ only in what they start as.
	"pyramid": [["base", "Width", "n", 8.0, 120.0, 1.0, 40.0], ["slope", "Steepness", "n", 40.0, 65.0, 1.0, 54.0], ["rise", "Height of a course", "n", 0.6, 1.6, 0.05, 1.35],
		["casing", "Smooth casing left", "n", 0.0, 1.0, 0.05, 0.0], ["cap", "Gold cap", "b", false], ["ruin", "Ruined", "n", 0.0, 1.0, 0.05, 0.0],
		["seed", "Which ruin", "n", 0.0, 99.0, 1.0, 1.0], ["door", "Doorway", "b", false], ["stone", "Stone", "c", ["Sandstone", "Pale limestone", "Red sandstone", "Dark stone"], 0]],
	"pyramid:finished": [["base", "Width", "n", 8.0, 120.0, 1.0, 40.0], ["slope", "Steepness", "n", 40.0, 65.0, 1.0, 54.0], ["rise", "Height of a course", "n", 0.6, 1.6, 0.05, 1.35],
		["casing", "Smooth casing left", "n", 0.0, 1.0, 0.05, 1.0], ["cap", "Gold cap", "b", true], ["ruin", "Ruined", "n", 0.0, 1.0, 0.05, 0.0],
		["seed", "Which ruin", "n", 0.0, 99.0, 1.0, 1.0], ["door", "Doorway", "b", false], ["stone", "Stone", "c", ["Sandstone", "Pale limestone", "Red sandstone", "Dark stone"], 1]],
	"pyramid:fallen": [["base", "Width", "n", 8.0, 120.0, 1.0, 30.0], ["slope", "Steepness", "n", 40.0, 65.0, 1.0, 54.0], ["rise", "Height of a course", "n", 0.6, 1.6, 0.05, 1.35],
		["casing", "Smooth casing left", "n", 0.0, 1.0, 0.05, 0.0], ["cap", "Gold cap", "b", false], ["ruin", "Ruined", "n", 0.0, 1.0, 0.05, 0.5],
		["seed", "Which ruin", "n", 0.0, 99.0, 1.0, 1.0], ["door", "Doorway", "b", false], ["stone", "Stone", "c", ["Sandstone", "Pale limestone", "Red sandstone", "Dark stone"], 0]],
	"pad": [["y", "Height", "n", -12.0, 40.0, 0.1, 0.0], ["half_x", "Half width", "n", 1.0, 80.0, 0.5, 8.0], ["half_z", "Half length", "n", 1.0, 80.0, 0.5, 8.0],
		["round", "Round", "b", true], ["ease", "Rise of the dunes round it", "n", 0.5, 40.0, 0.5, 10.0]],
	"dune": [["width", "Width", "n", 8.0, 140.0, 1.0, 46.0], ["height", "Height", "n", 0.5, 22.0, 0.25, 6.0], ["horns", "Horns", "n", 0.2, 0.9, 0.01, 0.55]],
	"ridge": [["length", "Length", "n", 20.0, 300.0, 2.0, 110.0], ["height", "Height", "n", 0.5, 22.0, 0.25, 7.0]],
	"pond": [["radius", "Radius", "n", 1.5, 60.0, 0.5, 8.0], ["depth", "Depth", "n", 0.2, 6.0, 0.1, 1.4], ["level", "Water level", "n", -4.0, 2.0, 0.05, -0.4],
		["bank", "Bank", "n", 1.0, 25.0, 0.5, 6.0]],
	"river": [["width", "Width", "n", 2.0, 40.0, 0.5, 9.0], ["depth", "Depth", "n", 0.2, 6.0, 0.1, 1.3], ["level", "Water level", "n", -4.0, 2.0, 0.05, -0.5],
		["bank", "Bank", "n", 1.0, 25.0, 0.5, 6.0]],
	"pool": [["y", "Surface height", "n", -12.0, 40.0, 0.05, 0.0], ["size_x", "Width", "n", 1.0, 80.0, 0.5, 6.0], ["size_z", "Length", "n", 1.0, 80.0, 0.5, 6.0],
		["depth", "Depth", "n", 0.3, 8.0, 0.1, 3.0]],
	"person:townsperson": [["seed", "Who", "n", 0.0, 99.0, 1.0, 1.0], ["sex", "Sex", "c", ["Either", "Male", "Female"], 0], ["wander", "Wanders", "n", 0.0, 20.0, 0.5, 3.5]],
	"person:brother": [],
	"person:cat": [["coat", "Coat", "c", ["Bronze", "Silver", "Black", "Ruddy", "Tabby", "Ginger"], 0], ["tame", "Tame", "n", 0.0, 1.0, 0.05, 0.6], ["curiosity", "Curious", "n", 0.0, 1.0, 0.05, 0.6]],
	"person:hound": [["breed", "Breed", "c", ["Either", "Bloodhound", "Pharaoh hound"], 0], ["alert", "Gives chase within", "n", 0.0, 60.0, 1.0, 14.0], ["links", "Set on by", "links"]],
	"person:mummy": [["alert", "Wakes within", "n", 0.0, 40.0, 0.5, 6.0], ["links", "Woken by", "links"]],
	"plate": [["span_x", "Width", "n", 0.6, 8.0, 0.1, 1.6], ["span_z", "Length", "n", 0.6, 8.0, 0.1, 1.6], ["latches", "Stays down", "b", false], ["only_him", "Only he presses it", "b", false]],
	"door": [["wide", "Width", "n", 0.6, 12.0, 0.1, 3.0], ["tall", "Height", "n", 1.0, 12.0, 0.1, 2.6], ["thick", "Thickness", "n", 0.2, 3.0, 0.05, 0.4],
		["links", "Opened by", "links"], ["needs_all", "Needs every one", "b", false], ["inverted", "Open until then", "b", false]],
	"mover": [["wide", "Width", "n", 0.6, 16.0, 0.1, 2.4], ["long", "Length", "n", 0.6, 20.0, 0.1, 4.0], ["thick", "Thickness", "n", 0.1, 3.0, 0.05, 0.3],
		["travel", "Travels", "n", 0.5, 30.0, 0.25, 4.0], ["way", "Which way", "c", ["Forward", "Up", "Sideways"], 0], ["speed", "Speed", "n", 0.3, 8.0, 0.1, 2.0],
		["links", "Worked by", "links"], ["needs_all", "Needs every one", "b", false], ["inverted", "Out until then", "b", false]],
	"rope": [["length", "Length", "n", 2.0, 16.0, 0.25, 5.5]],
	"ladder": [["height", "Height", "n", 1.0, 16.0, 0.25, 4.0]],
	"sandfall": [["width", "Width", "n", 0.0, 8.0, 0.25, 0.0], ["running", "Running", "b", true], ["links", "Turned by", "links"]],
	"checkpoint": [],
	"start": [],
	"sign": [["text", "Says", "t", "A SIGN"]],
}

## How far above the ground each kind is put when it is first set down.
const LIFTS := {"rope": 6.0, "sandfall": 5.0, "sign": 3.0, "person": 0.15, "door": 1.3, "mover": 0.5}


## The fields of an item's kind.
static func fields(item: Dictionary) -> Array:
	return FIELDS.get("%s:%s" % [item.get("kind", ""), item.get("what", "")], FIELDS.get(item.get("kind", ""), []))


## What a kind is called.
static func label(item: Dictionary) -> String:
	for page: String in PALETTE:
		for entry: Array in PALETTE[page]:
			if entry[1] == item.get("kind", "") and entry[2] == item.get("what", ""):
				return entry[0]
	return String(item.get("what", item.get("kind", "?"))).capitalize()


## A new item of a kind, as its fields start out, standing at `at` (x, z).
static func new_item(layout: Dictionary, kind: String, what: String, at: Vector2) -> Dictionary:
	var item := {"id": next_id(layout), "kind": kind, "at": [snappedf(at.x, 0.01), snappedf(at.y, 0.01)], "lift": LIFTS.get(kind, 0.0), "yaw": 0.0}
	if what != "":
		item["what"] = what
	for field: Array in fields(item):
		match field[2]:
			"n":
				item[field[0]] = field[6]
			"b", "t":
				item[field[0]] = field[3]
			"c":
				item[field[0]] = field[4]
			"links":
				item[field[0]] = []
	if kind == "river":
		item["points"] = [item["at"], [item["at"][0] + 30.0, item["at"][1]]]
	return item


static func next_id(layout: Dictionary) -> int:
	var highest := 0
	for item: Dictionary in layout.get("items", []):
		highest = maxi(highest, int(item.get("id", 0)))
	return highest + 1


## The layout to play: the one saved on this device, or the one the game came with.
static func load_layout() -> Dictionary:
	if has_saved():
		var saved := from_text(FileAccess.get_file_as_string(SAVED))
		if not saved.is_empty():
			return saved
	return built_in()


static func built_in() -> Dictionary:
	if FileAccess.file_exists(BUILT_IN):
		var made := from_text(FileAccess.get_file_as_string(BUILT_IN))
		if not made.is_empty():
			return made
	return {"version": VERSION, "terrain": {}, "weather": 1, "mirage": HeatMirage.USUAL, "items": []}


static func has_saved() -> bool:
	return FileAccess.file_exists(SAVED)


## Keeps a layout on this device. Says whether it could.
static func save(layout: Dictionary) -> bool:
	var file := FileAccess.open(SAVED, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(to_text(layout))
	file.close()
	return true


## Throws away what was saved on this device: the level is as the game came with it again.
static func forget_saved() -> void:
	if has_saved():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED) if not OS.has_feature("web") else SAVED)


static func to_text(layout: Dictionary) -> String:
	return JSON.stringify(layout, "\t", false)


## A layout from text, or an empty Dictionary if the text is not one.
static func from_text(text: String) -> Dictionary:
	var read: Variant = JSON.parse_string(text)
	if not (read is Dictionary) or not (read as Dictionary).get("items") is Array:
		return {}
	var layout: Dictionary = read
	# (a level from before there was a mirage has the usual one)
	layout["mirage"] = float(layout.get("mirage", HeatMirage.USUAL))
	# (JSON has no whole numbers: put back the ones that are)
	for item: Dictionary in layout["items"]:
		item["id"] = int(item.get("id", 0))
		if item.has("links"):
			var links: Array = []
			for link: Variant in item["links"]:
				links.append(int(link))
			item["links"] = links
	return layout
