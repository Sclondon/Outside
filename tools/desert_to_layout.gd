extends SceneTree
## Not part of the game. Reads a desert that was laid out as a scene of placed
## nodes (props, TerrainPads, a Pool, checkpoints) and writes it as a layout
## (`LevelLayout`): the form the game now makes the desert from and the level
## editor saves. It was run once, on the desert as it stood, to make
## `levels/desert.json`; it is kept for any other scene laid out that way.
## godot --headless --path . --script tools/desert_to_layout.gd -- <scene.tscn> <out.json>

var items: Array = []
var pads: Array = []
var next := 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: Node = (load(args[0]) as PackedScene).instantiate()
	var level: Node3D = scene.get_node("Level")
	var terrain_node: Node = level.get_node("Terrain")
	gather(level, Transform3D.IDENTITY, true)
	# The ground as it is with those pads, to say how far above it each thing stands.
	var terrain: Object = (load("res://scripts/desert_terrain.gd") as GDScript).new()
	for key: String in ["size", "cell", "dune_height", "seed", "rim_height", "rim_width", "wind"]:
		terrain.set(key, terrain_node.get(key))
	terrain.call(&"use_pads", pads)
	for item: Dictionary in items:
		if item.has("_y"):
			item["lift"] = snappedf(item["_y"] - terrain.call(&"height_at", item["at"][0], item["at"][1]), 0.01)
			item.erase("_y")
	var player := scene.get_node_or_null("Player") as Node3D
	if player:
		var at := player.transform.origin
		items.append({"id": next, "kind": "start", "at": [at.x, at.z], "lift": 0.0, "yaw": 0.0})
	var wind: Vector2 = terrain_node.get("wind")
	var layout := {
		"version": 1,
		"terrain": {"size": terrain_node.get("size"), "cell": terrain_node.get("cell"), "dune_height": terrain_node.get("dune_height"),
			"seed": terrain_node.get("seed"), "scatter": 1.0, "rim_height": terrain_node.get("rim_height"), "rim_width": terrain_node.get("rim_width"),
			"wind": [wind.x, wind.y]},
		"weather": int(level.get("weather")) if level.get("weather") != null else 1,
		"items": items,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(args[1].get_base_dir()))
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(layout, "\t", false))
	file.close()
	var counts := {}
	for item: Dictionary in items:
		counts[item["kind"]] = counts.get(item["kind"], 0) + 1
	print("LAYOUT %s: %d items %s" % [args[1], items.size(), counts])
	terrain.free()
	scene.free()
	quit()


func gather(node: Node, above: Transform3D, top := false) -> void:
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var here: Transform3D = above * (child as Node3D).transform
		var script := child.get_script() as Script
		var path := script.resource_path if script else ""
		var file := child.scene_file_path
		if top and child.name in [&"Sky", &"Sun", &"Terrain"]:
			continue
		if file.begins_with("res://props/") or file.begins_with("res://guns/"):
			var item := placed("prop" if file.begins_with("res://props/") else "thing", here)
			item["what"] = file.get_file().get_basename()
			if item["kind"] == "prop":
				var scale := here.basis.get_scale()
				item["scale"] = snappedf(scale.y, 0.001)
				if absf(scale.x - scale.y) > 0.001 or absf(scale.z - scale.y) > 0.001:
					item["stretch"] = [snappedf(scale.x / scale.y, 0.001), 1.0, snappedf(scale.z / scale.y, 0.001)]
				var turned := here.basis.orthonormalized().get_euler()
				item["tilt_x"] = snappedf(rad_to_deg(turned.x), 0.01)
				item["tilt_z"] = snappedf(rad_to_deg(turned.z), 0.01)
			items.append(item)
		elif path.ends_with("desert_pad.gd"):
			var half: Vector2 = child.get("half_size")
			var pad := {"id": next, "kind": "pad", "at": [snappedf(here.origin.x, 0.01), snappedf(here.origin.z, 0.01)], "y": snappedf(here.origin.y, 0.01),
				"yaw": snappedf(rad_to_deg(here.basis.get_euler().y), 0.01), "half_x": half.x, "half_z": half.y, "round": child.get("round"), "ease": child.get("ease")}
			next += 1
			items.append(pad)
			pads.append([here, half, child.get("round"), child.get("ease")])
		elif path.ends_with("pool.gd"):
			var size: Vector3 = child.get("size")
			items.append({"id": next, "kind": "pool", "at": [snappedf(here.origin.x, 0.01), snappedf(here.origin.z, 0.01)], "y": snappedf(here.origin.y, 0.01), "yaw": 0.0,
				"size_x": size.x, "size_z": size.z, "depth": size.y})
			next += 1
		elif child.is_in_group(&"checkpoints"):
			var mark := placed("checkpoint", here)
			mark["name"] = String(child.name)
			items.append(mark)
		else:
			gather(child, here)


func placed(kind: String, here: Transform3D) -> Dictionary:
	var item := {"id": next, "kind": kind, "at": [snappedf(here.origin.x, 0.01), snappedf(here.origin.z, 0.01)], "_y": here.origin.y,
		"yaw": snappedf(rad_to_deg(here.basis.orthonormalized().get_euler().y), 0.01)}
	next += 1
	return item
