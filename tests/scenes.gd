extends SceneTree

func _initialize():
	call_deferred('check_scenes')

func check_scenes():
	var scene=load('res://main.tscn').instantiate()
	# Geometry must exist before _ready, including in the editor.
	assert(scene.get_node('Robots').get_child_count()==4)
	assert(scene.get_node('Objects').get_child_count()==53)
	assert(scene.get_node('Field').mesh!=null)
	var stadium_count=scene.get_node('Stadium').get_child_count()
	root.add_child(scene)
	await process_frame
	assert(scene.stadium.get_child_count()==stadium_count)
	assert(scene.items.size()==scene.game.objects.size())
	for i in range(scene.items.size()):
		assert(scene.items[i].position.distance_to(scene.game.objects[i].p)<0.01)
	scene.start('free')
	for i in range(5):await process_frame
	assert(scene.mode=='free' and not scene.ui_open)
	assert(not scene.audio.in_menu and not scene.audio.match_start_delay.is_stopped())
	scene.audio.unlock()
	scene.start('cpu')
	scene.game.elapsed=scene.game.duration-.01
	scene.game.step(.02)
	await physics_frame
	await process_frame
	assert(scene.hud.get_node('Finish').visible and not scene.result_shown)
	assert(not scene.hud.get_node('Names').visible)
	assert(scene.audio.cue_counts.get('finish',0)==1)
	assert(scene.audio.match_start_delay.is_stopped())
	await create_timer(scene.finish_remaining+.15).timeout
	assert(scene.result_shown and not scene.hud.get_node('Finish').visible)
	assert(scene.audio.cue_counts.get('finish',0)==1)
	scene.start('free')
	assert(not scene.hud.get_node('Finish').visible and scene.finish_remaining==0)
	scene.pause_menu()
	scene.show_title()
	await process_frame
	await process_frame
	assert(scene.mode=='title' and scene.ui_open)
	assert(scene.audio.in_menu and scene.audio.match_start_delay.is_stopped())
	assert(scene.get_node('Robots').get_child_count()==4)
	assert(scene.get_node('Objects').get_child_count()==53)
	print('PASS: editor geometry, stable node counts, object mapping, free play and menu return')
	scene.queue_free()
	await process_frame
	quit()
