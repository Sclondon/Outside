extends SceneTree
## Not part of the game. Puts birds into the desert as the level's editor would (an item of the layout, made by
## `Desert.make`), by the oasis and by the colonnade, and says where they have got to after a few seconds.
## Nothing is saved.
## godot --headless --path . --fixed-fps 60 --script tools/bird_place_check.gd


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var scene: Node = (load("res://desert.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var level: Desert = scene.get_node("Level")
	for i in 60:
		await physics_frame
	var failed := 0
	for place: Array in [[0, Vector2(62, 78), "sparrows by the oasis"], [4, Vector2(60, 80), "ibis by the oasis"], [7, Vector2(62, 78), "geese by the oasis"],
			[8, Vector2(0, 40), "a kestrel at the colonnade"], [10, Vector2(0, 0), "vultures over the sphinx"]]:
		var item := LevelLayout.new_item(level.layout, "person", "birds", place[1])
		item["bird"] = place[0]
		item["count"] = 6
		item["roam"] = 40.0
		level.layout["items"].append(item)
		level.make(item)
		var birds := level.nodes[item["id"]] as Birds
		for i in 300:
			await physics_frame
			await process_frame
		var tops := 0
		var water := 0
		for spot in birds.spots:
			tops += 1 if spot.where == Birds.Where.TOP else 0
			water += 1 if spot.where == Birds.Where.WATER or spot.where == Birds.Where.WADE else 0
		var low := INF
		var high := -INF
		var afloat := 0
		for b in birds.birds:
			var ground := level.terrain.height_at(b.at.x, b.at.z)
			low = minf(low, b.at.y - ground)
			high = maxf(high, b.at.y - ground)
			afloat += 1 if b.afloat else 0
		var good := birds != null and birds._placed and not birds._flat and low > -1.6
		print("%s  %s: %d places (%d high, %d wet); birds from %.2f to %.2f m over the ground, %d afloat, %d down" % ["ok   " if good else "FAIL ", place[2], birds.spots.size(), tops, water, low, high, afloat, birds.settled()])
		failed += 0 if good else 1
	print("PASSED" if failed == 0 else "FAILED")
	quit(failed)
