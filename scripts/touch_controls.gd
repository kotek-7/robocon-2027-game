class_name ArenaTouchControls
extends Control
signal action(name: String)
signal look(delta: Vector2)
var movement=Vector2.ZERO
var overview=false
var landscape_required=false
var fullscreen_supported=true
var move_id=-1
var look_id=-1
var anchor=Vector2.ZERO
var knob=Vector2.ZERO
var buttons={}
var held={}
var font: Font

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=load('res://assets/Fredoka-Semibold.ttf')
	resized.connect(reset)

func reset():
	movement=Vector2.ZERO;move_id=-1;look_id=-1;held.clear();overview=false;queue_redraw()

func layout():
	var w=size.x;var h=size.y
	buttons={'act':Rect2(w-92,h-104,72,72),'switch':Rect2(w-82,h-178,60,52),
		'previous':Rect2(w-208,h-82,48,48),'next':Rect2(w-150,h-82,48,48),
		'menu':Rect2(w-62,76,44,44),'overview':Rect2(w-118,76,44,44),'fullscreen':Rect2(w-174,76,44,44)}

func _input(event):
	if not visible:return
	if landscape_required:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:get_viewport().set_input_as_handled()
		return
	layout()
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if event.index==move_id:move_id=-1;movement=Vector2.ZERO
			if event.index==look_id:look_id=-1
			held.erase(event.index)
		else:
			for key in buttons:
				if buttons[key].has_point(event.position):
					if key=='fullscreen' and not fullscreen_supported:get_viewport().set_input_as_handled();return
					held[event.index]=key
					if key=='overview':overview=not overview
					else:action.emit(key)
					get_viewport().set_input_as_handled();queue_redraw();return
			if event.position.x<size.x*.45 and event.position.y>size.y*.45 and move_id<0:
				move_id=event.index;anchor=event.position;knob=anchor
			elif look_id<0:look_id=event.index
		get_viewport().set_input_as_handled();queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index==move_id:
			var delta=(event.position-anchor).limit_length(54)
			knob=anchor+delta;movement=delta/54
			if movement.length()<.12:movement=Vector2.ZERO
		elif event.index==look_id:look.emit(event.relative)
		get_viewport().set_input_as_handled();queue_redraw()

func _draw():
	if landscape_required:
		draw_rect(Rect2(Vector2.ZERO,size),Color('#20243e'))
		var center=size/2
		var phone=StyleBoxFlat.new();phone.bg_color=Color('#12bfe7');phone.border_color=Color('#fffaf0');phone.set_border_width_all(5);phone.set_corner_radius_all(12)
		draw_style_box(phone,Rect2(center-Vector2(65,34),Vector2(130,68)))
		draw_circle(center+Vector2(53,0),3,Color('#20243e'))
		draw_arc(center,91,-PI*.85,PI*.15,36,Color('#ffda16'),5,true)
		var tip=center+Vector2(cos(PI*.15),sin(PI*.15))*91
		draw_polyline(PackedVector2Array([tip+Vector2(-17,-4),tip,tip+Vector2(5,-17)]),Color('#ffda16'),5,true)
		return
	layout()
	var center=anchor if move_id>=0 else Vector2(84,size.y-92)
	draw_circle(center,58,Color(.1,.1,.2,.22));draw_arc(center,58,0,TAU,40,Color(1,1,1,.7),2,true)
	draw_circle(knob if move_id>=0 else center,24,Color(1,1,1,.75))
	for key in buttons:
		var rect: Rect2=buttons[key];var style=StyleBoxFlat.new()
		style.bg_color=Color('#ffda16') if key in held.values() or (key=='overview' and overview) else Color(1,.98,.94,.9)
		if key=='fullscreen' and not fullscreen_supported:style.bg_color=Color(.6,.6,.65,.7)
		style.set_corner_radius_all(20 if key=='act' else 14)
		style.border_color=Color('#20243e');style.set_border_width_all(2);draw_style_box(style,rect)
		var label={'act':'ACT','switch':'TR/BR','previous':'<','next':'>','menu':'II','overview':'','fullscreen':''}[key]
		var fs=18 if key in ['act','switch'] else 24
		var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		draw_string(font,rect.get_center()+Vector2(-width/2,fs*.35),label,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color('#20243e'))
		if key=='fullscreen':
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
				var point=rect.get_center()+corner*11
				draw_polyline(PackedVector2Array([point-Vector2(corner.x*7,0),point,point-Vector2(0,corner.y*7)]),Color('#20243e'),2,true)
		if key=='overview':
			draw_rect(Rect2(rect.get_center()-Vector2(12,10),Vector2(24,20)),Color('#20243e'),false,2)
			draw_rect(Rect2(rect.get_center()-Vector2(5,4),Vector2(10,8)),Color('#20243e'),false,2)

func qa_buttons() -> Array:
	layout()
	var out=[]
	for key in buttons:
		var center: Vector2=buttons[key].get_center()
		out.append({'name':key,'x':center.x,'y':center.y})
	return out
