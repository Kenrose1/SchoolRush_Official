extends Node
## Procedural chiptune + SFX (GDD section 07). Everything is synthesised at
## startup so the project ships without audio files.

const RATE := 22050
const POOL := 8

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _sfx: Dictionary = {}
var _intensity := 0.0
var _music_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = -7.0
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -13.0
	_music.stream = _build_loop()
	add_child(_music)
	_build_sfx()


## 0 = cruising, 1 = flat out. Drives the soundtrack tempo.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	if _music_on:
		_music.pitch_scale = lerpf(0.94, 1.22, _intensity)


func start_music() -> void:
	if _music.stream == null:
		return
	_music_on = true
	_music.pitch_scale = lerpf(0.94, 1.22, _intensity)
	if not _music.playing:
		_music.play()


func stop_music() -> void:
	_music_on = false
	_music.stop()


func play(sound: String, volume_db := 0.0) -> void:
	if not _sfx.has(sound):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sfx[sound]
			p.volume_db = -7.0 + volume_db
			p.play()
			return
	var fallback: AudioStreamPlayer = _players[0]
	fallback.stream = _sfx[sound]
	fallback.volume_db = -7.0 + volume_db
	fallback.play()


# --- synthesis -------------------------------------------------------------

func _freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


func _new_buffer(samples: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(samples)
	return buf


func _mix_square(buf: PackedFloat32Array, start: int, dur: int, freq: float, vol: float, duty := 0.5) -> void:
	var phase := 0.0
	var step := freq / float(RATE)
	for i in dur:
		var idx := start + i
		if idx < 0 or idx >= buf.size():
			continue
		var env := _envelope(i, dur)
		var s := 1.0 if phase < duty else -1.0
		buf[idx] += s * vol * env
		phase += step
		if phase >= 1.0:
			phase -= 1.0


func _mix_sine(buf: PackedFloat32Array, start: int, dur: int, freq: float, vol: float) -> void:
	var phase := 0.0
	var step := freq / float(RATE)
	for i in dur:
		var idx := start + i
		if idx < 0 or idx >= buf.size():
			continue
		buf[idx] += sin(phase * TAU) * vol * _envelope(i, dur)
		phase += step
		if phase >= 1.0:
			phase -= 1.0


func _mix_noise(buf: PackedFloat32Array, start: int, dur: int, vol: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in dur:
		var idx := start + i
		if idx < 0 or idx >= buf.size():
			continue
		buf[idx] += rng.randf_range(-1.0, 1.0) * vol * _envelope(i, dur)


func _envelope(i: int, dur: int) -> float:
	var attack := maxi(1, int(dur * 0.05))
	var release := maxi(1, int(dur * 0.4))
	if i < attack:
		return float(i) / float(attack)
	if i > dur - release:
		return float(dur - i) / float(release)
	return 1.0 - 0.25 * (float(i - attack) / float(maxi(1, dur - attack - release)))


func _to_stream(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream


func _dur(seconds: float) -> int:
	return maxi(1, int(RATE * seconds))


func _build_sfx() -> void:
	# Jump: rising square blip.
	var b := _new_buffer(_dur(0.16))
	_mix_square(b, 0, _dur(0.15), _freq(64), 0.25, 0.35)
	_sfx["jump"] = _to_stream(b)

	# Slide: short noise swoosh.
	b = _new_buffer(_dur(0.22))
	_mix_noise(b, 0, _dur(0.21), 0.16)
	_sfx["slide"] = _to_stream(b)

	# Hit: low thud plus crunch.
	b = _new_buffer(_dur(0.3))
	_mix_square(b, 0, _dur(0.28), _freq(43), 0.3, 0.5)
	_mix_noise(b, 0, _dur(0.12), 0.12)
	_sfx["hit"] = _to_stream(b)

	# Pickup: two-step blip.
	b = _new_buffer(_dur(0.12))
	_mix_square(b, 0, _dur(0.05), _freq(81), 0.22, 0.25)
	_mix_square(b, _dur(0.05), _dur(0.06), _freq(88), 0.22, 0.25)
	_sfx["pickup"] = _to_stream(b)

	# Combo up: brighter three-note run.
	b = _new_buffer(_dur(0.2))
	_mix_square(b, 0, _dur(0.05), _freq(84), 0.2, 0.25)
	_mix_square(b, _dur(0.05), _dur(0.05), _freq(88), 0.2, 0.25)
	_mix_square(b, _dur(0.1), _dur(0.08), _freq(91), 0.2, 0.25)
	_sfx["combo"] = _to_stream(b)

	# Pursuer growl.
	b = _new_buffer(_dur(0.5))
	_mix_square(b, 0, _dur(0.48), _freq(33), 0.22, 0.5)
	_mix_noise(b, 0, _dur(0.3), 0.08)
	_sfx["pursuer"] = _to_stream(b)

	# School bell.
	b = _new_buffer(_dur(1.1))
	_mix_sine(b, 0, _dur(1.05), _freq(88), 0.22)
	_mix_sine(b, _dur(0.02), _dur(1.0), _freq(84), 0.14)
	_sfx["bell"] = _to_stream(b)

	# Game over: descending square.
	b = _new_buffer(_dur(0.75))
	_mix_square(b, 0, _dur(0.18), _freq(64), 0.24, 0.5)
	_mix_square(b, _dur(0.16), _dur(0.18), _freq(60), 0.24, 0.5)
	_mix_square(b, _dur(0.32), _dur(0.2), _freq(55), 0.24, 0.5)
	_mix_square(b, _dur(0.5), _dur(0.24), _freq(48), 0.24, 0.5)
	_sfx["over"] = _to_stream(b)

	# Win sting.
	b = _new_buffer(_dur(0.9))
	_mix_square(b, 0, _dur(0.14), _freq(72), 0.22, 0.4)
	_mix_square(b, _dur(0.14), _dur(0.14), _freq(76), 0.22, 0.4)
	_mix_square(b, _dur(0.28), _dur(0.14), _freq(79), 0.22, 0.4)
	_mix_square(b, _dur(0.42), _dur(0.4), _freq(84), 0.24, 0.4)
	_sfx["win"] = _to_stream(b)

	# UI click.
	b = _new_buffer(_dur(0.06))
	_mix_square(b, 0, _dur(0.05), _freq(84), 0.15, 0.5)
	_sfx["click"] = _to_stream(b)


## Four-bar loop in C minor: square bass, arpeggio lead and noise hats.
func _build_loop() -> AudioStreamWAV:
	var bpm := 132.0
	var spb := 60.0 / bpm
	var bars := 4
	var beats := bars * 4
	var total := _dur(spb * beats)
	var buf := _new_buffer(total)
	var roots: Array[int] = [36, 32, 39, 34]
	var chords: Array[Array] = [
		[60, 63, 67, 72],
		[56, 60, 63, 68],
		[63, 67, 70, 75],
		[58, 62, 65, 70],
	]
	for bar in bars:
		var bar_start := int(spb * 4.0 * bar * RATE)
		var root: int = roots[bar]
		var chord: Array = chords[bar]
		# Bass: driving eighths.
		for eighth in 8:
			var t := bar_start + int(spb * 0.5 * eighth * RATE)
			var note: int = root if eighth % 2 == 0 else root + 7
			_mix_square(buf, t, _dur(spb * 0.42), _freq(note), 0.16, 0.5)
		# Lead: arpeggio in sixteenths.
		for sixteenth in 16:
			var t := bar_start + int(spb * 0.25 * sixteenth * RATE)
			var note: int = chord[sixteenth % chord.size()] + 12
			if sixteenth % 4 == 3:
				note += 12
			_mix_square(buf, t, _dur(spb * 0.2), _freq(note), 0.075, 0.16)
		# Hats on the eighths.
		for eighth in 8:
			var t := bar_start + int(spb * 0.5 * eighth * RATE)
			_mix_noise(buf, t, _dur(spb * 0.06), 0.05)
	return _to_stream(buf, true)
