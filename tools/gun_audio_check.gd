extends SceneTree
## Not part of the game. Loads every recording in audio/guns/ as the game does and prints,
## from its samples: length, peak, RMS, when it starts (the first sample over a tenth of
## its peak), and how loud each fifth of a second of it is, to see that none goes
## silent, jumps or starts again partway.
## godot --headless --path . --script tools/gun_audio_check.gd

func _initialize() -> void:
	var files := Array(DirAccess.get_files_at("res://audio/guns")).filter(func(file: String) -> bool: return file.ends_with(".wav"))
	files.sort()
	var bad := 0
	for file: String in files:
		var imported := load("res://audio/guns/" + file) as AudioStreamWAV
		# (the game plays the imported, packed stream; the samples are read from the file itself)
		var stream := AudioStreamWAV.load_from_file("res://audio/guns/" + file, {"compress/mode": 0})
		if imported == null or stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or absf(imported.get_length() - stream.get_length()) > 0.01:
			print("FAIL %s does not load" % file)
			bad += 1
			continue
		var step := 4 if stream.stereo else 2
		var count := stream.data.size() / step
		var peak := 0.0
		var total := 0.0
		var onset := -1
		var values := PackedFloat32Array()
		values.resize(count)
		for i in count:
			values[i] = stream.data.decode_s16(i * step) / 32768.0
			peak = maxf(peak, absf(values[i]))
			total += values[i] * values[i]
		for i in count:
			if absf(values[i]) > peak * 0.1:
				onset = i
				break
		var window := stream.mix_rate / 5
		var levels: Array = []
		var jump := 0.0
		for start in range(0, count, window):
			var sum := 0.0
			var many := mini(window, count - start)
			for i in many:
				sum += values[start + i] * values[start + i]
			levels.append("%.3f" % sqrt(sum / maxi(many, 1)))
		# The biggest step from one sample to the next after the first twentieth of a second: a splice shows as one.
		for i in range(stream.mix_rate / 20, count - 1):
			jump = maxf(jump, absf(values[i + 1] - values[i]))
		print("%-20s %5.3fs %dHz peak %.2f rms %.3f onset %5.1fms jump %.2f loop %d | %s" % [file.get_basename(), float(count) / stream.mix_rate,
				stream.mix_rate, peak, sqrt(total / maxi(count, 1)), onset * 1000.0 / stream.mix_rate, jump, stream.loop_mode, " ".join(levels)])
	print("AUDIO CHECK: %d files, %d failed to load" % [files.size(), bad])
	quit()
