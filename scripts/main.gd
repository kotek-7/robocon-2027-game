extends Node3D
var field: ArenaField
var game: MatchState
var cpu=ArenaCPU.new()
var art=ArenaVisuals.new()
var net: ArenaNetwork
var camera: Camera3D
var robots: Array=[]
var items: Array=[]
var hud: ArenaHUD
var ui: Control
var menu: VBoxContainer
var overlay: Control
var info: Label
var team=0
var mode='title'
var yaw=0.0
var pitch=.55
var overview=false
var capture_grace=0.0
var pending={}
var ui_open=true
var net_clock=0.0
var tones={}
var sound: AudioStreamPlayer
var last_states=[]
var action_ring: MeshInstance3D
var font: Font
var previous_buttons={}
var title_clock=0.0
var qa_clock=0.0
var qa_enabled=false
var camera_target=Vector3.ZERO
var result_shown=false
var stadium: ArenaStadium
var shadows: Array=[]
var last_jobs=[false,false,false,false]

func _ready():
	field=ArenaField.new();game=MatchState.new(field);game.reset('cpu')
	net=ArenaNetwork.new();add_child(net)
	if '--server' in OS.get_cmdline_user_args(): net.host(field);set_process(false);set_physics_process(false);return
	font=load('res://assets/Fredoka-Semibold.ttf')
	if OS.has_feature('web'):qa_enabled=bool(JavaScriptBridge.eval("location.search.includes('qa=1')"))
	if OS.has_feature('web'):
		net.endpoint=str(JavaScriptBridge.eval("location.hostname==='localhost'||location.hostname==='127.0.0.1'?'ws://127.0.0.1:9080':`wss://${location.host}/ws`"))
	field.build(self)
	stadium=ArenaStadium.new();add_child(stadium)
	art.box(self,Vector3(11.35,.35,11.35),Color('#6028c7'),Vector3(0,-.22,0))
	var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color('#12bfe7');e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=.38;env.environment=e;add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-38,-38,0);light.light_energy=.85;light.shadow_opacity=.65;light.shadow_enabled=true;light.directional_shadow_max_distance=28;add_child(light)
	camera=Camera3D.new();camera.fov=62;camera.near=.08;camera.far=80;add_child(camera)
	for i in range(4):
		var r=art.robot(i);add_child(r);robots.append(r)
		var disc=CylinderMesh.new();disc.top_radius=.3;disc.bottom_radius=.3;disc.height=.002;disc.radial_segments=24
		var shadow=art.mesh(self,disc,Color(0.1,.07,.2,.22),Vector3.ZERO)
		var shadow_material=shadow.material_override.duplicate();shadow_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shadow_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow.material_override=shadow_material;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;shadows.append(shadow)
	for o in game.objects:
		var n=art.object(o.kind,o.owner);add_child(n);items.append(n);last_states.append('')
	var torus=TorusMesh.new();torus.inner_radius=.24;torus.outer_radius=.27;torus.rings=28;torus.ring_segments=8
	action_ring=art.mesh(self,torus,Color.WHITE,Vector3.ZERO)
	var ring_edge=TorusMesh.new();ring_edge.inner_radius=.269;ring_edge.outer_radius=.287;ring_edge.rings=28;ring_edge.ring_segments=8
	art.mesh(action_ring,ring_edge,Color('#20243e'),Vector3.ZERO)
	var canvas=CanvasLayer.new();add_child(canvas)
	ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(ui);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud=ArenaHUD.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(hud);hud.match_state=game
	sound=AudioStreamPlayer.new();sound.max_polyphony=4;add_child(sound)
	net.message.connect(network_message)
	show_title()

func panel():
	if is_instance_valid(overlay): overlay.queue_free()
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(overlay)
	var shade=ColorRect.new();shade.color=Color(.14,.1,.24,.18);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(shade)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(center)
	menu=VBoxContainer.new();menu.add_theme_constant_override('separation',14);menu.custom_minimum_size=Vector2(320,0);center.add_child(menu)
	ui_open=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func label(s: String, size=28) -> Label:
	var l=Label.new();l.text=s;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_font_override('font',font);l.add_theme_font_size_override('font_size',size);l.add_theme_color_override('font_color',Color('#20243e'));menu.add_child(l);return l

func button(s: String, call: Callable, color=Color('#fffaf0')) -> Button:
	var b=Button.new();b.text=s;b.custom_minimum_size=Vector2(320,58);b.add_theme_font_override('font',font);b.add_theme_font_size_override('font_size',26);b.add_theme_color_override('font_color',Color('#20243e'));b.add_theme_color_override('font_hover_color',Color('#20243e'));b.add_theme_color_override('font_focus_color',Color('#20243e'));b.add_theme_color_override('font_pressed_color',Color('#20243e'))
	for state in ['normal','hover','pressed','focus']:
		var style=StyleBoxFlat.new();style.bg_color=color.lightened(.12) if state=='hover' else color;style.set_corner_radius_all(18);style.content_margin_left=24;style.content_margin_right=24
		if state=='focus': style.bg_color=Color.TRANSPARENT;style.border_color=Color('#20243e');style.set_border_width_all(3)
		if state=='normal':style.shadow_color=Color(.17,.1,.3,.16);style.shadow_size=8;style.shadow_offset=Vector2(0,4)
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(call);menu.add_child(b);return b

func show_title():
	mode='title';net.leave();game.reset('cpu');panel();hud.title=true;result_shown=false
	label('ROBOCON',62);label('2027',32)
	button('VS CPU',func(): start('cpu'),Color('#ffda16')).grab_focus()
	button('ONLINE',show_online)
	button('FREE',func(): start('free'))
	var note=button('',show_notes);menu.remove_child(note)
	var holder=CenterContainer.new();menu.add_child(holder);holder.add_child(note)
	note.custom_minimum_size=Vector2(48,40);note.icon=load('res://assets/info.svg');note.add_theme_constant_override('icon_max_width',22)

func show_notes():
	panel();label('TR + BR',30);label('Both robots are manually controlled.',16)
	label('ABU 2027 / v1.1',16)
	button('BACK',show_title)

func show_online():
	mode='title';hud.title=true;net.leave();panel();label('ONLINE',42);info=label('CONNECTING',22)
	button('CANCEL',show_title).grab_focus();net.connect_to(net.endpoint)

func network_message(d: Dictionary):
	match d.type:
		'connected':net.find_match()
		'queued':
			if is_instance_valid(info):info.text='FINDING PLAYER'
		'joined':
			team=int(d.team)
			if mode!='online':
				panel();label('MATCH FOUND',40);info=label('',18);net.send({'type':'ready'})
			hud.disconnected=false
		'ready':
			if d.started: start('online')
		'state':
			if mode!='online': start('online')
			# Authoritative correction; presentation interpolates the resulting poses.
			game.restore(d.state)
		'lost': hud.disconnected=true
		'error':
			net.leave();panel();label(str(d.text),24);button('RETRY',show_online);button('BACK',show_title)

func start(which: String):
	mode=which;game.reset(which);cpu=ArenaCPU.new();pending.clear();result_shown=false
	if which!='online':team=0
	hud.title=false;hud.team=team;hud.disconnected=false
	yaw=0;pitch=.58
	camera_target=game.robots[game.active[team]].p+Vector3(0,.4,0)
	# Network start arrives outside a browser gesture; capture only on RESUME.
	if which=='online':pause_menu()
	else:close_menu()
	tone(500,.08)

func close_menu():
	if OS.has_feature('web') and not bool(JavaScriptBridge.eval('document.hasFocus()')):
		pause_menu();return
	if is_instance_valid(overlay):overlay.queue_free()
	ui_open=false;pending.clear();capture_grace=.5;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func pause_menu():
	if mode=='title':return
	panel();label('PAUSED' if mode!='online' else 'MENU',40)
	button('RESUME',close_menu).grab_focus()
	button('RETRY',func(): pending.retry=true;close_menu();pending.retry=true)
	if mode!='online':button('RESET',func():start(mode))
	button('EXIT',show_title)

func results():
	result_shown=true;panel()
	label('DRAW' if game.winner<0 else ('YOU WIN' if game.winner==team else 'CPU WINS' if mode=='cpu' else 'YOU LOSE'),48)
	label('%d : %d'%[game.scores[0],game.scores[1]],38)
	if mode!='online':button('AGAIN',func():start(mode),Color('#ffda16')).grab_focus()
	else:button('AGAIN',func():net.send({'type':'rematch'}),Color('#ffda16')).grab_focus()
	button('BACK',show_title)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		hud.using_pad=false
		if event.keycode==KEY_ESCAPE:
			if mode!='title' and not game.finished:
				if ui_open:close_menu()
				else:pause_menu()
		if ui_open:return
		if event.keycode==KEY_E: pending.act=true
		if event.keycode==KEY_Q: pending.switch=true
	if event is InputEventMouseMotion and not ui_open:
		hud.using_pad=false
		yaw-=event.relative.x*.003;pitch=clampf(pitch+event.relative.y*.002,.22,1.15)
	if event is InputEventMouseButton and event.pressed and not ui_open:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:pending.select=1
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:pending.select=-1

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud):
		pending.clear()
		if mode!='title' and not ui_open and not game.finished:pause_menu()

func gamepad_pressed(button_id: int) -> bool:
	var down=Input.is_joy_button_pressed(0,button_id)
	var edge=down and not previous_buttons.get(button_id,false)
	if edge:hud.using_pad=true
	previous_buttons[button_id]=down
	return edge

func _physics_process(dt):
	if not is_instance_valid(hud) or mode=='title':return
	if game.finished:
		if not result_shown:results()
		return
	if gamepad_pressed(JOY_BUTTON_START):
		if ui_open:close_menu()
		else:pause_menu()
	var cmd={}
	if not ui_open:
		var axes=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var stick=Vector2(Input.get_joy_axis(0,JOY_AXIS_LEFT_X),Input.get_joy_axis(0,JOY_AXIS_LEFT_Y))
		if stick.length()>.18:axes=stick;hud.using_pad=true
		var look=Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
		if look.length()>.18:yaw-=look.x*dt*2.5;pitch=clampf(pitch+look.y*dt*1.5,.22,1.15)
		var dir=Vector3(axes.x,0,axes.y).rotated(Vector3.UP,yaw).limit_length(1)
		cmd=pending.duplicate();cmd.x=dir.x;cmd.z=dir.z;pending.clear()
		if gamepad_pressed(JOY_BUTTON_A):cmd.act=true
		if gamepad_pressed(JOY_BUTTON_Y):cmd.switch=true
		if gamepad_pressed(JOY_BUTTON_LEFT_SHOULDER):cmd.select=-1
		if gamepad_pressed(JOY_BUTTON_RIGHT_SHOULDER):cmd.select=1
		overview=Input.is_physical_key_pressed(KEY_TAB) or Input.get_joy_axis(0,JOY_AXIS_TRIGGER_LEFT)>.5
	if mode=='online':
		net.input(cmd)
		if not ui_open and net.connected:
			# Predict locomotion only. Object operations always await authority.
			game.command(team,{'x':cmd.get('x',0),'z':cmd.get('z',0)},dt)
	elif not ui_open:
		game.command(team,cmd,dt)
		if mode=='cpu':game.command(1,cpu.command(game,1,dt),dt)
		game.step(dt)

func _process(dt):
	if not camera:return
	title_clock+=dt
	capture_grace=maxf(0,capture_grace-dt)
	if mode!='title' and not ui_open and not game.finished and capture_grace<=0 and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		pause_menu()
	for i in range(robots.size()):
		var r=game.robots[i];var node: Node3D=robots[i]
		node.visible=not (mode=='free' and i>=2)
		node.position=node.position.lerp(r.p,1-exp(-22*dt));node.rotation.y=lerp_angle(node.rotation.y,r.yaw,1-exp(-15*dt))
		var body=node.get_child(0)
		body.rotation.x=lerpf(body.rotation.x,-r.v.length()*.035,1-exp(-12*dt))
		body.position.y=sin(title_clock*12)*.012*r.v.length()
		var climbing=r.job.get('type','')=='climb'
		if climbing:
			body.rotation.x=-.13 if r.job.to.y>r.job.from.y else .10
			body.position.y=abs(sin(title_clock*10))*.035
		if last_jobs[i] and not climbing and mode!='title':
			stadium.burst(r.p+Vector3(0,.12,0),Color('#fffaf0'),8);tone(300,.1)
		last_jobs[i]=climbing
		shadows[i].position=Vector3(node.position.x,field.height(node.position)+.012,node.position.z);shadows[i].visible=node.visible
		if mode=='title':body.position.y=sin(title_clock*2+i)*.035
	for i in range(items.size()):
		var o=game.objects[i];var node: Node3D=items[i]
		var pos: Vector3=o.p
		if o.where=='held':
			var rid=int(o.holder);var index=game.robots[rid].carry.find(i)
			pos=robots[rid].position+Vector3((index%2)*.2-.1,.75+int(index/2)*.28,.18).rotated(Vector3.UP,robots[rid].rotation.y)
		node.position=node.position.lerp(pos,1-exp(-20*dt))
		if o.kind=='S':node.rotation.z=lerp_angle(node.rotation.z,PI if o.face==1 else 0.0,1-exp(-12*dt))
		if last_states[i]!=o.where:
			if mode!='title' and last_states[i]!='':
				tone(650 if o.where=='tower' else 430,.065)
				if o.where in ['tower','pillar','buffer']:stadium.burst(pos+Vector3(0,.15,0),ArenaVisuals.RED if o.owner==0 else ArenaVisuals.BLUE,24 if o.where=='pillar' else 12)
			node.scale=Vector3(1.14,.86,1.14);last_states[i]=o.where
		node.scale=node.scale.lerp(Vector3.ONE,1-exp(-12*dt))
	var target: Vector3=game.robots[game.active[team]].p+Vector3(0,.45,0)
	var desired: Vector3
	if mode=='title':
		target=Vector3(0,.2,0);desired=Vector3(10*sin(.65+title_clock*.025),10,10*cos(.65+title_clock*.025))
	elif overview:target=Vector3.ZERO;desired=Vector3(0,14,6)
	else:
		camera_target=camera_target.lerp(target,1-exp(-12*dt));target=camera_target
		var offset=Vector3(0,sin(pitch)*4,cos(pitch)*4).rotated(Vector3.UP,yaw)
		desired=target+offset
		# Lift the boom over the CAD platforms instead of allowing the camera inside them.
		for n in range(1,9):
			var q=target.lerp(desired,n/8.0)
			if abs(q.x)<5.4 and abs(q.z)<5.4:desired.y=max(desired.y,field.height(q)+.45)
	camera.position=camera.position.lerp(desired,1-exp(-8*dt));camera.look_at(target)
	var ctx=game.context(game.active[team]) if mode!='title' and not ui_open else {}
	hud.action=ctx
	if not ctx.is_empty():
		var p: Vector3=ctx.p+Vector3(0,.75,0)
		hud.action_screen=camera.unproject_position(p) if not camera.is_position_behind(p) else Vector2(-1,-1)
		action_ring.visible=true;action_ring.position=ctx.p+Vector3(0,.035,0)
	else:action_ring.visible=false
	hud.queue_redraw()
	if qa_enabled:
		qa_clock+=dt
		if qa_clock>.5:
			qa_clock=0
			JavaScriptBridge.eval('window.__arenaQA='+JSON.stringify({'mode':mode,'state':game.snapshot(),'fps':Engine.get_frames_per_second(),'menu':ui_open,'room':net.room_code,'team':team,'buttons':qa_buttons()}))

func tone(frequency: float, length: float):
	if tones.has(frequency):sound.stream=tones[frequency];sound.play();return
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050
	var data=PackedByteArray();data.resize(int(22050*length)*2)
	for i in range(data.size()/2):
		var envelope=pow(1-float(i)/(data.size()/2),2)
		var v=int(sin(TAU*frequency*i/22050.0)*envelope*3200)
		data.encode_s16(i*2,v)
	wav.data=data;tones[frequency]=wav;sound.stream=wav;sound.play()

func qa_buttons() -> Array:
	var out=[]
	if is_instance_valid(menu) and ui_open:
		for child in menu.get_children():
			if child is Button:
				var rect=child.get_global_rect()
				out.append({'text':child.text,'x':rect.get_center().x,'y':rect.get_center().y})
	return out
