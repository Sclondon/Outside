extends Node3D
## The desert (`desert.tscn`): dunes several hundred metres across, an oasis, a
## camp, a ruined colonnade, the sphinx, and the great pyramid behind it.
##
## Unlike the other levels this one is not built here. It is a scene of placed
## nodes, to be edited in the editor: every thing in it is an instance of a
## scene in `props/`, grouped under Approach, Camp, Oasis, Colonnade, Sphinx,
## Pyramid and so on. Move, copy and delete them freely. The ground is the
## `Terrain` node (`scripts/desert_terrain.gd`), which makes itself from a
## height function and is pressed level under each `TerrainPad`. PROPS.md says
## what each prop is and how to place more.
##
## What is left for this script: the light on the web, checkpoints, and putting
## back loose things that have been lost.
##
## - Checkpoints are the Marker3Ds in the group `checkpoints` (those under the
##   Checkpoints node). He comes back to the last one he was near. Add one by
##   copying one.
## - `Sun` and `Sky` are ordinary nodes: turn the sun and change the sky there.

## How much of the sun is left on in the web's renderer (see `Sand.sky`).
const WEB_SUN := 0.3

## How near a checkpoint he must come for it to become where he starts again.
@export var checkpoint_radius := 5.0
## The weather: calm, a breeze or a storm (see `SandWind`). It blows the way
## the Terrain's `wind` points, which is the way its dunes were shaped.
@export var weather := SandWind.Weather.BREEZE:
	set(value):
		weather = value
		if wind:
			wind.weather = value

## The wind over the level.
var wind: SandWind

var _player: Player
var _marks: Array[Node3D] = []
var _mark: Node3D
var _loose: Array[RigidBody3D] = []
var _loose_starts: Array[Transform3D] = []


func _enter_tree() -> void:
	# Before the ground makes its sand: on the web a sun that casts shadows
	# comes out much too bright. There it is turned down and the sand is told,
	# just as in the sand yard.
	Sand.sun_gain = 1.0
	Sand.sky = Color.BLACK
	var sun := get_node_or_null(^"Sun") as DirectionalLight3D
	var sky := get_node_or_null(^"Sky") as WorldEnvironment
	if sun and sky and sky.environment and RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy *= WEB_SUN
		Sand.sun_gain = 1.0 / WEB_SUN
		Sand.sky = sky.environment.ambient_light_color.srgb_to_linear() * sky.environment.ambient_light_energy
		sky.environment.fog_enabled = false


func _ready() -> void:
	_settle_in.call_deferred()


func _settle_in() -> void:
	_player = get_parent().get_node_or_null(^"Player") as Player
	# The wind, and damp sand round whatever water there is.
	var terrain := get_node_or_null(^"Terrain")
	wind = SandWind.new()
	wind.weather = weather
	if terrain and &"wind" in terrain:
		wind.direction = terrain.get(&"wind")
	add_child(wind)
	var sand := terrain.get(&"ground") as SandGround if terrain else null
	if sand:
		for water: Node in get_tree().get_nodes_in_group(&"water"):
			if water is Pool:
				var pool := water as Pool
				sand.paint(Sand.Kind.DAMP, Vector2(pool.global_position.x, pool.global_position.z), maxf(pool.size.x, pool.size.z) * 0.5 + 1.5, 1.0, 3.5)
	# Every brazier, torch stand and campfire is lit, and there are people about:
	# his brother at his heels, and a few of the camp wandering near the tents.
	for marker in find_children("Flame*", "Marker3D"):
		marker.add_child(Fire.brazier())
	if _player:
		var brother := Brother.new()
		brother.position = _player.position + Vector3(-2.0, 0.0, 1.0)
		add_child(brother)
		brother.follow(_player)
	var camp := get_node_or_null(^"Camp") as Node3D
	for i in 5 if camp else 0:
		var someone := Townsperson.new()
		someone.seed = 11 + i
		someone.position = camp.position + Vector3(cos(i * 1.3) * (4.0 + i), 0.3, sin(i * 1.3) * (4.0 + i))
		add_child(someone)
	for mark: Node in get_tree().get_nodes_in_group(&"checkpoints"):
		if mark is Node3D:
			_marks.append(mark)
	for thing: Node in get_tree().get_nodes_in_group(&"throwable"):
		if thing is RigidBody3D and is_ancestor_of(thing):
			_loose.append(thing)
			_loose_starts.append((thing as RigidBody3D).global_transform)


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if _player.is_on_floor():
		var at := _player.global_position
		for mark in _marks:
			if mark != _mark and at.distance_to(mark.global_position) < checkpoint_radius:
				_mark = mark
				_player.set_spawn(mark.global_position + Vector3.UP * 0.05)
	# Anything loose that has left the world goes back where it was put.
	for i in _loose.size():
		var thing := _loose[i]
		if is_instance_valid(thing) and thing != _player.carried and thing.global_position.y < _player.kill_height:
			thing.linear_velocity = Vector3.ZERO
			thing.angular_velocity = Vector3.ZERO
			thing.global_transform = _loose_starts[i]
