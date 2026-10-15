class_name ArenaAudio
extends Node
const CUES={
	'hover':['system08',-17.0,1.0], 'confirm':['system49',-9.0,1.0], 'back':['system18',-12.0,1.0],
	'pause':['system18',-14.0,.9], 'resume':['system17',-13.0,1.0], 'start':['system03',-12.0,1.0],
	'switch':['system17',-13.0,1.15], 'select':['system10',-15.0,1.2], 'deny':['system18',-14.0,.7],
	'work':['sound19',-9.0,1.0], 'pick':['sound20',-8.0,1.2], 'drop':['sound20',-7.0,.85],
	'give':['onepoint24',-14.0,1.2], 'place':['sound20',-6.0,.7], 'flip':['onepoint20',-13.0,1.0],
	'mustika':['onepoint15',-9.0,1.0], 'mandate':['onepoint20',-11.0,1.0], 'score':['system10',-21.0,1.4],
	'climb':['sound05',-12.0,1.0], 'land':['sound20',-8.0,.8], 'retry':['system03',-16.0,1.4],
	'bump':['sound20',-20.0,.65], 'brake':['sound19',-22.0,.8], 'camera':['system08',-28.0,.85],
	'overview':['system17',-16.0,.8], 'fullscreen':['system10',-16.0,1.0], 'tick':['system08',-12.0,1.0],
	'warning':['onepoint24',-14.0,.8], 'finish':['system18',-10.0,.5], 'win':['onepoint15',-9.0,1.0],
	'lose':['onepoint14',-13.0,1.0], 'draw':['onepoint24',-12.0,1.0], 'found':['onepoint15',-15.0,1.3],
	'lost':['system18',-12.0,.8], 'reconnected':['system49',-12.0,1.2]
}
var streams={}
var voices: Array=[]
var motors: Array=[]
var music: AudioStreamPlayer
var next_voice=0
var unlocked=false
var focused=true
var last_event=0
var cooldowns={}
var cue_counts={}
var previous_positions=[]
var previous_moving=[false,false,false,false]
var motion_hold=[0.0,0.0,0.0,0.0]
var last_seconds=-1
var look_at_time=0.0

func _ready():
	AudioServer.add_bus_effect(0,AudioEffectLimiter.new())
	for name in ['Music','SFX']:
		if AudioServer.get_bus_index(name)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,name)
	for cue in CUES.values():
		if not streams.has(cue[0]):streams[cue[0]]=load('res://assets/audio/maou_se_'+cue[0]+'.ogg')
	for i in range(12):
		var player=AudioStreamPlayer.new();player.bus='SFX';add_child(player);voices.append(player)
	var roll=load('res://assets/audio/maou_se_sound23.ogg').duplicate();roll.loop=true
	for i in range(4):
		var player=AudioStreamPlayer3D.new();player.stream=roll;player.bus='SFX';player.unit_size=2;player.max_distance=16;player.volume_db=-24;add_child(player);motors.append(player)
	music=AudioStreamPlayer.new();music.bus='Music';music.stream=load('res://assets/audio/maou_loop_bgm_neorock82.mp3').duplicate();music.stream.loop=true;music.volume_db=-10;add_child(music)

func levels(bgm: float, sfx: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'),linear_to_db(maxf(.0001,bgm)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('SFX'),linear_to_db(maxf(.0001,sfx)))

func unlock():
	if unlocked:return
	unlocked=true
	music.play()

func play(cue: String, gain=0.0, cooldown=.08):
	if not unlocked or not focused or not CUES.has(cue):return
	var now=Time.get_ticks_msec()/1000.0
	if now<float(cooldowns.get(cue,-100)):return
	cooldowns[cue]=now+cooldown
	var spec=CUES[cue];var player=voices[next_voice];next_voice=(next_voice+1)%voices.size()
	player.stream=streams[spec[0]];player.volume_db=spec[1]+gain;player.pitch_scale=spec[2];player.play()
	cue_counts[cue]=int(cue_counts.get(cue,0))+1

func focus(value: bool):
	focused=value;music.stream_paused=not value
	if not value:
		for player in voices:player.stop()
		for player in motors:player.stop()

func prime(m: MatchState):
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
		var rid=int(event.rid)
		play(str(event.type),0 if rid==local_rid or rid<0 else -8)
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
		if moving and unlocked and focused:
			player.pitch_scale=.8+clampf(moved/maxf(dt,.001),0,1.7)*.15
			if not player.playing:player.play()
		else:player.stop()
		if rid==local_rid and not silent:
			if previous_moving[rid] and not moving:play('brake',0,.3)
			if not moving and r.v.length()>.3 and r.job.is_empty():play('bump',0,.7)
		previous_moving[rid]=moving
	music.volume_db=lerpf(music.volume_db,-17 if silent else -10,minf(1,dt*4))
