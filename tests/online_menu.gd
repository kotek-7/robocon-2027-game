extends SceneTree
func _initialize():call_deferred('run')
func run():
	var scene=load('res://main.tscn').instantiate();root.add_child(scene)
	await process_frame
	for mobile in [false,true]:
		scene.touch_mode=mobile
		scene.show_online()
		assert(scene.menu.has_node('Room') and scene.menu.has_node('Automatic'))
		scene.menu.get_node('Room').pressed.emit()
		assert(scene.online_method=='room' and not scene.menu.has_node('Solo'))
		assert(scene.online_format=='2v2' and scene.menu.has_node('Create'))
		scene.menu.get_node('Code').text='bad'
		scene.menu.get_node('Join').pressed.emit()
		assert(scene.menu.has_node('Code') and not scene.menu.get_node('Info').text.is_empty())
		scene.menu.get_node('Back').pressed.emit()
		scene.menu.get_node('Automatic').pressed.emit()
		assert(scene.online_method=='auto' and scene.menu.has_node('Solo'))
		scene.menu.get_node('Back').pressed.emit()
		assert(scene.menu.has_node('Room'))
	print('PASS: desktop/mobile room directly / automatic -> format, validation and back navigation')
	scene.queue_free();await process_frame;quit()
