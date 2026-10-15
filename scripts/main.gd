extends Node3D
var field: ArenaField
var game: MatchState
var drivers=[ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new()]
var previous_human=-1
var online_format='1v1'
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
var capture_confirmed=false
var pending={}
var ui_open=true
var net_clock=0.0
var audio: ArenaAudio
var profile=ArenaProfile.new()
var profile_button: Button
var nickname_edit: LineEdit
var editing_profile=false
var awaiting_audio_baseline=false
var browser_focus_callback
var last_overview=false
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
var touch_mode=false
var touch: ArenaTouchControls
var mobile_size=Vector2i.ZERO
var landscape_required=false
var fullscreen_button: Button

func _ready():
	field=ArenaField.new();game=MatchState.new(field);game.reset('cpu')
	net=ArenaNetwork.new();add_child(net)
	if '--server' in OS.get_cmdline_user_args(): net.host(field);set_process(false);set_physics_process(false);return
	touch_mode=DisplayServer.is_touchscreen_available()
	if OS.has_feature('web'):touch_mode=bool(JavaScriptBridge.eval('navigator.maxTouchPoints > 0'))
	if touch_mode:resize_mobile()
	font=load('res://assets/Fredoka-Semibold.ttf')
	font.fallbacks=[load('res://assets/MPLUS1p-Regular.ttf')]
	profile.read();audio=ArenaAudio.new();add_child(audio);audio.levels(profile.music_volume,profile.sfx_volume);net.nickname=profile.nickname
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
	hud=ArenaHUD.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(hud);hud.match_state=game;hud.touch_mode=touch_mode
	touch=ArenaTouchControls.new();touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(touch);touch.visible=false;touch.z_index=100
	touch.look.connect(func(delta):audio.look();yaw-=delta.x*.005;pitch=clampf(pitch+delta.y*.004,.22,1.15))
	touch.action.connect(func(key):
		match key:
			'act':pending.act=true
			'switch':pending.switch=true
			'previous':pending.select=-1
			'next':pending.select=1
			'menu':pause_menu()
			'fullscreen':toggle_fullscreen()
	)
	fullscreen_button=Button.new();fullscreen_button.icon=load('res://assets/fullscreen.svg');fullscreen_button.tooltip_text='Fullscreen'
	fullscreen_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);fullscreen_button.offset_left=-62;fullscreen_button.offset_right=-18;fullscreen_button.offset_top=16;fullscreen_button.offset_bottom=60
	fullscreen_button.add_theme_constant_override('icon_max_width',24);fullscreen_button.z_index=90
	var fullscreen_style=StyleBoxFlat.new();fullscreen_style.bg_color=Color('#fffaf0');fullscreen_style.set_corner_radius_all(12);fullscreen_style.border_color=Color('#20243e');fullscreen_style.set_border_width_all(2)
	for state in ['normal','hover','pressed','disabled','focus']:
		var style=fullscreen_style.duplicate()
		if state=='hover':style.bg_color=Color('#ffda16')
		if state=='pressed':style.bg_color=Color('#12bfe7')
		if state=='disabled':style.bg_color=Color('#c6cee8')
		if state=='focus':style.bg_color=Color.TRANSPARENT;style.border_color=Color('#0078dd')
		fullscreen_button.add_theme_stylebox_override(state,style)
	fullscreen_button.expand_icon=true;fullscreen_button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for state in ['normal','hover','pressed','focus','disabled']:
		fullscreen_button.add_theme_color_override('icon_'+state+'_color',Color.WHITE)
	fullscreen_button.custom_minimum_size=Vector2(44,44)
	if OS.has_feature('web'):
		fullscreen_button.disabled=not bool(JavaScriptBridge.eval('!!document.fullscreenEnabled && !!document.documentElement.requestFullscreen'))
		touch.fullscreen_supported=not fullscreen_button.disabled
	ui.add_child(fullscreen_button);fullscreen_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);fullscreen_button.offset_left=-62;fullscreen_button.offset_right=-18;fullscreen_button.offset_top=16;fullscreen_button.offset_bottom=60;fullscreen_button.pressed.connect(toggle_fullscreen)
	profile_button=Button.new();profile_button.text=profile.nickname;profile_button.add_theme_font_override('font',font);profile_button.add_theme_font_size_override('font_size',18);profile_button.custom_minimum_size=Vector2(200,44);ui.add_child(profile_button);profile_button.position=Vector2(16,16);profile_button.icon=load('res://assets/edit.svg');profile_button.add_theme_constant_override('icon_max_width',20);profile_button.add_theme_color_override('font_color',Color('#20243e'));profile_button.add_theme_color_override('font_hover_color',Color('#20243e'));
	for state in ['normal','hover','pressed','focus']:
		var style=fullscreen_style.duplicate();style.content_margin_left=12;style.content_margin_right=12;style.bg_color=Color('#ffda16') if state=='hover' else Color('#fffaf0');profile_button.add_theme_stylebox_override(state,style)
	profile_button.pressed.connect(func():audio.play('confirm');show_profile())
	net.message.connect(network_message)
	show_title()
	if OS.has_feature('web'):
		browser_focus_callback=JavaScriptBridge.create_callback(func(args):_notification(NOTIFICATION_APPLICATION_FOCUS_IN if bool(args[0]) else NOTIFICATION_APPLICATION_FOCUS_OUT))
		JavaScriptBridge.get_interface('window').arenaFocusCallback=browser_focus_callback
		JavaScriptBridge.eval("(()=>{const notify=()=>window.arenaFocusCallback(!document.hidden&&document.hasFocus());window.addEventListener('blur',notify);window.addEventListener('focus',notify);document.addEventListener('visibilitychange',notify);})()")

func toggle_fullscreen():
	audio.play('fullscreen')
	if OS.has_feature('web'):
		JavaScriptBridge.eval("""(() => {
		const lock = () => { if (navigator.maxTouchPoints > 0 && screen.orientation?.lock) screen.orientation.lock('landscape').catch(() => {}); };
		if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
		else if (document.documentElement.requestFullscreen) document.documentElement.requestFullscreen().then(lock).catch(() => {});
		})()""")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func resize_mobile():
	if not OS.has_feature('web'):return
	var dims=JSON.parse_string(str(JavaScriptBridge.eval('JSON.stringify([innerWidth,innerHeight])')))
	var next_size=Vector2i(int(dims[0]),int(dims[1]))
	if next_size==mobile_size:return
	mobile_size=next_size;landscape_required=next_size.y>next_size.x;get_window().content_scale_size=next_size
	if is_instance_valid(touch):touch.reset();pending.clear();overview=false

func panel():
	editing_profile=false
	if OS.has_feature('web'):JavaScriptBridge.eval("document.getElementById('arena-name')?.remove();window.arenaNameSubmit=false")
	pending.clear();overview=false
	if is_instance_valid(touch):touch.reset();touch.visible=false
	if is_instance_valid(overlay): overlay.queue_free()
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(overlay)
	ui.move_child(fullscreen_button,ui.get_child_count()-1)
	ui.move_child(profile_button,ui.get_child_count()-1)
	var shade=ColorRect.new();shade.color=Color(.14,.1,.24,.18);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(shade)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(center)
	menu=VBoxContainer.new();menu.add_theme_constant_override('separation',8 if touch_mode else 14);menu.custom_minimum_size=Vector2(320,0);center.add_child(menu)
	ui_open=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func label(s: String, size=28) -> Label:
	var l=Label.new();l.text=s;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_font_override('font',font);l.add_theme_font_size_override('font_size',mini(size,34) if touch_mode else size);l.add_theme_color_override('font_color',Color('#20243e'));menu.add_child(l);return l

func button(s: String, call: Callable, color=Color('#fffaf0')) -> Button:
	var b=Button.new();b.text=s;b.custom_minimum_size=Vector2(300,44 if touch_mode else 58);b.add_theme_font_override('font',font);b.add_theme_font_size_override('font_size',22 if touch_mode else 26);b.add_theme_color_override('font_color',Color('#20243e'));b.add_theme_color_override('font_hover_color',Color('#20243e'));b.add_theme_color_override('font_focus_color',Color('#20243e'));b.add_theme_color_override('font_pressed_color',Color('#20243e'))
	for state in ['normal','hover','pressed','focus']:
		var style=StyleBoxFlat.new();style.bg_color=color.lightened(.12) if state=='hover' else color;style.set_corner_radius_all(18);style.content_margin_left=24;style.content_margin_right=24
		if state=='focus': style.bg_color=Color.TRANSPARENT;style.border_color=Color('#20243e');style.set_border_width_all(3)
		if state=='normal':style.shadow_color=Color(.17,.1,.3,.16);style.shadow_size=8;style.shadow_offset=Vector2(0,4)
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(func():audio.play('back' if s in ['BACK','CANCEL','EXIT'] else 'confirm');call.call());menu.add_child(b);return b

func show_title():
	mode='title';net.leave();game.reset('cpu');panel();hud.title=true;result_shown=false
	var logo=ArenaTitle.new();logo.compact=touch_mode;logo.custom_minimum_size=Vector2(370 if touch_mode else 540,132 if touch_mode else 260);menu.add_child(logo)
	button('VS CPU',func(): start('cpu'),Color('#ffda16')).grab_focus()
	button('ONLINE',show_online)
	button('FREE',func(): start('free'))
	var note=button('',show_notes);menu.remove_child(note)
	var holder=CenterContainer.new();menu.add_child(holder);holder.add_child(note)
	note.custom_minimum_size=Vector2(48,40);note.icon=load('res://assets/info.svg');note.add_theme_constant_override('icon_max_width',22)

func show_notes():
	panel();label('ROBOTS',30);label('VS CPU: partner on autopilot.',16)
	label('ABU 2027 / v1.1',16)
	label('Music / SE: MaouDamashii',18)
	label('Koichi Morita · CC BY 4.0',16)
	button('maou.audio',func():OS.shell_open('https://maou.audio/'))
	button('BACK',show_title)

func show_profile():
	panel();label('NAME',28)
	nickname_edit=LineEdit.new();nickname_edit.text=profile.nickname;nickname_edit.max_length=16;nickname_edit.custom_minimum_size=Vector2(320,44);nickname_edit.add_theme_font_override('font',font);nickname_edit.add_theme_font_size_override('font_size',22);menu.add_child(nickname_edit)
	var field_style=StyleBoxFlat.new();field_style.bg_color=Color('#fffaf0');field_style.set_corner_radius_all(12);field_style.content_margin_left=12;nickname_edit.add_theme_stylebox_override('normal',field_style);nickname_edit.add_theme_color_override('font_color',Color('#20243e'))
	nickname_edit.text_changed.connect(func(_value):audio.play('hover',-6,.08))
	button('RANDOM',func():
		nickname_edit.text=ArenaProfile.random_name()
		if OS.has_feature('web'):JavaScriptBridge.eval("document.getElementById('arena-name').value="+JSON.stringify(nickname_edit.text)))
	for kind in ['BGM','SE']:
		var row=HBoxContainer.new();menu.add_child(row)
		var caption=Label.new();caption.text=kind;caption.custom_minimum_size.x=55;caption.add_theme_font_override('font',font);row.add_child(caption)
		var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=profile.music_volume if kind=='BGM' else profile.sfx_volume;slider.custom_minimum_size=Vector2(245,32);slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(slider)
		slider.value_changed.connect(func(value):
			if kind=='BGM':profile.music_volume=value
			else:profile.sfx_volume=value
			audio.levels(profile.music_volume,profile.sfx_volume);audio.play('select');profile.save())
	button('OK',save_profile,Color('#ffda16'))
	nickname_edit.text_submitted.connect(func(_value):save_profile())
	nickname_edit.grab_focus();nickname_edit.select_all();editing_profile=true
	if OS.has_feature('web'):
		nickname_edit.modulate.a=0
		JavaScriptBridge.eval("""(()=>{const input=document.createElement('input');input.id='arena-name';input.type='text';input.maxLength=16;input.autocomplete='nickname';input.setAttribute('aria-label','Nickname');input.style.cssText='position:fixed;z-index:200;box-sizing:border-box;border:2px solid #20243e;border-radius:12px;background:#fffaf0;color:#20243e;padding:0 12px;font:600 22px sans-serif;';input.addEventListener('input',()=>window.arenaNameChanged=true);input.addEventListener('keydown',e=>{e.stopPropagation();if(e.key==='Enter'&&!e.isComposing){window.arenaNameSubmit=true;input.blur();}});document.body.append(input);input.value="""+JSON.stringify(profile.nickname)+";input.focus();input.select();})()")


func save_profile():
	var value=nickname_edit.text
	if OS.has_feature('web'):value=str(JavaScriptBridge.eval("document.getElementById('arena-name')?.value||''"))
	profile.nickname=ArenaProfile.clean_name(value);profile.save();net.nickname=profile.nickname;profile_button.text=profile.nickname;audio.play('confirm');show_title()

func _input(event):
	if is_instance_valid(audio) and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed)):audio.unlock()

func show_online():
	mode='title';hud.title=true;net.leave();panel();label('ONLINE',42)
	button('1 vs 1',func():search_online('1v1'),Color('#ffda16')).grab_focus()
	button('2 vs 2',func():search_online('2v2'))
	button('BACK',show_title)

func search_online(format: String):
	online_format=format;panel();label('1 vs 1' if format=='1v1' else '2 vs 2',42);info=label('CONNECTING',22)
	button('CANCEL',show_online).grab_focus();net.connect_to(net.endpoint)

func network_message(d: Dictionary):
	match d.type:
		'connected':net.find_match(online_format)
		'queued':
			if is_instance_valid(info):info.text='FINDING PLAYERS' if online_format=='2v2' else 'FINDING PLAYER'
		'joined':
			audio.play('reconnected' if mode=='online' else 'found');awaiting_audio_baseline=true
			team=int(d.team)
			if mode!='online':
				panel();label('MATCH FOUND',40);info=label(profile.nickname,18);net.send({'type':'ready'})
			hud.disconnected=false
		'ready':
			if d.started: start('online')
		'state':
			if mode!='online': start('online')
			# Authoritative correction; presentation interpolates the resulting poses.
			game.restore(d.state)
			if net.robot_id>=0:game.active[team]=net.robot_id
			if awaiting_audio_baseline:audio.prime(game);awaiting_audio_baseline=false
		'lost': hud.disconnected=true;audio.play('lost')
		'error':
			audio.play('deny')
			net.leave();panel();label(str(d.text),24);button('RETRY',show_online);button('BACK',show_title)

func start(which: String):
	mode=which;game.reset(which);drivers=[ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new()];previous_human=-1;pending.clear();result_shown=false
	if which!='online':team=0
	elif net.robot_id>=0:game.active[team]=net.robot_id
	hud.can_switch=which!='online' or net.robot_id<0;touch.can_switch=hud.can_switch
	hud.partner_cpu=which=='cpu'
	hud.title=false;hud.team=team;hud.disconnected=false
	yaw=0;pitch=.58
	camera_target=game.robots[game.active[team]].p+Vector3(0,.4,0)
	# Network start arrives outside a browser gesture; capture only on RESUME.
	if which=='online':pause_menu()
	else:close_menu()
	audio.prime(game);audio.play('start')

func close_menu():
	audio.play('resume')
	if OS.has_feature('web') and not bool(JavaScriptBridge.eval('document.hasFocus()')):
		pause_menu();return
	if is_instance_valid(overlay):overlay.queue_free()
	ui_open=false;pending.clear();capture_grace=.5;capture_confirmed=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if touch_mode else Input.MOUSE_MODE_CAPTURED
	touch.reset();touch.visible=touch_mode

func pause_menu():
	if mode=='title':return
	audio.play('pause')
	panel();label('PAUSED' if mode!='online' else 'MENU',40)
	button('RESUME',close_menu).grab_focus()
	button('RETRY',func(): pending.retry=true;close_menu();pending.retry=true)
	if mode!='online':button('RESET',func():start(mode))
	button('EXIT',show_title)

func results():
	audio.play('draw' if game.winner<0 else 'win' if game.winner==team else 'lose')
	result_shown=true;panel()
	label('DRAW' if game.winner<0 else ('YOU WIN' if game.winner==team else 'CPU WINS' if mode=='cpu' else 'YOU LOSE'),48)
	label('%d : %d'%[game.scores[0],game.scores[1]],38)
	if mode!='online':button('AGAIN',func():start(mode),Color('#ffda16')).grab_focus()
	else:button('AGAIN',func():net.send({'type':'rematch'}),Color('#ffda16')).grab_focus()
	button('BACK',show_title)

func _unhandled_input(event):
	if landscape_required:return
	if event is InputEventKey and event.pressed and not event.echo:
		hud.using_pad=false
		if event.keycode==KEY_ESCAPE:
			if mode!='title' and not game.finished:
				if ui_open:close_menu()
				else:pause_menu()
		if ui_open:return
		if event.keycode==KEY_E: pending.act=true
		if event.keycode==KEY_Q: pending.switch=true
	if event is InputEventMouseMotion and not ui_open and not touch_mode and (Input.mouse_mode==Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		hud.using_pad=false
		audio.look();yaw-=event.relative.x*.003;pitch=clampf(pitch+event.relative.y*.002,.22,1.15)
	if event is InputEventMouseButton and event.pressed and not ui_open:
		if event.button_index==MOUSE_BUTTON_LEFT and not touch_mode:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;capture_confirmed=false;capture_grace=.5
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:pending.select=1
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:pending.select=-1

func _notification(what):
	if is_instance_valid(audio):
		if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
			audio.focus(false)
			if qa_enabled and OS.has_feature('web'):JavaScriptBridge.eval('window.__arenaAudioBackground=true')
		elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
			audio.focus(true)
			if qa_enabled and OS.has_feature('web'):JavaScriptBridge.eval('window.__arenaAudioBackground=false')
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud):
		pending.clear()
		if is_instance_valid(touch):touch.reset()
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
	if not ui_open and not landscape_required:
		var axes=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if touch_mode and touch.movement.length()>.01:axes=touch.movement
		var stick=Vector2(Input.get_joy_axis(0,JOY_AXIS_LEFT_X),Input.get_joy_axis(0,JOY_AXIS_LEFT_Y))
		if stick.length()>.18:axes=stick;hud.using_pad=true
		var look=Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
		if look.length()>.18:audio.look();yaw-=look.x*dt*2.5;pitch=clampf(pitch+look.y*dt*1.5,.22,1.15)
		var dir=Vector3(axes.x,0,axes.y).rotated(Vector3.UP,yaw).limit_length(1)
		cmd=pending.duplicate();cmd.x=dir.x;cmd.z=dir.z;pending.clear()
		if gamepad_pressed(JOY_BUTTON_A):cmd.act=true
		if gamepad_pressed(JOY_BUTTON_Y):cmd.switch=true
		if gamepad_pressed(JOY_BUTTON_LEFT_SHOULDER):cmd.select=-1
		if gamepad_pressed(JOY_BUTTON_RIGHT_SHOULDER):cmd.select=1
		overview=touch.overview if touch_mode else (Input.is_physical_key_pressed(KEY_TAB) or Input.get_joy_axis(0,JOY_AXIS_TRIGGER_LEFT)>.5)
	if not hud.can_switch:cmd.erase('switch')
	if mode=='online':
		net.input(cmd)
		if not ui_open and not landscape_required and net.connected:
			# Predict locomotion only. Object operations always await authority.
			game.command_robot(int(game.active[team]),{'x':cmd.get('x',0),'z':cmd.get('z',0)},dt)
	elif not ui_open and not landscape_required:
		game.command(team,cmd,dt)
		if mode=='cpu':
			var human=int(game.active[team])
			if human!=previous_human:
				drivers[1-human]=ArenaCPU.new();previous_human=human
			for rid in range(4):
				if rid!=human:game.command_robot(rid,drivers[rid].command(game,int(rid/2),dt,rid),dt)
		game.step(dt)

func _process(dt):
	if not camera:return
	if editing_profile and OS.has_feature('web'):
		var rect=nickname_edit.get_global_rect();var viewport_size=get_viewport().get_visible_rect().size
		JavaScriptBridge.eval("(()=>{const e=document.getElementById('arena-name');if(!e)return;const c=document.getElementById('canvas').getBoundingClientRect();e.style.left=(c.left+"+str(rect.position.x/viewport_size.x)+"*c.width)+'px';e.style.top=Math.max(8,c.top+"+str(rect.position.y/viewport_size.y)+"*c.height)+'px';e.style.width=("+str(rect.size.x/viewport_size.x)+"*c.width)+'px';e.style.height=("+str(rect.size.y/viewport_size.y)+"*c.height)+'px';e.style.visibility="+JSON.stringify('hidden' if landscape_required else 'visible')+";})()")
		if bool(JavaScriptBridge.eval('window.arenaNameChanged===true')):
			audio.play('hover',-6,.08);JavaScriptBridge.eval('window.arenaNameChanged=false')
		if bool(JavaScriptBridge.eval('window.arenaNameSubmit===true')):save_profile()
	if touch_mode:
		resize_mobile();touch.landscape_required=landscape_required;touch.visible=landscape_required or not ui_open;touch.queue_redraw()
	profile_button.visible=mode=='title' and ui_open and hud.title and not landscape_required and is_instance_valid(menu) and menu.get_child(0) is ArenaTitle
	fullscreen_button.visible=not landscape_required and ui_open
	if overview!=last_overview:audio.play('overview');last_overview=overview
	audio.set_menu(mode=='title' or result_shown)
	audio.observe(game,int(game.active[team]),mode=='title' or ui_open or landscape_required or hud.disconnected,dt)
	fullscreen_button.offset_top=16 if mode=='title' else 100
	fullscreen_button.offset_bottom=fullscreen_button.offset_top+44
	title_clock+=dt
	capture_grace=maxf(0,capture_grace-dt)
	var locked=Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
	if OS.has_feature('web') and not touch_mode:locked=bool(JavaScriptBridge.eval('!!document.pointerLockElement'))
	if not ui_open and locked:capture_confirmed=true
	if not touch_mode and mode!='title' and not ui_open and not game.finished and capture_grace<=0 and capture_confirmed and not locked:
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
			stadium.burst(r.p+Vector3(0,.12,0),Color('#fffaf0'),8)
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
		if o.kind=='S':node.quaternion=node.quaternion.slerp(Quaternion.from_euler(art.sky_rotation(o)),1-exp(-12*dt))
		if last_states[i]!=o.where:
			if mode!='title' and last_states[i]!='':
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
	hud.name_tags=[]
	if mode!='title':
		for rid in range(4):
			if mode=='free' and rid>=2:continue
			var point=robots[rid].position+Vector3(0,1.3,0)
			if camera.is_position_behind(point):continue
			var name=profile.nickname
			if mode=='cpu' and rid!=game.active[team]:name='CPU'
			elif mode=='online':name=net.robot_names[rid]
			hud.name_tags.append({'name':name,'role':'TR' if rid%2==0 else 'BR','team':int(rid/2),'self':rid==game.active[team],'p':camera.unproject_position(point)})
	hud.queue_redraw()
	if qa_enabled:
		qa_clock+=dt
		if qa_clock>.5:
			qa_clock=0
			JavaScriptBridge.eval('window.__arenaQA='+JSON.stringify({'mode':mode,'state':game.snapshot(),'fps':Engine.get_frames_per_second(),'menu':ui_open,'room':net.room_code,'team':team,'robot_id':net.robot_id,'format':online_format,'nickname':profile.nickname,'names':hud.name_tags.map(func(tag):return tag.name),'audio':audio.cue_counts,'music_playing':audio.music.playing,'music_paused':audio.music.stream_paused,'motors':audio.motors.filter(func(player):return player.playing).size(),'audio_peak':AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index('Master'),0),'buttons':qa_buttons(),'touch':touch_mode,'landscape_required':landscape_required,'touch_buttons':touch.qa_buttons(),'move':[touch.movement.x,touch.movement.y],'yaw':yaw,'pitch':pitch,'overview':overview}))

func qa_buttons() -> Array:
	var out=[]
	if is_instance_valid(menu) and ui_open:
		for child in menu.get_children():
			if child is Button:
				var rect=child.get_global_rect()
				out.append({'text':child.text,'x':rect.get_center().x,'y':rect.get_center().y})
	return out
