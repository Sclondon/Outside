extends "res://tools/pose_sheets.gd"
## Not part of the game. Draws what is worn (scripts/worn.gd) and what is swung, on the
## stage tools/pose_sheets.gd builds, to see that a helmet or the backpack sits right and
## does not go through whoever has it on.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/worn_sheets.gd -- <outdir> [heads figures moves swing] [anubis horus sobek bastet thoth khnum] [nopack] [lo]
##
##   heads     the boy's head and shoulders in each helmet from the front, three quarters,
##             the side and behind (`heads.png`), and again with the sculpted face and
##             the biggest hair there is, which the helmet must hide (`heads_curls.png`)
##   figures   the boy, his brother, three townspeople and the mummy in a row, each in a
##             helmet and the backpack, from four sides: a sheet for each helmet named
##             (`figures_anubis.png`...; with none named, all six)
##   moves     the boy in the first helmet named and the backpack, doing what
##             pose_sheets.gd draws: running, sneaking, sliding, crawling, hanging,
##             climbing, on a ladder, rolling, sitting and asleep, and running seen from
##             behind (`behind.png`)
##   swing     the boy swinging the khopesh, the pickaxe and the shovel (`swing_khopesh.png`...)
## With none of the four, all of them. `nopack` leaves the backpack off.

const GODS := ["anubis", "horus", "sobek", "bastet", "thoth", "khnum"]

var gods: Array = []
var pack := true


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	for word: String in only.duplicate():
		if word in GODS:
			gods.append(word)
			only.erase(word)
		elif word == "nopack":
			pack = false
			only.erase(word)
	if gods.is_empty():
		gods = GODS.duplicate()
	await frames(5)
	if wants("heads"):
		await heads("heads")
		Settings.face = "sculpt"
		Settings.hair = "curls"
		Settings.cap = false
		player._rig.restyle()
		await heads("heads_curls")
		Settings.undress()
		Worn.take_off(player._rig)
	if wants("figures"):
		await figures()
	if wants("moves"):
		Worn.put_on(player._rig, StringName("helmet_" + gods[0]))
		if pack:
			Worn.put_on(player._rig, &"backpack")
		await behind()
		for name: String in ["sprint", "sneak", "slide", "crawl", "hang", "climb", "ladder", "roll", "sit", "sleep"]:
			seed(hash(name))
			await call(name)
	if wants("swing"):
		Worn.take_off(player._rig)
		for tool: String in ["khopesh", "pickaxe", "shovel"]:
			await swing(tool)
	quit()


## The boy's head and shoulders in each helmet, from four sides.
func heads(name: String) -> void:
	place(Vector3(0, 0.05, 0), 0.0)
	hold_yaw = 0.0
	look_h = 1.06
	if pack:
		Worn.put_on(player._rig, &"backpack")
	for god: String in GODS:
		Worn.put_on(player._rig, StringName("helmet_" + god))
		await frames(30)
		for yaw: float in [0.0, 0.75, PI * 0.5, PI]:
			view = Vector3(yaw, 0.06, 1.7)
			await frames(2)
			await snap()
	hold_yaw = NAN
	look_h = 0.65
	sheet(name, 4)


## Everyone there is to wear them, stood in a row.
func figures() -> void:
	player.visible = false
	var stood: Array[Node3D] = []
	var boy := Figure.new()
	stood.append(boy)
	var brother := Figure.new()
	brother.model = load("res://models/brother.glb")
	brother.size = 1.25
	stood.append(brother)
	# Three townspeople: a man in a jacket, a grown woman, and a girl
	var wanted := [func(look: Dictionary) -> bool: return look["outfit"] == "suit",
		func(look: Dictionary) -> bool: return look["sex"] == CharacterLook.Sex.FEMALE and look["size"] > 1.25,
		func(look: Dictionary) -> bool: return look["sex"] == CharacterLook.Sex.FEMALE and look["size"] < 1.1]
	for want: Callable in wanted:
		for number in range(1, 200):
			if want.call(CharacterLook.random(number)):
				var someone := Townsperson.new()
				someone.seed = number
				someone.wander = 0.0
				stood.append(someone)
				break
	var mummy := Figure.new()
	mummy.model = load("res://models/mummy.glb")
	mummy.size = 1.3
	mummy.looseness = 0.2
	stood.append(mummy)
	for i in stood.size():
		# (on a slant, so that none is in front of another from any of the four sides)
		stood[i].position = Vector3(8.0 + i * 5.0, 0.02, -38.0 + i * 5.0)
		stage.add_child(stood[i])
	for someone in stood:
		if pack:
			Worn.put_on(someone, &"backpack")
	hold_yaw = 0.0
	for god: String in gods:
		for someone in stood:
			Worn.put_on(someone, StringName("helmet_" + god))
		await frames(40)
		for someone in stood:
			var tall: float = (someone.get(&"rig") as Node3D).scale.y
			pin = someone.global_position + Vector3.UP * 0.92 * tall
			for yaw: float in [0.0, 0.75, PI * 0.5, PI]:
				view = Vector3(yaw, 0.06, 2.3 * tall)
				await frames(2)
				await snap()
		sheet("figures_" + god, 4)
	pin = Vector3.INF
	hold_yaw = NAN
	for someone in stood:
		someone.queue_free()
	player.visible = true
	await frames(2)


## Running, seen from behind and from behind and above: where a pack shows most.
func behind() -> void:
	await strip("behind", Vector3(1, 0, 0), 70, 4, 6, Vector3(PI - 0.5, 0.2, 3.0))
	await strip("behind_walk", Vector3(1, 0, 0), 60, 6, 6, Vector3(PI - 0.9, 0.1, 2.6), 0.5)


## He picks a thing up and swings it, as pose_sheets.gd does the bat.
func swing(tool: String) -> void:
	place(Vector3(0, 0.05, 0), PI * 0.5)
	var held := (load("res://props/%s.tscn" % tool) as PackedScene).instantiate() as RigidBody3D
	held.position = Vector3(0.4, 0.1, 0.0)
	held.rotation.z = PI * 0.5
	held.freeze = true
	stage.add_child(held)
	view = Vector3(0.5, 0.12, 3.6)
	await frames(40)
	player._act()
	await frames(90)
	await snap()
	view = Vector3(PI * 0.5 - 0.4, 0.12, 3.6)
	await frames(2)
	await snap()
	view = Vector3(0.5, 0.12, 3.6)
	player._act()
	for i in 10:
		await frames(4)
		await snap()
	sheet("swing_" + tool, 4)
	for yaw: float in [0.5, PI * 0.5 - 0.2]:
		view = Vector3(yaw, 0.12, 3.4)
		await frames(50)
		player._act()
		for i in 12:
			await frames(3)
			await snap()
	sheet("swing_%s_fine" % tool, 6)
	held.queue_free()
	player._let_go()
	await frames(3)
