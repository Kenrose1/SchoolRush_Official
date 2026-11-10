extends SceneTree
## Builds the game's sound effects as small mono WAV files.
##
##   godot --headless --path . --script tools/build_audio.gd
##
## Every clip is synthesised here so the project carries no third-party audio.

const RATE := 22050
const OUT_DIR := "res://assets/audio"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save("pickup", _chime())
	_save("jump", _tone(340.0, 720.0, 0.16, 0.45))
	_save("hit", _tone(220.0, 70.0, 0.24, 0.55, true))
	_save("ui_click", _tone(1250.0, 880.0, 0.05, 0.3))
	_save("finish", _fanfare())
	quit()


## Short two-note rise for School Item pickups.
func _chime() -> PackedByteArray:
	var data := _tone(880.0, 1320.0, 0.08, 0.45)
	data.append_array(_tone(1320.0, 1760.0, 0.1, 0.4))
	return data


## Four-note rise for reaching the exit door.
func _fanfare() -> PackedByteArray:
	var data := PackedByteArray()
	for pair in [[523.0, 659.0], [659.0, 784.0], [784.0, 1046.0]]:
		data.append_array(_tone(pair[0], pair[1], 0.12, 0.42))
	data.append_array(_tone(1046.0, 1046.0, 0.22, 0.35))
	return data


## Frequency sweep with an exponential decay envelope, as 16-bit mono PCM.
## [param square] rounds the wave off into a buzz for impacts.
func _tone(from: float, to: float, seconds: float, gain: float,
		square: bool = false) -> PackedByteArray:
	var count := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for index in count:
		var t := float(index) / float(count)
		var frequency := lerpf(from, to, t)
		phase += TAU * frequency / RATE
		var sample := sin(phase)
		if square:
			sample = signf(sample) * 0.65
		sample *= pow(1.0 - t, 2.0) * gain
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	return data


func _save(clip_name: String, data: PackedByteArray) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	var path := "%s/%s.wav" % [OUT_DIR, clip_name]
	var err := stream.save_to_wav(ProjectSettings.globalize_path(path))
	print("wrote ", path, " err=", err, " bytes=", data.size())
