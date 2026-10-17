class_name ArenaNetwork
extends Node
signal message(data: Dictionary)
var server: TCPServer
var peers={}
var rooms={}
var client: WebSocketPeer
var inputs={}
var endpoint='ws://127.0.0.1:9080'
var room_code=''
var token=''
var team=0
var robot_id=-1
var nickname='Pilot'
var robot_names=['Pilot','Pilot','Pilot','Pilot']
var connected=false
var server_mode=false
var field: ArenaField
var send_clock=0.0
var reconnect_clock=0.0
var reconnect_until=0.0
var client_seq=0
var latest_seq={}
var server_id=1
const PROTOCOL = 'robocon2027-v4'
const RULESET = 'abu2027-v1.1-fixed-r5'
var queue: Array=[]
var ticket=''
var connect_clock=0.0

func host(f: ArenaField):
	server_mode=true;field=f;server=TCPServer.new()
	var port=int(OS.get_environment('PORT')) if not OS.get_environment('PORT').is_empty() else 9080
	var err=server.listen(port)
	if err!=OK: push_error('Cannot listen: '+str(err));get_tree().quit(1)
	else: print('ROOM SERVER ',port)

func connect_to(url: String):
	endpoint=url;client=WebSocketPeer.new();connected=false;connect_clock=0
	var err=client.connect_to_url(endpoint)
	if err!=OK: message.emit({'type':'error','text':'Connection failed'})

func send(data: Dictionary):
	if client and client.get_ready_state()==WebSocketPeer.STATE_OPEN: client.send_text(JSON.stringify(data))

func input(cmd: Dictionary):
	client_seq+=1;send({'type':'input','seq':client_seq,'cmd':cmd})

func _process(dt):
	if server_mode:
		while server.is_connection_available():
			var stream=server.take_connection()
			if peers.size()>=128:stream.disconnect_from_host();continue
			var ws=WebSocketPeer.new();ws.accept_stream(stream);peers[server_id]={'ws':ws,'room':'','team':-1,'seat':-1,'format':'1v1','ticket':'','revision':0,'queued_at':0.0,'nickname':'Pilot'};server_id+=1
		for id in peers.keys():
			var p=peers[id];p.ws.poll()
			if p.ws.get_ready_state()==WebSocketPeer.STATE_CLOSED:
				queue.erase(id);latest_seq.erase(id)
				if rooms.has(p.room) and p.team>=0:
					var room=rooms[p.room]
					if room.ids[p.seat]==id:
						room.ids[p.seat]=0;room.deadline[p.seat]=Time.get_ticks_msec()/1000.0+30;inputs.erase(id)
						if room.get('private',false) and not room.started:broadcast_lobby(p.room)
				peers.erase(id);continue
			var packets=0
			while p.ws.get_available_packet_count()>0 and packets<32:
				packets+=1
				var bytes=p.ws.get_packet()
				if bytes.size()>2048: continue
				var data=JSON.parse_string(bytes.get_string_from_utf8())
				if data is Dictionary: handle(id,data)
		for id in queue.duplicate():
			if peers.has(id) and Time.get_ticks_msec()/1000.0-peers[id].queued_at>120:
				queue.erase(id);emit_to(id,{'type':'error','text':'Search timed out'})
		match_waiting()
	else:
		if not client: return
		connect_clock+=dt
		if not connected and token.is_empty() and connect_clock>45:
			client.close();client=null;message.emit({'type':'error','text':'Connection timed out'});return
		client.poll()
		if client.get_ready_state()==WebSocketPeer.STATE_OPEN:
			if not connected:
				connected=true
				if not token.is_empty(): send({'type':'resume','room':room_code,'token':token})
				else: message.emit({'type':'connected'})
			while client and client.get_available_packet_count()>0:
				var data=JSON.parse_string(client.get_packet().get_string_from_utf8())
				if not data is Dictionary: continue
				if data.get('type')=='joined': room_code=data.room;token=data.token;team=int(data.team);robot_id=int(data.robot_id);robot_names=data.robot_names;reconnect_until=0
				if data.has('robot_names'):robot_names=data.robot_names
				if data.has('robot_id'):robot_id=int(data.robot_id)
				message.emit(data)
		elif client.get_ready_state()==WebSocketPeer.STATE_CLOSED:
			if connected:
				connected=false;reconnect_until=Time.get_ticks_msec()/1000.0+30;message.emit({'type':'lost'})
			reconnect_clock+=dt
			if reconnect_until>0 and Time.get_ticks_msec()/1000.0>=reconnect_until:
				client=null;message.emit({'type':'error','text':'Connection lost'});return
			if not token.is_empty() and reconnect_clock>2 and Time.get_ticks_msec()/1000.0<reconnect_until:
				reconnect_clock=0;connect_to(endpoint)

func _physics_process(dt):
	if not server_mode: return
	send_clock+=dt
	var broadcast=send_clock>=0.05
	if broadcast: send_clock=0
	for code in rooms.keys():
		var room=rooms[code]
		var now=Time.get_ticks_msec()/1000.0
		if room.ids.all(func(id):return id==0) and now>room.deadline.max():rooms.erase(code);continue
		if not room.started and now-room.created>(600 if room.get('private',false) else 45):
			for id in room.ids:
				emit_to(id,{'type':'error','text':'Match expired'})
				if peers.has(id):peers[id].ws.close()
			rooms.erase(code);continue
		if not room.started: continue
		var m: MatchState=room.match
		for seat in range(room.ids.size()):
			var t=seat%2
			var id=room.ids[seat]
			if id==0 and room.deadline[seat]>0 and now>room.deadline[seat] and not m.finished:
				m.finished=true;m.winner=1-t; room.reason='disconnect'
			var cmd=inputs.get(id,{}).duplicate()
			if now-cmd.get('at',0)>0.25: cmd={}
			var switchable=team_can_switch(room,t)
			if room.cpu_seats[seat] and switchable:continue
			if room.cpu_seats[seat]:
				var rid=t*2+int(seat/2)
				m.command_robot(rid,room.drivers[rid].command(m,t,dt,rid),dt)
			elif not switchable:m.command_robot(t*2+int(seat/2),cmd,dt)
			else:m.command(t,cmd,dt)
			if switchable:
				var human=int(m.active[t])
				var partner=t*2+(1-human%2)
				if room.previous_human[t]!=human:
					room.drivers[partner]=ArenaCPU.new();room.previous_human[t]=human
				m.command_robot(partner,room.drivers[partner].command(m,t,dt,partner),dt)
			if inputs.has(id):
				for key in ['act','switch','retry']: inputs[id].erase(key)
		m.step(dt)
		if broadcast:
			var packet={'type':'state','state':m.snapshot(),'reason':room.reason,'robot_names':room_robot_names(room)}
			for id in room.ids:
				if peers.has(id): emit_to(id,packet)

func emit_to(id: int, data: Dictionary):
	if peers.has(id) and peers[id].ws.get_ready_state()==WebSocketPeer.STATE_OPEN: peers[id].ws.send_text(JSON.stringify(data))

func handle(id: int, d: Dictionary):
	var p=peers[id]
	match d.get('type',''):
		'queue':
			if p.room!='':return
			if not d.get('revision',0) is float and not d.get('revision',0) is int:return
			if d.get('protocol')!=PROTOCOL or d.get('ruleset')!=RULESET:
				emit_to(id,{'type':'error','text':'Reload to update'});return
			var format=str(d.get('format','1v1'))
			if format not in ['1v1','2v2']:emit_to(id,{'type':'error','text':'Invalid format'});return
			var requested=str(d.get('ticket',''))
			var revision=int(d.get('revision',0))
			if requested.length()<8 or requested.length()>64 or revision<1:return
			if p.ticket==requested and revision<=p.revision:
				if id in queue:emit_to(id,{'type':'queued','ticket':requested,'revision':revision})
				return
			queue.erase(id);p.nickname=ArenaProfile.clean_name(str(d.get('nickname','Pilot')));p.format=format;p.ticket=requested;p.revision=revision;p.queued_at=Time.get_ticks_msec()/1000.0
			queue.append(id);emit_to(id,{'type':'queued','ticket':requested,'revision':revision})
			match_waiting()
		'create_room','join_room':
			if p.room!='':return
			if d.get('protocol')!=PROTOCOL or d.get('ruleset')!=RULESET:
				emit_to(id,{'type':'error','text':'Reload to update'});return
			var format='2v2'
			var code=str(d.get('room','')).strip_edges().to_upper()
			if d.type=='create_room':
				if rooms.size()>=32:emit_to(id,{'type':'error','text':'Server full'});return
				code=create_room(format,true)
			if not rooms.has(code) or not rooms[code].get('private',false):
				emit_to(id,{'type':'error','text':'Room not found'});return
			var room=rooms[code]
			if room.started:emit_to(id,{'type':'error','text':'Match in progress'});return
			var seat=-1
			for i in range(room.ids.size()):
				if room.ids[i]==0 and room.deadline[i]<=Time.get_ticks_msec()/1000.0:
					seat=i;break
			if seat<0:emit_to(id,{'type':'error','text':'Room full'});return
			queue.erase(id);p.nickname=ArenaProfile.clean_name(str(d.get('nickname','Pilot')))
			room.ids[seat]=id;room.ready[seat]=false;room.deadline[seat]=0.0
			room.tokens[seat]=Crypto.new().generate_random_bytes(16).hex_encode()
			var rid=(seat%2)*2+int(seat/2)
			room.names[rid]=p.nickname
			if format=='1v1':room.names[rid+1]=p.nickname
			join(id,code,seat)
			broadcast_lobby(code)
		'cancel':
			if not d.get('revision',0) is float and not d.get('revision',0) is int:return
			if p.ticket==str(d.get('ticket','')) and int(d.get('revision',0))>=p.revision:
				p.revision=int(d.revision);queue.erase(id);emit_to(id,{'type':'cancelled','ticket':p.ticket})
		'resume':
			var code=str(d.get('room',''))
			if p.room!='' or not rooms.has(code): return
			var room=rooms[code]
			for seat in range(room.ids.size()):
				if str(d.get('token',''))==room.tokens[seat] and room.ids[seat]==0 and Time.get_ticks_msec()/1000.0<room.deadline[seat]:
					queue.erase(id);room.ids[seat]=id;join(id,code,seat)
					if room.get('private',false) and not room.started:broadcast_lobby(code)
					return
		'ready':
			if not rooms.has(p.room): return
			var room=rooms[p.room]
			if room.started: return
			room.ready[p.seat]=true
			if not room.get('private',false) and room.ready.all(func(value):return value) and not room.ids.has(0): room.started=true
			send_ready(room)
		'start_room':
			if not rooms.has(p.room):return
			var room=rooms[p.room]
			if not room.get('private',false) or room.started or p.seat!=room.host_seat:return
			for seat in range(room.ids.size()):
				room.cpu_seats[seat]=room.ids[seat]==0
				if room.cpu_seats[seat]:
					room.names[(seat%2)*2+int(seat/2)]='CPU'
					room.deadline[seat]=0.0
					room.tokens[seat]=Crypto.new().generate_random_bytes(16).hex_encode()
			room.started=true
			broadcast_lobby(p.room)
			send_ready(room)
		'rematch':
			if not rooms.has(p.room):return
			var room=rooms[p.room]
			if not room.match.finished:return
			for seat in range(room.ids.size()):
				if room.ids[seat]==0 and not room.cpu_seats[seat]:return
			if not room.has('again'):room.again=[];room.again.resize(room.ids.size());room.again.fill(false)
			room.again[p.seat]=true
			var everyone=true
			for seat in range(room.ids.size()):
				if not room.cpu_seats[seat] and not room.again[seat]:everyone=false
			if everyone:
				room.match.reset('online');room.reason='';room.again.fill(false)
				room.drivers=[ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new()];room.previous_human=[-1,-1]
				for pid in room.ids:
					inputs.erase(pid)
				send_ready(room)
		'input':
			if not rooms.has(p.room) or not rooms[p.room].started or not d.get('cmd') is Dictionary: return
			if not d.get('seq',0) is float and not d.get('seq',0) is int:return
			var seq=int(d.get('seq',0))
			if seq<=latest_seq.get(id,-1): return
			latest_seq[id]=seq
			var c=d.cmd
			if not c.get('x',0) is float and not c.get('x',0) is int: return
			if not c.get('z',0) is float and not c.get('z',0) is int: return
			if not is_finite(float(c.get('x',0))) or not is_finite(float(c.get('z',0))): return
			var prior=inputs.get(id,{})
			inputs[id]={'x':clampf(c.get('x',0),-1,1),'z':clampf(c.get('z',0),-1,1),'at':Time.get_ticks_msec()/1000.0}
			for key in ['act','switch','retry']: inputs[id][key]=c.get(key,false)==true or prior.get(key,false)==true
		'leave':
			if rooms.has(p.room) and rooms[p.room].get('private',false) and not rooms[p.room].started:
				var room=rooms[p.room]
				room.ids[p.seat]=0;room.ready[p.seat]=false;room.deadline[p.seat]=0.0
				room.tokens[p.seat]=Crypto.new().generate_random_bytes(16).hex_encode()
				broadcast_lobby(p.room)
			p.ws.close()

func team_can_switch(room: Dictionary, team: int) -> bool:
	return room.format=='1v1' or (room.get('private',false) and room.cpu_seats[team]!=room.cpu_seats[team+2])

func control_robot(room: Dictionary, seat: int) -> int:
	return -1 if team_can_switch(room,seat%2) else (seat%2)*2+int(seat/2)

func room_robot_names(room: Dictionary) -> Array:
	var names=room.names.duplicate()
	if not room.get('private',false):return names
	for team in range(2):
		if not team_can_switch(room,team):continue
		var seat=team if not room.cpu_seats[team] else team+2
		var name=room.names[team*2+int(seat/2)]
		var active=int(room.match.active[team])
		names[active]=name;names[team*2+(1-active%2)]='CPU'
	return names

func send_ready(room: Dictionary):
	for seat in range(room.ids.size()):
		emit_to(room.ids[seat],{'type':'ready','ready':room.ready,'started':room.started,'robot_id':control_robot(room,seat),'robot_names':room_robot_names(room)})

func join(id: int, code: String, seat: int):
	var room=rooms[code];var t=seat%2
	peers[id].room=code;peers[id].team=t;peers[id].seat=seat
	emit_to(id,{'type':'joined','room':code,'team':t,'seat':seat,'format':room.format,'robot_id':control_robot(room,seat),'token':room.tokens[seat],'robot_names':room_robot_names(room),'private':room.get('private',false)})

func broadcast_lobby(code: String):
	var room=rooms[code]
	if room.ids[room.host_seat]==0:
		for seat in range(room.ids.size()):
			if room.ids[seat]!=0:
				room.host_seat=seat;break
	for id in room.ids:
		emit_to(id,{'host':id==room.ids[room.host_seat],'type':'lobby','room':code,'count':room.ids.filter(func(pid):return pid!=0).size(),'capacity':room.ids.size(),'robot_names':room.names})

func create_room(format: String, private_room: bool = false) -> String:
	var count=2 if format=='1v1' else 4
	var ids=[];var tokens=[];var ready=[];var deadline=[]
	for seat in range(count):
		ids.append(0);tokens.append(Crypto.new().generate_random_bytes(16).hex_encode());ready.append(false);deadline.append(0.0)
	var code=Crypto.new().generate_random_bytes(3 if private_room else 12).hex_encode().to_upper()
	while rooms.has(code):code=Crypto.new().generate_random_bytes(3 if private_room else 12).hex_encode().to_upper()
	var m=MatchState.new(field);m.reset('online')
	rooms[code]={'private':private_room,'host_seat':0,'cpu_seats':[false,false,false,false] if count==4 else [false,false],'drivers':[ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new()],'previous_human':[-1,-1],'match':m,'names':['Pilot','Pilot','Pilot','Pilot'],'format':format,'ids':ids,'tokens':tokens,'ready':ready,'started':false,'deadline':deadline,'reason':'','created':Time.get_ticks_msec()/1000.0}
	return code

func match_waiting():
	for format in ['1v1','2v2']:
		var count=2 if format=='1v1' else 4
		var waiting=queue.filter(func(id):return peers.has(id) and peers[id].format==format)
		while waiting.size()>=count and rooms.size()<32:
			var code=create_room(format)
			var room=rooms[code]
			for seat in range(count):
				var id=int(waiting.pop_front());queue.erase(id);room.ids[seat]=id
				var rid=(seat%2)*2+int(seat/2)
				room.names[rid]=peers[id].nickname
				if format=='1v1':room.names[rid+1]=room.names[rid]
			for seat in range(count):join(room.ids[seat],code,seat)

func request_room(code: String = ''):
	send({'type':'create_room' if code.is_empty() else 'join_room','room':code,'protocol':PROTOCOL,'ruleset':RULESET,'nickname':nickname})

func find_match(format: String = '1v1'):
	ticket=Crypto.new().generate_random_bytes(16).hex_encode()
	send({'type':'queue','ticket':ticket,'revision':1,'protocol':PROTOCOL,'ruleset':RULESET,'format':format,'nickname':nickname})

func leave():
	if not ticket.is_empty():send({'type':'cancel','ticket':ticket,'revision':2})
	if client:
		send({'type':'leave'})
		client.close()
	client=null;connected=false;token='';room_code='';ticket='';robot_id=-1
