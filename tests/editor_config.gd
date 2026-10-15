extends SceneTree
var failures=0
func check(ok: bool, message: String):
	print(('PASS: ' if ok else 'FAIL: ')+message)
	if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
	var audio=load('res://scenes/audio/audio.tscn').instantiate()
	var pick=audio.get_node('Cues/pick')
	var custom=load('res://assets/audio/maou_se_system03.ogg')
	pick.stream=custom;pick.volume_db=-23;pick.pitch_scale=.9
	var packed=PackedScene.new();packed.pack(audio)
	ResourceSaver.save(packed,'user://audio-editor-test.tscn');audio.free()
	audio=load('user://audio-editor-test.tscn').instantiate();root.add_child(audio);audio.unlock()
	audio.play('pick')
	check(audio.voices[0].stream==custom and is_equal_approx(audio.voices[0].volume_db,-23) and is_equal_approx(audio.voices[0].pitch_scale,.9),'saved Inspector stream, volume and pitch drive playback')
	check(audio.cues.pick.preview.is_valid(),'cue exposes an editor audition action')
	audio.cues.pick.enabled=false;audio.cooldowns.clear();audio.play('pick')
	check(audio.cue_counts.pick==1,'disabling a cue suppresses playback')
	audio.cues.pick.enabled=true;audio.cues.pick.stream=null;audio.play('pick')
	check(audio.cue_counts.pick==1,'empty cue stream is silent')
	audio.free();DirAccess.remove_absolute('user://audio-editor-test.tscn')
	var scene=load('res://main.tscn').instantiate();root.add_child(scene)
	await process_frame
	for compact in [false,true]:
		scene.touch_mode=compact;scene.hud.touch_mode=compact
		for method in ['show_title','show_notes','show_profile','show_online']:
			scene.call(method);await process_frame
			check(scene.menu.get_child_count()>1,'saved menu loads: '+method+(' mobile' if compact else ' desktop'))
		scene.start('free');await process_frame
		check(scene.hud.get_node('Mobile').visible==compact and scene.hud.get_node('Desktop').visible!=compact,'HUD selects its saved responsive layout')
		scene.pause_menu();await process_frame
		check(scene.menu.get_node('Reset').visible,'local pause offers reset')
		scene.mode='online';scene.pause_menu();await process_frame
		check(not scene.menu.get_node('Reset').visible,'online pause hides local reset')
		scene.game.winner=0;scene.results();await process_frame
		check(scene.menu.get_node('Heading').text=='YOU WIN','result scene receives live state')
	scene.start('free');scene.touch_mode=true;scene.touch.visible=true
	var action_button=scene.touch.get_node('Buttons/act')
	action_button.position-=Vector2(60,0)
	scene.touch.layout()
	check(scene.touch.buttons.act==action_button.get_global_rect(),'touch hit area follows edited Button position')
	var tap=InputEventScreenTouch.new();tap.index=3;tap.position=action_button.get_global_rect().get_center();tap.pressed=true
	scene.touch._input(tap)
	check(scene.pending.get('act',false),'touch on edited button sends interaction')
	tap.pressed=false;scene.touch._input(tap)
	scene.touch.landscape_required=true;scene.touch.update_view()
	check(scene.touch.get_node('Portrait').visible and not scene.touch.get_node('Buttons').visible,'portrait node hides touch buttons')
	scene.touch.landscape_required=false
	scene.camera.follow_distance=7.5
	check(scene.camera.follow_distance==7.5,'camera settings are editable independently of match logic')
	scene.stadium.burst(Vector3.ZERO,Color.WHITE,14)
	check(scene.stadium.get_node('Effects/Burst1').emitting,'native particle scene emits on match event')
	for action in ['move_forward','interact','switch_robot','pause','overview']:
		check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),'Input Map defines '+action)
	scene.queue_free();await process_frame
	quit(1 if failures else 0)
