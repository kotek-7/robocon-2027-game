extends SceneTree
func _initialize():call_deferred('run')
func run():
 var hud=load('res://scenes/ui/hud.tscn').instantiate();root.add_child(hud)
 var field=ArenaField.new();var match_state=MatchState.new(field);match_state.reset('cpu')
 hud.match_state=match_state;hud.menu_open=false
 match_state.scores=[12,34]
 hud.participant_names=['あいうえおかきくけこさしすせそた','Red Two','Blue One','CPU']
 hud.name_tags=[{'name':'World Name','self':true,'p':Vector2(280,180)}]
 for dims in [Vector2i(1280,720),Vector2i(844,390),Vector2i(568,320)]:
  for own_team in [0,1,0]:
   hud.team=own_team
   root.content_scale_size=dims;hud.touch_mode=dims.y<500
   await process_frame;hud.update_view();await process_frame;hud.update_view();await process_frame
   var layout=hud.get_node('Mobile' if hud.touch_mode else 'Desktop')
   assert(hud.get_node('Names').visible and hud.get_node('Names/Name0/Label').text=='World Name')
   assert(hud.get_node('ScoreNames').visible)
   var own=layout.get_node('Red' if own_team==0 else 'Blue')
   var opponent=layout.get_node('Blue' if own_team==0 else 'Red')
   assert(own.position.x<opponent.position.x)
   assert(own.get_node('Value').text==str(match_state.scores[own_team]))
   assert(own.theme_type_variation==('RedScore' if own_team==0 else 'BlueScore'))
   var objective=layout.get_node('RedObjective' if own_team==0 else 'BlueObjective')
   assert(objective.get_rect().end.x<layout.get_node('Clock').get_rect().get_center().x)
   assert(objective.get_child(0).name=='Tower1')
   for i in range(4):
    var plate=hud.get_node('ScoreNames/Name%d'%i)
    assert(plate.get_node('Label').text==hud.participant_names[i])
    var rect=plate.get_rect()
    assert((rect.get_center().x<dims.x/2)==(int(i/2)==own_team))
    assert(rect.position.x>=0 and rect.end.x<=dims.x)
    assert(not rect.intersects(layout.get_node('Clock').get_rect()))
    assert(not rect.intersects(layout.get_node('Red').get_rect()))
    assert(not rect.intersects(layout.get_node('Blue').get_rect()))
    assert(not rect.intersects(layout.get_node('RedObjective').get_rect()))
    assert(not rect.intersects(layout.get_node('BlueObjective').get_rect()))
    assert(plate.get_theme_stylebox('panel').bg_color==Color(0,0,0,.38))
    for j in range(i):assert(not rect.intersects(hud.get_node('ScoreNames/Name%d'%j).get_rect()))
 hud.menu_open=true;hud.update_view();assert(not hud.get_node('ScoreNames').visible)
 print('PASS: four score nameplates, long names, responsive bounds, black alpha and existing world labels')
 hud.queue_free();await process_frame;quit()
