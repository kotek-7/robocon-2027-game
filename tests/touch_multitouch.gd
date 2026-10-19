extends SceneTree
var deltas=[]
func _initialize():call_deferred('run')
func press(touch, id: int, p: Vector2, down=true):
 var event=InputEventScreenTouch.new();event.index=id;event.position=p;event.pressed=down
 touch._input(event)
func drag(touch, id: int, p: Vector2):
 var event=InputEventScreenDrag.new();event.index=id;event.position=p
 # Simulate Web relative data contaminated by the other finger.
 event.relative=Vector2(700,-400)
 touch._input(event)
func run():
 root.content_scale_size=Vector2i(844,390)
 var touch=load('res://scenes/ui/touch_controls.tscn').instantiate();root.add_child(touch)
 await process_frame
 touch.look.connect(func(delta):deltas.append(delta))
 press(touch,7,Vector2(80,290));drag(touch,7,Vector2(80,240))
 press(touch,42,Vector2(430,180))
 for i in range(1,11):
  drag(touch,7,Vector2(80+i,240))
  drag(touch,42,Vector2(430+i*2,180+i))
 assert(deltas.size()==10)
 for delta in deltas:assert(delta==Vector2(2,1))
 assert(touch.movement.y<-.5)
 press(touch,42,Vector2(450,190),false)
 assert(touch.move_id==7 and touch.look_id==-1 and touch.movement.y<-.5)
 press(touch,99,Vector2(700,170));drag(touch,99,Vector2(703,168))
 assert(deltas.back()==Vector2(3,-2))
 touch.reset();drag(touch,99,Vector2(710,160))
 assert(deltas.size()==11 and touch.movement==Vector2.ZERO)
 print('PASS: interleaved pointers, independent deltas, release, new touch baseline and reset')
 touch.queue_free();await process_frame;quit()
