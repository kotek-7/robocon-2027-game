extends SceneTree
var failures=0
func check(value: bool, message: String):
	print(('PASS: ' if value else 'FAIL: ')+message)
	if not value:failures+=1
func _initialize():call_deferred('run')
func run():
	var audio=load("res://scenes/audio/audio.tscn").instantiate();root.add_child(audio)
	audio.unlock()
	check(audio.music.stream.get_length()>30 and audio.music.stream.loop,'supplied BGM decodes and loops')
	check(audio.cues.size()==35 and audio.voices.size()==12 and audio.motors.size()==4,'all cue samples load into bounded voices')
	for cue in audio.cues:audio.play(cue)
	check(audio.cue_counts.size()==audio.cues.values().filter(func(cue):return cue.enabled and cue.stream!=null).size(),'every enabled assigned cue can play')
	audio.cooldowns.clear();audio.cue_counts.clear()
	var m=MatchState.new(ArenaField.new());m.reset('free');audio.prime(m)
	m.emit_event('pick',0);audio.observe(m,0,false,.016);audio.observe(m,0,false,.016)
	check(audio.cue_counts.get('pick')==1,'repeated snapshot does not repeat an event')
	m.emit_event('place',0);audio.prime(m);audio.observe(m,0,false,.016)
	check(not audio.cue_counts.has('place'),'reconnect baseline skips old events')
	m.emit_event('flip',1);audio.observe(m,0,true,.016);audio.observe(m,0,false,.016)
	check(not audio.cue_counts.has('flip'),'paused history is not replayed on resume')
	audio.cooldowns.clear();audio.cue_counts.clear()
	for rid in [1,2,3]:
		for cue in audio.LOCAL_CUES:m.emit_event(cue,rid)
	audio.observe(m,0,false,.016)
	check(audio.cue_counts.is_empty(),'partner and opponent minor cues are silent')
	for rid in [0,1,2,3]:
		audio.cooldowns.clear();m.emit_event('retry',rid);audio.observe(m,0,false,.016)
	check(audio.cue_counts.get('retry')==4,'retry plays for every robot on both teams')
	m.scores[1]+=10;m.emit_event('score');audio.observe(m,0,false,.016)
	check(not audio.cue_counts.has('score'),'opponent scoring is silent')
	m.scores[0]+=10;m.emit_event('score');audio.observe(m,0,false,.016)
	check(audio.cue_counts.get('score')==1,'own team scoring plays once')
	audio.cooldowns.clear();audio.cue_counts.clear();audio.prime(m)
	m.scores[0]+=10;audio.observe(m,0,true,.016);audio.observe(m,0,false,.016)
	check(not audio.cue_counts.has('score'),'muted score changes are not replayed')
	audio.prime(m)
	for r in m.robots:r.p.x+=.1
	audio.observe(m,0,false,.016)
	check(audio.motors.all(func(player):return player.stream==null and not player.playing),'motor audio is disabled for all robots')
	check(is_equal_approx(audio.music.volume_db,audio.menu_music.volume_db),'menu music starts at configured volume without fade-in')
	audio.focus(false)
	check(audio.music.stream_paused and audio.motors.all(func(player):return not player.playing),'background stops motors and pauses music')
	audio.focus(true);check(not audio.music.stream_paused,'foreground restores music')
	audio.start_match()
	check(is_equal_approx(audio.match_start_delay.wait_time,1.0),'match delay is configured as one second')
	await create_timer(.65).timeout
	check(not audio.music.playing,'match music remains silent before one second')
	await create_timer(.45).timeout
	check(audio.music.playing and audio.music.stream==audio.match_music.stream and is_equal_approx(audio.music.volume_db,audio.match_music.volume_db),'match BGM starts after delay at full configured volume')
	audio.set_menu(false)
	check(audio.match_start_delay.is_stopped(),'pause does not restart match delay')
	audio.start_match()
	await create_timer(.65).timeout
	check(not audio.music.playing,'reset delays BGM even when already in match mode')
	audio.set_menu(true)
	await create_timer(.55).timeout
	check(audio.music.playing and audio.music.stream==audio.menu_music.stream and is_equal_approx(audio.music.volume_db,audio.menu_music.volume_db),'return to title cancels delayed match BGM without fade-in')
	audio.start_match();audio.focus(false)
	await create_timer(1.1).timeout
	audio.focus(true)
	await create_timer(.15).timeout
	check(audio.music.playing and audio.music.stream==audio.match_music.stream and is_equal_approx(audio.music.volume_db,audio.match_music.volume_db),'focus restoration cannot revive an old fade-out after delayed start')
	for player in audio.voices+audio.motors+[audio.music]:player.stop()
	await create_timer(.2).timeout
	audio.free();await create_timer(.2).timeout
	quit(1 if failures else 0)
