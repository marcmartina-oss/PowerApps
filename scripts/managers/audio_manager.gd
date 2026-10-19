extends Node
## Autoload "Audio": every sound in the game is synthesized at startup into
## AudioStreamWAV resources, so there are no audio files to license. Music is a
## short generated loop per world, built on a worker thread the first time a
## world is entered.

const RATE := 22050
const MUSIC_SECONDS := 12.0

var _sfx: Dictionary[StringName, AudioStreamWAV] = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer
var _music: Dictionary[int, AudioStreamWAV] = {}
var _music_tasks: Dictionary[int, int] = {}
var _wanted_world := 0
var _last_play: Dictionary[StringName, float] = {}


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -9.0
	add_child(_music_player)
	_build_sfx()


func _exit_tree() -> void:
	# Never quit with a generator thread still writing into this node's data.
	for world in _music_tasks:
		WorkerThreadPool.wait_for_task_completion(_music_tasks[world])
	_music_tasks.clear()


func play(name: StringName, volume_db := 0.0) -> void:
	if not Save.sfx_on() or not _sfx.has(name):
		return
	# Many towers fire on the same frame; don't stack identical sounds.
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_play.get(name, -1.0) < 0.04:
		return
	_last_play[name] = now
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sfx[name]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


## Starts the loop for a world (1-3, or 0 for the menu theme), generating it if needed.
func play_music(world: int) -> void:
	_wanted_world = world
	if not Save.music_on():
		_music_player.stop()
		return
	if _music.has(world):
		if _music_player.stream != _music[world] or not _music_player.playing:
			_music_player.stream = _music[world]
			_music_player.play()
		return
	if not _music_tasks.has(world):
		_music_tasks[world] = WorkerThreadPool.add_task(_generate_music.bind(world))


## Generates a world's loop in the background so it is ready when the level starts.
func prewarm(world: int) -> void:
	if not _music.has(world) and not _music_tasks.has(world):
		_music_tasks[world] = WorkerThreadPool.add_task(_generate_music.bind(world))


func stop_music() -> void:
	_wanted_world = -1
	_music_player.stop()


func apply_settings() -> void:
	if Save.music_on():
		if _wanted_world >= 0:
			play_music(_wanted_world)
	else:
		_music_player.stop()


func _process(_delta: float) -> void:
	for world in _music_tasks.keys():
		if WorkerThreadPool.is_task_completed(_music_tasks[world]):
			WorkerThreadPool.wait_for_task_completion(_music_tasks[world])
			_music_tasks.erase(world)
			if world == _wanted_world:
				play_music(world)


# --- Synthesis ---

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream


## A tone with pitch sweep, waveform mix and exponential decay. `noise` mixes in white noise.
static func _tone(seconds: float, f0: float, f1: float, decay: float, noise := 0.0, square := 0.0, volume := 0.6) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var s := sin(phase * TAU)
		if square > 0.0:
			s = lerpf(s, 1.0 if s > 0.0 else -1.0, square)
		if noise > 0.0:
			s = lerpf(s, rng.randf_range(-1.0, 1.0), noise)
		var env := exp(-decay * t) * minf(i / 60.0, 1.0)
		out[i] = s * env * volume
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset_seconds := 0.0) -> PackedFloat32Array:
	var offset := int(offset_seconds * RATE)
	var n := maxi(a.size(), b.size() + offset)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in a.size():
		out[i] += a[i]
	for i in b.size():
		out[i + offset] += b[i]
	return out


func _build_sfx() -> void:
	_sfx[&"shoot_archer"] = _wav(_tone(0.12, 900, 500, 9.0, 0.15))
	_sfx[&"shoot_stone"] = _wav(_tone(0.25, 180, 60, 7.0, 0.4, 0.0, 0.7))
	_sfx[&"shoot_frost"] = _wav(_tone(0.25, 1400, 2200, 8.0, 0.1))
	_sfx[&"shoot_flame"] = _wav(_tone(0.3, 200, 120, 6.0, 0.8, 0.0, 0.4))
	_sfx[&"shoot_arcane"] = _wav(_mix(_tone(0.3, 600, 1800, 7.0, 0.0, 0.3), _tone(0.3, 900, 2700, 7.0, 0.0, 0.3, 0.3)))
	_sfx[&"hit"] = _wav(_tone(0.08, 300, 150, 12.0, 0.5, 0.0, 0.4))
	_sfx[&"splash"] = _wav(_tone(0.35, 120, 40, 6.0, 0.7, 0.0, 0.8))
	_sfx[&"death"] = _wav(_tone(0.25, 400, 120, 8.0, 0.3, 0.4, 0.5))
	_sfx[&"death_boss"] = _wav(_mix(_tone(0.8, 200, 40, 4.0, 0.5, 0.3, 0.8), _tone(0.6, 90, 30, 4.0, 0.2, 0.0, 0.6), 0.1))
	_sfx[&"build"] = _wav(_mix(_tone(0.12, 220, 220, 8.0, 0.3, 0.2, 0.5), _tone(0.12, 330, 330, 8.0, 0.1, 0.2, 0.4), 0.06))
	_sfx[&"wall"] = _wav(_tone(0.08, 180, 140, 10.0, 0.5, 0.0, 0.4))
	_sfx[&"sell"] = _wav(_mix(_tone(0.1, 880, 880, 6.0, 0.0, 0.2, 0.4), _tone(0.15, 1320, 1320, 6.0, 0.0, 0.2, 0.4), 0.08))
	_sfx[&"upgrade"] = _wav(_mix(_mix(_tone(0.12, 523, 523, 5.0, 0.0, 0.3, 0.4), _tone(0.12, 659, 659, 5.0, 0.0, 0.3, 0.4), 0.1), _tone(0.3, 784, 784, 4.0, 0.0, 0.3, 0.4), 0.2))
	_sfx[&"invalid"] = _wav(_tone(0.2, 200, 150, 8.0, 0.0, 0.6, 0.35))
	_sfx[&"leak"] = _wav(_mix(_tone(0.3, 300, 150, 5.0, 0.0, 0.5, 0.5), _tone(0.3, 150, 75, 5.0, 0.0, 0.5, 0.5), 0.15))
	_sfx[&"wave"] = _wav(_mix(_mix(_tone(0.25, 330, 330, 3.0, 0.0, 0.4, 0.5), _tone(0.25, 440, 440, 3.0, 0.0, 0.4, 0.5), 0.2), _tone(0.5, 554, 554, 3.0, 0.0, 0.4, 0.5), 0.4))
	_sfx[&"gold"] = _wav(_tone(0.1, 1760, 2200, 10.0, 0.0, 0.0, 0.3))
	_sfx[&"click"] = _wav(_tone(0.05, 700, 500, 14.0, 0.2, 0.2, 0.35))
	var win := PackedFloat32Array()
	for i in [523, 659, 784, 1047]:
		win = _mix(win, _tone(0.4, i, i, 3.0, 0.0, 0.3, 0.45), win.size() / float(RATE) * 0.55)
	_sfx[&"win"] = _wav(win)
	var lose := PackedFloat32Array()
	for i in [392, 349, 311, 262]:
		lose = _mix(lose, _tone(0.5, i, i, 2.5, 0.0, 0.5, 0.45), lose.size() / float(RATE) * 0.6)
	_sfx[&"lose"] = _wav(lose)
	_sfx[&"smash"] = _wav(_tone(0.3, 100, 50, 7.0, 0.8, 0.0, 0.8))
	_sfx[&"heal"] = _wav(_tone(0.3, 600, 1200, 5.0, 0.0, 0.0, 0.25))


## One bar-based loop: a bass line, an arpeggio and a sparse melody over a
## world-specific scale and timbre. Runs on a worker thread.
func _generate_music(world: int) -> void:
	var n := int(MUSIC_SECONDS * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var scales := {
		0: [0, 2, 4, 7, 9],          # menu: pentatonic major
		1: [0, 2, 4, 5, 7, 9, 11],   # borderlands: major
		2: [0, 2, 3, 5, 7, 8, 10],   # marsh: natural minor
		3: [0, 1, 4, 5, 7, 8, 11],   # peaks: harmonic minor-ish
	}
	var scale: Array = scales.get(world, scales[1])
	var root: float = [220.0, 220.0, 196.0, 164.8][clampi(world, 0, 3)]
	var bpm: float = [84.0, 104.0, 88.0, 118.0][clampi(world, 0, 3)]
	var beat := 60.0 / bpm
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + world
	var beats := int(MUSIC_SECONDS / beat)
	var melody_notes: Array[int] = []
	for b in beats:
		melody_notes.append(scale[rng.randi_range(0, scale.size() - 1)] + (12 if rng.randf() < 0.3 else 0))
	var chord_roots := [0, 3, 4, 0] if world != 2 else [0, 5, 3, 4]
	for i in n:
		var t := i / float(RATE)
		var b := t / beat
		var bar := int(b / 4.0) % 4
		var chord_root: int = scale[chord_roots[bar] % scale.size()]
		var bass_f := root * 0.5 * pow(2.0, chord_root / 12.0)
		var bass := sin(TAU * bass_f * t) * 0.35 * (0.6 + 0.4 * (1.0 - fmod(b, 1.0)))
		var arp_step := int(b * 2.0) % 3
		var arp_note: int = chord_root + [0, 4, 7][arp_step] if world != 2 else chord_root + [0, 3, 7][arp_step]
		var arp_f := root * pow(2.0, arp_note / 12.0)
		var arp_env := exp(-3.0 * fmod(b * 2.0, 1.0))
		var arp := sin(TAU * arp_f * t) * 0.18 * arp_env
		if world == 3:
			arp = (1.0 if arp > 0.0 else -1.0) * 0.08 * arp_env
		var mel_i := int(b) % beats
		var mel_f := root * 2.0 * pow(2.0, melody_notes[mel_i] / 12.0)
		var mel_env := exp(-2.0 * fmod(b, 1.0)) if melody_notes[mel_i] >= 0 and int(b) % 2 == 0 else 0.0
		var mel := (sin(TAU * mel_f * t) + 0.3 * sin(TAU * mel_f * 2.0 * t)) * 0.14 * mel_env
		var pad := 0.0
		if world == 2:
			pad = sin(TAU * bass_f * 2.0 * t + sin(t * 0.5)) * 0.08
		out[i] = bass + arp + mel + pad
	# Short crossfade at the loop point.
	var fade := int(0.05 * RATE)
	for i in fade:
		var k := i / float(fade)
		out[n - fade + i] = out[n - fade + i] * (1.0 - k) + out[i] * k
	_music[world] = _wav(out, true)
