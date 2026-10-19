extends Node3D

@export_group("Menu scenes")
@export var title_menu: PackedScene
@export var notes_menu: PackedScene
@export var profile_menu: PackedScene
@export var online_menu: PackedScene
@export var online_format_menu: PackedScene
@export var room_menu: PackedScene
@export var room_lobby_menu: PackedScene
@export var search_menu: PackedScene
@export var found_menu: PackedScene
@export var error_menu: PackedScene
@export var pause_screen: PackedScene
@export var results_menu: PackedScene
@export var panel_scene: PackedScene

var field: ArenaField
var game: MatchState
var drivers=[ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new()]
var previous_human=-1
var online_format='1v1'
var online_method='auto'
var requested_room=''
var member_seat=-1
var art=ArenaVisuals.new()
var net: ArenaNetwork
var camera
var robots: Array=[]
var items: Array=[]
var hud: ArenaHUD
var ui: Control
var menu: Control
var overlay: Control
var info: Label
var team=0
var mode='title'
@export_group("Input sensitivity")
@export var mouse_look = Vector2(0.003, 0.002)
@export var touch_look = Vector2(0.005, 0.004)
@export var gamepad_look_speed = Vector2(2.5, 1.5)

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
var browser_edit: LineEdit
var browser_submit: Callable
var browser_input_id=""
var awaiting_audio_baseline=false
var browser_focus_callback
var last_overview=false
var last_states=[]
var action_ring: MeshInstance3D
var title_clock=0.0
var qa_clock=0.0
var qa_enabled=false
var result_shown=false
var finish_remaining=0.0
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
	net=$Network
	if '--server' in OS.get_cmdline_user_args():
		# A headless renderer does not disable animation scripts. Keep only networking.
		Engine.max_fps=60
		for child in get_children():
			if child!=net:child.process_mode=Node.PROCESS_MODE_DISABLED
		net.host(field);set_process(false);set_physics_process(false);return
	touch_mode=DisplayServer.is_touchscreen_available()
	if OS.has_feature('web'):touch_mode=bool(JavaScriptBridge.eval('navigator.maxTouchPoints > 0'))
	if touch_mode:resize_mobile()
	profile.read();audio=$Audio;audio.levels(profile.music_volume,profile.sfx_volume);net.nickname=profile.nickname
	if OS.has_feature('web'):qa_enabled=bool(JavaScriptBridge.eval("location.search.includes('qa=1')"))
	if OS.has_feature('web'):
		net.endpoint=str(JavaScriptBridge.eval("location.hostname==='localhost'||location.hostname==='127.0.0.1'?'ws://127.0.0.1:9080':`wss://${location.host}/ws`"))
	stadium=$Stadium
	camera=$Camera
	robots=$Robots.get_children()
	shadows=$RobotShadows.get_children()
	items=$Objects.get_children()
	for item in items:last_states.append('')
	action_ring=$ActionRing
	ui=$Interface/UI
	hud=$Interface/UI/HUD
	hud.match_state=game;hud.touch_mode=touch_mode
	touch=$Interface/UI/TouchControls
	fullscreen_button=$Interface/UI/Fullscreen
	profile_button=$Interface/UI/Profile
	profile_button.text=profile.nickname
	touch.look.connect(func(delta):audio.look();yaw-=delta.x*touch_look.x;pitch=clampf(pitch+delta.y*touch_look.y,.22,1.15))
	touch.action.connect(func(key):
		match key:
			'act':pending.act=true
			'switch':pending.switch=true
			'menu':pause_menu()
			'fullscreen':toggle_fullscreen()
	)
	if OS.has_feature('web'):
		fullscreen_button.disabled=not bool(JavaScriptBridge.eval('!!document.fullscreenEnabled && !!document.documentElement.requestFullscreen'))
		touch.fullscreen_supported=not fullscreen_button.disabled
	fullscreen_button.pressed.connect(toggle_fullscreen)
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

func panel(content: PackedScene):
	browser_edit=null;browser_submit=Callable();browser_input_id=""
	if OS.has_feature('web'):JavaScriptBridge.eval("document.querySelector('[data-arena-input]')?.remove();window.arenaNameSubmit=false")
	pending.clear();overview=false
	if is_instance_valid(touch):touch.reset();touch.visible=false
	if is_instance_valid(overlay): overlay.queue_free()
	overlay=panel_scene.instantiate();ui.add_child(overlay)
	ui.move_child(fullscreen_button,ui.get_child_count()-1)
	ui.move_child(profile_button,ui.get_child_count()-1)
	menu=content.instantiate()
	overlay.get_node('Center').add_child(menu)
	menu.configure(touch_mode)
	ui_open=true;hud.menu_open=true;hud.update_view();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func bind_button(path: String, callback: Callable, cue='confirm') -> Button:
	var node: Button=menu.get_node(path)
	node.pressed.connect(func():audio.play(cue);callback.call())
	return node

func show_title():
	finish_remaining=0.0;hud.hide_finish()
	mode='title';net.leave();game.reset('cpu');panel(title_menu);hud.title=true;result_shown=false
	bind_button('CPU',func():start('cpu')).grab_focus()
	bind_button('Online',show_online)
	bind_button('Free',func():start('free'))
	bind_button('Footer/Notes',show_notes)

func show_notes():
	panel(notes_menu)
	bind_button('Website',func():OS.shell_open('https://maou.audio/'))
	bind_button('Back',show_title,'back')

func show_profile():
	panel(profile_menu)
	nickname_edit=menu.get_node('Nickname');nickname_edit.text=profile.nickname
	nickname_edit.text_changed.connect(func(_value):audio.play('hover',-6,.08))
	bind_button('Random',func():
		nickname_edit.text=ArenaProfile.random_name()
		if OS.has_feature('web'):JavaScriptBridge.eval("document.getElementById('arena-name').value="+JSON.stringify(nickname_edit.text)))
	for kind in ['Music','Effects']:
		var slider: HSlider=menu.get_node(kind+'/Volume')
		slider.value=profile.music_volume if kind=='Music' else profile.sfx_volume
		slider.value_changed.connect(func(value):
			if kind=='Music':profile.music_volume=value
			else:profile.sfx_volume=value
			audio.levels(profile.music_volume,profile.sfx_volume);audio.play('select');profile.save())
	bind_button('Save',save_profile)
	nickname_edit.text_submitted.connect(func(_value):save_profile())
	setup_text_input(nickname_edit,'arena-name','Nickname',save_profile)

func setup_text_input(edit: LineEdit, id: String, label: String, submit: Callable):
	if not OS.has_feature('web'):
		edit.grab_focus();edit.select_all();return
	# The browser owns text/IME input. A focused hidden LineEdit steals focus every 100 ms.
	edit.release_focus();edit.focus_mode=Control.FOCUS_NONE;edit.mouse_filter=Control.MOUSE_FILTER_IGNORE
	edit.modulate.a=0
	browser_edit=edit;browser_submit=submit;browser_input_id=id
	JavaScriptBridge.eval("""(()=>{
	const input=document.createElement('input');input.id="""+JSON.stringify(id)+""";
	input.dataset.arenaInput='';input.type='text';input.maxLength="""+str(edit.max_length)+""";
	input.autocomplete='off';input.spellcheck=false;input.setAttribute('aria-label',"""+JSON.stringify(label)+""");
	input.style.cssText='position:fixed;z-index:200;box-sizing:border-box;border:2px solid #20243e;border-radius:12px;background:#fffaf0;color:#20243e;padding:0 12px;font:600 22px ArenaLatin,ArenaJapanese,sans-serif;touch-action:manipulation;';
	input.addEventListener('input',()=>window.arenaNameChanged=true);
	input.addEventListener('keydown',e=>{e.stopPropagation();if(e.key==='Enter'&&!e.isComposing){window.arenaNameSubmit=true;}});
	input.addEventListener('keyup',e=>e.stopPropagation());
	document.body.append(input);input.value="""+JSON.stringify(edit.text)+""";input.placeholder="""+JSON.stringify(edit.placeholder_text)+""";
	input.focus();input.select();})()""")

func text_input_value(edit: LineEdit) -> String:
	if OS.has_feature('web') and edit==browser_edit:
		return str(JavaScriptBridge.eval("document.getElementById("+JSON.stringify(browser_input_id)+")?.value||''"))
	return edit.text


func save_profile():
	var value=text_input_value(nickname_edit)
	profile.nickname=ArenaProfile.clean_name(value);profile.save();net.nickname=profile.nickname;profile_button.text=profile.nickname;audio.play('confirm');show_title()

func _input(event):
	if event is InputEventJoypadMotion and abs(event.axis_value)>.18 and is_instance_valid(hud):hud.using_pad=true
	if is_instance_valid(audio) and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed)):audio.unlock()

func show_online():
	mode='title';hud.title=true;net.leave();panel(online_menu)
	bind_button('Room',show_room_options).grab_focus()
	bind_button('Automatic',func():show_online_format())
	bind_button('Back',show_title,'back')

func show_online_format():
	online_method='auto';net.leave();panel(online_format_menu)
	menu.get_node('Heading').text='AUTO MATCH'
	bind_button('Solo',func():select_online_format('1v1')).grab_focus()
	bind_button('Teams',func():select_online_format('2v2'))
	bind_button('Back',show_online,'back')

func select_online_format(format: String):
	search_online(format)

func show_room_options():
	online_method='room';online_format='2v2'
	net.leave();panel(room_menu)
	bind_button('Create',func():connect_room('')).grab_focus()
	bind_button('Join',join_room_code)
	menu.get_node('Code').text_submitted.connect(func(_value):join_room_code())
	setup_text_input(menu.get_node('Code'),'arena-room','Room code',join_room_code)
	bind_button('Back',show_online,'back')

func join_room_code():
	var code=text_input_value(menu.get_node('Code')).strip_edges().to_upper()
	if code.length()!=6 or not code.is_valid_hex_number():
		menu.get_node('Info').visible=true
		menu.get_node('Info').text='INVALID CODE';return
	connect_room(code)

func connect_room(code: String):
	requested_room=code
	panel(search_menu);info=menu.get_node('Info')
	menu.get_node('Heading').text='CONNECTING'
	bind_button('Cancel',show_room_options,'back').grab_focus()
	net.connect_pool('room')

func search_online(format: String):
	online_format=format;panel(search_menu)
	menu.get_node('Heading').text='1 vs 1' if format=='1v1' else '2 vs 2'
	info=menu.get_node('Info')
	bind_button('Cancel',func():show_online_format(),'back').grab_focus();net.connect_pool(format)

func network_message(d: Dictionary):
	match d.type:
		'connected':
			if online_method=='room':net.request_room(requested_room)
			else:net.find_match(online_format)
		'queued':
			if is_instance_valid(info):info.text='FINDING PLAYERS' if online_format=='2v2' else 'FINDING PLAYER'
		'joined':
			audio.play('reconnected' if mode=='online' else 'found');awaiting_audio_baseline=true
			team=int(d.team);member_seat=int(d.seat)
			if mode!='online':
				if d.get('private',false):
					panel(room_lobby_menu);info=menu.get_node('Content/Info')
					menu.get_node('Content/Header/Copy').text=str(d.room)
					bind_button('Content/Header/Copy',func():DisplayServer.clipboard_set(net.room_code))
					bind_button('Content/Actions/Start',func():net.send({'type':'start_room'}))
					bind_button('Content/Header/Cancel',show_room_options,'back').grab_focus()
					menu.get_node('Content/Roster').show_members(d.get('members',[]),member_seat)
					net.send({'type':'ready'})
				else:
					panel(found_menu);info=menu.get_node('Content/Info')
					menu.get_node('Content/Roster').show_members(d.get('members',[]),member_seat)
					prepare_auto_match(menu)
			hud.disconnected=false
		'lobby':
			if mode!='online' and is_instance_valid(info) and menu.has_node('Content/Actions/Start'):
				menu.get_node('Content/Roster').show_members(d.get('members',[]),member_seat)
				menu.get_node('Content/Actions/Start').disabled=not bool(d.host)
				menu.get_node('Content/Actions/Start').visible=bool(d.host)
				menu.get_node('Content/Actions/Waiting').visible=not bool(d.host)
		'ready':
			if d.started: start('online')
		'state':
			if mode!='online': start('online')
			# Authoritative correction; presentation interpolates the resulting poses.
			game.restore(d.state)
			if net.robot_id>=0:game.active[team]=net.robot_id
			if awaiting_audio_baseline:audio.prime(game);hud.get_node('Feedback').prime(game);awaiting_audio_baseline=false
		'lost': hud.disconnected=true;audio.play('lost')
		'error':
			audio.play('deny')
			net.leave();panel(error_menu);menu.get_node('Info').text=str(d.text)
			bind_button('Retry',show_room_options if online_method=='room' else show_online);bind_button('Back',show_title,'back')

func prepare_auto_match(matched_menu: Control):
	# Keep the roster readable before signalling readiness; the server clock has
	# not started yet. A replaced menu invalidates this asynchronous countdown.
	for seconds in [3,2,1]:
		if not is_instance_valid(matched_menu) or menu!=matched_menu or mode=='online':return
		matched_menu.get_node('Content/Info').text=str(seconds)
		await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(matched_menu) or menu!=matched_menu or mode=='online':return
	matched_menu.get_node('Content/Info').text='…'
	net.send({'type':'ready'})

func start(which: String):
	finish_remaining=0.0;hud.hide_finish()
	mode=which;game.reset(which);drivers=[ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new()];previous_human=-1;pending.clear();result_shown=false
	if which!='online':team=0
	elif net.robot_id>=0:game.active[team]=net.robot_id
	hud.can_switch=which!='online' or net.robot_id<0;touch.can_switch=hud.can_switch
	hud.title=false;hud.team=team;hud.disconnected=false
	yaw=0;pitch=.58
	camera.follow_target=game.robots[game.active[team]].p+Vector3(0,.4,0)
	# Web matches start asynchronously; acquire pointer lock on the next click.
	close_menu(which!='online' or not OS.has_feature('web'))
	audio.prime(game);hud.get_node('Feedback').prime(game);audio.start_match();audio.play('start')

func close_menu(capture_mouse: bool = true):
	audio.play('resume')
	if capture_mouse and OS.has_feature('web') and not bool(JavaScriptBridge.eval('document.hasFocus()')):
		pause_menu();return
	if is_instance_valid(overlay):overlay.queue_free()
	ui_open=false;hud.menu_open=false;pending.clear();capture_grace=.5;capture_confirmed=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if touch_mode or not capture_mouse else Input.MOUSE_MODE_CAPTURED
	touch.reset();touch.visible=touch_mode

func pause_menu():
	if mode=='title':return
	audio.play('pause')
	panel(pause_screen)
	menu.get_node('Heading').text='PAUSED' if mode!='online' else 'MENU'
	bind_button('Resume',close_menu).grab_focus()
	bind_button('Retry',func():pending.retry=true;close_menu();pending.retry=true)
	menu.get_node('Reset').visible=mode!='online'
	bind_button('Reset',func():start(mode))
	bind_button('Exit',show_title,'back')

func results():
	audio.play('draw' if game.winner<0 else 'win' if game.winner==team else 'lose')
	result_shown=true;panel(results_menu)
	menu.get_node('Heading').text='DRAW' if game.winner<0 else ('YOU WIN' if game.winner==team else 'CPU WINS' if mode=='cpu' else 'YOU LOSE')
	menu.get_node('Score').text='%d : %d'%[game.scores[0],game.scores[1]]
	bind_button('Again',func():
		if mode=='online':net.send({'type':'rematch'})
		else:start(mode)).grab_focus()
	bind_button('Back',show_title,'back')

func _unhandled_input(event):
	if landscape_required:return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo():
		hud.using_pad=event is InputEventJoypadButton
		if event.is_action_pressed("pause"):
			if mode!='title' and not game.finished:
				if ui_open:close_menu()
				else:pause_menu()
		if ui_open or game.finished:return
		if event.is_action_pressed("interact"):pending.act=true
		if event.is_action_pressed("switch_robot"):pending.switch=true
	if event is InputEventMouseMotion and not ui_open and not touch_mode and (Input.mouse_mode==Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		hud.using_pad=false
		audio.look();yaw-=event.relative.x*mouse_look.x;pitch=clampf(pitch+event.relative.y*mouse_look.y,.22,1.15)
	if event is InputEventMouseButton and event.pressed and not ui_open:
		if event.button_index==MOUSE_BUTTON_LEFT and not touch_mode:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;capture_confirmed=false;capture_grace=.5

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

func _physics_process(dt):
	if not is_instance_valid(hud) or mode=='title':return
	if game.finished:
		if result_shown:return
		if finish_remaining<=0:
			if not audio.focused:return
			# Consume the final snapshot before opening any overlay.
			audio.observe(game,int(game.active[team]),false,dt)
			finish_remaining=audio.finish_match()
			pending.clear();touch.reset();hud.show_finish()
			if is_instance_valid(overlay):overlay.queue_free()
			ui_open=true
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		elif audio.focused:
			finish_remaining=maxf(0,finish_remaining-dt)
			if finish_remaining<=0:
				hud.hide_finish();results()
		return
	var cmd={}
	if not ui_open and not landscape_required:
		var axes=Input.get_vector('move_left','move_right','move_forward','move_back')
		if touch_mode and touch.movement.length()>.01:axes=touch.movement
		var look=Input.get_vector('look_left','look_right','look_up','look_down')
		if look.length()>.01:
			audio.look();yaw-=look.x*dt*gamepad_look_speed.x;pitch=clampf(pitch+look.y*dt*gamepad_look_speed.y,.22,1.15)
		var dir=Vector3(axes.x,0,axes.y).rotated(Vector3.UP,yaw).limit_length(1)
		cmd=pending.duplicate();cmd.x=dir.x;cmd.z=dir.z;pending.clear()
		overview=touch.overview if touch_mode else Input.is_action_pressed('overview')
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
	if is_instance_valid(browser_edit) and OS.has_feature('web'):
		var rect=browser_edit.get_global_rect();var viewport_size=get_viewport().get_visible_rect().size
		JavaScriptBridge.eval("(()=>{const e=document.querySelector('[data-arena-input]');if(!e)return;const c=document.getElementById('canvas').getBoundingClientRect();e.style.left=(c.left+"+str(rect.position.x/viewport_size.x)+"*c.width)+'px';e.style.top=Math.max(8,c.top+"+str(rect.position.y/viewport_size.y)+"*c.height)+'px';e.style.width=("+str(rect.size.x/viewport_size.x)+"*c.width)+'px';e.style.height=("+str(rect.size.y/viewport_size.y)+"*c.height)+'px';e.style.visibility="+JSON.stringify('hidden' if landscape_required else 'visible')+";})()")
		if bool(JavaScriptBridge.eval('window.arenaNameChanged===true')):
			audio.play('hover',-6,.08);JavaScriptBridge.eval('window.arenaNameChanged=false')
		if bool(JavaScriptBridge.eval('window.arenaNameSubmit===true')):
			JavaScriptBridge.eval('window.arenaNameSubmit=false');browser_submit.call()
	if touch_mode:
		resize_mobile();touch.landscape_required=landscape_required;touch.visible=landscape_required or not ui_open;touch.update_view()
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
		node.update_pose(r,dt,title_clock,mode=='title',i)
		var climbing=r.job.get('type','')=='climb'
		if last_jobs[i] and not climbing and mode!='title':
			stadium.burst(r.p+Vector3(0,.12,0),Color('#fffaf0'),8)
		last_jobs[i]=climbing
		shadows[i].position=Vector3(node.position.x,field.height(node.position)+.012,node.position.z);shadows[i].visible=node.visible
	for i in range(items.size()):
		var o=game.objects[i];var node: Node3D=items[i]
		var pos: Vector3=o.p
		if o.where=='held':
			var rid=int(o.holder);var index=game.robots[rid].carry.find(i)
			pos=robots[rid].position+Vector3((index%2)*.2-.1,.75+int(index/2)*.28,.18).rotated(Vector3.UP,robots[rid].rotation.y)
		var changed=last_states[i]!=o.where
		if changed:
			if mode!='title' and last_states[i]!='':
				if o.where in ['tower','pillar','buffer']:stadium.burst(pos+Vector3(0,.15,0),ArenaVisuals.RED if o.owner==0 else ArenaVisuals.BLUE,24 if o.where=='pillar' else 12)
			last_states[i]=o.where
		node.update_pose(pos,art.sky_rotation(o),o.kind=='S',changed,dt)
	camera.update_view(dt,game.robots[game.active[team]].p,field,mode=='title',overview,yaw,pitch)
	var ctx=game.context(game.active[team]) if mode!='title' and not ui_open else {}
	touch.get_node('Buttons/act').text='RETURN' if ctx.get('type')=='return' else 'ACT'
	hud.action=ctx
	if not ctx.is_empty():
		var p: Vector3=ctx.p+Vector3(0,.75,0)
		hud.action_screen=camera.unproject_position(p) if not camera.is_position_behind(p) else Vector2(-1,-1)
		action_ring.visible=true;action_ring.position=ctx.p+Vector3(0,.035,0)
	else:action_ring.visible=false
	hud.participant_names.fill("CPU")
	hud.name_tags=[]
	if mode!='title':
		for rid in range(4):
			if mode=='free' and rid>=2:continue
			var name=profile.nickname
			if mode=='cpu' and rid!=game.active[team]:name='CPU'
			elif mode=='online':
				name=net.robot_names[rid]
				if online_format=='1v1' and rid!=game.active[int(rid/2)]:name='CPU'
			hud.participant_names[rid]=name
			var point=robots[rid].position+Vector3(0,1.3,0)
			if camera.is_position_behind(point):continue
			hud.name_tags.append({'name':name,'role':'TR' if rid%2==0 else 'BR','team':int(rid/2),'self':rid==game.active[team],'p':camera.unproject_position(point)})
	hud.update_view()
	hud.get_node('Feedback').observe(game,camera,hud,mode=='title' or ui_open or landscape_required or hud.disconnected,dt)
	if qa_enabled:
		qa_clock+=dt
		if qa_clock>.5:
			qa_clock=0
			JavaScriptBridge.eval('window.__arenaQA='+JSON.stringify({'mode':mode,'state':game.snapshot(),'fps':Engine.get_frames_per_second(),'menu':ui_open,'room':net.room_code,'team':team,'robot_id':net.robot_id,'format':online_format,'nickname':profile.nickname,'nameplates_visible':hud.get_node('Names').visible,'names':hud.name_tags.map(func(tag):return tag.name),'audio':audio.cue_counts,'music_playing':audio.music.playing,'music_paused':audio.music.stream_paused,'motors':audio.motors.filter(func(player):return player.playing).size(),'audio_peak':AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index('Master'),0),'buttons':qa_buttons(),'touch':touch_mode,'landscape_required':landscape_required,'touch_buttons':touch.qa_buttons(),'move':[touch.movement.x,touch.movement.y],'yaw':yaw,'pitch':pitch,'overview':overview}))

func qa_buttons() -> Array:
	var out=[]
	if is_instance_valid(menu) and ui_open:
		for child in menu.get_children():
			if child is Button:
				var rect=child.get_global_rect()
				out.append({'text':child.text,'x':rect.get_center().x,'y':rect.get_center().y})
	return out
