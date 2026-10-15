class_name ArenaHUD
extends Control

@export_group("Icons")
@export var tr_icon: Texture2D
@export var br_icon: Texture2D
@export var earth_icon: Texture2D
@export var mustika_icon: Texture2D
@export var tower_icon: Texture2D
@export var completed_tower_icon: Texture2D
@export_group("Colors")
@export var red_color = Color('#ed174c')
@export var blue_color = Color('#0078dd')
@export var inactive_color = Color('#433074')
@export var local_name_color = Color('#ffda16')

var match_state: MatchState
var team=0
var can_switch=true
var partner_cpu=false
var action={}
var name_tags=[]
var action_screen=Vector2.ZERO
var title=false
var menu_open=true
var touch_mode=false
var using_pad=false
var disconnected=false

func update_view():
	$Desktop.visible=not title and not touch_mode and match_state!=null
	$Mobile.visible=not title and touch_mode and match_state!=null
	$Names.visible=not title and not menu_open and match_state!=null and not match_state.finished
	if title or not match_state:return
	var layout=$Mobile if touch_mode else $Desktop
	var m=match_state
	layout.get_node('Red/Value').text=str(m.scores[0])
	layout.get_node('Blue/Value').text=str(m.scores[1])
	var seconds=maxi(0,ceili(m.duration-m.elapsed))
	layout.get_node('Clock/Value').text='%d:%02d'%[seconds/60,seconds%60] if m.mode!='free' else 'FREE'
	var rid=int(m.active[team]);var robot=m.robots[rid]
	layout.get_node('Cargo/Robot').texture=tr_icon if rid%2==0 else br_icon
	layout.get_node('Cargo/SwitchKey').visible=can_switch and not touch_mode
	layout.get_node('Cargo/SwitchKey').text='Y' if using_pad else 'Q'
	layout.get_node('Cargo/Partner').visible=partner_cpu
	var selected_slot=posmod(robot.selected,maxi(1,robot.carry.size()))
	if action.get('type') in ['place','mustika']:selected_slot=robot.carry.find(action.object)
	for i in range(3):
		var slot=layout.get_node('Cargo/Slot%d'%i)
		slot.visible=i<m.capacity(rid)
		slot.get_node('Icon').visible=i<robot.carry.size()
		slot.get_node('Selection').visible=i<robot.carry.size() and i==selected_slot
		if i<robot.carry.size():
			var o=m.objects[robot.carry[i]]
			var icon=slot.get_node('Icon')
			icon.texture=mustika_icon if o.kind=='M' else earth_icon
			icon.self_modulate=Color.WHITE if o.kind=='M' else red_color if (o.face if o.kind=='S' else o.owner)==0 else blue_color
	for t in range(2):
		var objective=layout.get_node('RedObjective' if t==0 else 'BlueObjective')
		var progress=m.mandate_progress(t)
		for i in range(2):
			var icon=objective.get_node('Tower%d'%(i+1))
			icon.texture=completed_tower_icon if progress[i] else tower_icon
			icon.self_modulate=(red_color if t==0 else blue_color) if progress[i] else Color(1,1,1,0.4)
		objective.get_node('Mustika').modulate=Color.WHITE if m.mustika_acquired(t) else inactive_color
	var legend='LS  MOVE    A  ACT    %sLT  FIELD' if using_pad else 'WASD  MOVE    E  ACT    %sTAB  FIELD'
	layout.get_node('Legend').text=legend%(('Y  SWITCH    ' if using_pad else 'Q  SWITCH    ') if can_switch else '')
	layout.get_node('Connection').visible=disconnected
	var prompt=layout.get_node('Action')
	prompt.visible=not action.is_empty() and action_screen.x>0
	if prompt.visible:
		prompt.position=action_screen
		prompt.get_node('Key/Label').text='A' if using_pad else 'E'
		prompt.get_node('Climb').visible=action.type=='climb'
		prompt.get_node('Pick').visible=action.type=='pick' and not touch_mode
		prompt.get_node('Seconds').visible=action.type in ['climb','return']
		if action.type=='return':prompt.get_node('Seconds').text='戻す'
		if action.type=='climb':prompt.get_node('Seconds').text='%ds'%int(action.seconds)
	var progress=layout.get_node('JobProgress')
	progress.visible=not robot.job.is_empty()
	if progress.visible:
		var duration=robot.job.seconds if robot.job.type=='climb' else .65 if robot.job.type in ['pick','drop','give','return'] else 1.1
		progress.value=1-robot.left/duration
	update_names()

func update_names():
	var used=[]
	for node in $Names.get_children():node.visible=false
	for i in range(mini(name_tags.size(),$Names.get_child_count())):
		var tag=name_tags[i]
		var node=$Names.get_child(i)
		var label: Label=node.get_node('Label')
		label.text=str(tag.name)
		label.add_theme_font_size_override('font_size',14 if touch_mode else 18)
		label.modulate=local_name_color if tag.self else Color.WHITE
		node.reset_size()
		var rect=Rect2(tag.p-Vector2(node.size.x/2,24),node.size)
		for other in used:
			if rect.intersects(other):rect.position.y=other.position.y-rect.size.y-2
		if rect.position.x<0 or rect.end.x>size.x or rect.position.y<65:continue
		used.append(rect);node.position=rect.position;node.visible=true

var finish_tween: Tween

func show_finish():
	if is_instance_valid(finish_tween):finish_tween.kill()
	$Finish.visible=true
	$Finish.modulate.a=0.0
	finish_tween=create_tween()
	finish_tween.tween_property($Finish,"modulate:a",1.0,0.2)

func hide_finish():
	if is_instance_valid(finish_tween):finish_tween.kill()
	$Finish.visible=false
