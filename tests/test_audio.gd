extends "res://tests/test_case.gd"
## The audio is synthesized, so check it actually produces streams of the right shape.


func test_every_sound_effect_exists_and_is_short() -> void:
	var names := [&"shoot_archer", &"shoot_stone", &"shoot_frost", &"shoot_flame", &"shoot_arcane", &"hit", &"splash",
		&"death", &"death_boss", &"build", &"wall", &"sell", &"upgrade", &"invalid", &"leak", &"wave", &"gold", &"click",
		&"win", &"lose", &"smash", &"heal"]
	for n: StringName in names:
		var stream: AudioStreamWAV = Audio._sfx.get(n)
		assert_true(stream != null, "missing sfx %s" % n)
		if stream:
			assert_true(stream.get_length() > 0.03 and stream.get_length() < 3.0, "%s is %.2fs" % [n, stream.get_length()])


func test_music_generates_on_a_worker_thread() -> void:
	Save.set_setting("music", true)
	var started := Time.get_ticks_msec()
	Audio.play_music(2)
	# Headless frames run far faster than real time; the worker thread needs wall-clock time.
	while Time.get_ticks_msec() - started < 15000 and not Audio._music.has(2):
		OS.delay_msec(20)
		await tree.process_frame
	assert_true(Audio._music.has(2), "marsh theme generated")
	if Audio._music.has(2):
		var stream: AudioStreamWAV = Audio._music[2]
		assert_true(absf(stream.get_length() - Audio.MUSIC_SECONDS) < 0.05, "loop is %.2fs" % stream.get_length())
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		# Not silent and not clipping.
		var peak := 0
		for i in range(0, stream.data.size(), 2):
			peak = maxi(peak, absi(stream.data.decode_s16(i)))
		assert_true(peak > 3000 and peak < 32767, "peak sample %d" % peak)
	print("          music generated in %d ms" % (Time.get_ticks_msec() - started))
	Audio.stop_music()
