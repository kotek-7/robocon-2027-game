class_name ArenaHUD
extends Control
var match_state: MatchState
var team=0
var action={}
var action_screen=Vector2.ZERO
var title=false
var using_pad=false
var disconnected=false
var font: Font

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=load('res://assets/Fredoka-Semibold.ttf')

func text(p: Vector2, s: String, size: int, color=Color('#20243e')):
	draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func tile(rect: Rect2,color: Color,radius=18):
	var style=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(radius);style.shadow_color=Color(0.12,.1,.2,.15);style.shadow_size=8;style.shadow_offset=Vector2(0,3);draw_style_box(style,rect)

func _draw():
	if title or not match_state: return
	var m=match_state;var w=size.x;var h=size.y
	for t in range(2):
		var x=28 if t==0 else w-158
		tile(Rect2(x,24,130,70),ArenaVisuals.RED if t==0 else ArenaVisuals.BLUE)
		text(Vector2(x+22,75),str(m.scores[t]),40,Color.WHITE)
		for j in range(1 if t==0 else 2): draw_circle(Vector2(x+105+j*12,40),4,Color.WHITE)
	var seconds=maxi(0,ceili(m.duration-m.elapsed))
	var clock='%d:%02d'%[seconds/60,seconds%60] if m.mode!='free' else 'FREE'
	tile(Rect2(w/2-70,24,140,62),Color('#fffaf0'))
	text(Vector2(w/2-52,68),clock,32)
	var rid=int(m.active[team]);var r=m.robots[rid]
	tile(Rect2(28,h-96,240,68),Color('#fffaf0'))
	text(Vector2(47,h-49),'TR' if rid%2==0 else 'BR',30)
	text(Vector2(49,h-76),'Y' if using_pad else 'Q',13,Color('#433074'))
	for i in range(m.capacity(rid)):
		var p=Vector2(130+i*43,h-62)
		draw_circle(p,17,Color('#c6cee8'))
		if i<r.carry.size():
			var o=m.objects[r.carry[i]]
			var c=Color('#ffda16') if o.kind=='M' else (ArenaVisuals.RED if (o.face if o.kind=='S' else o.owner)==0 else ArenaVisuals.BLUE)
			if o.kind=='M': draw_circle(p,12,c)
			else: draw_rect(Rect2(p-Vector2(12,12),Vector2(24,24)),c)
			if i==posmod(r.selected,maxi(1,r.carry.size())): draw_arc(p,19,0,TAU,24,Color('#20243e'),2,true)
	# Objective is pictured as two towers, a shared-zone ring and the gold sphere.
	for j in range(2):
		var p=Vector2(w-122+j*42,h-61)
		var c=Color('#fffaf0') if m.mandate[team] else Color('#433074')
		draw_rect(Rect2(p+Vector2(-9,0),Vector2(18,16)),c)
		draw_rect(Rect2(p+Vector2(-9,-19),Vector2(18,16)),c)
		draw_rect(Rect2(p+Vector2(-6,-32),Vector2(12,10)),c)
	draw_circle(Vector2(w-34,h-62),12,Color('#ffda16') if m.mandate[team] else Color('#433074'))
	control_legend(Vector2(w/2-155,h-38))
	if not action.is_empty() and action_screen.x>0:
		var p=action_screen
		tile(Rect2(p-Vector2(29,29),Vector2(58,58)),Color('#fffaf0'),29)
		text(p+Vector2(-10,10),'A' if using_pad else 'E',26)
		if action.type=='climb':
			draw_polyline(PackedVector2Array([p+Vector2(-18,-42),p+Vector2(-6,-42),p+Vector2(-6,-51),p+Vector2(6,-51),p+Vector2(6,-60),p+Vector2(18,-60)]),Color('#20243e'),4,true)
			text(p+Vector2(34,7),'%ds'%int(action.seconds),18,Color('#20243e'))
		if action.type=='pick':
			draw_line(p+Vector2(0,-43),p+Vector2(0,-60),Color('#fffaf0'),4,true)
			draw_polyline(PackedVector2Array([p+Vector2(-6,-54),p+Vector2(0,-60),p+Vector2(6,-54)]),Color('#fffaf0'),3,true)
	if not r.job.is_empty():
		var fraction=1-r.left/(r.job.seconds if r.job.type=='climb' else .65 if r.job.type in ['pick','drop','give'] else 1.1)
		draw_arc(Vector2(w/2,h/2+60),24,-PI/2,-PI/2+TAU*fraction,32,Color('#fffaf0'),5,true)
	if disconnected: text(Vector2(w/2-80,120),'RECONNECTING',18,Color('#20243e'))

func control_legend(origin: Vector2):
	var ink=Color('#25204e')
	var keys=['LS','A','Y','LT'] if using_pad else ['WASD','E','Q','TAB']
	for i in range(4):
		var p=origin+Vector2(i*88,0)
		match i:
			0:
				draw_line(p+Vector2(-9,0),p+Vector2(9,0),ink,2,true)
				draw_line(p+Vector2(0,-9),p+Vector2(0,9),ink,2,true)
				for v in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
					var n=v.orthogonal()
					draw_polyline(PackedVector2Array([p+v*6+n*3,p+v*10,p+v*6-n*3]),ink,2,true)
			1:
				draw_rect(Rect2(p-Vector2(5,5),Vector2(10,10)),ink,false,2)
				draw_polyline(PackedVector2Array([p+Vector2(-7,-9),p+Vector2(-12,-9),p+Vector2(-12,9),p+Vector2(-7,9)]),ink,2,true)
				draw_polyline(PackedVector2Array([p+Vector2(7,-9),p+Vector2(12,-9),p+Vector2(12,9),p+Vector2(7,9)]),ink,2,true)
			2:
				draw_polyline(PackedVector2Array([p+Vector2(-12,-5),p+Vector2(10,-5),p+Vector2(5,-10)]),ink,2,true)
				draw_polyline(PackedVector2Array([p+Vector2(12,5),p+Vector2(-10,5),p+Vector2(-5,10)]),ink,2,true)
			3:
				draw_rect(Rect2(p-Vector2(11,9),Vector2(22,18)),ink,false,2)
				draw_rect(Rect2(p-Vector2(5,4),Vector2(10,8)),ink,false,2)
		text(p+Vector2(18,5),keys[i],13,ink)
