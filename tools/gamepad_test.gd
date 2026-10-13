extends SceneTree
## Not part of the game. Plays it with a gamepad and nothing else, with nothing
## drawn, and says whether each thing happened: every input here is an
## InputEventJoypadButton or an InputEventJoypadMotion given to
## Input.parse_input_event. On a bare floor he walks, runs, sprints, jumps,
## ducks, picks up and throws, the camera turns, and a guardian is answered;
## in the desert the notebook is taken out, every tab visited, a setting
## changed, his shirt painted on the colour wheel, and the level editor opened
## from it: a thing is put in, carried, changed, joined, named, removed and
## brought back; then the notebook goes to the tombs, the card there is worked,
## and a room is made in the tomb editor.
##
## The gamepad it plays with is number 7, and nothing else is listened to
## while it runs (`Gamepad.listen_to`): a real one on the desk, which is heard
## whether the window has the focus or not, cannot upset it. What it makes is
## kept in files of its own, not where the game keeps the player's.
## godot --headless --path . --fixed-fps 60 --script tools/gamepad_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

const PAD := 7

var stage: Node3D
var boy: Player
var failed := 0
var menu: GameMenu


func _initialize() -> void:
	Gamepad.device = PAD
	LevelLayout.saved_at = "user://gamepad_test_layout.json"
	TombSpec.path = "user://gamepad_test_my_tombs.json"
	TombDaily.path = "user://gamepad_test_tombs.json"
	TombEditor.keeps = false
	TombEditor.layout = "desk"
	LevelLayout.forget_saved()
	create_timer(420.0, true, false, true).timeout.connect(func() -> void:
		print("GAMEPAD TEST: gave up after seven minutes")
		print("FAILED")
		quit(1))
	run.call_deferred()


func check(what: String, passed: bool, detail := "") -> void:
	print("PASS " if passed else "FAIL ", what, "  ", detail)
	if not passed:
		failed += 1


## Lets `seconds` go by, or fewer if `until` comes true first. Returns whether it did.
func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		await process_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


# --- The gamepad

func button(which: JoyButton, down: bool, device := PAD) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = which
	event.pressed = down
	event.pressure = 1.0 if down else 0.0
	Input.parse_input_event(event)


## A button down and up again.
func press(which: JoyButton, held := 0.06, device := PAD) -> void:
	button(which, true, device)
	await wait(held)
	button(which, false, device)
	await wait(0.06)


func axis(which: JoyAxis, value: float, device := PAD) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = which
	event.axis_value = value
	Input.parse_input_event(event)


func left_stick(to: Vector2) -> void:
	axis(JOY_AXIS_LEFT_X, to.x)
	axis(JOY_AXIS_LEFT_Y, to.y)


func right_stick(to: Vector2) -> void:
	axis(JOY_AXIS_RIGHT_X, to.x)
	axis(JOY_AXIS_RIGHT_Y, to.y)


func dpad(way: Vector2) -> void:
	var which := JOY_BUTTON_DPAD_LEFT
	if way.x > 0.0:
		which = JOY_BUTTON_DPAD_RIGHT
	elif way.y < 0.0:
		which = JOY_BUTTON_DPAD_UP
	elif way.y > 0.0:
		which = JOY_BUTTON_DPAD_DOWN
	await press(which)


## Everything in the tree that is of a class.
func all_of(found: Callable, from: Node = root) -> Array:
	var all: Array = []
	for child in from.get_children():
		if found.call(child):
			all.append(child)
		all.append_array(all_of(found, child))
	return all


func run() -> void:
	await on_a_floor()
	await a_guardian()
	boy.set_physics_process(false)
	stage.queue_free()
	await wait(0.2)
	await the_notebook()
	await the_level_editor()
	await the_tombs()
	await the_tomb_editor()
	LevelLayout.forget_saved()
	for path: String in [TombSpec.path, TombDaily.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


# --- Play

func on_a_floor() -> void:
	stage = Node3D.new()
	stage.name = "Stage"
	root.add_child(stage)
	stage.add_child(DirectionalLight3D.new())
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400, 2, 400)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector3(0, -1, 0)
	stage.add_child(body)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(0, 0.05, 40)
	boy.rest_enabled = false
	stage.add_child(boy)
	var cam := FollowCamera.new()
	cam.target = boy
	cam.mode = FollowCamera.Mode.ORBIT
	cam.settle_speed = 0.0
	stage.add_child(cam)
	cam.make_current()
	await wait(0.5)
	# Only gamepad 7 is listened to from here on, whatever else is plugged in.
	Gamepad.listen_to(PAD)
	var bound := 0
	for action: StringName in [&"move_left", &"jump", &"duck", &"act", &"look_left", &"pad_a", &"pad_ls_left", &"pad_rt"]:
		for event: InputEvent in InputMap.action_get_events(action):
			if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device == PAD:
				bound += 1
	check("moving, jumping, ducking, his hand and the camera each have something on the gamepad", bound >= 8, "%d" % bound)
	check("before anything is pressed, it is not a gamepad that is in use", not Gamepad.using_pad())

	var flat := func() -> float: return Vector2(boy.velocity.x, boy.velocity.z).length()
	var from := boy.global_position
	left_stick(Vector2(0.0, -0.4))
	await wait(1.5)
	var walking: float = flat.call()
	check("the left stick pushed a little: he walks", walking > 0.6 and walking < boy.run_speed * 0.7 and not boy.is_sprinting, "%.2f m/s" % walking)
	check("and it is away from the camera that he goes", boy.global_position.distance_to(from) > 1.0 and (boy.global_position - from).normalized().dot(-cam.global_basis.z) > 0.5)
	check("now it is a gamepad that is in use", Gamepad.using_pad())
	left_stick(Vector2(0.0, -1.0))
	await wait(0.7)
	var running: float = flat.call()
	check("pushed all the way: he runs", running > boy.run_speed * 0.85, "%.2f m/s" % running)
	var sprinted := await wait(2.5, func() -> bool: return boy.is_sprinting)
	check("held there: he sprints", sprinted and flat.call() > boy.run_speed, "%.2f m/s" % flat.call())
	left_stick(Vector2.ZERO)
	await wait(1.2)
	check("let go: he stops", flat.call() < 0.2, "%.2f m/s" % flat.call())

	# A real gamepad on the desk (number 0) is not his.
	await press(JOY_BUTTON_A, 0.1, 0)
	var rose := await wait(0.4, func() -> bool: return not boy.is_on_floor())
	check("another gamepad's A does nothing while this runs", not rose)
	button(JOY_BUTTON_A, true)
	rose = await wait(0.5, func() -> bool: return not boy.is_on_floor())
	button(JOY_BUTTON_A, false)
	check("A: he jumps", rose, "y %.2f" % boy.global_position.y)
	await wait(1.5, func() -> bool: return boy.is_on_floor())
	await wait(0.6)
	button(JOY_BUTTON_B, true)
	var ducked := await wait(0.8, func() -> bool: return boy.is_ducking)
	check("B held: he ducks", ducked)
	left_stick(Vector2(0.0, -1.0))
	await wait(0.8)
	check("and goes along ducked, slowly", boy.is_ducking and flat.call() < boy.run_speed * 0.8 and flat.call() > 0.2, "%.2f m/s" % flat.call())
	left_stick(Vector2.ZERO)
	button(JOY_BUTTON_B, false)
	var stood := await wait(1.5, func() -> bool: return not boy.is_ducking)
	check("B let go: he stands", stood)
	await wait(0.6)

	# Something to pick up, in front of him.
	var stone := RigidBody3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.14
	var round := CollisionShape3D.new()
	round.shape = ball
	stone.add_child(round)
	stone.mass = 1.0
	stone.add_to_group(&"throwable")
	stage.add_child(stone)
	stone.global_position = boy.global_position + Vector3(sin(boy.facing_yaw), 0.2, cos(boy.facing_yaw)) * 0.55
	await wait(0.6)
	await press(JOY_BUTTON_X)
	var has := await wait(2.5, func() -> bool: return boy.carried == stone)
	check("X by a stone: he picks it up", has)
	await wait(0.5)
	# (the right trigger is his hand as well: pulled slowly, all the way, it is one press)
	for pull: float in [0.2, 0.45, 0.6, 0.8, 1.0]:
		axis(JOY_AXIS_TRIGGER_RIGHT, pull)
		await wait(0.03)
	var thrown := await wait(2.5, func() -> bool: return boy.carried == null)
	await wait(0.3)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check("the right trigger: he throws it", thrown and stone.global_position.distance_to(boy.global_position) > 1.0, "%.1f m off" % stone.global_position.distance_to(boy.global_position))
	check("and has not picked anything up again for the trigger going on being pulled", boy.carried == null and boy.pickup_progress >= 1.0)

	# The camera.
	var yaw := cam._yaw
	var pitch := cam._pitch
	right_stick(Vector2(1.0, 0.0))
	await wait(0.5)
	right_stick(Vector2.ZERO)
	await wait(0.05)
	var turned := absf(angle_difference(yaw, cam._yaw))
	check("the right stick turns the camera", turned > 0.8 and turned < 1.6, "%.2f rad in half a second" % turned)
	right_stick(Vector2(0.03, 0.0))
	await wait(0.05)
	yaw = cam._yaw
	await wait(0.3)
	check("a stick a hair off its middle does not", is_equal_approx(yaw, cam._yaw))
	right_stick(Vector2(0.0, -1.0))
	await wait(0.2)
	right_stick(Vector2.ZERO)
	await wait(0.05)
	check("pushed away it looks up (the camera comes down)", cam._pitch < pitch - 0.1, "%.2f to %.2f" % [pitch, cam._pitch])
	pitch = cam._pitch
	Settings.look_invert = true
	right_stick(Vector2(0.0, -1.0))
	await wait(0.2)
	right_stick(Vector2.ZERO)
	await wait(0.05)
	check("or down, if he has asked for that", cam._pitch > pitch + 0.1, "%.2f to %.2f" % [pitch, cam._pitch])
	Settings.look_invert = false
	Settings.look_speed = 2.0
	yaw = cam._yaw
	right_stick(Vector2(1.0, 0.0))
	await wait(0.25)
	right_stick(Vector2.ZERO)
	await wait(0.05)
	Settings.look_speed = 1.0
	var fast := absf(angle_difference(yaw, cam._yaw))
	check("and twice as fast, if he has asked for that", fast > turned * 0.85 and fast < turned * 1.2, "%.2f rad in a quarter of a second" % fast)
	await wait(0.1)
	await press(JOY_BUTTON_RIGHT_STICK)
	await wait(1.0)
	check("the right stick pressed in brings it round behind him", absf(angle_difference(cam._yaw, boy.facing_yaw + PI)) < 0.1, "%.2f rad off" % angle_difference(cam._yaw, boy.facing_yaw + PI))
	cam.queue_free()


# --- A guardian

func a_guardian() -> void:
	var made := GateGuardian.new()
	made.who = 6
	made.bars_way = true
	made.seed = 7
	made.position = Vector3.ZERO
	stage.add_child(made)
	await wait(0.3)
	var up := func() -> GuardianPanel: return GuardianPanel.current if is_instance_valid(GuardianPanel.current) else null
	boy.global_position = Vector3(0.0, 0.05, 1.05)
	boy.velocity = Vector3.ZERO
	boy.facing_yaw = PI
	await wait(0.4)
	await press(JOY_BUTTON_X)
	var asked := await wait(1.5, func() -> bool: return up.call() != null)
	check("X before a guardian: it asks", asked and paused)
	if not asked:
		return
	await wait(0.7)
	var panel: GuardianPanel = up.call()
	check("with a gamepad the mark is on the first name from the start", panel._keys and panel._focus == panel.dealt[0], str(panel._focus))
	await dpad(Vector2.DOWN)
	check("down: the mark is on Step back", panel._focus == -1)
	await press(JOY_BUTTON_A)
	await wait(0.3)
	check("A there: nothing is said, and the game goes on", up.call() == null and not paused and not made.on and made.wrong == 0)
	await wait(0.4)
	await press(JOY_BUTTON_X)
	asked = await wait(1.5, func() -> bool: return up.call() != null)
	await wait(0.7)
	if not asked:
		check("X again: it asks again", false)
		return
	await press(JOY_BUTTON_B)
	await wait(0.3)
	check("B steps back too", up.call() == null and not paused and not made.on and made.wrong == 0)
	await wait(0.4)
	await press(JOY_BUTTON_X)
	asked = await wait(1.5, func() -> bool: return up.call() != null)
	await wait(0.7)
	if not asked:
		check("X again: it asks again", false)
		return
	panel = up.call()
	for i in 3:
		if panel._focus == 6:
			break
		await dpad(Vector2.RIGHT)
	check("the d-pad goes along the names", panel._focus == 6, str(panel._focus))
	await press(JOY_BUTTON_A)
	await wait(0.5)
	check("A on its name: it is named, and on", up.call() == null and not paused and made.on and made.wrong == 0)


# --- The notebook

## The spot of the notebook that the mark is on, or one by its name.
func spot(id: String) -> Dictionary:
	for found: Dictionary in menu._spots:
		if found["id"] == id:
			return found
	return {}


## Moves the notebook's mark to a spot, with the d-pad alone.
func mark_to(id: String) -> bool:
	for tries in 40:
		if menu._focus == id:
			return true
		var to := spot(id)
		var here := spot(menu._focus)
		if to.is_empty():
			return false
		if here.is_empty():
			await dpad(Vector2.LEFT)
			continue
		var by: Vector2 = menu._middle(to) - menu._middle(here)
		var was := menu._focus
		var first := Vector2(signf(by.x), 0.0) if absf(by.x) > absf(by.y) else Vector2(0.0, signf(by.y))
		await dpad(first)
		if menu._focus == was:
			# (nothing that way: the other way first, then)
			var other := Vector2(0.0, signf(by.y)) if first.x != 0.0 else Vector2(signf(by.x), 0.0)
			if other == Vector2.ZERO:
				other = Vector2(0.0, 1.0) if first.x != 0.0 else Vector2(1.0, 0.0)
			await dpad(other)
	return menu._focus == id


func to_the_desert() -> void:
	change_scene_to_file("res://desert.tscn")
	await wait(1.5)
	await wait(20.0, func() -> bool: return current_scene != null and not all_of(func(node: Node) -> bool: return node is GameMenu).is_empty())
	await wait(0.6)
	menu = all_of(func(node: Node) -> bool: return node is GameMenu)[0]
	Gamepad.listen_to(PAD)


func the_notebook() -> void:
	await to_the_desert()
	var touch: TouchControls = get_first_node_in_group(&"touch_controls")
	check("with a gamepad in use there are no touch controls over the picture", Gamepad.using_pad() and not TouchControls.wanted() and touch != null and touch._hint_alpha <= 0.0)
	await press(JOY_BUTTON_B)
	await wait(0.3)
	check("B (which ducks) does not take the notebook out", not menu._open and not paused)
	await press(JOY_BUTTON_START)
	var out := await wait(2.0, func() -> bool: return menu._open and menu._out >= 1.0)
	check("Start takes it out, and the game stands still", out and paused)
	await wait(0.3)
	# Every part, with the right shoulder; and back with the left.
	var seen := [menu._section]
	for i in 6:
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		await wait(0.6)
		if not seen.has(menu._section):
			seen.append(menu._section)
	for i in 12:
		await press(JOY_BUTTON_LEFT_SHOULDER)
		await wait(0.5)
		if not seen.has(menu._section):
			seen.append(menu._section)
	seen.sort()
	var parts: Array = menu._parts().duplicate()
	parts.sort()
	check("the shoulders turn to every part of it", seen == parts and menu._section == menu._parts()[0], str(seen))

	# Notes: how fast the stick turns the camera, and which way up.
	for i in 6:
		if menu._section == "notes":
			break
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		await wait(0.6)
	check("on a page turned to with a shoulder, the mark is on its first thing", menu._keys and not spot(menu._focus).is_empty() and not menu._focus.begins_with("tab:"), menu._focus)
	var reached := await mark_to("look_speed")
	check("the d-pad takes the mark to the line for how fast the camera turns", reached, menu._focus)
	var speed := Settings.look_speed
	for i in 3:
		await dpad(Vector2.RIGHT)
	check("right, there, slides it: the stick turns the camera faster", Settings.look_speed > speed + 0.3 and menu._focus == "look_speed", "%.2f to %.2f" % [speed, Settings.look_speed])
	for i in 5:
		await dpad(Vector2.LEFT)
	check("and left, slower", Settings.look_speed < speed - 0.2, "%.2f" % Settings.look_speed)
	reached = await mark_to("look_invert:1")
	await press(JOY_BUTTON_A)
	check("A on \"down\": pushed away, the stick looks down", reached and Settings.look_invert)
	reached = await mark_to("look_invert:0")
	await press(JOY_BUTTON_A)
	check("and on \"up\", up again", reached and not Settings.look_invert)
	Settings.look_speed = 1.0
	await press(JOY_BUTTON_B)
	check("B: the mark goes back to the tab", menu._focus == "tab:notes" and menu._open)

	# Me: the colour wheel.
	for i in 6:
		if menu._section == "me":
			break
		await press(JOY_BUTTON_LEFT_SHOULDER)
		await wait(0.6)
	reached = await mark_to("garment:0")
	await press(JOY_BUTTON_A)
	var shirt: String = menu._garments[0][1]
	check("A on his shirt: it is what the wheel paints", reached and menu._painted() == shirt, menu._painted())
	reached = await mark_to("wheel")
	var before: Color = menu._colour_of(shirt)
	await press(JOY_BUTTON_A)
	check("A on the wheel takes hold of it", reached and menu._wheel_held)
	left_stick(Vector2(1.0, 0.0))
	await wait(0.2)
	left_stick(Vector2.ZERO)
	check("the left stick points at a hue: to the right is green", absf(menu._wheel.hue - 0.25) < 0.01, "%.3f" % menu._wheel.hue)
	for i in 30:
		await dpad(Vector2.RIGHT)
	for i in 30:
		await dpad(Vector2.UP)
	var now: Color = menu._colour_of(shirt)
	check("the d-pad goes about the square: all the way right and up is the full colour", now.is_equal_approx(Color.from_hsv(0.25, 1.0, 1.0)), str(now))
	right_stick(Vector2(-1.0, 1.0))
	await wait(0.6)
	right_stick(Vector2.ZERO)
	await wait(0.1)
	now = menu._colour_of(shirt)
	check("and so does the right stick: paler and darker", now.s < 0.8 and now.v < 0.8 and absf(now.h - 0.25) < 0.02, "s %.2f v %.2f" % [now.s, now.v])
	check("his shirt is that colour as it is turned", Settings.colours.get(shirt, Color.BLACK).is_equal_approx(now))
	await press(JOY_BUTTON_A)
	check("A keeps it", not menu._wheel_held and menu._colour_of(shirt).is_equal_approx(now))
	await press(JOY_BUTTON_A)
	left_stick(Vector2(-1.0, 0.0))
	await wait(0.2)
	left_stick(Vector2.ZERO)
	check("taken hold of again and turned: another colour", menu._wheel_held and not menu._colour_of(shirt).is_equal_approx(now))
	await press(JOY_BUTTON_B)
	check("B puts it back as it was", not menu._wheel_held and menu._colour_of(shirt).is_equal_approx(now) and menu._open, str(menu._colour_of(shirt)))
	check("and it is not the colour he came in", not now.is_equal_approx(before))
	# A finger on the same wheel.
	var ring: Vector2 = menu._right.get_global_transform() * (menu._wheel.centre() + Vector2(0.0, menu._wheel.radius() * 0.87))
	for step: Array in [[true, Vector2.ZERO], [false, Vector2.ZERO]]:
		var finger := InputEventScreenTouch.new()
		finger.device = InputEvent.DEVICE_ID_EMULATION
		finger.position = ring
		finger.pressed = step[0]
		root.push_input(finger, true)
		await wait(0.05)
	check("a finger (or a mouse) on the ring turns it too: the bottom is blue-green", absf(menu._wheel.hue - 0.5) < 0.01, "%.3f" % menu._wheel.hue)
	Gamepad.using = Gamepad.Using.PAD


# --- The level editor

var editor: LevelEditor
var pad: LevelEditorPad


func count(kind: String) -> int:
	var found := 0
	for item: Dictionary in editor.layout["items"]:
		if item["kind"] == kind:
			found += 1
	return found


## Brings the editor's cross over a place on the ground with the left stick.
func cross_to(to: Vector2) -> bool:
	for tries in 900:
		var by := to - Vector2(editor._focus.x, editor._focus.z)
		if by.length() < 0.12:
			break
		var yaw := editor._yaw
		var stick := Vector2(by.dot(Vector2(cos(yaw), -sin(yaw))), by.dot(Vector2(sin(yaw), cos(yaw))))
		# (gently, as it comes near: the stick is pushed as far as there is to go)
		var push := clampf(sqrt(by.length() / (editor._reach * 0.85) * 4.0), 0.22, 1.0)
		left_stick(stick.normalized() * push)
		await process_frame
	left_stick(Vector2.ZERO)
	await wait(0.1)
	return Vector2(editor._focus.x, editor._focus.z).distance_to(to) < 0.6


## Moves a PadFocus's mark to the thing `wanted` says yes to, with the d-pad alone.
func focus_to(mark: PadFocus, wanted: Callable) -> bool:
	for tries in 60:
		var here: Variant = mark.now()
		if here != null and wanted.call(here):
			return true
		var to: Variant = null
		for thing: Variant in mark.things():
			if wanted.call(thing):
				to = thing
				break
		if to == null or here == null:
			await wait(0.1)
			continue
		var by := mark.rect_of(to).get_center() - mark.rect_of(here).get_center()
		var first := Vector2(signf(by.x), 0.0) if absf(by.x) > absf(by.y) else Vector2(0.0, signf(by.y))
		# (left and right slide a slider and step a list: off one of those it is up or down first)
		if (here is HSlider or here is OptionButton) and by.y != 0.0:
			first = Vector2(0.0, signf(by.y))
		await dpad(first)
		await wait(0.05)
		if mark.now() == here:
			var other := Vector2(0.0, signf(by.y)) if first.x != 0.0 else Vector2(signf(by.x), 0.0)
			if other != Vector2.ZERO and not ((here is HSlider or here is OptionButton) and other.x != 0.0):
				await dpad(other)
				await wait(0.05)
	var at: Variant = mark.now()
	return at != null and wanted.call(at)


func says(text: String) -> Callable:
	return func(thing: Variant) -> bool: return thing is Button and (thing as Button).text == text


## Writes a word on the letters that are up, with the d-pad and A.
func type(word: String) -> void:
	var keys: PadKeyboard = all_of(func(node: Node) -> bool: return node is PadKeyboard)[0]
	for letter in word:
		var to := Vector2i(-1, -1)
		for y in PadKeyboard.ROWS.size():
			var x: int = (PadKeyboard.ROWS[y] as String).find(letter)
			if x != -1:
				to = Vector2i(x, y)
		while keys._at.y != to.y:
			await dpad(Vector2(0.0, signf(to.y - keys._at.y)))
		while keys._at.x != to.x:
			await dpad(Vector2(signf(to.x - keys._at.x), 0.0))
		await press(JOY_BUTTON_A)


func the_level_editor() -> void:
	for i in 6:
		if menu._section == "places":
			break
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		await wait(0.6)
	var reached := await mark_to("edit")
	await press(JOY_BUTTON_A)
	await wait(0.6)
	var found := all_of(func(node: Node) -> bool: return node is LevelEditor)
	check("the notebook's Places, and A on \"Edit this level\": the editor opens, laid out for a desk", reached and found.size() == 1 and (found[0] as LevelEditor).visible and not (found[0] as LevelEditor).phone and paused)
	if found.is_empty():
		return
	editor = found[0]
	pad = editor._gamepad
	var level: Desert = editor.level
	await wait(0.3)

	# Looking about.
	var was := [editor._focus, editor._yaw, editor._pitch, editor._reach]
	left_stick(Vector2(1.0, 0.0))
	await wait(0.4)
	left_stick(Vector2.ZERO)
	check("the left stick moves the cross over the ground", editor._focus.distance_to(was[0]) > 5.0, "%.1f m" % editor._focus.distance_to(was[0]))
	right_stick(Vector2(1.0, 0.6))
	await wait(0.4)
	right_stick(Vector2.ZERO)
	check("the right stick turns the view and tips it", absf(editor._yaw - was[1]) > 0.3 and absf(editor._pitch - was[2]) > 0.1, "%.2f rad, %.2f rad" % [editor._yaw - was[1], editor._pitch - was[2]])
	axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await wait(0.5)
	axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	var near := editor._reach
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await wait(0.25)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check("the left trigger comes nearer, the right goes further", near < was[3] * 0.7 and editor._reach > near * 1.2, "%.0f m, %.0f m, %.0f m" % [was[3], near, editor._reach])
	editor._yaw = 0.3
	editor._pitch = 0.9
	editor._reach = 30.0
	# Somewhere clear of everything to work.
	var clear := Vector2.ZERO
	for tries in 400:
		clear = Vector2(-60.0 + (tries % 20) * 6.0, -60.0 + (tries / 20) * 6.0)
		var free := true
		for item: Dictionary in editor.layout["items"]:
			if Vector2(item["at"][0], item["at"][1]).distance_to(clear) < 16.0:
				free = false
		if free:
			break
	check("the cross can be steered to a place", await cross_to(clear), str(editor._focus))

	# Putting things in: a page with the shoulders, a thing with the d-pad, A.
	for i in 14:
		if editor._page == "Puzzle":
			break
		await press(JOY_BUTTON_RIGHT_SHOULDER)
	check("the shoulders turn the pages", editor._page == "Puzzle", editor._page)
	await dpad(Vector2.RIGHT)
	check("the d-pad takes up the first thing on the page", editor._next == "place" and editor._armed[0] == "Pressure plate", str(editor._armed))
	var plates := count("plate")
	await press(JOY_BUTTON_A)
	var plate: Dictionary = editor.chosen
	check("A puts it in at the cross, and it is chosen", count("plate") == plates + 1 and plate.get("kind", "") == "plate" and Vector2(plate["at"][0], plate["at"][1]).distance_to(clear) < 0.5, str(plate.get("at")))
	await cross_to(clear + Vector2(7.0, 0.0))
	await dpad(Vector2.RIGHT)
	await dpad(Vector2.RIGHT)
	check("on along the page: a door", editor._armed[0] == "Door", str(editor._armed))
	await press(JOY_BUTTON_A)
	var door: Dictionary = editor.chosen
	check("and A puts that in", door.get("kind", "") == "door" and level.nodes.has(door["id"]))
	await dpad(Vector2.RIGHT)
	check("the d-pad again: another thing to put in", editor._next == "place")
	await press(JOY_BUTTON_B)
	check("B: not now", editor._next == "" and count("mover") == 0 or editor._next == "")

	# Carrying it: A held, and the cross moved.
	await cross_to(Vector2(plate["at"][0], plate["at"][1]))
	var stood := Vector2(plate["at"][0], plate["at"][1])
	var undos := editor._undo.size()
	button(JOY_BUTTON_A, true)
	await wait(0.1)
	await cross_to(stood + Vector2(3.0, 4.0))
	button(JOY_BUTTON_A, false)
	await wait(0.2)
	var moved := Vector2(plate["at"][0], plate["at"][1])
	check("A held on the plate (which chooses it) while the cross is moved carries it", moved.distance_to(stood + Vector2(3.0, 4.0)) < 0.8 and editor.chosen.get("id", -1) == plate["id"], "%s to %s" % [stood, moved])
	var stands: Vector3 = level.nodes[plate["id"]].global_position
	check("as one change, to undo; and the plate itself has gone with it", editor._undo.size() == undos + 1 and Vector2(stands.x, stands.z).distance_to(moved) < 0.1, "%d notes, were %d; it stands at %s" % [editor._undo.size(), undos, stands])

	# Changing a thing: A on it, Y, the rows, left and right.
	await cross_to(Vector2(door["at"][0], door["at"][1]))
	await press(JOY_BUTTON_A)
	check("A with the cross on the door chooses the door", editor.chosen.get("id", -1) == door["id"])
	await press(JOY_BUTTON_Y)
	await wait(0.2)
	check("Y: the mark is in its settings", pad.mode == "panel" and pad.mark.now() != null and editor._side.is_ancestor_of(pad.mark.now()))
	var wide: float = door.get("wide", 3.0)
	var on_slider := await focus_to(pad.mark, func(thing: Variant) -> bool: return thing is HSlider and is_equal_approx((thing as HSlider).value, wide) and (thing as HSlider).max_value == 12.0)
	for i in 5:
		await dpad(Vector2.RIGHT)
	check("the d-pad down to its width, and right: it is wider", on_slider and float(door["wide"]) > wide + 0.45, "%.2f to %.2f" % [wide, float(door["wide"])])
	await dpad(Vector2.LEFT)
	check("and left, narrower", float(door["wide"]) < wide + 0.45 and float(door["wide"]) > wide)

	# Joining: "Choose what works it", then A on the plate.
	var on_link := await focus_to(pad.mark, says("Choose what works it..."))
	await press(JOY_BUTTON_A)
	await wait(0.1)
	check("A on \"Choose what works it\": back to the cross, to choose", on_link and editor._next == "link" and pad.mode == "ground")
	await cross_to(Vector2(plate["at"][0], plate["at"][1]))
	await press(JOY_BUTTON_A)
	check("A with the cross on the plate: the plate works the door", (door.get("links", []) as Array).has(plate["id"]), str(door.get("links", [])))
	await press(JOY_BUTTON_A)
	check("A again: it does not", not (door.get("links", []) as Array).has(plate["id"]))
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_B)
	check("and B when finished", editor._next == "" and (door.get("links", []) as Array).has(plate["id"]) and editor.chosen.get("id", -1) == door["id"])

	# Removing, and undoing.
	await press(JOY_BUTTON_A)
	check("A with the cross on the plate chooses the plate", editor.chosen.get("id", -1) == plate["id"])
	await press(JOY_BUTTON_X)
	check("X removes it, and the door is worked by nothing", count("plate") == plates and (door.get("links", []) as Array).is_empty() and editor.chosen.is_empty())
	await press(JOY_BUTTON_LEFT_STICK)
	await wait(0.2)
	var back := false
	for item: Dictionary in editor.layout["items"]:
		if item["kind"] == "door" and (item.get("links", []) as Array).has(plate["id"]):
			back = true
	check("the left stick pressed in undoes that", count("plate") == plates + 1 and back)
	await press(JOY_BUTTON_RIGHT_STICK)
	await wait(0.2)
	check("and the right, pressed in, does it again", count("plate") == plates)
	await press(JOY_BUTTON_LEFT_STICK)
	await wait(0.2)

	# Writing: a sign, and what it says.
	await cross_to(clear + Vector2(-7.0, 3.0))
	for i in 40:
		await dpad(Vector2.RIGHT)
		if editor._armed[0] == "Sign":
			break
	await press(JOY_BUTTON_A)
	var sign: Dictionary = editor.chosen
	await press(JOY_BUTTON_Y)
	await wait(0.2)
	var on_line := await focus_to(pad.mark, func(thing: Variant) -> bool: return thing is LineEdit)
	await press(JOY_BUTTON_A)
	await wait(0.3)
	check("a sign put in; A on what it says brings up letters", sign.get("kind", "") == "sign" and on_line and pad.mark.typing())
	if pad.mark.typing():
		for i in 6:
			await press(JOY_BUTTON_X)
		await type("mind")
		await press(JOY_BUTTON_Y)
		await press(JOY_BUTTON_START)
		await wait(0.2)
		check("X rubs out, the d-pad and A write, Start is done: the sign says it", String(sign.get("text", "")) == "mind" and not pad.mark.typing(), String(sign.get("text", "")))
	await press(JOY_BUTTON_B)
	check("B: back to the ground", pad.mode == "ground")

	# Every other button of the editor.
	await press(JOY_BUTTON_START)
	await wait(0.2)
	check("Start: the mark is on the editor's own buttons", pad.mode == "bar" and pad.mark.now() is Button)
	var on_more := await focus_to(pad.mark, says("More"))
	await press(JOY_BUTTON_A)
	await wait(0.2)
	check("A on More: the level as text", on_more and editor._share.visible)
	var on_close := await focus_to(pad.mark, says("Close"))
	check("where the mark keeps to that sheet", on_close and editor._share.is_ancestor_of(pad.mark.now()))
	await press(JOY_BUTTON_B)
	await wait(0.2)
	check("B closes it", not editor._share.visible and pad.mode == "ground")
	await press(JOY_BUTTON_START)
	await wait(0.2)
	var on_play := await focus_to(pad.mark, says("Play"))
	await press(JOY_BUTTON_A)
	await wait(1.0)
	await wait(20.0, func() -> bool: return current_scene != null and not paused and not all_of(func(node: Node) -> bool: return node is GameMenu).is_empty())
	await wait(0.5)
	check("A on Play: the level is played", on_play and not paused and all_of(func(node: Node) -> bool: return node is LevelEditor and (node as LevelEditor).visible).is_empty())
	var kept := false
	for item: Dictionary in LevelLayout.load_layout().get("items", []):
		if item["kind"] == "sign" and item.get("text", "") == "mind":
			kept = true
	check("with what was made in it (kept in the test's own file)", kept and LevelLayout.saved_at.contains("gamepad_test"))


# --- The tombs

func the_tombs() -> void:
	menu = all_of(func(node: Node) -> bool: return node is GameMenu)[0]
	Gamepad.listen_to(PAD)
	await press(JOY_BUTTON_START)
	await wait(2.0, func() -> bool: return menu._open and menu._out >= 1.0)
	for i in 6:
		if menu._section == "places":
			break
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		await wait(0.6)
	var reached := await mark_to("go:res://tomb.tscn")
	await press(JOY_BUTTON_A)
	await wait(1.0)
	var there := await wait(20.0, func() -> bool: return current_scene != null and current_scene.scene_file_path == "res://tomb.tscn" and not all_of(func(node: Node) -> bool: return node is TombLevel).is_empty())
	await wait(0.8)
	check("the notebook's Places, and A on the tombs: he goes there", reached and there)
	if not there:
		return
	Gamepad.listen_to(PAD)
	var tomb: TombLevel = all_of(func(node: Node) -> bool: return node is TombLevel)[0]
	var mark: PadFocus = all_of(func(node: Node) -> bool: return node is PadFocus, current_scene)[0]
	check("the card that comes up has the gamepad's mark on it", is_instance_valid(tomb._card) and mark.has_pad() and mark.now() != null and tomb._card.is_ancestor_of(mark.now()))
	var on_play := await focus_to(mark, says("Play today's tomb"))
	await press(JOY_BUTTON_A)
	await wait(0.3)
	check("the d-pad to \"Play today's tomb\" and A: the card goes, and he is let go", on_play and not is_instance_valid(tomb._card) and not tomb._held and not mark.has_pad())
	var player: Player = all_of(func(node: Node) -> bool: return node is Player, current_scene)[0]
	await wait(0.4)
	check("that A was the card's, not a jump", player.is_on_floor() or player.velocity.y <= 0.0)
	await press(JOY_BUTTON_BACK)
	await wait(0.2)
	check("Back: the mark is on the buttons at the top", mark.has_pad() and mark.now() is Button, str(mark.now()))
	var on_stuck := await focus_to(mark, says("Stuck"))
	check("the d-pad finds Stuck", on_stuck)
	await press(JOY_BUTTON_B)
	check("B gives the gamepad back to the game", not mark.has_pad())
	# The notebook again, and from it the tomb editor.
	menu = all_of(func(node: Node) -> bool: return node is GameMenu)[0]
	await press(JOY_BUTTON_START)
	await wait(2.0, func() -> bool: return menu._open and menu._out >= 1.0)
	for i in 6:
		if menu._section == "places":
			break
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		await wait(0.6)
	reached = await mark_to("edit")
	await press(JOY_BUTTON_A)
	await wait(1.0)
	there = await wait(20.0, func() -> bool: return current_scene is TombEditor)
	check("and \"Make a tomb of my own\": the tomb editor", reached and there)


# --- The tomb editor

func the_tomb_editor() -> void:
	if not current_scene is TombEditor:
		change_scene_to_file("res://tomb_editor.tscn")
		await wait(2.0)
	var made := current_scene as TombEditor
	await wait(1.0)
	Gamepad.listen_to(PAD)
	var pads := all_of(func(node: Node) -> bool: return node is TombEditorPad)
	check("it is laid out for a desk, with a gamepad's mark", made._phone == null and pads.size() == 1)
	if pads.is_empty():
		return
	var mark: PadFocus = (pads[0] as TombEditorPad).mark
	await dpad(Vector2.DOWN)
	check("the mark is on something", mark.now() != null)
	var rooms := made.rooms().size()
	var chose := made.chosen
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	await wait(0.2)
	check("the right shoulder: the next room", made.chosen == mini(chose + 1, rooms - 1), "%d" % made.chosen)
	await press(JOY_BUTTON_LEFT_SHOULDER)
	await wait(0.2)
	check("the left: the one before", made.chosen == chose)
	var on_add := await focus_to(mark, says("+ Room"))
	await press(JOY_BUTTON_A)
	await wait(0.6)
	check("the d-pad to \"+ Room\" and A: a room is made", on_add and made.rooms().size() == rooms + 1, "%d rooms, were %d" % [made.rooms().size(), rooms])
	await press(JOY_BUTTON_Y)
	await wait(0.2)
	check("Y: the mark is in the chosen room's panel", mark.now() is Control and made._inspector.is_ancestor_of(mark.now()))
	var on_list := await focus_to(mark, func(thing: Variant) -> bool: return thing is OptionButton and made._inspector.is_ancestor_of(thing))
	var text := TombSpec.to_text(made.spec)
	await dpad(Vector2.RIGHT)
	await wait(0.3)
	check("down to a list, and right: the room is changed", on_list and TombSpec.to_text(made.spec) != text)
	var focus := made._focus
	var reach := made._reach
	left_stick(Vector2(1.0, 0.0))
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await wait(0.4)
	left_stick(Vector2.ZERO)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check("the left stick moves the tomb, and the right trigger goes further off", made._focus.x > focus.x + 1.0 and made._reach > reach * 1.2, "%.1f m, %.0f to %.0f" % [made._focus.x - focus.x, reach, made._reach])
	await press(JOY_BUTTON_LEFT_STICK)
	await wait(0.3)
	await press(JOY_BUTTON_LEFT_STICK)
	await wait(0.6)
	check("the left stick pressed in, twice: both are undone", made.rooms().size() == rooms)
	await press(JOY_BUTTON_START)
	await wait(0.2)
	check("Start: the mark is on Play", says("Play").call(mark.now()))
	var on_tombs := await focus_to(mark, says("Tombs"))
	await press(JOY_BUTTON_A)
	await wait(0.3)
	check("A on Tombs: its sheet, and the mark kept to it", on_tombs and made._sheet.visible and mark.now() != null and made._sheet.is_ancestor_of(mark.now()))
	var on_name := await focus_to(mark, func(thing: Variant) -> bool: return thing is LineEdit)
	await press(JOY_BUTTON_A)
	await wait(0.3)
	check("A on the tomb's name brings up letters", on_name and mark.typing())
	if mark.typing():
		await press(JOY_BUTTON_B)
		await wait(0.2)
	await press(JOY_BUTTON_B)
	await wait(0.2)
	check("B, and B again: the letters go, then the sheet", not mark.typing() and not made._sheet.visible)
