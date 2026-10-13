extends RefCounted
## Not part of the game. Tombs made by hand for the tools to build, play and
## draw (`tools/tomb_test.gd`, `tools/tomb3d_sheets.gd`): each has something
## that a tomb from the generator may not.


## A tomb with one of every lock the tomb editor offers, and every thing to carry.
static func every_lock() -> Dictionary:
	var spec := TombSpec.fresh("Every lock")
	var rooms: Array = []
	for role: String in ["entrance", "corridor", "hall", "well", "gallery", "corridor", "antechamber", "corridor", "corridor", "burial"]:
		rooms.append(TombSpec.room(role))
	rooms[0]["torch"] = 1
	rooms[0]["jar"] = 1
	rooms[1]["hook"] = 1
	rooms[2]["lock"] = "cross"
	rooms[2]["way"] = "stairs"
	rooms[3]["lock"] = "lever_below"
	rooms[3]["stone_in"] = 3
	rooms[4]["lock"] = "brazier"
	rooms[4]["dark"] = true
	rooms[4]["way"] = "stairs"
	rooms[5]["lock"] = "offering"
	rooms[6]["lock"] = "lever_above"
	rooms[6]["stone_in"] = 5
	rooms[6]["way"] = "stairs"
	rooms[7]["way"] = "gap"
	rooms[8]["lock"] = "bypass"
	rooms[9]["mummy"] = 0
	spec["rooms"] = rooms
	return spec


## A tomb with the two-plate door, the rope and the sand: the torch for the
## brazier beyond them is dropped down the shaft with, and carried up the heap.
static func three_new() -> Dictionary:
	var spec := TombSpec.fresh("Two plates, a rope, the sand")
	var rooms: Array = []
	for role: String in ["entrance", "corridor", "hall", "corridor", "gallery", "antechamber", "corridor", "burial"]:
		rooms.append(TombSpec.room(role))
	rooms[0]["torch"] = 1
	rooms[2]["lock"] = "pair"
	rooms[2]["way"] = "stairs"
	rooms[3]["way"] = "rope"
	rooms[4]["way"] = "sand"
	rooms[5]["lock"] = "brazier"
	rooms[5]["dark"] = true
	rooms[5]["way"] = "sand"
	rooms[6]["way"] = "stairs"
	spec["rooms"] = rooms
	return spec


## A tomb whose only way on is up the sand, which a block on its plate lets in.
static func only_sand() -> Dictionary:
	var spec := TombSpec.fresh("Only the sand")
	spec["rooms"] = [TombSpec.room("entrance"), TombSpec.room("corridor"), TombSpec.room("burial")]
	spec["rooms"][1]["way"] = "sand"
	spec["rooms"][1]["lock"] = "work"
	return spec


## A tomb with every way there is between rooms, one after another, and a
## mummy behind each thing that holds one: for looking at.
static func every_way() -> Dictionary:
	var spec := TombSpec.fresh("Every way")
	var rooms: Array = []
	for role: String in ["entrance", "corridor", "hall", "corridor", "gallery", "corridor", "antechamber", "corridor", "corridor", "burial"]:
		rooms.append(TombSpec.room(role))
	rooms[0]["way"] = "stairs"
	rooms[0]["hook"] = 1
	rooms[1]["way"] = "crawl"
	rooms[1]["mummy"] = 1
	rooms[2]["way"] = "gap"
	rooms[2]["mummy"] = 2
	rooms[3]["way"] = "flood"
	rooms[4]["way"] = "shaft"
	rooms[4]["mummy"] = 0
	rooms[5]["way"] = "open"
	rooms[6]["way"] = "rope"
	rooms[7]["way"] = "sand"
	rooms[8]["way"] = "stairs"
	rooms[9]["mummy"] = 5
	spec["rooms"] = rooms
	return spec


## A plan whose rooms have been given their cells by hand, as `TombBranching`
## gives them to the tombs it makes: a side chamber off the hall, reached by a crawl, and a
## way on from it that comes round to the room beyond the hall, so that there
## are two ways to there. The door to the burial chamber is opened from the
## room at the far corner of that loop. (It was written before there was a
## generator for such tombs, and is kept as one whose every number is known. Already solved: `solution` is its way through.)
static func branching() -> TombPlan:
	var plan := TombPlan.new()
	plan.seed_value = 7001
	plan.difficulty = 1
	# [role, cell]: x and z the square, y the level
	var set_out: Array = [
		[TombPlan.Role.ENTRANCE, Vector3i(0, 0, 0)], [TombPlan.Role.CORRIDOR, Vector3i(1, 1, 0)], [TombPlan.Role.HALL, Vector3i(2, 1, 0)],
		[TombPlan.Role.CORRIDOR, Vector3i(2, 1, 1)], [TombPlan.Role.ANTECHAMBER, Vector3i(3, 1, 0)], [TombPlan.Role.GALLERY, Vector3i(3, 1, 1)],
		[TombPlan.Role.BURIAL, Vector3i(4, 2, 0)],
	]
	for i in set_out.size():
		var room := plan.add_room(set_out[i][0])
		room.spine = i
		room.cell = set_out[i][1]
	plan.add_link(0, 1, TombPlan.Pass.STAIRS)
	plan.add_link(1, 2, TombPlan.Pass.OPEN)
	var east := plan.add_link(2, 4, TombPlan.Pass.OPEN)
	plan.add_link(2, 3, TombPlan.Pass.CRAWL)
	plan.add_link(4, 5, TombPlan.Pass.OPEN)
	plan.add_link(3, 5, TombPlan.Pass.OPEN)
	var last := plan.add_link(4, 6, TombPlan.Pass.STAIRS)
	plan.add_trigger(TombPlan.Switch.TREASURE, 6)
	east.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, 2).id]
	east.hint = "weight"
	last.switches = [plan.add_trigger(TombPlan.Switch.LEVER, 5).id]
	last.hint = "lever_below"
	plan.rooms[3].mummy = 1
	plan.rooms[3].barrier = TombPlan.Barrier.KERB
	var proof := TombSolver.solve(plan)
	plan.solution = proof["steps"]
	plan.proof = proof
	return plan


## A tomb with the creatures that keep a way: a gate guardian whose leaf lies
## in the open in the room before, another whose leaf is up in a loft, and a
## sphinx that wants the torch from the first corridor.
static func keepers() -> Dictionary:
	var spec := TombSpec.fresh("Keepers")
	var rooms: Array = []
	for role: String in ["entrance", "corridor", "antechamber", "corridor", "hall", "corridor", "burial"]:
		rooms.append(TombSpec.room(role))
	rooms[2]["lock"] = "name"
	rooms[2]["stone_in"] = 1
	rooms[2]["way"] = "stairs"
	rooms[4]["lock"] = "name_above"
	rooms[4]["stone_in"] = 3
	rooms[1]["torch"] = 1
	rooms[5]["lock"] = "sphinx_torch"
	rooms[5]["way"] = "stairs"
	spec["rooms"] = rooms
	return spec


## A tomb with a sphinx that wants a jar, and a torch lying about as well to
## give it by mistake.
static func one_sphinx() -> Dictionary:
	var spec := TombSpec.fresh("One sphinx")
	var rooms: Array = []
	for role: String in ["entrance", "corridor", "hall", "corridor", "burial"]:
		rooms.append(TombSpec.room(role))
	rooms[1]["jar"] = 1
	rooms[1]["torch"] = 1
	rooms[2]["lock"] = "sphinx_jar"
	spec["rooms"] = rooms
	return spec
