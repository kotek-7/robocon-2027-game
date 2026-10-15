extends Control

var bursts: Array=[]
var phase=0.0

func reset():
	bursts.clear()
	phase=0.0
	queue_redraw()

func celebrate(kind: String, team: int):
	bursts.append({'kind':kind,'team':team,'age':0.0})
	if bursts.size()>8:bursts.pop_front()

func _process(dt: float):
	var hud=get_parent()
	if hud.title or hud.menu_open or not hud.match_state:
		reset()
		return
	phase+=dt
	for i in range(bursts.size()-1,-1,-1):
		bursts[i].age+=dt
		if bursts[i].age>=1.2:bursts.remove_at(i)
	queue_redraw()

func _draw():
	var hud=get_parent()
	if hud.title or hud.menu_open or not hud.match_state:return
	var layout=hud.get_node('Mobile' if hud.touch_mode else 'Desktop')
	for team in range(2):
		var objective=layout.get_node('RedObjective' if team==0 else 'BlueObjective')
		var center=objective.get_node('Mustika').get_global_rect().get_center()-global_position
		var tint: Color=hud.red_color if team==0 else hud.blue_color
		if hud.match_state.mustika_acquired(team):tint=Color('#ffda16')
		if hud.match_state.mandate[team] and not hud.match_state.mustika_offered(team):
			# A slow breathing ring marks the unlocked, still unoffered Mustika.
			var breath=(sin(phase*TAU/1.8)+1)*0.5
			draw_arc(center,15+breath*3,0,TAU,48,Color(tint,0.3+breath*0.45),2,true)
			draw_arc(center,21,phase,phase+PI*0.65,24,Color(tint,0.65),2,true)
	for burst in bursts:
		var objective=layout.get_node('RedObjective' if burst.team==0 else 'BlueObjective')
		var mustika_effect=burst.kind in ['mustika','mustika_pick']
		var target=objective.get_node('Mustika') if mustika_effect else objective
		var center=target.get_global_rect().get_center()-global_position
		var tint=Color('#ffda16') if mustika_effect else (hud.red_color if burst.team==0 else hud.blue_color)
		var p=float(burst.age)/1.2
		var radius=lerpf(12,22,p) if hud.touch_mode else lerpf(18,40,p)
		if burst.kind=='mustika_pick':radius=lerpf(26 if hud.touch_mode else 40,12,p)
		var fade=1-p
		draw_arc(center,radius,0,TAU,64,Color(tint,fade),3*fade+1,true)
		for i in range(12):
			var angle=TAU*i/12.0
			var direction=Vector2.from_angle(angle)
			var point=center+direction*radius
			draw_line(point,point+direction*(3+6*fade),Color(tint,fade),2,true)
