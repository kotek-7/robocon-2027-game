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
	for mobile in [false,true]:
		scene.touch_mode=mobile;scene.net.robot_id=-1
		scene.network_message({'type':'ready','started':true})
		assert(scene.mode=='online' and not scene.ui_open and not scene.hud.menu_open)
		# Exercise the no-gesture browser path without requiring pointer lock.
		scene.pause_menu();scene.close_menu(false)
		assert(not scene.ui_open and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
		scene._process(.6)
		assert(not scene.ui_open and not scene.capture_confirmed)
		scene.pause_menu()
		assert(scene.ui_open)
		scene.show_title()
	var listener=TCPServer.new()
	assert(listener.listen(19081,'127.0.0.1')==OK)
	scene.net.endpoint='ws://127.0.0.1:19081/ws'
	for pool in ['1v1','2v2','room']:
		scene.net.connect_pool(pool)
		assert(scene.net.connection_endpoint=='ws://127.0.0.1:19081/ws?pool='+pool)
		assert(scene.net.endpoint=='ws://127.0.0.1:19081/ws')
		var deadline=Time.get_ticks_msec()+2000
		while not listener.is_connection_available() and Time.get_ticks_msec()<deadline:await process_frame
		assert(listener.is_connection_available())
		var stream=listener.take_connection()
		while stream.get_available_bytes()==0 and Time.get_ticks_msec()<deadline:
			stream.poll();await process_frame
		assert(stream.get_available_bytes()>0)
		var request=stream.get_utf8_string(stream.get_available_bytes())
		assert(request.begins_with('GET /ws?pool='+pool+' HTTP/1.1'))
		stream.disconnect_from_host()
		scene.net.leave()
	print('PASS: desktop/mobile room directly / automatic -> format, validation, back navigation and unpaused online start')
	scene.queue_free();await process_frame;quit()
