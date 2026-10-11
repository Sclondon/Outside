extends SceneTree
## Not part of the game. Paints the sheet of pictures that fire is drawn from,
## and saves it as `textures/fire_sheet.res`: eight by eight frames, read left
## to right and top to bottom, of one lick of flame from its lighting to its
## going out (in red: how hot), and of one puff of smoke from thick to thin (in
## green: how dense). `Fire` shows a great many of them at once, each at its
## own age.
## godot --headless --path . --script tools/bake_fire_sheet.gd
## (with `-- <folder>` it saves two pictures of the sheet there as well, to look at)

const ACROSS := 8
const FRAME := 64


func _initialize() -> void:
	var slow := _noise(11, 1.0)
	var licks := _noise(23, 1.0)
	var fine := _noise(37, 1.0)
	var side := ACROSS * FRAME
	var sheet := Image.create(side, side, false, Image.FORMAT_RG8)
	var count := ACROSS * ACROSS
	for frame in count:
		var age := frame / float(count - 1)
		var corner := Vector2i(frame % ACROSS, frame / ACROSS) * FRAME
		for py in FRAME:
			for px in FRAME:
				var x := (px + 0.5) / FRAME * 2.0 - 1.0
				var y := 1.0 - (py + 0.5) / FRAME * 2.0
				# (nothing of either reaches the edge of its frame)
				var inside := 1.0 - smoothstep(0.78, 0.98, maxf(absf(x), absf(y)))
				var heat := _flame(x, y, age, slow, licks, fine) * inside
				var dense := _smoke(x, y, age, slow, licks, fine) * inside
				sheet.set_pixel(corner.x + px, corner.y + py, Color(clampf(heat, 0.0, 1.0), clampf(dense, 0.0, 1.0), 0.0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://textures"))
	var texture := ImageTexture.create_from_image(sheet)
	var error := ResourceSaver.save(texture, "res://textures/fire_sheet.res", ResourceSaver.FLAG_COMPRESS)
	print("SAVED " if error == OK else "FAILED ", "res://textures/fire_sheet.res ", side, "x", side)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		for channel in 2:
			var look := Image.create(side, side, false, Image.FORMAT_RGB8)
			for py in side:
				for px in side:
					var value: float = sheet.get_pixel(px, py)[channel]
					look.set_pixel(px, py, Color(value, value, value))
			look.save_png(args[0].path_join("fire_sheet_%s.png" % ["flame", "smoke"][channel]))
	quit()


func _noise(seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.seed = seed
	noise.frequency = frequency
	return noise


# How hot a lick of flame is at a place in its frame (x, y from -1 to 1, y up)
# when it is `age` of the way through its life: a round hot ball at first, that
# is drawn up into a point, wavers, is eaten into by what streams up through it,
# and comes apart into wisps.
func _flame(x: float, y: float, age: float, slow: FastNoiseLite, licks: FastNoiseLite, fine: FastNoiseLite) -> float:
	# Up it from its foot (0) to its tip (1): a tear, round below and pointed above.
	var up := (y + 0.78) / 1.62
	if up <= 0.0 or up >= 1.0:
		return 0.0
	var bent := x + slow.get_noise_3d(x * 1.1, y * 1.1 - age * 2.0, 0.0) * 0.42 * (0.3 + age) * up
	var wide := 1.24 * sqrt(up) * pow(1.0 - up, lerpf(0.75, 1.15, age)) * lerpf(1.0, 0.72, age)
	var across := bent / maxf(wide, 0.0001)
	var eaten := licks.get_noise_3d(x * 1.9, y * 1.9 - age * 4.0, 3.0) * 0.65 + fine.get_noise_3d(x * 4.2, y * 4.2 - age * 7.0, 7.0) * 0.35
	return (1.0 - across * across) * (1.3 - 0.3 * age) + eaten * (0.12 + 1.15 * age) * (0.3 + 0.7 * up) - age * age * 0.4 - up * age * 0.3



# How dense a puff of smoke is there: a soft round cloud, lumpy, that thins
# from the inside and the edges both as it ages.
func _smoke(x: float, y: float, age: float, slow: FastNoiseLite, licks: FastNoiseLite, fine: FastNoiseLite) -> float:
	var from_middle := Vector2(x, y).length() / 0.8
	var lumps := slow.get_noise_3d(x * 1.5 + 40.0, y * 1.5 - age * 0.8, age * 1.2) * 0.6 + licks.get_noise_3d(x * 3.0, y * 3.0 - age * 1.4, 15.0 + age * 1.6) * 0.4
	var dense := (1.0 - from_middle * from_middle) * 1.1 + lumps * (0.3 + 0.55 * age) - age * 0.4
	return smoothstep(0.0, 1.1, dense)
