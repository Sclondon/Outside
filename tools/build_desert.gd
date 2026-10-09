extends SceneTree
## Not part of the game. Lays out desert.tscn the first time: the terrain, its pads,
## and every prop, each an instance of a scene in props/, grouped by place.
## After that the scene is edited by hand in the editor, and this would throw that
## work away: it will not write over an existing desert.tscn unless told to.
## godot --headless --path . --script tools/build_desert.gd [-- force]

const OUT := "res://desert.tscn"
## How far above the ground the origin of each thing that is picked up is.
const LIFT := {"jar_canopic": 0.21, "jar_canopic_jackal": 0.21, "pot": 0.16, "rock_small": 0.1, "block_push": 0.45}

var main: Node3D
var level: Node3D
var terrain: StaticBody3D
var pads: Array = []
var places: Array = []  # [middle (x, z), radius]: where nothing is scattered
var counts := {}
var scenes := {}
var random := RandomNumberGenerator.new()


func _initialize() -> void:
	if FileAccess.file_exists(OUT) and not "force" in OS.get_cmdline_user_args():
		print("desert.tscn is already there, and may have been edited by hand. To throw it away and lay it out again: -- force")
		quit()
		return
	random.seed = 1912
	build()
	var scene := PackedScene.new()
	var result := scene.pack(main)
	if result == OK:
		result = ResourceSaver.save(scene, OUT)
	print("DESERT %s: %d props" % ["ok" if result == OK else "FAILED %d" % result, counts.values().reduce(func(a: int, b: int) -> int: return a + b, 0)])
	print(counts)
	main.free()
	quit()


# --- Helpers ---

func add(parent: Node, node: Node, name: String) -> Node:
	node.name = name
	parent.add_child(node)
	node.owner = main
	return node


## A place: a node to hold what is there, and level ground under it.
func area(name: String, at: Vector3, half: Vector2, round: bool, ease: float) -> Node3D:
	var node := Node3D.new()
	node.position = at
	add(level, node, name)
	if half != Vector2.ZERO:
		pad(node, "Ground", Vector3.ZERO, half, round, ease)
		places.append([Vector2(at.x, at.z), half.length() + ease * 0.7])
	return node


func pad(parent: Node3D, name: String, local: Vector3, half: Vector2, round: bool, ease: float) -> void:
	var node := Marker3D.new()
	node.set_script(load("res://scripts/desert_pad.gd"))
	node.set(&"half_size", half)
	node.set(&"round", round)
	node.set(&"ease", ease)
	node.position = local
	add(parent, node, name)
	pads.append([Transform3D(Basis.IDENTITY, parent.position + local), half, round, ease])


func ground(x: float, z: float) -> float:
	return terrain.call(&"height_at", x, z)


## Puts a prop under `parent`, at (x, z) from it. `y`: how high above the parent
## (INF: on the ground, wherever that is there). `yaw` is in degrees.
func put(parent: Node3D, kind: String, x: float, z: float, yaw := 0.0, y := INF, size := 1.0, sink := 0.0) -> Node3D:
	if not scenes.has(kind):
		scenes[kind] = load("res://props/%s.tscn" % kind)
	var prop: Node3D = (scenes[kind] as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if y == INF:
		y = ground(parent.position.x + x, parent.position.z + z) - parent.position.y
	prop.position = Vector3(x, y + LIFT.get(kind, 0.0) - sink, z)
	prop.rotation_degrees.y = yaw
	if size != 1.0:
		prop.scale = Vector3.ONE * size
	counts[kind] = counts.get(kind, 0) + 1
	add(parent, prop, "%s%d" % [kind.to_pascal_case(), counts[kind]])
	return prop


func checkpoint(marks: Node3D, name: String, x: float, z: float) -> void:
	var mark := Marker3D.new()
	mark.position = Vector3(x, ground(x, z), z)
	mark.add_to_group(&"checkpoints", true)
	add(marks, mark, name)


# --- The level ---

func build() -> void:
	main = Node3D.new()
	main.name = "Main"
	level = Node3D.new()
	level.set_script(load("res://scripts/desert.gd"))
	add(main, level, "Level")
	level.owner = main
	build_light()
	terrain = StaticBody3D.new()
	terrain.set_script(load("res://scripts/desert_terrain.gd"))
	add(level, terrain, "Terrain")

	# Every place and its level ground first: the ground must be known before
	# anything is stood on it.
	var approach := area("Approach", Vector3(0, 0, 165), Vector2(8, 8), true, 12.0)
	var camp := area("Camp", Vector3(-62, 0.5, 105), Vector2(20, 15), false, 14.0)
	var oasis := area("Oasis", Vector3(62, -0.6, 78), Vector2(24, 24), true, 16.0)
	pad(oasis, "Basin", Vector3(0, -1.8, 0), Vector2(8, 7), true, 7.0)
	var colonnade := area("Colonnade", Vector3(0, 1.0, 40), Vector2(12, 31), false, 12.0)
	var sphinx := area("Sphinx", Vector3(0, 2.0, -30), Vector2(11, 19), false, 14.0)
	var pyramid := area("Pyramid", Vector3(0, 4.0, -110), Vector2(42, 42), false, 22.0)
	var ruin := area("RuinedPyramid", Vector3(118, 1.5, -38), Vector2(18, 18), false, 14.0)
	var shrine := area("Shrine", Vector3(-112, 1.0, -32), Vector2(12, 11), false, 12.0)
	var outpost := area("Outpost", Vector3(105, 0.8, 150), Vector2(10, 9), false, 10.0)
	terrain.call(&"use_pads", pads)

	build_approach(approach)
	build_camp(camp)
	build_oasis(oasis)
	build_colonnade(colonnade)
	build_sphinx(sphinx)
	build_pyramid(pyramid)
	build_ruin(ruin)
	build_shrine(shrine)
	build_outpost(outpost)
	build_obelisk()
	build_scatter()

	var marks := Node3D.new()
	add(level, marks, "Checkpoints")
	checkpoint(marks, "Start", 0, 165)
	checkpoint(marks, "AtCamp", -62, 118)
	checkpoint(marks, "AtOasis", 42, 80)
	checkpoint(marks, "AtColonnade", 0, 69)
	checkpoint(marks, "AtSphinx", 0, -13.5)
	checkpoint(marks, "AtPyramid", 0, -70)
	checkpoint(marks, "AtRuinedPyramid", 102, -38)
	checkpoint(marks, "AtShrine", -112, -23)
	checkpoint(marks, "AtOutpost", 105, 143)

	# The player, the camera and the controls, as in mechanics.tscn
	var player: Node3D = (load("res://player.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.position = Vector3(0, ground(0, 165) + 0.05, 165)
	add(main, player, "Player")
	var camera := Camera3D.new()
	camera.set_script(load("res://scripts/follow_camera.gd"))
	camera.position = player.position + Vector3(0, 1.7, 11)
	camera.current = true
	camera.fov = 30.0
	camera.far = 3000.0
	add(main, camera, "Camera")
	camera.set(&"target", player)
	camera.set(&"mode", 1)
	var hud := CanvasLayer.new()
	add(main, hud, "HUD")
	for part: Array in [["TouchControls", "res://scripts/touch_controls.gd"], ["Menu", "res://scripts/menu.gd"]]:
		var control := Control.new()
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.grow_horizontal = Control.GROW_DIRECTION_BOTH
		control.grow_vertical = Control.GROW_DIRECTION_BOTH
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.set_script(load(part[1]))
		add(hud, control, part[0])


func build_light() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.47, 0.8)
	sky_material.sky_horizon_color = Color(0.8, 0.83, 0.82)
	sky_material.sky_curve = 0.11
	sky_material.ground_horizon_color = Color(0.82, 0.8, 0.72)
	sky_material.ground_bottom_color = Color(0.74, 0.64, 0.46)
	sky_material.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.73, 0.8)
	environment.ambient_light_energy = 0.75
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A little haze, so that what is far looks far
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.84, 0.83, 0.78)
	environment.fog_density = 0.0007
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add(level, world, "Sky")
	var sun := DirectionalLight3D.new()
	# (from the south-east and high: the faces he walks up to are lit)
	sun.rotation_degrees = Vector3(-50.0, 32.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	add(level, sun, "Sun")


func build_approach(here: Node3D) -> void:
	put(here, "column_stump", -4.0, -3.0)
	put(here, "column_broken", 4.5, -4.0, 40.0)
	put(here, "block", 3.0, 3.5, 20.0)
	put(here, "crate", -4.5, 2.5, 12.0)
	put(here, "torch_stand", -2.5, -6.5)
	put(here, "torch_stand", 2.5, -6.5)
	put(here, "palm_c", 6.5, 5.5, 70.0)
	for at: Vector2 in [Vector2(1.5, 1.0), Vector2(1.9, 1.5), Vector2(1.1, 1.8)]:
		put(here, "rock_small", at.x, at.y, random.randf_range(0.0, 360.0))
	# Waymarks north, towards the colonnade
	put(here, "column_stump", -3.5, -26.0, 0.0, INF, 1.0, 0.15)
	put(here, "torch_stand", 3.5, -27.0, 0.0, INF, 1.0, 0.05)
	put(here, "column_broken", 4.0, -48.0, 0.0, INF, 1.0, 0.2)
	put(here, "rubble", -3.0, -50.0, 30.0, INF, 1.0, 0.05)
	put(here, "column_stump", -4.0, -70.0, 0.0, INF, 1.0, 0.15)
	put(here, "torch_stand", 4.0, -71.0, 0.0, INF, 1.0, 0.05)


func build_camp(here: Node3D) -> void:
	# Tents along the north side, facing in; stalls along the south
	put(here, "tent", -12.0, -8.0, 20.0)
	put(here, "tent", -3.5, -10.0, -8.0)
	put(here, "tent", 5.5, -9.0, 14.0)
	put(here, "awning", -10.0, 9.0, 180.0)
	put(here, "awning", -3.0, 10.0, 184.0)
	put(here, "awning", 5.0, 9.2, 172.0)
	put(here, "well", 12.0, 0.5, 15.0)
	put(here, "campfire", -2.0, -1.0)
	put(here, "brazier", -7.0, -4.0)
	put(here, "brazier", 3.5, -4.5)
	put(here, "crate", 10.0, -10.5, 5.0)
	put(here, "crate", 11.0, -10.3, 28.0)
	put(here, "crate", 10.4, -10.4, 14.0, 0.9)
	put(here, "crate", -16.0, 2.0, 0.0)
	put(here, "crate", -15.0, 3.2, 40.0)
	put(here, "pot_large", 14.5, 8.0)
	put(here, "pot_large", 15.4, 7.1, 0.0, INF, 0.85)
	put(here, "pot_large", -17.0, -3.0)
	put(here, "pot_large", 8.5, 6.0, 0.0, INF, 0.9)
	put(here, "pot", -8.6, 6.4)
	put(here, "pot", -1.8, 7.4, 60.0)
	put(here, "pot", 0.4, -0.2, 20.0)
	put(here, "jar_canopic", 6.6, 7.0)
	put(here, "jar_canopic_jackal", 7.2, 7.3, 200.0)
	for at: Vector2 in [Vector2(-3.4, 0.2), Vector2(-3.0, 0.6), Vector2(-3.7, 0.7)]:
		put(here, "rock_small", at.x, at.y, random.randf_range(0.0, 360.0))
	put(here, "block_push", -8.0, 1.0)
	# A lookout, its ladder towards the camp
	put(here, "scaffold", 17.0, -9.5, -90.0)
	put(here, "palm_a", -19.0, -13.0, 30.0)
	put(here, "palm_b", 19.5, 12.5, 200.0)
	put(here, "palm_c", -20.5, 11.0, 100.0)
	put(here, "torch_stand", -1.5, 14.5)
	put(here, "torch_stand", 2.0, 14.5)


func build_oasis(here: Node3D) -> void:
	# The water lies in the hollow the Basin pad makes: where the ground is
	# under its surface, it shows.
	var pool := Node3D.new()
	pool.set_script(load("res://scripts/pool.gd"))
	pool.set(&"size", Vector3(30.0, 2.4, 30.0))
	pool.position = Vector3(0.0, -0.4, 0.0)
	add(here, pool, "Pool")
	var kinds := ["palm_a", "palm_b", "palm_c"]
	for i in 15:
		var angle := TAU * i / 15.0 + random.randf_range(-0.12, 0.12)
		var away := random.randf_range(14.0, 22.0)
		put(here, kinds[i % 3], cos(angle) * away, sin(angle) * away, random.randf_range(0.0, 360.0), INF, random.randf_range(0.88, 1.15), 0.1)
	# A kerb of worn stones round the north side of the water
	put(here, "oasis_rim", 0.0, 0.0, 90.0, -0.62, 2.1)
	put(here, "oasis_rim", 0.0, 0.0, 180.0, -0.62, 2.1)
	put(here, "rock_b", -13.5, 6.0, 40.0, INF, 1.2, 0.15)
	put(here, "rock_b", -12.0, 9.5, 190.0, INF, 0.8, 0.1)
	put(here, "rock_b", 9.0, 12.5, 100.0, INF, 1.0, 0.15)
	put(here, "rock_a", 19.0, 14.0, 20.0, INF, 0.9, 0.3)
	put(here, "rock_a", -20.0, -9.0, 250.0, INF, 0.7, 0.2)
	put(here, "block", -15.5, -4.0, 80.0)
	put(here, "block", -16.0, 0.5, 100.0)
	put(here, "pot_large", -16.5, -1.8)
	put(here, "pot", -14.6, -1.6)
	put(here, "pot", -14.2, -2.3, 90.0)
	put(here, "brazier", -17.5, 3.5)
	put(here, "awning", -19.0, -3.0, 90.0)


func build_colonnade(here: Node3D) -> void:
	# Two rows up the avenue, south to north. C: standing, B: broken, S: a stump,
	# F: fallen outwards, a dot: gone.
	var rows := {-5.5: "CCBCCS.CCCFC", 5.5: "CSCC.BCCFCCC"}
	for x: float in rows:
		var row: String = rows[x]
		for i in row.length():
			var z := 26.0 - i * 4.6
			match row[i]:
				"C":
					put(here, "column", x, z, random.randi_range(0, 3) * 90.0)
					# A lintel to the next, if that stands too
					if i + 1 < row.length() and row[i + 1] == "C" and (i == 0 or row[i - 1] != "C" or i % 2 == 1):
						put(here, "lintel", x, z - 2.3, 90.0, 6.0)
				"B":
					put(here, "column_broken", x, z, random.randf_range(0.0, 360.0))
				"S":
					put(here, "column_stump", x, z, random.randf_range(0.0, 360.0))
				"F":
					put(here, "column_stump", x, z, random.randf_range(0.0, 360.0))
					put(here, "column_fallen", x + signf(x) * 5.6, z - 0.6, 90.0 * signf(x) + 8.0)
				".":
					put(here, "rubble", x, z, random.randf_range(0.0, 360.0))
	put(here, "statue_pharaoh", -9.3, 28.0)
	put(here, "statue_pharaoh", 9.3, 28.0)
	put(here, "brazier", -3.0, 29.5)
	put(here, "brazier", 3.0, 29.5)
	put(here, "wall_glyphs", -10.6, -3.0, 90.0)
	put(here, "wall_glyphs", 10.6, 8.5, -90.0)
	put(here, "wall_ruin", 10.6, -17.0, 90.0)
	put(here, "wall_ruin", -10.6, 12.0, -90.0)
	put(here, "sarcophagus", -9.6, -22.5, 20.0)
	put(here, "jar_canopic", -8.0, -21.0)
	put(here, "jar_canopic_jackal", -8.3, -23.9, 140.0)
	put(here, "jar_canopic", -10.9, -20.6, 80.0)
	put(here, "block_stack", 9.0, 19.0, 30.0)
	put(here, "block", -9.5, 20.0, 70.0)
	put(here, "pot_large", 9.5, -2.0)
	put(here, "pot_large", 10.2, -3.1, 0.0, INF, 0.8)
	put(here, "block_push", 0.8, -12.0, 10.0)
	put(here, "lintel", 1.5, 3.0, 24.0)
	# A pair of obelisks where it ends, before the sphinx
	put(here, "obelisk", -8.5, -29.0)
	put(here, "obelisk", 8.5, -29.0)


func build_sphinx(here: Node3D) -> void:
	put(here, "sphinx", 0.0, -1.0)
	put(here, "brazier", -6.5, 14.5)
	put(here, "brazier", 6.5, 14.5)
	put(here, "torch_stand", -0.0, 16.5).position.x = -3.4
	put(here, "torch_stand", 3.4, 16.5)
	put(here, "rubble", 8.0, -13.0, 50.0)
	put(here, "block", -8.2, -6.0, 85.0)
	put(here, "block_stack", 7.6, 4.0, 95.0)
	# Stones to throw, up on a paw
	for z: float in [6.5, 7.0, 7.5]:
		put(here, "rock_small", 1.6 + (z - 7.0) * 0.4, z, random.randf_range(0.0, 360.0), 1.62)
	put(here, "jar_canopic", 0.0, 4.2, 0.0)


func build_pyramid(here: Node3D) -> void:
	put(here, "pyramid_great", 0.0, 0.0)
	# The way in, against the south face
	put(here, "pyramid_entrance", 0.0, 32.8)
	put(here, "statue_anubis", -7.5, 38.5)
	put(here, "statue_anubis", 7.5, 38.5)
	put(here, "torch_stand", -3.3, 37.5)
	put(here, "torch_stand", 3.3, 37.5)
	put(here, "statue_pharaoh", -22.0, 36.0)
	put(here, "statue_pharaoh", 22.0, 36.0)
	put(here, "block_stack", -34.0, 20.0, 80.0)
	put(here, "block_stack", 33.5, -6.0, 100.0)
	put(here, "block", 34.0, 12.0, 10.0)
	put(here, "block", 33.0, 14.5, 60.0)
	put(here, "block", -33.0, -15.0, 95.0)
	put(here, "rubble", -32.5, 5.0)
	put(here, "rubble", 12.0, 33.0, 80.0)
	put(here, "rubble", 20.0, -33.0, 160.0)
	put(here, "crate", -33.5, 12.5, 15.0)
	put(here, "crate", -34.2, 8.0, 50.0)


func build_ruin(here: Node3D) -> void:
	# (turned so that its fallen corner is to the south-west, where he comes from)
	put(here, "pyramid_ruined", 0.0, 0.0, -90.0)
	# A scaffold against the north face: its deck is level with the third course
	put(here, "scaffold", 0.0, -9.75, -90.0)
	put(here, "jar_canopic_jackal", 0.0, -5.3, 0.0, 7.2)
	put(here, "crate", -2.5, -11.5, 20.0)
	put(here, "rubble", -14.0, 10.0)
	put(here, "rubble", 13.5, -13.0, 120.0)
	put(here, "rock_a", 15.0, 13.0, 0.0, INF, 0.8, 0.2)
	put(here, "palm_a", -15.5, -14.0, 140.0)
	put(here, "palm_c", -16.5, -10.5, 20.0)
	put(here, "brazier", -3.0, -12.5)


func build_shrine(here: Node3D) -> void:
	put(here, "wall_glyphs", 0.0, -8.5)
	put(here, "wall_glyphs", -4.7, -8.5)
	put(here, "wall_glyphs", 4.7, -8.5)
	put(here, "wall_glyphs", -7.4, -5.0, 90.0)
	put(here, "wall_glyphs", 7.4, -5.0, -90.0)
	put(here, "statue_anubis", -4.6, 3.5)
	put(here, "statue_anubis", 4.6, 3.5)
	put(here, "sarcophagus", 0.0, -3.5, 90.0)
	put(here, "brazier", -2.6, 0.8)
	put(here, "brazier", 2.6, 0.8)
	put(here, "jar_canopic", -1.5, -1.2)
	put(here, "jar_canopic_jackal", -0.5, -1.0, 30.0)
	put(here, "jar_canopic", 0.5, -1.1, 110.0)
	put(here, "jar_canopic_jackal", 1.5, -1.3, 300.0)
	put(here, "column_broken", -9.5, 8.0)
	put(here, "column", 9.5, 8.0)
	put(here, "pot", -6.0, -3.0)
	put(here, "rubble", 8.5, -1.0, 40.0)


func build_outpost(here: Node3D) -> void:
	put(here, "wall_ruin", -2.0, -6.5, 180.0)
	put(here, "wall_ruin", -7.0, -1.5, 90.0)
	put(here, "column", 6.0, -6.0)
	put(here, "column_fallen", 6.5, 1.0, 12.0)
	put(here, "tent", -1.0, 0.5, 30.0)
	put(here, "campfire", 2.0, 4.5)
	put(here, "crate", -4.0, 4.5, 30.0)
	put(here, "pot", -3.0, 5.2)
	put(here, "palm_a", -9.5, -8.5, 0.0, INF, 1.1)
	put(here, "palm_c", -8.5, 7.5, 90.0)


## An obelisk that fell long ago, out in the dunes to the west.
func build_obelisk() -> void:
	var at := Vector3(-105.0, 0.0, 50.0)
	at.y = ground(at.x, at.z)
	var here := area("FallenObelisk", at, Vector2.ZERO, false, 0.0)
	places.append([Vector2(at.x, at.z), 16.0])
	var fallen := put(here, "obelisk", 0.0, 0.0, 35.0, 0.3)
	fallen.rotation_degrees.x = 86.0
	put(here, "rock_a", -4.0, -3.0, 60.0, INF, 1.0, 0.3)
	put(here, "rock_b", 3.5, 4.0, 10.0, INF, 1.3, 0.15)
	put(here, "rubble", -2.5, 3.0, 0.0, INF, 1.0, 0.05)
	put(here, "palm_b", -6.0, 5.0, 220.0, INF, 1.0, 0.1)


## Rocks, lone palms and odd stones across the open dunes: landmarks to steer by.
func build_scatter() -> void:
	var here := area("Scatter", Vector3.ZERO, Vector2.ZERO, false, 0.0)
	var kinds := ["rock_a", "rock_b", "rock_a", "rock_b", "rock_b", "palm_a", "palm_b", "rubble", "column_stump", "block", "rock_a", "palm_c", "column_broken"]
	var placed := 0
	var tries := 0
	while placed < 60 and tries < 2000:
		tries += 1
		var at := Vector2(random.randf_range(-165.0, 165.0), random.randf_range(-165.0, 165.0))
		var free := true
		for place: Array in places:
			if at.distance_to(place[0]) < place[1]:
				free = false
		# (the way from the start to the colonnade is left clear)
		if not free or (absf(at.x) < 7.0 and at.y > 60.0):
			continue
		var kind: String = kinds[placed % kinds.size()]
		var size := random.randf_range(0.6, 1.5) if kind.begins_with("rock") else random.randf_range(0.9, 1.15) if kind.begins_with("palm") else 1.0
		var sink := 0.25 * size if kind.begins_with("rock") else 0.12
		put(here, kind, at.x, at.y, random.randf_range(0.0, 360.0), INF, size, sink)
		places.append([at, 9.0])
		placed += 1
