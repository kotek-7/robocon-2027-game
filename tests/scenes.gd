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
	scene.pause_menu()
	scene.show_title()
	await process_frame
	assert(scene.mode=='title' and scene.ui_open)
	assert(scene.get_node('Robots').get_child_count()==4)
	assert(scene.get_node('Objects').get_child_count()==53)
	print('PASS: editor geometry, stable node counts, object mapping, free play and menu return')
	scene.queue_free()
	await process_frame
	quit()
