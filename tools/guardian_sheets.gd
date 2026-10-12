extends SceneTree
## Not part of the game. Pictures of the gate guardians and the leaves of the Book of the Dead:
##   heads    every head, from the front quarter and from the side
##   round    one guardian from all round, in wrappings and in a kilt
##   far      a row of them at the distance the game's camera sees them from, with the boy for size
##   idle     its head following the boy as he walks past, its knives twitching
##   strike   a wrong name: it rises and strikes (consecutive moments)
##   named    the right name: it bows, lowers its knives, and the knives across the gateway go up
##   dark     the same gate in the dark, by the light of a torch
##   leaf     a leaf lying, and one rolled
##   panel    the three names on a phone's screen (1560 x 720), without the leaf and with it; and the leaf to read
##   book     the drawings of all thirteen keepers with their names, as the papyrus has them
##   yard     the station in the test yard, and the notebook open at its page of the leaves found
## Strips are consecutive moments, left to right and top to bottom.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/guardian_sheets.gd -- <outdir> [heads round far idle strike named dark leaf panel book yard]
## (`panel` and `book` are the whole window, so for them: --resolution 1560x720)

const CELL := 480
var out := ""
var names: Array[String] = []
var cells: Array[Image] = []
var cam: Camera3D
var world: WorldEnvironment
var sun: DirectionalLight3D
var stage: Node3D
var touch: TouchControls
var player: Player


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	for i in range(1, args.size()):
		names.append(args[i])
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func wanted(name: String) -> bool:
	return names.is_empty() or names.has(name)


func snap() -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


## The whole window, as it is, to a file of its own.
func whole(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("PICTURE ", name)


func sheet(name: String, columns: int) -> void:
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	page.save_png(out.path_join(name + ".png"))
	cells.clear()
	print("SHEET ", name)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func light(day: bool) -> void:
	world.environment.background_color = Color(0.5, 0.56, 0.62) if day else Color(0.015, 0.017, 0.025)
	world.environment.ambient_light_energy = 0.7 if day else 0.05
	sun.light_energy = 1.2 if day else 0.0


func look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov


func box(at: Vector3, size: Vector3, colour: Color, solid := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(colour)
	body.add_child(visual)
	body.position = at
	stage.add_child(body)
	return body


func put(at: Vector3, facing := 0.0) -> void:
	touch.move = Vector2.ZERO
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.facing_yaw = facing


func keeper(at: Vector3, who: int, more := {}) -> GateGuardian:
	var made := GateGuardian.new()
	made.who = who
	made.asks_at_threshold = false
	for key: String in more:
		made.set(key, more[key])
	made.position = at
	stage.add_child(made)
	return made


## A wall with a gateway in it, for a guardian at `at` to keep.
func gateway(at: Vector3, made: GateGuardian) -> void:
	var middle := at + Vector3(made.gate_at, 0.0, -0.75 if made.gate_at != 0.0 else 0.0)
	var stone := Color(0.6, 0.54, 0.46)
	for side: float in [-1.0, 1.0]:
		box(middle + Vector3(side * (made.wide * 0.5 + 1.5), 1.6, 0.0), Vector3(3.0, 3.2, 0.4), stone)
	box(middle + Vector3(0.0, made.tall + 0.3, 0.0), Vector3(made.wide, 0.6, 0.4), stone)


func clear() -> void:
	for child in stage.get_children():
		if child is GateGuardian or child is BookPage or (child is StaticBody3D and child.position.y > 0.0) or child is HandTorch:
			child.queue_free()
	if is_instance_valid(GuardianPanel.current):
		GuardianPanel.current.put_away()
	await frames(2)


func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world = WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(160, 2, 160), Color(0.7, 0.62, 0.46))
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = Vector3(0, 0.05, 30)
	player.rest_enabled = false
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	light(true)
	await frames(20)

	if wanted("heads"):
		for kind in BookOfTheDead.HEADS.size():
			var made := keeper(Vector3.ZERO, 0, {"head": kind, "notice": 0.0})
			await frames(4)
			look(Vector3(1.1, 1.75, 1.9), Vector3(0, 1.65, 0.05), 40.0)
			await snap()
			look(Vector3(2.4, 1.6, 0.1), Vector3(0, 1.6, 0.1), 40.0)
			await snap()
			made.queue_free()
			await frames(2)
		await sheet("heads", 6)

	if wanted("round"):
		for dress: int in [GateGuardian.Dress.WRAPPINGS, GateGuardian.Dress.KILT]:
			var made := keeper(Vector3.ZERO, 6 if dress == 0 else 11, {"dress": dress, "notice": 0.0})
			await frames(4)
			for n in 6:
				var turn := TAU * n / 6.0 + 0.4
				look(Vector3(sin(turn) * 4.2, 1.9, cos(turn) * 4.2), Vector3(0, 1.0, 0), 38.0)
				await snap()
			made.queue_free()
			await frames(2)
		await sheet("round", 6)
		var tris := GuardianMesh.Clay.new()
		for kind in BookOfTheDead.HEADS.size():
			var clay := GuardianMesh.Clay.new()
			GuardianMesh.head(clay, kind)
			print("  head ", BookOfTheDead.HEADS[kind], ": ", clay.triangles(), " triangles")

	if wanted("far"):
		# As the game's camera sees them: the boy among them for size.
		var row: Array[int] = [8, 6, 2, 7, 12, 1, 0, 10, 11]
		for n in row.size():
			keeper(Vector3((n - 4) * 2.2, 0, 0), row[n], {"notice": 0.0, "dress": n % 2})
		put(Vector3(0.0, 0.05, 2.2), PI)
		await frames(30)
		look(Vector3(0, 4.2, 15.0), Vector3(0, 1.0, 0), 40.0)
		await snap()
		look(Vector3(-5.0, 3.0, 8.0), Vector3(-3.0, 1.0, 0), 40.0)
		await snap()
		look(Vector3(5.0, 3.0, 8.0), Vector3(3.0, 1.0, 0), 40.0)
		await snap()
		await sheet("far", 3)
		put(Vector3(0, 0.05, 30))
		await clear()

	if wanted("idle"):
		var made := keeper(Vector3.ZERO, 8)
		look(Vector3(0.6, 2.0, 5.2), Vector3(0, 1.2, 0), 40.0)
		for n in 6:
			put(Vector3(-2.5 + n, 0.05, 2.0), PI)
			await frames(40)
			await snap()
		await sheet("idle", 6)
		put(Vector3(0, 0.05, 30))
		await clear()

	if wanted("strike"):
		var made := keeper(Vector3.ZERO, 5, {"bars_way": true})
		gateway(Vector3.ZERO, made)
		put(Vector3(1.9, 0.05, 1.0), PI)
		await frames(30)
		look(Vector3(5.2, 2.2, 5.0), Vector3(0.9, 1.2, 0), 40.0)
		await snap()
		var wrong := 0 if made.who != 0 else 1
		made.dealt = [wrong, made.who, 2]
		made.answer(wrong)
		for n in 9:
			await frames(5)
			await snap()
		await frames(60)
		await snap()
		await frames(50)
		await snap()
		await sheet("strike", 6)
		put(Vector3(0, 0.05, 30))
		await clear()

	if wanted("named"):
		var made := keeper(Vector3.ZERO, 7, {"bars_way": true})
		gateway(Vector3.ZERO, made)
		put(Vector3(1.9, 0.05, 1.6), PI)
		await frames(30)
		look(Vector3(5.2, 2.2, 5.0), Vector3(0.9, 1.2, 0), 40.0)
		await snap()
		made.answer(made.who)
		for n in 5:
			await frames(18)
			await snap()
		await sheet("named", 6)
		put(Vector3(0, 0.05, 30))
		await clear()

	if wanted("dark"):
		light(false)
		var made := keeper(Vector3.ZERO, 1, {"bars_way": true})
		gateway(Vector3.ZERO, made)
		var torch := HandTorch.new()
		torch.position = Vector3(1.6, 0.3, 2.4)
		torch.freeze = true
		stage.add_child(torch)
		put(Vector3(1.9, 0.05, 2.4), PI)
		await frames(20)
		player._act()
		await frames(60)
		look(Vector3(5.2, 2.2, 5.6), Vector3(0.9, 1.2, 0), 40.0)
		await snap()
		put(Vector3(0.6, 0.05, 1.5), PI)
		await frames(40)
		look(Vector3(2.6, 1.9, 4.2), Vector3(0.3, 1.3, 0), 40.0)
		await snap()
		made.dealt = [0, 1, 2]
		made.answer(0)
		await frames(22)
		await snap()
		await frames(8)
		await snap()
		await sheet("dark", 4)
		if player.carried:
			player._let_go()
		put(Vector3(0, 0.05, 30))
		light(true)
		await clear()

	if wanted("leaf"):
		var lying := BookPage.new()
		lying.who = 6
		lying.reach = 0.0
		lying.position = Vector3(-0.6, 0, 0)
		stage.add_child(lying)
		var roll := BookPage.new()
		roll.who = 7
		roll.rolled = true
		roll.reach = 0.0
		roll.position = Vector3(0.6, 0, 0)
		stage.add_child(roll)
		put(Vector3(0.0, 0.05, -1.4), 0.0)
		await frames(20)
		look(Vector3(0.0, 1.0, 2.0), Vector3(0, 0.2, 0), 40.0)
		await snap()
		await frames(50)
		await snap()
		look(Vector3(0, 4.2, 10.0), Vector3(0, 0.5, 0), 40.0)
		await snap()
		light(false)
		await frames(3)
		await snap()
		light(true)
		await sheet("leaf", 4)
		put(Vector3(0, 0.05, 30))
		await clear()

	if wanted("panel"):
		var made := keeper(Vector3.ZERO, 2)
		look(Vector3(0.6, 2.0, 5.2), Vector3(0, 1.2, 0), 40.0)
		await frames(5)
		made.challenge()
		await frames(8)
		await whole("panel_without_leaf")
		GuardianPanel.current.choose(-1)
		await frames(4)
		BookOfTheDead.of(made).take(made.who)
		made.challenge()
		await frames(8)
		await whole("panel_with_leaf")
		GuardianPanel.current._held = made.dealt[0]
		await frames(3)
		await whole("panel_pressed")
		GuardianPanel.current.choose(-1)
		await frames(4)
		for who: int in [2, 6, 11]:
			GuardianPanel.read(made, who)
			await frames(40)
			await whole("leaf_%d" % who)
			GuardianPanel.current.choose(-1)
			await frames(4)
		await clear()

	if wanted("book"):
		var page := BookSheet.new()
		var layer := CanvasLayer.new()
		layer.add_child(page)
		root.add_child(layer)
		await frames(4)
		await whole("book")
		layer.queue_free()

	if wanted("yard"):
		stage.queue_free()
		await frames(2)
		var yard: Node = load("res://test_yard.tscn").instantiate()
		root.add_child(yard)
		await frames(40)
		var him := yard.get_node("Player") as Player
		him.set_physics_process(false)
		var view := Camera3D.new()
		yard.add_child(view)
		view.make_current()
		var at := Vector3(0.0, 0.0, 77.0)
		for shot: Array in [[Vector3(0, 9, -15), Vector3(0, 1, 2)], [Vector3(-8, 3, -7), Vector3(-5, 1.2, 0)], [Vector3(4.5, 3, -7), Vector3(1.5, 1.2, 0)], [Vector3(9, 2.6, -6), Vector3(7, 1.3, 0)]]:
			view.global_position = at + shot[0]
			view.look_at(at + shot[1])
			view.fov = 45.0
			await frames(6)
			await snap()
		await sheet("yard", 4)
		# And the notebook's page of the leaves found there.
		var book := BookOfTheDead.of(yard)
		for who: int in [6, 7, 11, 2, 0]:
			book.take(who)
		var menu := yard.find_child("Menu", true, false) as GameMenu
		menu._set_open(true)
		menu._turn_to("dead")
		await frames(60)
		await whole("notebook")
	quit()


## Every keeper drawn as the papyrus has him, with his name in signs and in English.
class BookSheet extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		BookOfTheDead.draw_papyrus(self, Rect2(Vector2.ZERO, size), false)
		var columns := 7
		var cell := Vector2(size.x / columns, size.y / 2.0)
		for who in BookOfTheDead.NAMES.size():
			var corner := Vector2((who % columns) * cell.x, (who / columns) * cell.y)
			BookOfTheDead.draw_vignette(self, Rect2(corner + Vector2(10, 8), Vector2(cell.x - 20, cell.y * 0.52)), who)
			BookOfTheDead.draw_signs(self, Rect2(corner + Vector2(10, cell.y * 0.56), Vector2(cell.x - 20, cell.y * 0.2)), who)
			var lines := NotebookInk.wrap(BookOfTheDead.NAMES[who]["name"], cell.x - 16, 20)
			for n in lines.size():
				draw_string(NotebookInk.font(), corner + Vector2(8, cell.y * 0.82 + n * 22), lines[n], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BookOfTheDead.INK)
