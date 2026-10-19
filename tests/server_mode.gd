extends SceneTree

func _initialize():call_deferred('run')

func run():
	var scene=load('res://main.tscn').instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.net.server_mode)
	assert(Engine.max_fps==60)
	assert(not scene.is_processing() and not scene.is_physics_processing())
	assert(scene.net.can_process())
	for child in scene.get_children():
		if child!=scene.net:assert(not child.can_process())
	var clock=scene.get_node('Stadium').clock
	await create_timer(.1).timeout
	assert(scene.get_node('Stadium').clock==clock)
	print('PASS: server keeps networking active and stops presentation processing')
	scene.queue_free()
	await process_frame
	quit()
