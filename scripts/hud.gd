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
var action={}
var name_tags=[]
var participant_names=["CPU","CPU","CPU","CPU"]
var action_screen=Vector2.ZERO
var title=false
var menu_open=true
var touch_mode=false
var using_pad=false
var disconnected=false

func update_view():
	$Desktop.visible=not title and not touch_mode and match_state!=null
	$Mobile.visible=not title and touch_mode and match_state!=null
	$ScoreNames.visible=not title and not menu_open and match_state!=null and not match_state.finished
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
		if action.type=='return':prompt.get_node('Seconds').text='RETURN'
		if action.type=='climb':prompt.get_node('Seconds').text='%ds'%int(action.seconds)
	var progress=layout.get_node('JobProgress')
	progress.visible=not robot.job.is_empty()
	if progress.visible:
		var duration=robot.job.seconds if robot.job.type=='climb' else .65 if robot.job.type in ['pick','drop','give','return'] else 1.1
		progress.value=1-robot.left/duration
	update_names()
	update_score_names(layout)

func update_names():
	var used: Array[Rect2]=[]
	for node in $Names.get_children():node.visible=false
	for i in range(mini(name_tags.size(),$Names.get_child_count())):
		var tag=name_tags[i]
		var node=$Names.get_child(i)
		var label: Label=node.get_node('Label')
		var font_size=14 if touch_mode else 18
		label.text=str(tag.name)
		label.add_theme_font_size_override('font_size',font_size)
		label.modulate=local_name_color if tag.self else Color.WHITE
		label.clip_text=true
		label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		var padding=node.get_theme_stylebox('panel').get_minimum_size()
		var text_size=label.get_theme_font('font').get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		node.size=Vector2(minf(text_size.x+padding.x, minf(240,size.x-16)),label.get_theme_font('font').get_height(font_size)+padding.y)
		var rect=Rect2(tag.p-Vector2(node.size.x/2,24),node.size)
		rect.position=rect.position.clamp(Vector2(8,104),size-rect.size-Vector2(8,8))
		# Try the nearest free vertical slot; never discard an overlapping name.
		var candidates: Array[float]=[rect.position.y,104.0,size.y-rect.size.y-8]
		for other in used:
			candidates.append(other.position.y-rect.size.y-3)
			candidates.append(other.end.y+3)
		var best=rect.position
		var distance=INF
		for y in candidates:
			var candidate=Rect2(Vector2(rect.position.x,y),rect.size)
			if y<104 or candidate.end.y>size.y-8:continue
			var overlaps=false
			for other in used:
				if candidate.intersects(other):overlaps=true;break
			if not overlaps and absf(y-rect.position.y)<distance:
				best=candidate.position;distance=absf(y-rect.position.y)
		rect.position=best
		used.append(rect);node.position=rect.position;node.visible=true

func update_score_names(layout: Control):
	var clock=layout.get_node('Clock').get_rect()
	for t in range(2):
		var score=layout.get_node('Red' if t==0 else 'Blue').get_rect()
		var gap=5.0
		var available=clock.position.x-score.end.x-gap*2 if t==0 else score.position.x-clock.end.x-gap*2
		var width=minf(112 if touch_mode else 144,available)
		var height=18.0 if touch_mode else 23.0
		for slot in range(2):
			var rid=t*2+slot
			var plate=$ScoreNames.get_node('Name%d'%rid)
			var label=plate.get_node('Label')
			label.text=str(participant_names[rid])
			label.add_theme_font_size_override('font_size',11 if touch_mode else 13)
			plate.tooltip_text=label.text
			plate.size=Vector2(width,height)
			plate.position=Vector2(score.end.x+gap if t==0 else score.position.x-gap-width,score.position.y+(score.size.y-height*2-2)/2+slot*(height+2))

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
