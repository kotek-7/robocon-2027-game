class_name ArenaAudio
extends Node
var voices: Array=[]
var motors: Array=[]
var motor_pitches: Array=[]
var music: AudioStreamPlayer
var menu_music: AudioStreamPlayer
var match_music: AudioStreamPlayer
var cues: Dictionary = {}
@export_range(0.0, 3.0) var fade_out_seconds = 0.35
@export_range(-40.0, 0.0) var remote_gain_db = -8.0
@export_range(0.1, 2.0) var motor_base_pitch = 0.8
@export_range(0.0, 1.0) var motor_speed_pitch = 0.15
var in_menu=true
var music_fade: Tween
@onready var match_start_delay: Timer = $MatchStartDelay
var next_voice=0
var unlocked=false
var focused=true
var last_event=0
var cooldowns={}
var cue_counts={}
var previous_positions=[]
var previous_moving=[false,false,false,false]
var motion_hold=[0.0,0.0,0.0,0.0]
var previous_scores=[]
const LOCAL_CUES = ["switch", "select", "deny", "work", "pick", "drop", "give", "place", "flip", "climb", "land", "bump", "brake"]
var last_seconds=-1
var look_at_time=0.0

func _ready():
	match_start_delay.timeout.connect(_start_current_music)
	voices=$Voices.get_children()
	motors=$Motors.get_children()
	for motor in motors:motor_pitches.append(motor.pitch_scale)
	music=$Music
	menu_music=$MenuMusic
	match_music=$MatchMusic
	music.stream=menu_music.stream;music.pitch_scale=menu_music.pitch_scale;music.bus=menu_music.bus
	for cue in $Cues.get_children():
		if cues.has(String(cue.event)):push_error('Duplicate audio event: '+String(cue.event))
		cues[String(cue.event)]=cue

func set_menu(value: bool):
	if in_menu==value:return
	if not value:
		start_match()
		return
	in_menu=true
	match_start_delay.stop()
	_fade_out_then(_start_current_music)

func start_match():
	# Every new match/reset restarts the delay; opening pause does not.
	in_menu=false
	match_start_delay.stop()
	_fade_out_then(music.stop)
	match_start_delay.start()

func finish_match() -> float:
	match_start_delay.stop()
	_fade_out_then(music.stop)
	for player in voices+motors:player.stop()
	play("finish",0,0)
	var spec=cues.get("finish")
	return maxf(2.0,spec.stream.get_length()/spec.pitch_scale) if spec and spec.enabled and spec.stream else 2.0

func _fade_out_then(next: Callable):
	if is_instance_valid(music_fade) and music_fade.is_valid():music_fade.kill()
	if unlocked and music.playing and fade_out_seconds>0:
		music_fade=create_tween()
		music_fade.tween_property(music,'volume_linear',0.0,fade_out_seconds)
		music_fade.tween_callback(next)
		if not focused:music_fade.pause()
	else:next.call()

func _start_current_music():
	# A delayed start may overtake a long/paused fade-out. Cancel its callback.
	if is_instance_valid(music_fade) and music_fade.is_valid():music_fade.kill()
	var target=menu_music if in_menu else match_music
	music.stop();music.stream=target.stream
	music.pitch_scale=target.pitch_scale;music.bus=target.bus
	music.volume_db=target.volume_db
	if unlocked and music.stream:
		music.play();music.stream_paused=not focused

func levels(bgm: float, sfx: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'),linear_to_db(maxf(.0001,bgm)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('SFX'),linear_to_db(maxf(.0001,sfx)))

func unlock():
	if unlocked:return
	unlocked=true
	if match_start_delay.is_stopped():_start_current_music()

func play(cue: String, gain=0.0, cooldown=.08):
	if not unlocked or not focused or not cues.has(cue):return
	var spec=cues[cue]
	if not spec.enabled or not spec.stream:return
	var now=Time.get_ticks_msec()/1000.0
	if now<float(cooldowns.get(cue,-100)):return
	cooldowns[cue]=now+cooldown
	var player=voices[next_voice];next_voice=(next_voice+1)%voices.size()
	player.stream=spec.stream;player.volume_db=spec.volume_db+gain;player.pitch_scale=spec.pitch_scale;player.bus=spec.bus;player.play()
	cue_counts[cue]=int(cue_counts.get(cue,0))+1

func focus(value: bool):
	focused=value;music.stream_paused=not value
	if is_instance_valid(music_fade) and music_fade.is_valid():
		if value:music_fade.play()
		else:music_fade.pause()
	if not value:
		for player in voices:player.stop()
		for player in motors:player.stop()

func prime(m: MatchState):
	previous_scores=m.scores.duplicate()
	last_event=m.event_seq;last_seconds=ceili(m.duration-m.elapsed);previous_positions.clear()
	for r in m.robots:previous_positions.append(r.p)
	previous_moving=[false,false,false,false]
	for player in motors:player.stop()

func look():
	var now=Time.get_ticks_msec()/1000.0
	if now-look_at_time>.25:play('camera',0,.3)
	look_at_time=now

func observe(m: MatchState, local_rid: int, silent: bool, dt: float):
	if previous_positions.size()!=4:prime(m)
	for event in m.events:
		if int(event.id)<=last_event:continue
		last_event=int(event.id)
		if silent:continue
		var kind=str(event.type)
		if kind in ["score", "finish"]:continue
		var rid=int(event.rid)
		if kind in LOCAL_CUES and rid!=local_rid:continue
		play(str(event.type),0 if rid==local_rid or rid<0 else remote_gain_db)
	var local_team=int(local_rid/2)
	if not silent and previous_scores.size()==2 and m.scores[local_team]>previous_scores[local_team]:play("score")
	previous_scores=m.scores.duplicate()
	var seconds=ceili(m.duration-m.elapsed)
	if seconds!=last_seconds and not silent and m.mode!='free':
		if seconds in [60,30]:play('warning')
		elif seconds>0 and seconds<=10:play('tick')
	last_seconds=seconds
	for rid in range(4):
		var r=m.robots[rid];var moved=r.p.distance_to(previous_positions[rid]);previous_positions[rid]=r.p
		motion_hold[rid]=.12 if moved>.0001 else maxf(0,motion_hold[rid]-dt)
		var moving=not silent and not m.finished and (motion_hold[rid]>0 or r.job.get('type')=='climb')
		var player=motors[rid];player.position=r.p
		if player.stream and rid==local_rid and moving and unlocked and focused:
			player.pitch_scale=motor_pitches[rid]*(motor_base_pitch+clampf(moved/maxf(dt,.001),0,1.7)*motor_speed_pitch)
			if not player.playing:player.play()
		else:player.stop()
		if rid==local_rid and not silent and not m.finished:
			if previous_moving[rid] and not moving:play('brake',0,.3)
			if not moving and r.v.length()>.3 and r.job.is_empty():play('bump',0,.7)
		previous_moving[rid]=moving
