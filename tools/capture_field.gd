extends SceneTree
func _initialize():
	call_deferred('capture')
func capture():
	root.size=Vector2i(1280,720)
	var scene=load('res://main.tscn').instantiate();root.add_child(scene)
	await create_timer(1.0).timeout
	scene.ui.visible=false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg('res://web/field-backdrop.jpg',.85)
	quit()
