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
		["Cobweb: corner", "cobweb", "corner"], ["Cobweb: across a passage", "cobweb", "sheet"], ["Cobweb: hanging", "cobweb", "hanging"], ["Cobweb: draped", "cobweb", "drape"],
		["Inscription", "inscription", ""],
	],
	"Camp": [
		["Palm", "prop", "palm_a"], ["Bent palm", "prop", "palm_b"], ["Small palm", "prop", "palm_c"],
		["Doum palm", "prop", "palm_doum"], ["Palm bush", "prop", "palm_sucker"], ["Reeds", "prop", "reeds"],
		["Dry shrub", "prop", "shrub_dry"], ["Grass tuft", "prop", "grass_tuft"],
		["Tent", "prop", "tent"], ["Awning", "prop", "awning"], ["Scaffold", "prop", "scaffold"], ["Crate", "prop", "crate"],
		["Big jar", "prop", "pot_large"], ["Brazier", "prop", "brazier"], ["Torch", "prop", "torch_stand"], ["Campfire", "prop", "campfire"],
		["Pot", "prop", "pot"], ["Canopic jar", "prop", "jar_canopic"], ["Jackal jar", "prop", "jar_canopic_jackal"], ["Stone to throw", "prop", "rock_small"],
	],
	# An excavation of the 1910s. The pick, the shovel, the turia and the khopesh are swung as a bat is;
	# the trowel, brush, tape, lantern and basket of spoil are picked up; the rest is fixed.
	"Dig": [
		["Pickaxe", "prop", "pickaxe"], ["Shovel", "prop", "shovel"], ["Turia (hoe)", "prop", "turia"], ["Trowel", "prop", "trowel"],
		["Hand brush", "prop", "brush"], ["Brushes", "prop", "brushes"], ["Tape measure", "prop", "tape_measure"], ["Lantern", "prop", "lantern"],
		["Basket of spoil", "prop", "dig_basket"], ["Baskets", "prop", "dig_baskets"], ["Sieve", "prop", "sieve"], ["Wheelbarrow", "prop", "wheelbarrow"],
		["Tools", "prop", "dig_tools"], ["Surveyor's level", "prop", "surveyor_level"], ["Plumb line", "prop", "plumb_tripod"],
		["Ranging pole", "prop", "ranging_pole"], ["Levelling staff", "prop", "measuring_staff"], ["Crate of finds", "prop", "crate_finds"],
		["Camp table", "prop", "camp_table"], ["Backpack", "prop", "backpack"], ["Bedroll", "prop", "bedroll"],
		["Khopesh", "prop", "khopesh"], ["Khopesh on a rack", "prop", "khopesh_stand"],
		["Helmet: Anubis", "prop", "helmet_anubis"], ["Helmet: Horus", "prop", "helmet_horus"], ["Helmet: Sobek", "prop", "helmet_sobek"],
		["Helmet: Bastet", "prop", "helmet_bastet"], ["Helmet: Thoth", "prop", "helmet_thoth"], ["Helmet: Khnum", "prop", "helmet_khnum"],
	],
	"People": [
		["Townsperson", "person", "townsperson"], ["Brother", "person", "brother"], ["Cat", "person", "cat"],
		["Hound", "person", "hound"], ["Mummy", "person", "mummy"], ["Camel", "person", "camel"],
		["Scarab swarm", "person", "scarabs"], ["Scarabs (harmless)", "person", "scarabs_harmless"],
		["Mummified jackal", "person", "jackal_mummy"], ["Hyena", "person", "hyena"],
		["Crocodile", "person", "crocodile"],
		["Birds", "person", "birds"],
	],
	"Puzzle": [
		["Pressure plate", "plate", ""], ["Door", "door", ""], ["Bridge or lift", "mover", ""], ["Block to push", "prop", "block_push"],
		# (more to make puzzles of: README, "More puzzle parts")
		["Lever", "lever", ""], ["Key", "key", ""], ["Lock", "lock", ""], ["Timed plate", "plate", "timed"], ["Seal stone", "plate", "seal"],
		["Sun lens", "beam", ""], ["Mirror", "mirror", ""], ["Sun disc", "sundisc", ""], ["Sluice", "sluice", ""],
		["Offering table", "offering", ""], ["Brazier to light", "brazier", ""],
		["Torch to carry", "torch", ""], ["Grappling hook", "grapple", ""], ["Grapple point", "grapple_point", ""], ["Rope", "rope", ""], ["Ladder", "ladder", ""], ["Sand fall", "sandfall", ""], ["Checkpoint", "checkpoint", ""], ["Where he starts", "start", ""], ["Sign", "sign", ""],
		["Scarab amulet", "amulet", ""], ["Scarab socket", "plate", "scarab"],
	],
	"Guns": [
		["Revolver", "thing", "revolver"], ["Rifle", "thing", "rifle"], ["Shotgun", "thing", "shotgun"], ["Flare pistol", "thing", "flare_pistol"],
		["Cartridges", "thing", "ammo_box"], ["Target board", "thing", "target_board"], ["Gong", "thing", "target_gong"],
		["Pot to shoot", "thing", "target_pot"], ["Bottle", "thing", "bottle"], ["Tin can", "thing", "tin_can"],
	],
	# A railway of about 1910 (PROPS.md, "The railway"). A "Train" is vehicles coupled up that run (`scripts/train.gd`);
	# each vehicle is also a prop by itself, standing where it is put. Track and what stands by a line are props.
	"Railway": [
		["Train", "train", ""], ["Engine", "prop", "loco"], ["Tender", "prop", "tender"], ["Carriage", "prop", "carriage"],
		["Third-class carriage", "prop", "carriage_third"], ["Goods van", "prop", "van_goods"], ["Open wagon", "prop", "wagon_open"],
		["Wagon of finds", "prop", "wagon_finds"], ["Flat wagon", "prop", "wagon_flat"], ["Tank wagon", "prop", "wagon_tank"], ["Brake van", "prop", "van_brake"],
		["Track", "prop", "track_straight"], ["Curved track", "prop", "track_curve"], ["Points", "prop", "track_points"], ["Buffer stop", "prop", "buffer_stop"],
		["Level crossing", "prop", "level_crossing"], ["Low bridge", "prop", "bridge_low"], ["Loading gauge", "prop", "loading_gauge"],
		["Signal", "prop", "signal_semaphore"], ["Telegraph pole", "prop", "telegraph_pole"], ["Water tower", "prop", "water_tower"], ["Water column", "prop", "water_column"],
		["Platform", "prop", "halt_platform"], ["Station building", "prop", "halt_shelter"], ["Name board", "prop", "station_nameboard"],
		["Station lamp", "prop", "halt_lamp"], ["Bench", "prop", "halt_bench"], ["Luggage", "prop", "luggage"],
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
	# (`sort` is which kind of mummy, in the order of `Mummy.Kind`; "kind" is already what sort of thing an item is)
	"person:mummy": [["sort", "Kind", "c", ["Shambler", "Priest", "Brute", "Crawler", "Child", "Royal"], 0], ["alert", "Wakes within", "n", 0.0, 40.0, 0.5, 6.0], ["links", "Woken by", "links"]],
	"person:camel": [["saddled", "Saddled", "b", false], ["packed", "Carries packs", "b", false], ["tethered", "Tethered", "b", false], ["couched", "Couched", "b", false],
		["roam", "Roams", "n", 0.0, 30.0, 0.5, 6.0]],
	# (`rest` and `finery` are in the order of `JackalMummy.Rest` and `JackalMummy.Finery`)
	"person:jackal_mummy": [["rest", "Waits", "c", ["Lying", "Standing"], 0], ["finery", "Wears", "c", ["Wrappings", "Collar", "Mask and collar"], 0],
		["alert", "Wakes within", "n", 0.0, 40.0, 0.5, 5.0], ["links", "Woken by", "links"]],
	"person:hyena": [["bold", "How bold", "n", 0.0, 1.0, 0.05, 0.4], ["roam", "Roams", "n", 0.0, 40.0, 1.0, 12.0]],
	"person:crocodile": [["docile", "Docile", "b", false], ["reach", "Comes this far from the water", "n", 0.0, 20.0, 0.5, 5.0]],
	# (`bird` is which kind, in the order of `Birds.Kind`; they find their own perches, ground and water within their range)
	"person:birds": [["bird", "Kind", "c", ["Sparrows", "Doves", "Hoopoe", "Swallows", "Sacred ibis", "Grey heron", "Cattle egret", "Egyptian goose", "Kestrel", "Pied kingfisher", "Egyptian vulture", "Griffon vulture", "Black kite"], 1],
		["count", "How many", "n", 1.0, 40.0, 1.0, 8.0], ["roam", "They range", "n", 5.0, 150.0, 1.0, 30.0]],
	"plate": [["span_x", "Width", "n", 0.6, 8.0, 0.1, 1.6], ["span_z", "Length", "n", 0.6, 8.0, 0.1, 1.6], ["latches", "Stays down", "b", false], ["only_him", "Only he presses it", "b", false]],
	# --- More puzzle parts. What is on or off, and so works what a plate works: a lever (`Lever`), a lock that has been
	# given its key (`KeyLock`, `DoorKey`: `which` is the metal, in the order of `DoorKey.Metal`), a plate that stays down
	# for a time (`TimedPlate`), a seal stone (`SealStone`), a sun disc with the light on it (`SunDisc`), an offering table
	# with a jar on it (`OfferingTable`), a brazier that has been lit (`ColdBrazier`). And what is worked: the light itself
	# (`SunBeam`), and a sluice (`Sluice`), which lets down the nearest tank of water. A mirror (`Mirror`) is neither.
	"lever": [["starts_on", "Pulled already", "b", false], ["returns", "Springs back after (0: stays)", "n", 0.0, 60.0, 0.5, 0.0]],
	"key": [["which", "Made of", "c", ["Iron", "Bronze", "Gold"], 0]],
	"lock": [["which", "Opened by the key of", "c", ["Iron", "Bronze", "Gold"], 0]],
	"plate:timed": [["span_x", "Width", "n", 0.6, 8.0, 0.1, 1.2], ["span_z", "Length", "n", 0.6, 8.0, 0.1, 1.2], ["seconds", "Stays down for", "n", 1.0, 120.0, 0.5, 6.0],
		["only_him", "Only he presses it", "b", true]],
	"plate:seal": [["span_x", "Width", "n", 0.6, 8.0, 0.1, 1.1], ["span_z", "Length", "n", 0.6, 8.0, 0.1, 1.6], ["latches", "Stays down", "b", true]],
	"beam": [["height", "Height of the light", "n", 0.4, 12.0, 0.05, 0.7], ["pitch", "Tipped up", "n", -80.0, 80.0, 1.0, 0.0], ["reach", "Reaches", "n", 2.0, 80.0, 1.0, 40.0],
		["stand", "On a stand", "b", true], ["shining", "Shining", "b", true], ["links", "Covered and uncovered by", "links"]],
	"mirror": [["height", "Height", "n", 0.6, 6.0, 0.05, 0.7], ["step", "A press turns it", "n", 5.0, 90.0, 2.5, 45.0], ["turned", "Turned already (presses)", "n", 0.0, 35.0, 1.0, 0.0],
		["tilt", "Tipped up", "n", -60.0, 60.0, 1.0, 0.0], ["fixed", "He cannot turn it", "b", false]],
	"sundisc": [["height", "Height", "n", 0.6, 6.0, 0.05, 0.7], ["latches", "Stays lit", "b", false]],
	"sluice": [["drop", "Lets the water down by", "n", 0.2, 8.0, 0.1, 2.0], ["speed", "Speed", "n", 0.1, 3.0, 0.05, 0.6], ["links", "Opened by", "links"],
		["needs_all", "Needs every one", "b", false], ["inverted", "Open until then", "b", false]],
	"offering": [["latches", "Stays on once given", "b", true]],
	"brazier": [["lit", "Burning already", "b", false]],
	# --- (the end of them)
	"door": [["wide", "Width", "n", 0.6, 12.0, 0.1, 3.0], ["tall", "Height", "n", 1.0, 12.0, 0.1, 2.6], ["thick", "Thickness", "n", 0.2, 3.0, 0.05, 0.4],
		["links", "Opened by", "links"], ["needs_all", "Needs every one", "b", false], ["inverted", "Open until then", "b", false]],
	"mover": [["wide", "Width", "n", 0.6, 16.0, 0.1, 2.4], ["long", "Length", "n", 0.6, 20.0, 0.1, 4.0], ["thick", "Thickness", "n", 0.1, 3.0, 0.05, 0.3],
		["travel", "Travels", "n", 0.5, 30.0, 0.25, 4.0], ["way", "Which way", "c", ["Forward", "Up", "Sideways"], 0], ["speed", "Speed", "n", 0.3, 8.0, 0.1, 2.0],
		["links", "Worked by", "links"], ["needs_all", "Needs every one", "b", false], ["inverted", "Out until then", "b", false]],
	"torch": [["lit", "Burning", "b", true]],
	"rope": [["length", "Length", "n", 2.0, 16.0, 0.25, 5.5]],
	"grapple": [["reach", "Length of its rope", "n", 4.0, 16.0, 0.5, 9.5]],
	"grapple_point": [["ring", "Shows an iron ring", "b", true]],
	"ladder": [["height", "Height", "n", 1.0, 16.0, 0.25, 4.0]],
	"sandfall": [["width", "Width", "n", 0.0, 8.0, 0.25, 0.0], ["running", "Running", "b", true], ["links", "Turned by", "links"]],
	"checkpoint": [],
	"start": [],
	"sign": [["text", "Says", "t", "A SIGN"]],
	# Scarabs (`scripts/scarab_swarm.gd`): a swarm that comes out of its nest after him, and a few that only wander.
	"person:scarabs": [["count", "How many", "n", 20.0, 300.0, 10.0, 120.0], ["chase", "How far they chase", "n", 5.0, 60.0, 1.0, 22.0], ["fire", "Fire holds them off", "b", true],
		["alert", "Come out within", "n", 0.0, 40.0, 0.5, 8.0], ["links", "Let out by", "links"]],
	"person:scarabs_harmless": [["count", "How many", "n", 1.0, 30.0, 1.0, 5.0], ["roam", "Wander", "n", 0.5, 10.0, 0.5, 2.5], ["ball", "One rolls a ball", "b", true]],
	# A scarab of gold to carry, and the stone it is laid in, which is a plate that only it presses.
	"amulet": [],
	"plate:scarab": [["latches", "Stays on", "b", true]],
	# Cobwebs (`scripts/cobweb.gd`).
	"cobweb:corner": [["size", "Size", "n", 0.3, 3.0, 0.05, 1.0], ["height", "Height of the corner", "n", 0.0, 8.0, 0.05, 2.4], ["tilt_x", "Tip forward", "n", -180.0, 180.0, 1.0, 0.0],
		["dust", "Dust", "n", 0.0, 1.0, 0.05, 0.45], ["seed", "Which web", "n", 0.0, 99.0, 1.0, 1.0]],
	"cobweb:sheet": [["wide", "Width", "n", 0.8, 8.0, 0.1, 2.4], ["tall", "Height", "n", 1.0, 6.0, 0.1, 2.4], ["dust", "Dust", "n", 0.0, 1.0, 0.05, 0.45], ["seed", "Which web", "n", 0.0, 99.0, 1.0, 1.0]],
	"cobweb:hanging": [["size", "Length", "n", 0.2, 3.0, 0.05, 0.9], ["wide", "Over a width of", "n", 0.2, 6.0, 0.1, 1.6], ["height", "Hangs from", "n", 0.0, 8.0, 0.05, 2.4],
		["dust", "Dust", "n", 0.0, 1.0, 0.05, 0.45], ["seed", "Which web", "n", 0.0, 99.0, 1.0, 1.0]],
	"cobweb:drape": [["size", "Size", "n", 0.3, 4.0, 0.05, 1.0], ["dust", "Dust", "n", 0.0, 1.0, 0.05, 0.6], ["seed", "Which web", "n", 0.0, 99.0, 1.0, 1.0]],
	# Writing carved in hieroglyphs (`scripts/inscription.gd`): what is typed, or one of the texts in `InscriptionTexts`.
	"inscription": [["text", "Says", "t", "The king lives forever"], ["named", "Or a text", "c", InscriptionTexts.TITLES, 0],
		["width", "Width", "n", 0.4, 24.0, 0.1, 2.4], ["height", "Height", "n", 0.3, 8.0, 0.1, 1.2], ["columns", "In columns", "b", false], ["rtl", "Read from the right", "b", false],
		["sign", "Size of a sign (0: to fit)", "n", 0.0, 1.0, 0.05, 0.0], ["fill", "Repeats to fill it", "b", false], ["carved", "Carved", "b", true], ["painted", "Painted", "b", false],
		["wear", "Weathered", "n", 0.0, 1.0, 0.05, 0.2], ["slab", "On a slab of its own", "b", true], ["both", "On both faces", "b", false],
		["stone", "Stone", "c", ["Sandstone", "Pale limestone", "Red sandstone", "Dark stone"], 0]],
	# A train (`Train.from_item`): what it is made up of, how fast it goes and how far, and which way the ride is staged.
	"train": [["engine", "Engine and tender", "b", true], ["carriages", "Carriages", "n", 0.0, 4.0, 1.0, 1.0], ["wagons", "Goods wagons", "n", 0.0, 6.0, 1.0, 2.0],
		["brake", "Brake van", "b", true], ["speed", "Speed", "n", 1.0, 20.0, 0.5, 8.0], ["run", "Runs for", "n", 10.0, 400.0, 5.0, 80.0],
		["round", "At the end", "c", ["Stops", "Comes round again", "Goes back"], 0], ["staging", "What moves", "c", ["The train", "The world"], 0],
		["running", "Running", "b", false], ["links", "Started and stopped by", "links"]],
}

## How far above the ground each kind is put when it is first set down.
const LIFTS := {"rope": 6.0, "grapple": 0.3, "grapple_point": 5.0, "sandfall": 5.0, "sign": 3.0, "person": 0.15, "door": 1.3, "mover": 0.5}


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
