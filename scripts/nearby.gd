class_name Nearby
## Who and what is about, for things that must ask often and cheaply: the
## player, every fire that is burning (a `Fire`, wherever it is: on a brazier,
## on a torch in his hand, on a wall) and every flare. The scarabs keep away
## from these and the cobwebs are burnt by them.
##
## Nothing has to say it is there: the scene is looked through once, and after
## that every node that comes into it is looked at as it does.
##
##     for fire in Nearby.fires(get_tree()): ...
##     var boy := Nearby.player(get_tree())

static var _tree: SceneTree
static var _fires: Array[Node3D] = []
static var _player: Player
static var _pruned := 0


## Every fire burning in the scene, and every flare.
static func fires(tree: SceneTree) -> Array[Node3D]:
	_watch(tree)
	# (those that have gone out are dropped, a few times a second)
	var now := Time.get_ticks_msec()
	if now - _pruned > 200:
		_pruned = now
		for i in range(_fires.size() - 1, -1, -1):
			if not is_instance_valid(_fires[i]) or not _fires[i].is_inside_tree():
				_fires.remove_at(i)
	return _fires


## Everything that what fears fire keeps away from: every fire and flare, and
## whatever else gives a light it cannot bear (the group `sunlight`: the sun
## that `Khepri` rolls). Those are not fires: they burn no web and light no
## torch or oil, which is why they are not in `fires`.
static func feared(tree: SceneTree) -> Array[Node3D]:
	var burning := fires(tree)
	var suns := tree.get_nodes_in_group(&"sunlight")
	if suns.is_empty():
		return burning
	var all: Array[Node3D] = burning.duplicate()
	for sun: Node in suns:
		if sun is Node3D:
			all.append(sun)
	return all


## The player, if there is one.
static func player(tree: SceneTree) -> Player:
	_watch(tree)
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = null
	return _player


## How near a fire will let a thing that fears it come, for a fire whose reach
## is `reach` at the size of a torch: a brazier holds off more ground than a
## torch, a candle very little.
static func reach_of(fire: Node3D, reach: float) -> float:
	if fire is Fire:
		return reach * clampf(pow((fire as Fire).size / 0.3, 0.38), 0.45, 2.2)
	return reach * 1.7


static func _watch(tree: SceneTree) -> void:
	if tree == _tree:
		return
	_tree = tree
	_fires.clear()
	_player = null
	tree.node_added.connect(_notice)
	_look_through(tree.root)


static func _look_through(node: Node) -> void:
	_notice(node)
	for child in node.get_children():
		_look_through(child)


static func _notice(node: Node) -> void:
	if node is Fire or node is Flare:
		if not _fires.has(node):
			_fires.append(node)
	elif node is Player:
		_player = node
