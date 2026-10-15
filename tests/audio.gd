extends SceneTree
var failures=0
func check(value: bool, message: String):
	print(('PASS: ' if value else 'FAIL: ')+message)
	if not value:failures+=1
func _initialize():call_deferred('run')
func run():
	var audio=ArenaAudio.new();root.add_child(audio)
	audio.unlock()
	check(audio.music.stream.get_length()>30 and audio.music.stream.loop,'supplied BGM decodes and loops')
	check(audio.streams.size()==13 and audio.voices.size()==12 and audio.motors.size()==4,'all cue samples load into bounded voices')
	for cue in ArenaAudio.CUES:audio.play(cue)
	check(audio.cue_counts.size()==ArenaAudio.CUES.size(),'every declared cue can play')
	audio.cooldowns.clear();audio.cue_counts.clear()
	var m=MatchState.new(ArenaField.new());m.reset('free');audio.prime(m)
	m.emit_event('pick',0);audio.observe(m,0,false,.016);audio.observe(m,0,false,.016)
	check(audio.cue_counts.get('pick')==1,'repeated snapshot does not repeat an event')
	m.emit_event('place',0);audio.prime(m);audio.observe(m,0,false,.016)
	check(not audio.cue_counts.has('place'),'reconnect baseline skips old events')
	m.emit_event('flip',1);audio.observe(m,0,true,.016);audio.observe(m,0,false,.016)
	check(not audio.cue_counts.has('flip'),'paused history is not replayed on resume')
	audio.focus(false)
	check(audio.music.stream_paused and audio.motors.all(func(player):return not player.playing),'background stops motors and pauses music')
	audio.focus(true);check(not audio.music.stream_paused,'foreground restores music')
	for player in audio.voices+audio.motors+[audio.music]:player.stop()
	await create_timer(.2).timeout
	audio.free();await create_timer(.2).timeout
	quit(1 if failures else 0)
