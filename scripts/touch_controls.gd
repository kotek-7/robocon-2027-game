class_name ArenaTouchControls
extends Control
signal action(name: String)
signal look(delta: Vector2)
var movement=Vector2.ZERO
var overview=false
var can_switch=true
var landscape_required=false
var fullscreen_supported=true
var move_id=-1
var look_id=-1
var anchor=Vector2.ZERO
var knob=Vector2.ZERO
var buttons={}
var held={}
@export_range(1.0, 150.0) var joystick_radius = 54.0
@export_range(0.0, 0.9) var deadzone = 0.12
@export_range(0.0, 1.0) var move_area_width = 0.45
@export_range(0.0, 1.0) var move_area_top = 0.45

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(reset)

func reset():
	movement=Vector2.ZERO;move_id=-1;look_id=-1;held.clear();overview=false;update_view()

func layout():
	buttons.clear()
	for node in $Buttons.get_children():
		if node.name=='switch' and not can_switch:continue
		buttons[String(node.name)]=node.get_global_rect()

func update_view():
	$Portrait.visible=landscape_required
	$Buttons.visible=not landscape_required
	$Joystick.visible=not landscape_required
	$Buttons/switch.visible=can_switch
	$Buttons/fullscreen.disabled=not fullscreen_supported
	for node in $Buttons.get_children():
		node.set_pressed_no_signal(String(node.name) in held.values() or (node.name=='overview' and overview))
	var center=anchor if move_id>=0 else $JoystickHome.global_position
	$Joystick.global_position=center-$Joystick.size/2
	$Joystick/Knob.global_position=(knob if move_id>=0 else center)-$Joystick/Knob.size/2

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
					get_viewport().set_input_as_handled();update_view();return
			if event.position.x<size.x*move_area_width and event.position.y>size.y*move_area_top and move_id<0:
				move_id=event.index;anchor=event.position;knob=anchor
			elif look_id<0:look_id=event.index
		get_viewport().set_input_as_handled();update_view()
	elif event is InputEventScreenDrag:
		if event.index==move_id:
			var delta=(event.position-anchor).limit_length(joystick_radius)
			knob=anchor+delta;movement=delta/joystick_radius
			if movement.length()<deadzone:movement=Vector2.ZERO
		elif event.index==look_id:look.emit(event.relative)
		get_viewport().set_input_as_handled();update_view()

func qa_buttons() -> Array:
	layout()
	var out=[]
	for key in buttons:
		var center: Vector2=buttons[key].get_center()
		out.append({'name':key,'x':center.x,'y':center.y})
	return out
