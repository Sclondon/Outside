extends SceneTree
## Not part of the game. Takes pictures of everything a gamepad's mark is drawn
## on, to be looked at: the corner of the screen in play, each page of the
## notebook with the mark on something, the colour wheel taken hold of, the
## guardian's names, the level editor's cross (on the ground, carrying, in the
## settings, on its buttons, and the letters), the tomb's card and buttons, and
## the tomb editor. It gets there as tools/gamepad_test.gd does: with a gamepad
## of its own (number 7) and nothing else, so a real one on the desk does not
## upset it; and keeps what it makes in files of its own.
## godot --path . --resolution 1280x720 --script tools/gamepad_shots.gd -- <outdir>

const PAD := 7

var out := ""
var shot := 0
var menu: GameMenu


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	Gamepad.device = PAD
	Loading.instant = true
	LevelLayout.saved_at = "user://gamepad_shots_layout.json"
	TombSpec.path = "user://gamepad_shots_my_tombs.json"
	TombDaily.path = "user://gamepad_shots_tombs.json"
	TombEditor.keeps = false
	TombEditor.layout = "desk"
	LevelLayout.forget_saved()
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("GAMEPAD SHOTS: gave up after five minutes")
		quit(1))
	run.call_deferred()


func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await process_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func picture(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%02d_%s.png" % [shot, name]))
	print("picture ", "%02d_%s.png" % [shot, name])
	shot += 1


func button(which: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = PAD
	event.button_index = which
	event.pressed = down
	Input.parse_input_event(event)


func press(which: JoyButton) -> void:
	button(which, true)
	await wait(0.07)
	button(which, false)
	await wait(0.07)


func axis(which: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = PAD
	event.axis = which
	event.axis_value = value
	Input.parse_input_event(event)


func left_stick(to: Vector2) -> void:
	axis(JOY_AXIS_LEFT_X, to.x)
	axis(JOY_AXIS_LEFT_Y, to.y)


func dpad(way: Vector2) -> void:
	var which := JOY_BUTTON_DPAD_LEFT
	if way.x > 0.0:
		which = JOY_BUTTON_DPAD_RIGHT
	elif way.y < 0.0:
		which = JOY_BUTTON_DPAD_UP
	elif way.y > 0.0:
		which = JOY_BUTTON_DPAD_DOWN
	await press(which)


func all_of(found: Callable, from: Node = root) -> Array:
	var all: Array = []
	for child in from.get_children():
		if found.call(child):
			all.append(child)
		all.append_array(all_of(found, child))
	return all


func spot(id: String) -> Dictionary:
	for found: Dictionary in menu._spots:
		if found["id"] == id:
			return found
	return {}


## Moves the notebook's mark to a spot, with the d-pad alone.
func mark_to(id: String) -> void:
	for tries in 40:
		var to := spot(id)
		var here := spot(menu._focus)
		if menu._focus == id or to.is_empty():
			return
		if here.is_empty():
			await dpad(Vector2.LEFT)
			continue
		var by: Vector2 = menu._middle(to) - menu._middle(here)
		var was := menu._focus
		var first := Vector2(signf(by.x), 0.0) if absf(by.x) > absf(by.y) else Vector2(0.0, signf(by.y))
		await dpad(first)
		if menu._focus == was:
			await dpad(Vector2(0.0, signf(by.y) if by.y != 0.0 else 1.0) if first.x != 0.0 else Vector2(signf(by.x) if by.x != 0.0 else 1.0, 0.0))


func to_section(section: String) -> void:
	for i in 8:
		if menu._section == section:
			break
		await press(JOY_BUTTON_RIGHT_SHOULDER if menu._parts().find(section) > menu._parts().find(menu._section) else JOY_BUTTON_LEFT_SHOULDER)
		await wait(0.6)
	await wait(0.2)


## Moves a PadFocus's mark to the thing `wanted` says yes to, with the d-pad alone.
func focus_to(mark: PadFocus, wanted: Callable) -> void:
	for tries in 60:
		var here: Variant = mark.now()
		if here != null and wanted.call(here):
			return
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
		if (here is HSlider or here is OptionButton) and by.y != 0.0:
			first = Vector2(0.0, signf(by.y))
		await dpad(first)
		await wait(0.05)
		if mark.now() == here:
			var other := Vector2(0.0, signf(by.y)) if first.x != 0.0 else Vector2(signf(by.x), 0.0)
			if other != Vector2.ZERO and not ((here is HSlider or here is OptionButton) and other.x != 0.0):
				await dpad(other)
				await wait(0.05)


func says(text: String) -> Callable:
	return func(thing: Variant) -> bool: return thing is Button and (thing as Button).text == text


func to_scene(path: String) -> void:
	change_scene_to_file(path)
	await wait(1.0)
	await wait(30.0, func() -> bool: return current_scene != null and current_scene.scene_file_path == path)
	await wait(1.5)
	Gamepad.listen_to(PAD)
	var menus := all_of(func(node: Node) -> bool: return node is GameMenu)
	menu = menus[0] if not menus.is_empty() else null


func run() -> void:
	await to_scene("res://desert.tscn")
	# In play: nothing over the picture but the notebook in the corner, and the button that takes it out.
	left_stick(Vector2(0.0, -1.0))
	await wait(1.0)
	left_stick(Vector2.ZERO)
	await picture("play_start_by_the_notebook")

	await press(JOY_BUTTON_START)
	await wait(2.0, func() -> bool: return menu._open and menu._out >= 1.0)
	await to_section("journal")
	await picture("notebook_journal_tab")
	await to_section("me")
	await picture("notebook_me_first_thing")
	await mark_to("hair:on")
	await picture("notebook_me_hair")
	await mark_to("garment:1")
	await press(JOY_BUTTON_A)
	await picture("notebook_me_overalls_chosen")
	await mark_to("wheel")
	await picture("notebook_me_mark_on_wheel")
	await press(JOY_BUTTON_A)
	left_stick(Vector2(-0.9, 0.5))
	await wait(0.2)
	left_stick(Vector2.ZERO)
	for i in 9:
		await dpad(Vector2.RIGHT)
	for i in 3:
		await dpad(Vector2.UP)
	await picture("notebook_me_wheel_held")
	await press(JOY_BUTTON_A)
	await to_section("places")
	await picture("notebook_places_first_thing")
	await mark_to("go:res://tomb.tscn")
	await picture("notebook_places_tombs")
	await mark_to("edit")
	await picture("notebook_places_edit")
	await to_section("notes")
	await mark_to("look_speed")
	await dpad(Vector2.RIGHT)
	await dpad(Vector2.RIGHT)
	await picture("notebook_notes_slider")
	await mark_to("look_invert:1")
	await picture("notebook_notes_either")
	await mark_to("world:1")
	await picture("notebook_notes_world")
	await press(JOY_BUTTON_B)
	await picture("notebook_notes_back_on_tab")

	# The level editor.
	await to_section("places")
	await mark_to("edit")
	await press(JOY_BUTTON_A)
	await wait(1.0)
	var editor: LevelEditor = all_of(func(node: Node) -> bool: return node is LevelEditor)[0]
	var pad := editor._gamepad
	left_stick(Vector2(0.4, -0.3))
	await wait(0.5)
	left_stick(Vector2.ZERO)
	await wait(4.0)
	await picture("editor_cross")
	for i in 14:
		if editor._page == "Puzzle":
			break
		await press(JOY_BUTTON_RIGHT_SHOULDER)
	await dpad(Vector2.RIGHT)
	await dpad(Vector2.RIGHT)
	await picture("editor_putting_in")
	await press(JOY_BUTTON_A)
	await wait(0.3)
	await picture("editor_thing_chosen")
	button(JOY_BUTTON_A, true)
	await wait(0.1)
	left_stick(Vector2(0.5, 0.0))
	await wait(0.25)
	left_stick(Vector2.ZERO)
	await wait(0.2)
	await picture("editor_carrying")
	button(JOY_BUTTON_A, false)
	await wait(0.2)
	await press(JOY_BUTTON_Y)
	await wait(0.3)
	await picture("editor_settings_first")
	await focus_to(pad.mark, func(thing: Variant) -> bool: return thing is HSlider and (thing as HSlider).max_value == 12.0)
	await dpad(Vector2.RIGHT)
	await picture("editor_settings_slider")
	await focus_to(pad.mark, says("Choose what works it..."))
	await picture("editor_settings_link")
	await press(JOY_BUTTON_A)
	await wait(0.2)
	left_stick(Vector2(-0.5, 0.2))
	await wait(0.2)
	left_stick(Vector2.ZERO)
	await wait(0.3)
	await picture("editor_joining")
	await press(JOY_BUTTON_B)
	# A sign, and the letters for it.
	left_stick(Vector2(0.0, 0.6))
	await wait(0.3)
	left_stick(Vector2.ZERO)
	for i in 40:
		await dpad(Vector2.RIGHT)
		if editor._armed[0] == "Sign":
			break
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_Y)
	await wait(0.3)
	await focus_to(pad.mark, func(thing: Variant) -> bool: return thing is LineEdit)
	await press(JOY_BUTTON_A)
	await wait(0.4)
	await dpad(Vector2.DOWN)
	await dpad(Vector2.RIGHT)
	await dpad(Vector2.RIGHT)
	await picture("editor_letters")
	await press(JOY_BUTTON_B)
	await wait(0.2)
	await press(JOY_BUTTON_B)
	await press(JOY_BUTTON_START)
	await wait(0.3)
	await picture("editor_buttons")
	await focus_to(pad.mark, says("Stone"))
	await picture("editor_buttons_page")
	await focus_to(pad.mark, says("More"))
	await press(JOY_BUTTON_A)
	await wait(0.3)
	await picture("editor_level_as_text")
	await press(JOY_BUTTON_B)
	paused = false

	# A guardian's names, on a bare stage.
	await to_scene("res://test_yard.tscn")
	var panel := GuardianPanel.ask(current_scene, [3, 6, 9], 6, true, BookOfTheDead.NAMES[6]["head"])
	await wait(0.8)
	await dpad(Vector2.RIGHT)
	await picture("guardian_names")
	await dpad(Vector2.DOWN)
	await picture("guardian_step_back")
	await press(JOY_BUTTON_A)
	await wait(0.3)
	panel = GuardianPanel.read(current_scene, 6)
	await wait(0.8)
	await picture("guardian_leaf")
	await press(JOY_BUTTON_A)
	await wait(0.3)

	# The tombs: the card, and the buttons at the top.
	await to_scene("res://tomb.tscn")
	var mark: PadFocus = all_of(func(node: Node) -> bool: return node is PadFocus, current_scene)[0]
	await dpad(Vector2.DOWN)
	await picture("tomb_card")
	await focus_to(mark, says("Play today's tomb"))
	await picture("tomb_card_play")
	await press(JOY_BUTTON_A)
	await wait(1.0)
	await picture("tomb_playing_back_by_stuck")
	await press(JOY_BUTTON_BACK)
	await wait(0.3)
	await picture("tomb_buttons")
	await press(JOY_BUTTON_B)

	# The tomb editor.
	await to_scene("res://tomb_editor.tscn")
	var made := current_scene as TombEditor
	var tomb_pad: TombEditorPad = all_of(func(node: Node) -> bool: return node is TombEditorPad)[0]
	await dpad(Vector2.DOWN)
	await wait(0.3)
	await picture("tomb_editor_mark")
	await press(JOY_BUTTON_Y)
	await wait(0.3)
	await focus_to(tomb_pad.mark, func(thing: Variant) -> bool: return thing is OptionButton and made._inspector.is_ancestor_of(thing))
	await picture("tomb_editor_panel")
	await focus_to(tomb_pad.mark, says("Tombs"))
	await press(JOY_BUTTON_A)
	await wait(0.3)
	await picture("tomb_editor_sheet")
	# (a tomb that branches: its marks on the floor plan are things for the mark too)
	await focus_to(tomb_pad.mark, says("A new one"))
	await press(JOY_BUTTON_A)
	await wait(1.5)
	if made._sheet.visible:
		await press(JOY_BUTTON_B)
	for i in 12:
		await dpad(Vector2.UP)
		if tomb_pad.mark.now() is Dictionary:
			break
	await wait(0.3)
	await picture("tomb_editor_floor_plan")
	LevelLayout.forget_saved()
	for path: String in [TombSpec.path, TombDaily.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("done: ", shot, " pictures in ", out)
	quit()
