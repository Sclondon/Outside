extends SceneTree
## Not part of the game. Runs a hound straight ahead at each of the given speeds
## and writes where its joints are every frame, as JSON, to compare its gaits
## with a real dog's (C:\Projects\reference\canine-motion: its tools/gait.js
## reads it as it reads the mocap). `pharaoh` for the prick-eared hound.
## godot --headless --path . --fixed-fps 60 --script tools/hound_gait_dump.gd -- <file.json> [speed ...] [pharaoh]

const BONES: Array[StringName] = [&"pelvis", &"body", &"chest", &"neck", &"head", &"tail_1",
		&"upper_fl", &"paw_fl", &"upper_fr", &"paw_fr", &"upper_rl", &"paw_rl", &"upper_rr", &"paw_rr"]
const SETTLE := 3.0
const RECORD := 4.0

var stage: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var file := args[0] if args.size() > 0 else "user://hound_gait.json"
	var speeds: Array[float] = []
	for arg in args.slice(1):
		if arg.is_valid_float():
			speeds.append(float(arg))
	if speeds.is_empty():
		speeds = [1.0, 2.4, 5.4]
	stage = Node3D.new()
	root.add_child(stage)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2000.0, 1.0, 2000.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	stage.add_child(ground)
	var runs := []
	for speed in speeds:
		runs.append(await _run(speed, args.has("pharaoh")))
	var out := FileAccess.open(file, FileAccess.WRITE)
	out.store_string(JSON.stringify(runs))
	print("saved ", file)
	quit()


func _run(speed: float, pharaoh: bool) -> Dictionary:
	var dog := Hound.new()
	dog.breed = Hound.Breed.PHARAOH if pharaoh else Hound.Breed.BLOODHOUND
	dog.position = Vector3(-300.0, 0.05, 0.0)
	dog.play_time = 0.0
	dog.settle_after = 100000.0
	stage.add_child(dog)
	dog.facing_yaw = PI * 0.5
	dog.bidden = Vector3(400.0, 0.0, 0.0)
	dog.bidden_speed = speed
	var skeleton: Skeleton3D
	var frames := []
	var time := 0.0
	while time < SETTLE + RECORD:
		await physics_frame
		time += 1.0 / 60.0
		if time < SETTLE:
			continue
		if skeleton == null:
			skeleton = dog._rig.find_children("*", "Skeleton3D", true, false)[0]
		var frame := {}
		for bone in BONES:
			var at := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
			frame[bone] = [at.x, at.y, at.z]
		frames.append(frame)
	dog.queue_free()
	await process_frame
	return {"speed": speed, "dt": 1.0 / 60.0, "frames": frames}
