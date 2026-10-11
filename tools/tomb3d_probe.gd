extends SceneTree
## Not part of the game. Prints how a tomb is set out to be walked through: its cells, rooms, air and parts.
## godot --headless --path . --script tools/tomb3d_probe.gd -- <seed>:<difficulty> [branching] [areas] [parts] [lines]
## (`branching`: the tomb that branches, from `TombBranching`.)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var said := (args[0] if not args.is_empty() else "1:1").split(":")
	var plan := TombGenerator.generate(int(said[0]), int(said[1]) if said.size() > 1 else 1)
	if "branching" in args:
		plan = TombBranching.generate(int(said[0]), int(said[1]) if said.size() > 1 else 1)
	var layout := TombLayout3D.set_out(plan)
	print(plan.describe())
	for room in plan.rooms:
		var info := layout.rooms[room.id]
		print("room %d %s cell %s turn %d: %s" % [room.id, TombPlan.ROLE_NAMES[room.role], layout.cells[room.id], layout.turns[room.id], info])
	for link in plan.links:
		print("link %d %d>%d %s: %s" % [link.id, link.a, link.b, TombPlan.PASS_NAMES[link.pass_kind], layout.ways[link.id]])
	if "areas" in args:
		for area in layout.areas:
			print("area room %d x %.2f..%.2f z %.2f..%.2f floor %.2f ceil %.2f%s%s%s" % [area.room, area.x0, area.x1, area.z0, area.z1, area.floor, area.ceil,
					" deadly" if area.deadly else "", " sky" if area.sky else "", " gate" if area.gate else ""])
	if "parts" in args:
		for part in layout.parts:
			print("part ", part)
	if "lines" in args:
		for n in layout.walk_points.size():
			print("point %d room %d %s" % [n, layout.walk_rooms[n], layout.walk_points[n]])
		for line in layout.walk_lines:
			print("line %d-%d" % [line.x, line.y])
	for arg: String in args:
		if arg.begins_with("at="):
			# (every piece of stone, and every part, within two metres of a place: at=x,z)
			var said_at := arg.trim_prefix("at=").split(",")
			var spot := Vector2(float(said_at[0]), float(said_at[1]))
			for box: Array in layout.boxes:
				var middle: Vector3 = box[0]
				var extent: Vector3 = box[1]
				if absf(middle.x - spot.x) < extent.x * 0.5 + 2.0 and absf(middle.z - spot.y) < extent.z * 0.5 + 2.0:
					print("stone %s room %d: x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f" % [box[2], box[4], middle.x - extent.x * 0.5, middle.x + extent.x * 0.5, middle.y - extent.y * 0.5, middle.y + extent.y * 0.5, middle.z - extent.z * 0.5, middle.z + extent.z * 0.5])
			for part in layout.parts:
				if Vector2((part["at"] as Vector3).x, (part["at"] as Vector3).z).distance_to(spot) < 3.0:
					print("part ", part)
	print("moves ", layout.moves.size(), " boxes ", layout.boxes.size(), " areas ", layout.areas.size(), " length ", layout.length)
	quit()
