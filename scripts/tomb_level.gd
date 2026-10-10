class_name TombLevel
extends Node3D
## A tomb made from a seed (`tomb.tscn`): the daily tomb, the same for everyone
## on the same day, or one for practice from any seed.
##
## Which it is comes from `TombLevel.play`, set by whoever opens the scene
## (`{"mode": "daily"}` or `{"mode": "random", "seed": 12, "difficulty": 1}`),
## or from the command line (`-- tomb=daily`, `-- tomb=12:1`). With neither it
## is today's tomb, and a card comes up first that offers a random one instead.
## A tomb made by hand in the tomb editor is `{"mode": "custom", "spec": ...}`
## (a `TombSpec`), or `-- tomb=custom` for the one last worked on there: it is
## played and timed like any other, and kept nowhere.
##
## He goes in, takes the gold falcon from the burial chamber, and comes out the
## way he went in. The clock starts at his first step and stops when he is out
## of the door with it; it counts sixtieths of a second of play, not of the
## wall clock, so a slow phone is not a slow time. Dying costs the walk back
## from the last door he went through (each end of every room is a place to
## start again), and is counted. A finished daily tomb is kept (`TombDaily`).
##
## It runs the tomb's parts itself: doors open when their switches are done
## and stay open, and sand that makes a way up comes in the same and stays; mummies wake as he passes and go back when he is far away;
## what he carries goes back to where he last had it when he dies.

## Set before the scene is opened. Emptied when it has been read.
static var play := {}
## For the tools: no card, and no result card at the end.
static var bare := false

const NIGHT := Color(0.02, 0.025, 0.04)
## How near a mummy he must come (along the tomb) to wake it.
const WAKE_WITHIN := 2.2
## How long a mummy that cannot get at him goes on trying.
const LOSES_HIM_AFTER := 4.0
## How near a lit torch must be brought to a brazier.
const LIGHT_WITHIN := 1.8
## How near an offering table a jar must be put down to be set on it.
const OFFER_WITHIN := 1.5
## How near a door he must stand for it to become where he starts again.
const CHECK_WITHIN := 1.3
## How near an inscription he must stand to read it.
const READ_WITHIN := 2.6

var mode := "daily"
var day := 0
var seed_value := 0
var difficulty := 0
## The tomb as it was made by hand (a TombSpec), when it was.
var spec := {}
var plan: TombPlan
var layout: TombLayout
var built: TombBuilder
## Which switches are done, by the plan's switch.
var done: Array[bool] = []
var has_treasure := false
var finished := false
var deaths := 0
## Sixtieths of a second since his first step (0 until then), and at the treasure.
var ticks := 0
var goal_ticks := 0
## When each room was first stood in, by room (in ticks; -1 never).
var splits: Array[int] = []
## The finished run (see TombDaily.submission), once there is one.
var run := {}

var _player: Player
var _started := false
var _held := false
var _room := -1
var _label: Label
var _caption: Label
var _caption_time := 0.0
var _card: Control
var _hud: CanvasLayer


func _ready() -> void:
	_read_choice()
	_build_dark()
	if mode == "custom":
		plan = TombSpec.compile(spec)
		var proof := TombSolver.solve(plan)
		plan.solution = proof["steps"]
		plan.proof = proof
	else:
		plan = TombGenerator.generate(seed_value, difficulty)
	layout = TombLayout.lay(plan)
	built = TombBuilder.build(layout, self)
	done.resize(plan.triggers.size())
	done.fill(false)
	splits.resize(plan.rooms.size())
	splits.fill(-1)
	for area in built.deaths:
		area.body_entered.connect(_fell_in)
	for entry in built.mummies:
		var mummy: Node3D = entry["node"]
		if mummy.has_signal(&"caught"):
			mummy.connect(&"caught", _on_caught.bind(mummy))
	for thing in built.hooked:
		if thing and thing.has_signal(&"caught"):
			thing.connect(&"caught", _on_caught.bind(thing))
	_settle_in.call_deferred()


func _read_choice() -> void:
	var chosen := play.duplicate()
	play = {}
	var asked := not chosen.is_empty()
	for arg in OS.get_cmdline_user_args():
		if arg == "tomb=custom":
			chosen = {"mode": "custom", "spec": TombSpec.current()}
			asked = true
		elif arg == "tomb=daily":
			chosen = {"mode": "daily"}
			asked = true
		elif arg.begins_with("tomb="):
			var parts := arg.trim_prefix("tomb=").split(":")
			chosen = {"mode": "random", "seed": int(parts[0]), "difficulty": int(parts[1]) if parts.size() > 1 else 1}
			asked = true
	mode = chosen.get("mode", "daily")
	day = int(chosen.get("day", TombDaily.today()))
	if mode == "custom":
		spec = chosen.get("spec", {})
		# (one that cannot be built is not played: today's is, in its place)
		if spec.is_empty() or not TombSpec.problems(spec).is_empty():
			mode = "daily"
		else:
			seed_value = int(spec.get("seed", 1))
			difficulty = clampi(int(spec.get("difficulty", 0)), 0, 2)
	if mode == "custom":
		pass
	elif mode == "daily":
		seed_value = TombDaily.seed_for(day)
		difficulty = TombDaily.difficulty_for(day)
	else:
		seed_value = int(chosen.get("seed", 1))
		difficulty = clampi(int(chosen.get("difficulty", 1)), 0, 2)
	_held = not asked and not bare


func _build_dark() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = NIGHT
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.4, 0.46)
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	# A faint light from the camera's side, so that he is never a bare shadow.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 12.0, 0.0)
	fill.light_color = Color(0.85, 0.8, 0.75)
	fill.light_energy = 0.22
	add_child(fill)
	# The moon over the way in.
	var moon := OmniLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 2.2
	moon.omni_range = 26.0
	moon.omni_attenuation = 0.6
	moon.position = Vector3(2.0, 9.0, 6.0)
	add_child(moon)
	Sand.sun_gain = 1.0
	Sand.sky = Color.BLACK


func _settle_in() -> void:
	_player = get_parent().get_node_or_null(^"Player") as Player
	_hud = get_parent().get_node_or_null(^"HUD") as CanvasLayer
	if _player == null:
		return
	_player.move_mode = Player.MoveMode.SIDE_SCROLL
	_player.kill_height = -layout.depth - 30.0
	_player.global_position = layout.start + Vector3.UP * 0.05
	_player.velocity = Vector3.ZERO
	_player.set_spawn(layout.start + Vector3.UP * 0.05)
	_player.respawn()
	_player.respawned.connect(_on_respawned)
	for entry in built.mummies:
		var mummy: Node3D = entry["node"]
		if &"target" in mummy:
			mummy.set(&"target", _player)
	var camera := get_parent().get_node_or_null(^"Camera") as FollowCamera
	if camera:
		camera.snap()
	_build_hud()
	if _held:
		_player.set_physics_process(false)
		_show_choice()
	else:
		_announce()


# --- Running it

func _physics_process(delta: float) -> void:
	if _player == null or _held or finished:
		return
	var at := _player.global_position
	if not _started and at.distance_to(layout.start) > 0.4 and not _player.is_limp:
		_started = true
	if _started:
		ticks += 1
	_room = _room_of(at)
	if _room >= 0 and splits[_room] == -1:
		splits[_room] = ticks
	_put_away(layout.room_at(at.x))
	_work_switches(at)
	_work_mummies(at)
	_keep_things(at)
	_read_walls(at, delta)
	if has_treasure and at.x < layout.exit_x and _player.is_on_floor() and not _player.is_limp:
		_finish()
	_label.text = "%s   %s%s" % [TombDaily.time_text(time_ms()), "deaths %d" % deaths, "   the falcon" if has_treasure else ""]


func time_ms() -> int:
	return ticks * 1000 / 60


# Which of the plan's rooms he is in: a loft or a crypt, if he is in one.
func _room_of(at: Vector3) -> int:
	var on_axis := layout.room_at(at.x)
	for room in plan.rooms:
		if room.parent != on_axis:
			continue
		var info := layout.rooms[room.id]
		if at.x >= float(info["x0"]) - 0.3 and at.x <= float(info["x1"]) + 0.3 and absf(at.y - float(info["floor"])) < 1.0:
			return room.id
	# (a loft that goes on over the wall is over the next room)
	for room in plan.rooms:
		if room.role == TombPlan.Role.LOFT:
			var info := layout.rooms[room.id]
			if at.x >= float(info["x0"]) and at.x <= float(info["x1"]) and absf(at.y - float(info["floor"])) < 0.6:
				return room.id
	return on_axis


# Only the room he is in and the ones next to it are drawn.
func _put_away(here: int) -> void:
	var place := plan.rooms[here].spine if here >= 0 else 0
	for room in plan.spine():
		built.room_nodes[room.id].visible = absi(room.spine - place) <= 1


func _work_switches(at: Vector3) -> void:
	for trigger in plan.triggers:
		if done[trigger.id]:
			continue
		var now := false
		match trigger.kind:
			TombPlan.Switch.LEVER:
				now = (built.switches[trigger.id] as TombParts.Plate).pressed
			TombPlan.Switch.WORK_PLATE, TombPlan.Switch.PLATE:
				now = _weighed(built.switches[trigger.id], &"tomb_blocks")
			TombPlan.Switch.OFFERING:
				# A jar put down at the table, or thrown onto it, is set on it.
				var table := layout.switch_at[trigger.id]
				for jar: RigidBody3D in get_tree().get_nodes_in_group(&"tomb_jars"):
					var from := jar.global_position - table
					if jar != _player.carried and absf(from.x) < OFFER_WITHIN and absf(from.y) < 1.0 and jar.linear_velocity.length() < 1.5:
						jar.freeze = true
						jar.global_transform = Transform3D(Basis.IDENTITY, table + Vector3.UP * 0.23)
						jar.set_meta(&"offered", true)
						now = true
						break
			TombPlan.Switch.BRAZIER:
				var bowl: Node3D = built.switches[trigger.id]
				for torch: Node3D in get_tree().get_nodes_in_group(&"torches"):
					if torch.get(&"lit") and torch.global_position.distance_to(bowl.global_position + Vector3.UP * 0.9) < LIGHT_WITHIN:
						now = true
				if now:
					var flame := bowl.find_child("Flame*", true, false) as Node3D
					(flame if flame else bowl).add_child(Fire.brazier())
			TombPlan.Switch.TREASURE:
				now = at.distance_to(built.treasure.global_position) < 1.5
				if now:
					_take_treasure()
		done[trigger.id] = now
	for link in plan.links:
		if not built.doors.has(link.id) and not built.sands.has(link.id):
			continue
		var open := true
		for id in link.switches:
			open = open and done[id]
		if built.doors.has(link.id):
			(built.doors[link.id] as TombParts.Door).is_open = open
		else:
			# Sand comes in until the heap is as big as it gets. Nothing ever
			# empties it: what is done stays done, and so does the way up.
			var fall: SandFall = built.sands[link.id]
			fall.running = open and not (fall.pile != null and fall.pile.is_full())
			if fall.pile:
				fall.rate = TombBuilder.sand_rate(fall.pile_cap, fall.pile.radius)


func _weighed(plate: Area3D, group: StringName) -> bool:
	for body in plate.get_overlapping_bodies():
		if body.is_in_group(group):
			return true
	return false


func _take_treasure() -> void:
	has_treasure = true
	goal_ticks = ticks
	built.treasure.get_node(^"Figure").visible = false
	for entry in built.mummies:
		if entry["guardian"] and entry["node"].has_method(&"wake"):
			entry["node"].call(&"wake")
	_say("You have the falcon. Now get out.", 5.0)


func _work_mummies(at: Vector3) -> void:
	var here := layout.room_at(at.x)
	var place := plan.rooms[here].spine if here >= 0 else 0
	for entry in built.mummies:
		var mummy: Node3D = entry["node"]
		if not mummy.has_method(&"wake") or not mummy.has_method(&"is_awake"):
			continue
		var away := absi(plan.rooms[entry["room"]].spine - place)
		var awake: bool = mummy.call(&"is_awake")
		# Where it cannot get at him (past what holds it, or out of its room) it
		# loses him after a while and stands where it is, and wakes again only
		# when he comes by: so one left waiting at its kerb can be got past.
		# Two rooms off, it is put back where it began.
		var out_of_reach := away >= 1 or (at.x > float(entry["safe"])) == bool(entry["east"])
		if awake and away >= 2:
			mummy.call(&"reset")
			entry["lost"] = 0.0
		elif awake and out_of_reach:
			entry["lost"] = float(entry["lost"]) + get_physics_process_delta_time()
			if float(entry["lost"]) > LOSES_HIM_AFTER and &"chasing" in mummy:
				mummy.set(&"chasing", false)
		elif awake:
			entry["lost"] = 0.0
		elif away == 0 and not _player.is_limp and (has_treasure or not entry["guardian"]):
			var to := mummy.global_position - at
			if absf(to.x) < WAKE_WITHIN and absf(to.y) < 2.0:
				mummy.call(&"wake")
				entry["lost"] = 0.0


# Doors he has reached become where he starts again, and what he is carrying
# will come back to there; what has fallen where he cannot follow comes back now.
func _keep_things(at: Vector3) -> void:
	if _player.is_on_floor() and not _player.is_limp:
		for check in built.checks:
			var spot: Vector3 = check["at"]
			if at.distance_to(spot) < CHECK_WITHIN:
				_player.set_spawn(spot + Vector3.UP * 0.05)
				for id: int in built.items:
					if built.items[id] == _player.carried:
						built.item_homes[id] = Transform3D(Basis.IDENTITY, spot + Vector3(0.5, 0.3, 0.0))
	for id: int in built.items:
		var body: RigidBody3D = built.items[id]
		if body != _player.carried and _is_lost(body.global_position):
			_send_home(body, built.item_homes[id])
	for block in built.blocks:
		if _is_lost((block["body"] as RigidBody3D).global_position):
			_send_home(block["body"], block["home"])


func _is_lost(at: Vector3) -> bool:
	for area in built.deaths:
		var box := ((area.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
		var from := at - area.global_position
		if absf(from.x) < box.x * 0.5 and from.y < box.y * 0.5:
			return true
	for hole in layout.sunk:
		if at.x > hole.x and at.x < hole.y and at.y < hole.z:
			return true
	return at.y < -layout.depth - 20.0


func _send_home(body: RigidBody3D, home: Transform3D) -> void:
	# (what has been given stays given)
	if body.has_meta(&"offered"):
		return
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.global_transform = home
	body.freeze = false


# Standing under an inscription, he reads it: its meaning comes up, and goes in the notebook.
func _read_walls(at: Vector3, delta: float) -> void:
	_caption_time -= delta
	if _caption_time <= 0.0:
		_caption.visible = false
	for writing in built.writings:
		var spot: Vector3 = writing["at"]
		if absf(at.x - spot.x) < READ_WITHIN and absf(at.y - spot.y) < 3.5 and not writing.get("read", false):
			writing["read"] = true
			var meaning := TombHooks.read(writing["hint"], _title())
			if meaning != "":
				_say("\"%s\"" % meaning, 6.0)


# --- Dying

func _fell_in(body: Node3D) -> void:
	if body == _player and not _player.is_limp:
		_player.respawn()


func _on_caught(by: Node3D) -> void:
	if _player == null or _player.is_limp or finished:
		return
	_player.ragdoll((_player.global_position - by.global_position).normalized() * 22.0 + Vector3.UP * 10.0)
	await get_tree().create_timer(2.2).timeout
	if is_instance_valid(_player) and _player.is_limp:
		_player.respawn()


func _on_respawned() -> void:
	if not _started or finished:
		return
	deaths += 1
	for entry in built.mummies:
		if entry["node"].has_method(&"reset") and not (entry["guardian"] and has_treasure):
			entry["node"].call(&"reset")
	for entry in built.mummies:
		# (the guardian, once woken, starts after him again from its place)
		if entry["guardian"] and has_treasure and entry["node"].has_method(&"reset"):
			entry["node"].call(&"reset")
			entry["node"].call(&"wake")
	for thing in built.hooked:
		if thing and thing.has_method(&"reset"):
			thing.call(&"reset")
	for id: int in built.items:
		_send_home(built.items[id], built.item_homes[id])
	# A block goes back unless the plate it was for is done.
	for block in built.blocks:
		var serves: int = block["serves"]
		if serves < 0 or not done[serves]:
			_send_home(block["body"], block["home"])


## For the tools and for a way out of a corner: counts as a death.
func give_up() -> void:
	if _player and not _player.is_limp:
		_player.respawn()


# --- The end

func _finish() -> void:
	finished = true
	run = {
		"mode": mode, "day": day if mode == "daily" else 0, "seed": seed_value, "difficulty": difficulty,
		"plan": plan.fingerprint(), "stone": layout.fingerprint(),
		"ticks": ticks, "time_ms": time_ms(), "goal_ms": goal_ticks * 1000 / 60, "deaths": deaths, "splits": splits.duplicate(),
	}
	# (the tools keep nothing: what is kept is the player's own)
	var said := {"best": false, "first": false, "streak": 0}
	if not bare and mode != "custom":
		said = TombDaily.keep(run)
	TombHooks.note(_share_text(), _title())
	print("TOMB FINISHED ", JSON.stringify(TombDaily.submission(run)))
	if not bare:
		_show_result(said)


# The run in a line, to send to someone.
func _share_text() -> String:
	if mode != "custom":
		return TombDaily.share_text(run)
	var died := "no deaths" if deaths == 0 else ("1 death" if deaths == 1 else "%d deaths" % deaths)
	return "Outside tomb \"%s\"  %s  %s" % [spec.get("name", "My tomb"), TombDaily.time_text(int(run["time_ms"])), died]


func _title() -> String:
	if mode == "custom":
		return str(spec.get("name", "My tomb"))
	if mode == "daily":
		return "Daily tomb #%d" % TombDaily.number(day)
	return "Tomb %d" % seed_value


# --- What is on the screen

func _build_hud() -> void:
	if _hud == null:
		_hud = CanvasLayer.new()
		add_child(_hud)
	_label = Label.new()
	_label.position = Vector2(16.0, 10.0)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_label.add_theme_constant_override("outline_size", 6)
	_hud.add_child(_label)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.offset_top = 64.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.visible = false
	_hud.add_child(_caption)
	# A way out of any corner he has got himself into.
	if not bare:
		var stuck := _button("Stuck", give_up)
		stuck.modulate.a = 0.8
		stuck.anchor_left = 1.0
		stuck.anchor_right = 1.0
		stuck.offset_left = -236.0
		stuck.offset_right = -132.0
		stuck.offset_top = 12.0
		stuck.offset_bottom = 54.0
		_hud.add_child(stuck)
		if mode == "custom":
			var edit := _button("Edit", _to_editor)
			edit.modulate.a = 0.8
			edit.anchor_left = 1.0
			edit.anchor_right = 1.0
			edit.offset_left = -348.0
			edit.offset_right = -244.0
			edit.offset_top = 12.0
			edit.offset_bottom = 54.0
			_hud.add_child(edit)


func _say(text: String, seconds: float) -> void:
	_caption.text = text
	_caption.visible = true
	_caption_time = seconds


func _announce() -> void:
	var hard: String = TombGenerator.DIFFICULTY_NAMES[difficulty]
	if mode == "custom":
		_say("%s   ·   take the falcon, and get out" % _title(), 6.0)
	elif mode == "daily":
		_say("Daily tomb #%d   ·   %s   ·   %s" % [TombDaily.number(day), TombDaily.date_text(day), hard], 6.0)
	else:
		_say("Tomb %d   ·   %s" % [seed_value, hard], 6.0)


# The card that comes up first: today's tomb, or one for practice.
func _show_choice() -> void:
	var rows := _open_card("TOMBS")
	var record := TombDaily.day_record(day)
	var today_line := "Daily tomb #%d  ·  %s  ·  %s" % [TombDaily.number(day), TombDaily.date_text(day), TombGenerator.DIFFICULTY_NAMES[difficulty]]
	rows.add_child(_line(today_line, 22))
	if record.is_empty():
		rows.add_child(_line("Not yet finished today.   Days in a row: %d" % TombDaily.streak(), 17))
	else:
		rows.add_child(_line("Your best today: %s   Days in a row: %d" % [TombDaily.time_text(int(record["best_ms"])), TombDaily.streak()], 17))
	rows.add_child(_button("Play today's tomb", func() -> void:
		_close_card()
		_held = false
		_player.set_physics_process(true)
		_announce()))
	rows.add_child(_line("Or one for practice: a number of your own, or leave it empty", 17))
	var number := LineEdit.new()
	number.placeholder_text = "any number"
	number.custom_minimum_size.y = 40.0
	number.add_theme_font_size_override("font_size", 19)
	rows.add_child(number)
	var row := HBoxContainer.new()
	rows.add_child(row)
	for level in 3:
		var pick := _button(TombGenerator.DIFFICULTY_NAMES[level], func() -> void:
			# (choosing a tomb at random is not making one: the engine's dice will do)
			var chosen := int(number.text) if number.text.is_valid_int() else randi_range(1, 999999)
			_open_tomb({"mode": "random", "seed": chosen, "difficulty": level}))
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pick)
	rows.add_child(_button("Make a tomb of your own", _to_editor))


func _show_result(said: Dictionary) -> void:
	var rows := _open_card("OUT, WITH THE FALCON")
	var text := _share_text()
	rows.add_child(_line(text, 22))
	var more := "To the falcon in %s." % TombDaily.time_text(int(run["goal_ms"]))
	if said["best"] and not said["first"]:
		more += "  Your best for this tomb."
	if mode == "daily":
		more += "  Days in a row: %d." % int(said["streak"])
	rows.add_child(_line(more, 17))
	var copied := _button("Copy the result", func() -> void: pass)
	copied.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(text)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(%s)" % JSON.stringify(text), true)
		copied.text = "Copied")
	rows.add_child(copied)
	rows.add_child(_button("Again", func() -> void:
		_open_tomb({"mode": mode, "day": day, "seed": seed_value, "difficulty": difficulty, "spec": spec})))
	if mode == "custom":
		rows.add_child(_button("Back to the editor", _to_editor))
	rows.add_child(_button("Another tomb", func() -> void: _open_tomb({})))


func _open_tomb(chosen: Dictionary) -> void:
	TombLevel.play = chosen
	get_tree().paused = false
	get_tree().reload_current_scene()


## To the tomb editor (`tomb_editor.tscn`), which opens on the tomb last worked on there.
func _to_editor() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://tomb_editor.tscn")


func _open_card(title: String) -> VBoxContainer:
	_close_card()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hud.add_child(panel)
	_card = panel
	var margin := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.custom_minimum_size.x = 520.0
	margin.add_child(rows)
	var heading := _line(title, 14)
	heading.modulate.a = 0.6
	rows.add_child(heading)
	return rows


func _close_card() -> void:
	if _card:
		_card.queue_free()
		_card = null


func _line(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 48.0
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(pressed)
	return button
