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
var connected=false
var server_mode=false
var field: ArenaField
var send_clock=0.0
var reconnect_clock=0.0
var reconnect_until=0.0
var client_seq=0
var latest_seq={}
var server_id=1
const PROTOCOL = 'robocon2027-v2'
const RULESET = 'abu2027-v1.1-fixed-r3'
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
			var ws=WebSocketPeer.new();ws.accept_stream(stream);peers[server_id]={'ws':ws,'room':'','team':-1,'ticket':'','revision':0,'queued_at':0.0};server_id+=1
		for id in peers.keys():
			var p=peers[id];p.ws.poll()
			if p.ws.get_ready_state()==WebSocketPeer.STATE_CLOSED:
				queue.erase(id);latest_seq.erase(id)
				if rooms.has(p.room) and p.team>=0:
					var room=rooms[p.room]
					if room.ids[p.team]==id: room.ids[p.team]=0;room.deadline[p.team]=Time.get_ticks_msec()/1000.0+30;inputs.erase(id)
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
			while client.get_available_packet_count()>0:
				var data=JSON.parse_string(client.get_packet().get_string_from_utf8())
				if not data is Dictionary: continue
				if data.get('type')=='joined': room_code=data.room;token=data.token;team=int(data.team);reconnect_until=0
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
		if room.ids==[0,0] and now>max(room.deadline[0],room.deadline[1]): rooms.erase(code);continue
		if not room.started: continue
		var m: MatchState=room.match
		for t in range(2):
			var id=room.ids[t]
			if id==0 and room.deadline[t]>0 and now>room.deadline[t] and not m.finished:
				m.finished=true;m.winner=1-t; room.reason='disconnect'
			var cmd=inputs.get(id,{}).duplicate()
			if now-cmd.get('at',0)>0.25: cmd={}
			m.command(t,cmd,dt)
			if inputs.has(id):
				for key in ['act','switch','retry','select']: inputs[id].erase(key)
		m.step(dt)
		if broadcast:
			var packet={'type':'state','state':m.snapshot(),'reason':room.reason}
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
			var requested=str(d.get('ticket',''))
			var revision=int(d.get('revision',0))
			if requested.length()<8 or requested.length()>64 or revision<1:return
			if p.ticket==requested and revision<=p.revision:
				if id in queue:emit_to(id,{'type':'queued','ticket':requested,'revision':revision})
				return
			queue.erase(id);p.ticket=requested;p.revision=revision;p.queued_at=Time.get_ticks_msec()/1000.0
			queue.append(id);emit_to(id,{'type':'queued','ticket':requested,'revision':revision})
			match_waiting()
		'cancel':
			if not d.get('revision',0) is float and not d.get('revision',0) is int:return
			if p.ticket==str(d.get('ticket','')) and int(d.get('revision',0))>=p.revision:
				p.revision=int(d.revision);queue.erase(id);emit_to(id,{'type':'cancelled','ticket':p.ticket})
		'resume':
			var code=str(d.get('room',''))
			if p.room!='' or not rooms.has(code): return
			var room=rooms[code]
			for t in range(2):
				if str(d.get('token',''))==room.tokens[t] and room.ids[t]==0 and Time.get_ticks_msec()/1000.0<room.deadline[t]:
					room.ids[t]=id;join(id,code,t);return
		'ready':
			if not rooms.has(p.room): return
			var room=rooms[p.room]
			if room.started: return
			room.ready[p.team]=true
			if room.ready==[true,true] and room.ids[0]!=0 and room.ids[1]!=0: room.started=true
			for pid in room.ids: emit_to(pid,{'type':'ready','ready':room.ready,'started':room.started})
		'rematch':
			if not rooms.has(p.room):return
			var room=rooms[p.room]
			if not room.match.finished or room.ids[0]==0 or room.ids[1]==0:return
			if not room.has('again'):room.again=[false,false]
			room.again[p.team]=true
			if room.again==[true,true]:
				room.match.reset('online');room.reason='';room.again=[false,false]
				for pid in room.ids:
					inputs.erase(pid)
					emit_to(pid,{'type':'ready','ready':[true,true],'started':true})
		'input':
			if not rooms.has(p.room) or not rooms[p.room].started or not d.get('cmd') is Dictionary: return
			if not d.get('seq',0) is float and not d.get('seq',0) is int:return
			var seq=int(d.get('seq',0))
			if seq<=latest_seq.get(id,-1): return
			latest_seq[id]=seq
			var c=d.cmd
			if not c.get('select',0) is float and not c.get('select',0) is int:return
			if not c.get('x',0) is float and not c.get('x',0) is int: return
			if not c.get('z',0) is float and not c.get('z',0) is int: return
			if not is_finite(float(c.get('x',0))) or not is_finite(float(c.get('z',0))): return
			var prior=inputs.get(id,{})
			inputs[id]={'x':clampf(c.get('x',0),-1,1),'z':clampf(c.get('z',0),-1,1),'at':Time.get_ticks_msec()/1000.0}
			for key in ['act','switch','retry']: inputs[id][key]=c.get(key,false)==true or prior.get(key,false)==true
			inputs[id].select=clampi(int(c.get('select',prior.get('select',0))),-1,1)
		'leave':
			p.ws.close()

func join(id: int, code: String, t: int):
	peers[id].room=code;peers[id].team=t
	emit_to(id,{'type':'joined','room':code,'team':t,'token':rooms[code].tokens[t]})

func match_waiting():
	while queue.size()>=2 and rooms.size()<32:
		var a=int(queue.pop_front());var b=int(queue.pop_front())
		if not peers.has(a) or not peers.has(b):continue
		var code=Crypto.new().generate_random_bytes(12).hex_encode()
		var m=MatchState.new(field);m.reset('online')
		rooms[code]={'match':m,'ids':[a,b],'tokens':[Crypto.new().generate_random_bytes(16).hex_encode(),Crypto.new().generate_random_bytes(16).hex_encode()],'ready':[false,false],'started':false,'deadline':[0.0,0.0],'reason':''}
		join(a,code,0);join(b,code,1)

func find_match():
	ticket=Crypto.new().generate_random_bytes(16).hex_encode()
	send({'type':'queue','ticket':ticket,'revision':1,'protocol':PROTOCOL,'ruleset':RULESET})

func leave():
	if not ticket.is_empty():send({'type':'cancel','ticket':ticket,'revision':2})
	if client: client.close()
	client=null;connected=false;token='';room_code='';ticket=''
