class_name TrainVehicle
extends AnimatableBody3D
## A railway vehicle: one of the scenes tools/build_train_scenes.gd writes into
## `props/` (`loco`, `tender`, `carriage`, `van_goods`...). Put down by itself
## it stands where it is put, like any prop. A `Train` (`scripts/train.gd`)
## couples several and runs them, and tells each how far it has rolled:
## `roll` turns the wheels by that, works the rods of an engine, and rocks the
## body a little on its springs. What he stands on does not rock: only the
## model does, so his footing is as sure as on a floor.
##
## It lies along its own Z, front towards +Z, with the ground at its origin.

## How far off it is still drawn, in metres (0: always), and whether it casts a shadow.
@export var draw_distance := 0.0
@export var casts_shadow := true
## How far its buffers stand from its middle, at the front and at the back.
@export var front := 3.5
@export var rear := 3.5
## The radius of each pair of wheels, by the name of its piece in the model.
@export var wheels := {}
## An engine: the throw of its cranks, and the length of its connecting rods.
@export var crank := 0.0
@export var rod := 0.0
## The top of its roof (0: it has none to speak of).
@export var roof_top := 0.0
## Where someone inside it is: while he is, its roof is not drawn.
@export var inside := AABB()

## How far it has rolled, metres, and how fast it is going.
var rolled := 0.0
var pace := 0.0
## Smoke from its chimney, if it has one.
var smoke: TrainSmoke
## Who the roof is hidden for: the Train says, or the first Player found.
var passenger: Node3D

var _model: Node3D
var _turning: Array = []
var _roof: Node3D
var _sway := 0.0
var _sought := false
# A number of its own, so that no two vehicles rock in step.
var _own := 0.0


func _ready() -> void:
	sync_to_physics = false
	_model = get_node_or_null(^"Model")
	if _model == null:
		return
	Prop.dress(_model, draw_distance, casts_shadow)
	Worn.shine.call_deferred(_model)
	for piece: String in wheels:
		var wheel := _model.get_node_or_null(piece) as Node3D
		if wheel:
			_turning.append([wheel, float(wheels[piece])])
	_roof = _model.get_node_or_null(^"Roof")
	_own = fposmod(float(get_instance_id() % 997) * 0.618, 1.0) * TAU
	var chimney := get_node_or_null(^"Chimney") as Node3D
	if chimney:
		smoke = TrainSmoke.new()
		smoke.name = "Smoke"
		chimney.add_child(smoke)
	_pose()


## It has gone `distance` further (back, if that is less than nothing), at `speed`.
func roll(distance: float, speed: float) -> void:
	rolled += distance
	pace = speed
	_pose()


func _pose() -> void:
	for entry: Array in _turning:
		(entry[0] as Node3D).rotation.x = rolled / float(entry[1])
	if crank > 0.0 and not _turning.is_empty():
		_work_rods(rolled / float(_turning[0][1]))
	# Rocking: a slow roll from side to side, a nod, and a jolt at each rail joint (every ten metres).
	var lively := clampf(absf(pace) / 9.0, 0.0, 1.0)
	_model.rotation.z = (sin(rolled * 0.19 + _own) * 0.008 + sin(rolled * 0.53 + _own * 2.0) * 0.004) * lively
	_model.rotation.x = sin(rolled * 0.31 + _own) * 0.0025 * lively
	var joint := fposmod(rolled + _own, 10.0) / 10.0
	_model.position.y = -0.012 * lively * exp(-joint * 14.0)


# The rods of an engine, for a turn of its driving wheels. On the right the
# crank pin is forward when the wheels have not turned, and on the left it is
# a quarter of a turn on. A coupling rod goes round with its pins, level; a
# connecting rod has one end on the pin and the other on the crosshead, which
# only slides.
func _work_rods(turn: float) -> void:
	for side: Array in [["R", 0.0], ["L", PI * 0.5]]:
		var angle: float = turn + float(side[1])
		var up := -crank * sin(angle)
		var along := crank * cos(angle)
		var coupling := _model.get_node_or_null("Rod%s" % side[0]) as Node3D
		var connecting := _model.get_node_or_null("Con%s" % side[0]) as Node3D
		var crosshead := _model.get_node_or_null("Cross%s" % side[0]) as Node3D
		if coupling:
			_home(coupling)
			coupling.position = (coupling.get_meta(&"home") as Vector3) + Vector3(0.0, up, along - crank)
		var reach := sqrt(maxf(rod * rod - up * up, 0.0))
		if connecting:
			_home(connecting)
			connecting.position = (connecting.get_meta(&"home") as Vector3) + Vector3(0.0, up, along - crank)
			connecting.rotation.x = asin(clampf(up / maxf(rod, 0.01), -1.0, 1.0))
		if crosshead:
			_home(crosshead)
			crosshead.position = (crosshead.get_meta(&"home") as Vector3) + Vector3(0.0, 0.0, along + reach - crank - rod)


func _home(piece: Node3D) -> void:
	if not piece.has_meta(&"home"):
		piece.set_meta(&"home", piece.position)


func _process(_delta: float) -> void:
	if _roof == null or not inside.has_volume():
		return
	if passenger == null and not _sought:
		_sought = true
		passenger = _find_player(get_tree().root)
	if is_instance_valid(passenger):
		_roof.visible = not inside.has_point(to_local(passenger.global_position + Vector3.UP * 0.3))


static func _find_player(under: Node) -> Player:
	if under is Player:
		return under
	for child in under.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


## The ends of its floor or roof along its length: where someone could be standing on it.
func holds(point: Vector3) -> bool:
	var at := to_local(point)
	return at.z < front and at.z > -rear and absf(at.x) < 1.7 and at.y > 0.6
