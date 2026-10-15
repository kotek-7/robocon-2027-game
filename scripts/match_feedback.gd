extends Control

@export var bubble_scene: PackedScene
@export var score_scene: PackedScene
@export_range(0.5, 5.0) var bubble_seconds=2.2
@export_range(0.5, 2.0) var bubble_scale=1.3
@export_range(0.5, 5.0) var score_seconds=1.4
const CALLOUTS={'retry':'リトライ！','mandate':'マンデート！','mustika':'奉納！'}
var last_event=0
var effects: Array=[]

func prime(m: MatchState):
	last_event=m.event_seq
	get_parent().get_node('ObjectiveEffects').reset()
	for effect in effects:effect.node.queue_free()
	effects.clear()

func observe(m: MatchState, camera: Camera3D, hud: Control, silent: bool, dt: float):
	if silent:
		prime(m)
		return
	for event in m.events:
		if int(event.id)<=last_event:continue
		last_event=int(event.id)
		var kind=str(event.type)
		if kind in ['mandate','mustika'] and int(event.rid)>=0:
			hud.get_node('ObjectiveEffects').celebrate(kind,int(event.rid)/2)
		if CALLOUTS.has(kind) and int(event.rid)>=0:
			add_effect(bubble_scene,CALLOUTS[kind],int(event.rid),-1)
		elif kind=='score' and int(event.get('delta',0))>0:
			add_effect(score_scene,'+%d'%int(event.delta),-1,int(event.team))
	var occupied=[]
	for i in range(effects.size()-1,-1,-1):
		var effect=effects[i];effect.age+=dt
		var node: Control=effect.node
		var lifetime=bubble_seconds if effect.rid>=0 else score_seconds
		if effect.age>=lifetime:
			node.queue_free();effects.remove_at(i);continue
		var progress=float(effect.age)/lifetime
		node.modulate.a=minf(1.0,(1-progress)*4)
		var pop=lerpf(.8,1.0,minf(1.0,effect.age/.14))
		node.scale=Vector2.ONE*pop
		node.pivot_offset=node.size/2
		if effect.rid>=0:
			node.get_node('Label').add_theme_font_size_override('font_size',12 if hud.touch_mode else 13)
			node.reset_size()
			node.scale=Vector2.ONE*bubble_scale*pop
			node.pivot_offset=Vector2.ZERO
			var bubble_size=node.size*bubble_scale
			var point: Vector3=m.robots[effect.rid].p+Vector3(0,1.5,0)
			node.visible=not camera.is_position_behind(point)
			if not node.visible:continue
			var screen=camera.unproject_position(point)
			node.position=screen-Vector2(bubble_size.x/2,bubble_size.y+6*bubble_scale)
			node.position.x=clampf(node.position.x,8,maxf(8,size.x-bubble_size.x-8))
			var top=110.0 if not hud.touch_mode else 75.0
			node.position.y=maxf(top,node.position.y)
			for rect in occupied:
				if Rect2(node.position,bubble_size).intersects(rect):
					var above=rect.position.y-bubble_size.y-14
					node.position.y=above if above>=top else rect.end.y+14
			occupied.append(Rect2(node.position,bubble_size))
		else:
			node.get_node('Label').add_theme_font_size_override('font_size',26 if hud.touch_mode else 32)
			var layout=hud.get_node('Mobile' if hud.touch_mode else 'Desktop')
			var card=layout.get_node('Red' if effect.team==0 else 'Blue')
			var rect: Rect2=card.get_global_rect()
			var stack=0
			for j in range(i+1,effects.size()):
				if effects[j].team==effect.team:stack+=1
			node.position=Vector2(rect.get_center().x-global_position.x-node.size.x/2,rect.end.y-global_position.y+(52 if hud.touch_mode else 12)+stack*34-progress*24)

func add_effect(scene: PackedScene, message: String, rid: int, side: int):
	# Bound transient UI even when several snapshots arrive together.
	if effects.size()>=12:
		effects[0].node.queue_free();effects.pop_front()
	var node=scene.instantiate()
	add_child(node)
	node.get_node('Label').text=message
	if side>=0:
		var tint=Color('#ed174c') if side==0 else Color('#0078dd')
		node.get_node('Label').add_theme_color_override('font_color',tint)
		node.get_node('Particles').color=tint
		node.get_node('Particles').restart()
	effects.append({'node':node,'rid':rid,'team':side,'age':0.0})
