class_name Loading
extends CanvasLayer
## Going from one level to another, behind a page of the boy's notebook.
##
##   Loading.go("res://desert.tscn")            # to a level (the name on the page is found from the file,
##   Loading.go("res://tomb.tscn", "Tomb 12")   # or is whatever is given)
##   Loading.again()                            # this level again (not `reload`: every script has one of those)
##   await Loading.cover("The desert", work)    # the page over something long done to the level that is there
##
## Every change of level in the game goes through here, and nothing else changes
## the scene. A page of the notebook comes across the picture (a quarter of a
## second); behind it the old level is put away, the new one's file is read (on
## another thread where there is one) and the level builds itself; the page stays
## until the level is built, has stood for a few frames with nothing slow in
## them, and the page has been up for at least `LEAST` seconds; then it is turned
## away (a third of a second). A scarab walks along the foot of the page the whole
## time, drawing a pencil line after it, so it can be seen that nothing is stuck.
##
## Most of the wait is not the file but the level building itself in code, which
## is done on the main thread and stops everything while it runs. So a level
## that takes long builds in stages, and between them lets a frame go by:
##
##   await Loading.stage("Raising the cliffs", 0.4)   # always a frame: the page says so first
##   await Loading.breathe("Setting things out", 0.6) # a frame only if `BUDGET` has gone by since the last
##   Loading.built()                                  # at the end of its `_ready`
##
## With no page up these do nothing and take no time (the level builds in one go,
## as it does for the tools, which change scene themselves). A level that says
## nothing is taken to be built when its `_ready` is done.
##
## While the page is up `Loading.busy` is true: that is the one place to ask.
## The game is stopped (`paused`) until the level is built; for the few frames it
## then stands under the page it runs, so that the boy is on the ground and
## everything has been drawn once, but nothing is passed on to him or to the
## menu, and he reads no keys (see `Player._read_move_input`).
##
## With `Loading.instant` set (as it is with nothing drawn, `--headless`) there
## is no page and no waiting: the scene is changed as it always was.
##
## It is not an autoload: the page is a node it puts under the root itself the
## first time it is wanted, so there is nothing to set up in the project and the
## tools, which make their own trees, have no page unless they ask for one.

const Ink := preload("res://scripts/notebook_ink.gd")

## The level the game starts in, and goes to if another cannot be opened from nowhere.
const FIRST := "res://desert.tscn"
## The scene the game opens with, which only asks for `FIRST` (see scripts/start.gd).
const START := "res://start.tscn"
## Seconds for the page to come across, to be turned away, and the least it is up for.
const OUT_TIME := 0.25
const IN_TIME := 0.33
const LEAST := 0.4
## How long a level may build before `breathe` lets a frame go by, in thousandths of a second.
const BUDGET := 40
## A frame that took longer than this, under the page, was not a quiet one.
const QUIET := 50
## Nor was one in which the camera moved further than this, in metres.
const STILL := 0.05
## What is written and drawn for each place, and what is said before it starts to build.
const PLACES := {
	"res://desert.tscn": {"title": "The desert", "sketch": "pyramid", "first": "Laying out the sand"},
	"res://test_yard.tscn": {"title": "The test yard", "sketch": "yard", "first": "Marking out the yard"},
	"res://tomb.tscn": {"title": "The tombs", "sketch": "doorway", "first": "Cutting the stone"},
	"res://tomb_editor.tscn": {"title": "A tomb of my own", "sketch": "doorway", "first": "Finding a clean page"},
}
## A tomb's doorway in a cliff, drawn as NotebookInk.SKETCHES are.
const DOORWAY := [
	[0.0, 0.28, 0.16, 0.20, 0.36, 0.25, 0.60, 0.16, 0.84, 0.23, 1.0, 0.18],
	[0.0, 0.82, 0.28, 0.80, 0.34, 0.80], [0.66, 0.80, 0.80, 0.82, 1.0, 0.80],
	[0.34, 0.80, 0.37, 0.37], [0.66, 0.80, 0.63, 0.37],
	[0.33, 0.37, 0.67, 0.37], [0.34, 0.30, 0.66, 0.30], [0.34, 0.30, 0.33, 0.37], [0.66, 0.30, 0.67, 0.37],
	[0.42, 0.80, 0.43, 0.45, 0.57, 0.45, 0.58, 0.80],
	[0.455, 0.47, 0.45, 0.80], [0.485, 0.47, 0.482, 0.80], [0.515, 0.47, 0.518, 0.80], [0.545, 0.47, 0.55, 0.80],
	[0.43, 0.56, 0.57, 0.50], [0.43, 0.68, 0.57, 0.62], [0.43, 0.79, 0.57, 0.74],
	[0.38, 0.86, 0.62, 0.86], [0.35, 0.93, 0.65, 0.93], [0.38, 0.86, 0.35, 0.93], [0.62, 0.86, 0.65, 0.93],
	["o", 0.5, 0.335, 0.022, 0.022],
	[0.10, 0.44, 0.22, 0.40], [0.14, 0.58, 0.26, 0.55], [0.76, 0.42, 0.90, 0.46], [0.74, 0.60, 0.86, 0.57],
	[0.12, 0.90, 0.20, 0.87, 0.24, 0.91], [0.78, 0.90, 0.85, 0.87, 0.90, 0.91],
]

## No page and no waiting: the scene is changed at once, as the tools want.
static var instant := DisplayServer.get_name() == "headless"
## Whether a level's file is read on another thread: not where there is none (a web build without them).
static var threads := OS.has_feature("threads")
## Whether a page is up (from the moment it is asked for until it is quite gone). The one place to ask.
static var busy := false
## How long each stage of what was last built took, by what was said of it, in thousandths of a second:
## the work only, not the frames let go by between. (Kept with no page up as well, for the tools.)
static var stages := {}
## About the last change, for the tools: how long it took in all, how long the page was fully up,
## and the longest the page stood still (the longest gap between two frames of it), in thousandths of a second.
static var took := {}
## How many changes have been made through here.
static var count := 0

## Something that only draws what it is told to.
class Drawer extends Node2D:
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


static var _page: Loading
static var _pending := false
static var _showing := false
static var _breath := 0
static var _mark := 0
static var _stage := ""
static var _waited := 0

## The page has come right across: nothing of the old level is to be seen.
signal covered
## The new level is built and has stood its quiet frames; the page is about to be turned away.
signal ready_under
## The page has gone, and he can be moved again.
signal finished

## How far across the page is: 0 not there, 1 over everything, 2 turned away off the other side.
var across := 0.0
var _to := 0.0
var _title := ""
var _sketch: Variant = ""
var _words := ""
var _trouble := ""
var _fraction := 0.0
var _drawn_fraction := 0.0
var _walked := 0.0
var _size := Vector2.ZERO
var _leaf: Node2D
var _moving: Node2D
var _last_frame := 0
var _longest := 0


# ---------------------------------------------------------------- asked for from anywhere

## Goes to a level. `title` is what the page says (found from the file if it is not given);
## `at_once` has the page already up, with nothing of what was there before seen behind it.
## False if a change is already being made.
static func go(path: String, title := "", at_once := false) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or busy:
		return false
	count += 1
	if instant:
		tree.paused = false
		# (a scene is not taken out from under the physics, or from inside its own `_ready`)
		if Engine.is_in_physics_frame() or at_once:
			tree.change_scene_to_file.call_deferred(path)
		elif tree.change_scene_to_file(path) != OK:
			push_error("Loading: %s could not be opened" % path)
		return true
	busy = true
	_the_page()._begin.call_deferred(path, title if title != "" else title_of(path), at_once)
	return true


## Starts this level again.
static func again(title := "") -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or busy:
		return false
	if instant:
		count += 1
		tree.paused = false
		if Engine.is_in_physics_frame():
			tree.reload_current_scene.call_deferred()
		else:
			tree.reload_current_scene()
		return true
	var scene := tree.current_scene
	return go(scene.scene_file_path if scene and scene.scene_file_path != "" else FIRST, title)


## Puts the page over something long that is done to the level that is there (`work` is called
## once the page is up), and takes it away after. Wait for it: `await Loading.cover(...)`.
static func cover(title: String, work: Callable, words := "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if instant or tree == null or busy:
		work.call()
		return
	busy = true
	var page := _the_page()
	if not page.is_inside_tree():
		tree.root.add_child(page)
	await page._cover(title, work, words)


## For a level as it builds: says what is being made and how far along it is (0..1), and lets a
## frame go by so that the page shows it. Nothing, and no wait, if no page is up.
static func stage(words: String, fraction := -1.0) -> void:
	_note(words)
	if not _showing:
		return
	_pending = true
	_page._say(words, fraction)
	await _page._frame()


## The same, but a frame goes by only if `BUDGET` has been spent since the last one did.
static func breathe(words: String, fraction := -1.0) -> void:
	_note(words)
	if not _showing:
		return
	_pending = true
	if Time.get_ticks_msec() - _breath < BUDGET:
		return
	_page._say(words, fraction)
	await _page._frame()


## For a level that builds in stages: it is all made.
static func built() -> void:
	_note("")
	_pending = false


## What the page says of a level, from its file (and, for a tomb, from which tomb has been asked for).
static func title_of(path: String) -> String:
	if path == "res://tomb.tscn":
		var asked: Dictionary = TombLevel.play
		match asked.get("mode", "daily"):
			"daily":
				return "Tomb of the day #%d" % TombDaily.number(int(asked.get("day", TombDaily.today())))
			"random":
				return "Tomb %d" % int(asked.get("seed", 1))
			"custom":
				return str((asked.get("spec", {}) as Dictionary).get("name", "My tomb"))
	return PLACES.get(path, {}).get("title", path.get_file().get_basename().capitalize())


## The page itself, if there is one (for the tools).
static func page() -> Loading:
	return _page


static func _the_page() -> Loading:
	if not is_instance_valid(_page):
		_page = Loading.new()
	return _page


# Keeps how long each stage took: the time since the last note is the last stage's.
static func _note(words: String) -> void:
	var now := Time.get_ticks_usec()
	if _stage != "":
		stages[_stage] = stages.get(_stage, 0.0) + (now - _mark) / 1000.0
	_mark = now
	_stage = words


# ---------------------------------------------------------------- the change

func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_leaf = _drawer(self, _paint_page)
	_moving = _drawer(_leaf, _paint_moving)


func _drawer(under: Node, paint: Callable) -> Node2D:
	var drawer := Drawer.new()
	drawer.paint = paint
	under.add_child(drawer)
	return drawer


func _begin(path: String, title: String, at_once: bool) -> void:
	if not is_inside_tree():
		(Engine.get_main_loop() as SceneTree).root.add_child(self)
	_change(path, title, at_once)


func _change(path: String, title: String, at_once: bool) -> void:
	var tree := get_tree()
	var began := Time.get_ticks_msec()
	var was_paused := tree.paused
	var old := tree.current_scene
	var nowhere := old == null or old.scene_file_path == START
	tree.paused = true
	stages.clear()
	_stage = ""
	_waited = 0
	_open_page(title, PLACES.get(path, {}).get("sketch", ""), at_once)
	# The file is read on another thread while the page comes across, where there is another thread.
	var known := ResourceLoader.exists(path, "PackedScene")
	var threaded := known and threads and ResourceLoader.load_threaded_request(path, "PackedScene") == OK
	await _across()
	var up_at := Time.get_ticks_msec()
	covered.emit()
	_note("Opening the notebook")
	var packed: PackedScene
	if threaded:
		var how_far := []
		while ResourceLoader.load_threaded_get_status(path, how_far) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_say("", float(how_far[0]) * 0.12)
			await tree.process_frame
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			packed = ResourceLoader.load_threaded_get(path) as PackedScene
	elif known:
		# (with no other thread it stops everything while it is read: the page says so first)
		_say("Finding the place", 0.02)
		await tree.process_frame
		_note("Finding the place")
		packed = ResourceLoader.load(path, "PackedScene") as PackedScene
	var scene := packed.instantiate() if packed else null
	if scene == null:
		# It cannot be opened: the page says so, and he is back where he was (or, from nowhere, in the first level).
		push_error("Loading: %s could not be opened" % path)
		_trouble = "I cannot find the way there."
		_say("Going back." if not nowhere or path != FIRST else "", 0.0)
		for i in 100:
			await tree.process_frame
		if nowhere and path == FIRST:
			return
		if nowhere:
			_change(FIRST, title_of(FIRST), true)
			return
		await _lift(up_at)
		tree.paused = was_paused
		_done(began, up_at)
		return
	# The old level goes, and the new one builds itself: in stages, if it is one that says so.
	_say(PLACES.get(path, {}).get("first", "Setting out"), 0.12)
	if old:
		tree.current_scene = null
		tree.root.remove_child(old)
		old.queue_free()
	await tree.process_frame
	_note(_words)
	_pending = false
	_showing = true
	_breath = Time.get_ticks_msec()
	tree.root.add_child(scene)
	tree.current_scene = scene
	# (what is last under the root is first to be handed what is pressed)
	tree.root.move_child(self, -1)
	var patience := Time.get_ticks_msec() + 120000
	while _pending and Time.get_ticks_msec() < patience:
		await tree.process_frame
	_showing = false
	_pending = false
	# (whatever it left to be done when everything was ready: putting him at his start, the camera behind him)
	await tree.process_frame
	_note("Looking it over")
	_say("Looking it over", 0.96)
	# It runs under the page until it has stood a few frames with nothing slow in them and the camera
	# still: everything in sight has been drawn once, the camera is where it starts, and he is on the
	# ground (if he is ever going to be: he may have been put down in water).
	tree.paused = false
	var him := scene.get_node_or_null(^"Player") as CharacterBody3D
	var frames := 0
	var quiet := 0
	var physics := Engine.get_physics_frames()
	var eye_at := Vector3.INF
	while frames < 120:
		var from := Time.get_ticks_msec()
		await tree.process_frame
		frames += 1
		var eye := tree.root.get_camera_3d()
		var still := eye == null or eye.global_position.distance_to(eye_at) < STILL
		eye_at = eye.global_position if eye else Vector3.INF
		quiet = quiet + 1 if still and Time.get_ticks_msec() - from < QUIET else 0
		var down := him == null or not him.is_physics_processing() or him.is_on_floor() or frames >= 60
		if frames >= 5 and quiet >= 3 and down and Engine.get_physics_frames() - physics >= 3:
			break
	_note("")
	_say("", 1.0)
	ready_under.emit()
	await _lift(up_at)
	_done(began, up_at)


func _cover(title: String, work: Callable, words: String) -> void:
	var tree := get_tree()
	var began := Time.get_ticks_msec()
	var was_paused := tree.paused
	tree.paused = true
	stages.clear()
	_stage = ""
	_waited = 0
	var scene := tree.current_scene
	_open_page(title, PLACES.get(scene.scene_file_path if scene else "", {}).get("sketch", ""), false)
	await _across()
	var up_at := Time.get_ticks_msec()
	covered.emit()
	_say(words, 0.1)
	await tree.process_frame
	_note(words if words != "" else title)
	work.call()
	_note("Looking it over")
	_say("Looking it over", 0.96)
	var quiet := 0
	for i in 60:
		var from := Time.get_ticks_msec()
		await tree.process_frame
		quiet = quiet + 1 if Time.get_ticks_msec() - from < QUIET else 0
		if i >= 3 and quiet >= 3:
			break
	_note("")
	_say("", 1.0)
	ready_under.emit()
	await _lift(up_at)
	tree.paused = was_paused
	_done(began, up_at)


func _open_page(title: String, sketch: Variant, at_once: bool) -> void:
	_title = title
	_sketch = sketch
	_words = ""
	_trouble = ""
	_fraction = 0.0
	_drawn_fraction = 0.0
	_walked = 0.0
	_longest = 0
	_last_frame = Time.get_ticks_msec()
	across = 1.0 if at_once else 0.0
	_to = 1.0
	visible = true
	get_tree().root.move_child(self, -1)
	_set_out()
	_leaf.queue_redraw()


# Lets a frame go by for a level that is building, and keeps the wait out of what its stage took.
func _frame() -> void:
	var from := Time.get_ticks_usec()
	await get_tree().process_frame
	var waited := Time.get_ticks_usec() - from
	_waited += waited
	_mark += waited
	_breath = Time.get_ticks_msec()


# Waits until the page is right across.
func _across() -> void:
	while across < 1.0:
		await get_tree().process_frame


# Turns the page away, once it has been up long enough not to have been a flash.
func _lift(up_at: int) -> void:
	while Time.get_ticks_msec() - up_at < int(LEAST * 1000.0):
		await get_tree().process_frame
	_to = 2.0
	while across < 2.0:
		await get_tree().process_frame


func _done(began: int, up_at: int) -> void:
	visible = false
	across = 0.0
	_to = 0.0
	took = {"all": Time.get_ticks_msec() - began, "up": Time.get_ticks_msec() - up_at - int(IN_TIME * 1000.0), "longest": _longest, "frames": _waited / 1000}
	# A finger that came off the screen while the page was up was never heard of: whatever is still there lets go.
	get_tree().call_group(&"touch_controls", &"notification", NOTIFICATION_APPLICATION_FOCUS_OUT)
	busy = false
	finished.emit()


func _say(words: String, fraction := -1.0) -> void:
	if fraction >= 0.0:
		_fraction = maxf(_fraction, clampf(fraction, 0.0, 1.0)) if fraction < 1.0 else 1.0
	if words != _words:
		_words = words
		_leaf.queue_redraw()


# Nothing that is pressed gets past the page.
func _input(_event: InputEvent) -> void:
	if busy and visible:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	var now := Time.get_ticks_msec()
	_longest = maxi(_longest, now - _last_frame)
	_last_frame = now
	# (a frame that took long does not carry anything far: it all steps on from where it was)
	var step := minf(delta, 0.05)
	if across != _to:
		across = move_toward(across, _to, step / (OUT_TIME if _to <= 1.0 else IN_TIME))
	_walked += step
	_drawn_fraction = move_toward(_drawn_fraction, _fraction, step * 1.6)
	if _size != get_viewport().get_visible_rect().size:
		_leaf.queue_redraw()
	_set_out()
	_moving.queue_redraw()


# Where the page is: it comes across from the right, and is turned away to the left.
func _set_out() -> void:
	_size = get_viewport().get_visible_rect().size
	if across <= 1.0:
		_leaf.position.x = (1.0 - ease(across, -2.2)) * (_size.x + 60.0)
	else:
		_leaf.position.x = -ease(across - 1.0, -2.0) * (_size.x + 60.0)


# ---------------------------------------------------------------- the page

# What is on the page and stays still: the paper, the drawing, where he is going.
func _paint_page(on: Node2D) -> void:
	var size := _size
	# (the shadow it throws on the picture, either side of it)
	var dark := Color(0.06, 0.04, 0.02, 0.45)
	var clear := Color(0.06, 0.04, 0.02, 0.0)
	on.draw_polygon([Vector2(0, 0), Vector2(-56, 0), Vector2(-56, size.y), Vector2(0, size.y)], [dark, clear, clear, dark])
	on.draw_polygon([Vector2(size.x, 0), Vector2(size.x + 56, 0), Vector2(size.x + 56, size.y), Vector2(size.x, size.y)], [dark, clear, clear, dark])
	Ink.paper(on, size, 2, -1, 23.0 + _title.length())
	var middle := size.x * 0.5
	var top := size.y * 0.5 - 300.0
	var picture := Rect2(middle - 190.0, top + 26.0, 380.0, 250.0)
	if _sketch is String and _sketch == "doorway":
		Ink.strokes(on, picture, DOORWAY)
	else:
		Ink.sketch(on, _sketch, picture)
	Ink.write_mid(on, Vector2(middle, top + 326.0), "On my way to", 24, Ink.FAINT)
	var size_of := 58
	while size_of > 30 and Ink.width_of(_title, size_of) > size.x - 120.0:
		size_of -= 2
	Ink.write_mid(on, Vector2(middle, top + 392.0), _title, size_of, Ink.INK, -0.008)
	if _trouble != "":
		Ink.write_mid(on, Vector2(middle, top + 470.0), _trouble, 28, Ink.RED)
		Ink.write_mid(on, Vector2(middle, top + 506.0), _words, 24, Ink.FAINT)
	elif _words != "":
		Ink.write_mid(on, Vector2(middle, top + 470.0), _words + "...", 26, Ink.BLUE)


# What moves: the line under the name, as long as the level is far along; and the scarab at the
# foot of the page, with the pencil line it leaves.
func _paint_moving(on: Node2D) -> void:
	var size := _size
	var middle := size.x * 0.5
	var top := size.y * 0.5 - 300.0
	var half := clampf(Ink.width_of(_title, 58) * 0.5 + 40.0, 170.0, size.x * 0.5 - 50.0)
	_ruled(on, Vector2(middle - half, top + 410.0), half * 2.0 * _drawn_fraction, Ink.INK, 2.4)
	# The scarab: across the page and round again
	var foot := size.y * 0.5 + 262.0
	var from := 70.0
	var run := size.x - 140.0
	var at := fposmod(_walked * 130.0, run + 90.0)
	_ruled(on, Vector2(from, foot), minf(at, run), Ink.PENCIL, 1.8)
	if at > run:
		return
	var here := Vector2(from + at + 30.0, foot - 2.0 + sin(_walked * 9.0) * 1.2)
	var pace := _walked * 13.0
	on.draw_set_transform(here, PI * 0.5 + sin(pace * 0.5) * 0.05, Vector2.ONE)
	var box := Rect2(-26.0, -30.0, 52.0, 60.0)
	for stroke: Array in Ink.SKETCHES["scarab"]:
		if stroke[0] is String:
			var centre := box.position + Vector2(stroke[1], stroke[2]) * box.size
			# (its back is filled in, so that the line it draws does not show through it)
			on.draw_set_transform_matrix(Transform2D(PI * 0.5, here) * Transform2D(0.0, Vector2(stroke[3], stroke[4]) * box.size.x, 0.0, centre))
			on.draw_circle(Vector2.ZERO, 1.0, Ink.PAPER, true, -1.0, true)
			on.draw_set_transform(here, PI * 0.5 + sin(pace * 0.5) * 0.05, Vector2.ONE)
			Ink.ring(on, centre, Vector2(stroke[3], stroke[4]) * box.size.x, Ink.INK, 1.8, 3.0)
		elif stroke.size() == 6:
			# A leg: three on one side go forward as the three on the other go back
			var left: bool = stroke[0] < 0.5
			var which := int(stroke[1] > 0.45) + int(stroke[1] > 0.7)
			var swing := sin(pace + (PI if left == (which == 1) else 0.0)) * 0.07
			var points := PackedVector2Array()
			for i in 3:
				points.append(box.position + Vector2(stroke[i * 2], stroke[i * 2 + 1] + swing * i * 0.5) * box.size)
			on.draw_polyline(points, Ink.INK, 1.8, true)
		else:
			on.draw_line(box.position + Vector2(stroke[0], stroke[1]) * box.size, box.position + Vector2(stroke[2], stroke[3]) * box.size, Ink.INK, 1.4, true)
	on.draw_set_transform(Vector2.ZERO)


# A pencil line from `from` to the right, `length` long: in lengths that are each always drawn
# the same, so that it does not shimmer as it grows.
func _ruled(on: Node2D, from: Vector2, length: float, colour: Color, width: float) -> void:
	var done := 0.0
	while done < length:
		var piece := minf(48.0, length - done)
		if piece >= 48.0:
			Ink.line(on, from + Vector2(done, 0.0), from + Vector2(done + piece, 0.0), colour, width, 0.8)
		else:
			on.draw_line(from + Vector2(done, 0.0), from + Vector2(done + piece, 0.0), colour, width, true)
		done += piece
