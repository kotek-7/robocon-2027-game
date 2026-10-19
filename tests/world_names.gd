extends SceneTree
func _initialize():call_deferred('run')
func run():
 var hud=load('res://scenes/ui/hud.tscn').instantiate();root.add_child(hud)
 var camera=Camera3D.new();camera.set_script(load('res://scripts/arena_camera.gd'));root.add_child(camera)
 hud.match_state=MatchState.new(ArenaField.new());hud.match_state.reset('cpu');hud.menu_open=false
 for dims in [Vector2i(1280,720),Vector2i(844,390),Vector2i(568,320)]:
  root.content_scale_size=dims;hud.touch_mode=dims.y<500
  await process_frame
  for point in [Vector3(0,0,-5),Vector3(500,500,-5),Vector3(-500,-500,-5),Vector3(0,0,5),Vector3(0,0,0),Vector3(0,0,-10000)]:
   var anchor=camera.nameplate_position(point)
   assert(anchor.is_finite())
   hud.name_tags=[]
   for i in range(4):hud.name_tags.append({'name':'あいうえおかきくけこさしすせそた','self':i==0,'p':anchor})
   hud.update_view();await process_frame;hud.update_view();await process_frame
   for i in range(4):
    var node=hud.get_node('Names/Name%d'%i)
    assert(node.is_visible_in_tree())
    var rect=node.get_rect()
    assert(rect.position.x>=0 and rect.position.y>=104 and rect.end.x<=dims.x and rect.end.y<=dims.y)
    for j in range(i):assert(not rect.intersects(hud.get_node('Names/Name%d'%j).get_rect()))
 hud.menu_open=true;hud.update_view();assert(not hud.get_node('Names').visible)
 hud.menu_open=false;hud.update_view();assert(hud.get_node('Names').visible)
 print('PASS: all four world labels survive distance, offscreen, behind camera, overlaps and pause at three viewport sizes')
 hud.queue_free();camera.queue_free();await process_frame;quit()
