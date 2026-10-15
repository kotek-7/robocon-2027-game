class_name MatchState
extends RefCounted

const SPEED = 1.7
const ACCEL = 9.0
const REACH = 0.78
var field: ArenaField
var robots: Array = []
var objects: Array = []
var towers: Array = []
var tower_locks: Array = []
var active = [0,2]
var transfer_points = [0,0]
var mandate = [false,false]
var scores = [0,0]
var elapsed = 0.0
var duration = 180.0
var mode = 'cpu'
var finished = false
var winner = -1
var tick = 0
var events: Array = []

func _init(f: ArenaField):
	field=f

func reset(new_mode: String):
	mode=new_mode; robots.clear(); objects.clear(); towers.clear();tower_locks.clear()
	active=[0,2]; transfer_points=[0,0]; mandate=[false,false]; scores=[0,0]
	elapsed=0; tick=0; finished=false; winner=-1; events.clear()
	for i in range(4):
		var x=(-4.8 if i<2 else 4.8)+(0.75 if i%2 else 0.0)*(-1 if i>=2 else 1)
		robots.append({'p':Vector3(x,0,4.9),'v':Vector3.ZERO,'yaw':0.0,'carry':[],'selected':0,'job':{},'left':0.0,'upper':false})
	for t in range(2):
		for n in range(20):
			add_object('E',t,Vector3((-5.2+(n%5)*.37)*(1 if t==0 else -1),.175+int(n/10)*.35,-5.2+(int(n/5)%2)*.4))
	var sky_axes=[['N','','N','','S'],['','E','','W',''],['S','','','','N'],['','W','','E',''],['N','','S','','S']]
	for z in range(5):
		for x in range(5):
			if sky_axes[z][x]!='':
				add_object('S',-1,Vector3((x-2)*.24,.1,4.6073+(z-2)*.24))
				objects.back()['sky_axis']=sky_axes[z][x]
	add_object('M',-1,Vector3(0,.605,-3.88559))
	for i in range(field.spots.size()): towers.append([]);tower_locks.append(-1)

func add_object(kind: String, team: int, p: Vector3):
	objects.append({'kind':kind,'owner':team,'face':team,'p':p,'home':p,'where':'ground','holder':-1,'spot':-1,'delivered':[false,false],'lock':-1,'slot':-1})

func selected(rid: int) -> int:
	var r=robots[rid]
	if r.carry.is_empty(): return -1
	return r.carry[posmod(r.selected,r.carry.size())]

func capacity(rid: int) -> int:
	return 3 if rid%2==0 else 2

func switch_robot(team: int):
	if finished: return
	active[team]=team*2+(1-active[team]%2)

func command(team: int, cmd: Dictionary, dt: float):
	if finished or team<0 or team>1: return
	if cmd.get('switch',false): switch_robot(team)
	command_robot(int(active[team]),cmd,dt)

func command_robot(rid: int, cmd: Dictionary, dt: float):
	if finished or rid<0 or rid>=robots.size():return
	var r=robots[rid]
	if cmd.has('select'): r.selected+=clampi(int(cmd.select),-1,1)
	if cmd.get('retry',false): retry(rid)
	if not r.job.is_empty():r.v=Vector3.ZERO;return
	var dir=Vector3(float(cmd.get('x',0)),0,float(cmd.get('z',0))).limit_length(1.0)
	r.v=r.v.move_toward(dir*SPEED,ACCEL*dt)
	if dir.length()>0.1: r.yaw=lerp_angle(r.yaw,atan2(-dir.x,-dir.z),min(1.0,dt*15))
	var p: Vector3=r.p
	for axis in [Vector3(r.v.x*dt,0,0),Vector3(0,0,r.v.z*dt)]:
		var next=p+axis
		if not field.can_move(p,next,rid): continue
		if r.upper and rid%2==1 and field.height(next)<0.55 and next.z>1.8: continue
		var blocked=false
		for j in range(robots.size()):
			if j==rid or (mode=='free' and j>=2): continue
			if Vector2(next.x-robots[j].p.x,next.z-robots[j].p.z).length()<.49 and abs(next.y-robots[j].p.y)<.3: blocked=true
		if not blocked: p=next
	p.y=field.height(p); r.p=p
	if p.y>=0.59: r.upper=true
	if cmd.get('act',false): begin(rid,context(rid))

func accessible(rid: int, p: Vector3) -> bool:
	var r=robots[rid]
	if Vector2(r.p.x-p.x,r.p.z-p.z).length()>REACH: return false
	if abs(r.p.y-p.y)>1.15: return false
	# Trace floor-level clearance between actor and target, so a wall cannot be reached through.
	for j in range(1,5):
		var q: Vector3=r.p.lerp(p,j/5.0)
		if field.solid[field.cell(q)] and field.height(q)>r.p.y+.1: return false
	return true

func context(rid: int) -> Dictionary:
	var r=robots[rid]; var team=int(rid/2)
	if finished or not r.job.is_empty(): return {}
	var held=selected(rid)
	var transfer=field.transfer(team)
	if rid%2==0 and held>=0 and r.p.y>.55 and Vector2(r.p.x-transfer.x,r.p.z-transfer.z).length()<.48:
		var receiver=robots[team*2+1]
		if receiver.job.is_empty() and receiver.carry.size()<2 and Vector2(receiver.p.x-transfer.x,receiver.p.z-transfer.z).length()<.7:
			return {'type':'give','object':held,'p':transfer,'receiver':team*2+1}
		var count=0
		for obj in objects:
			if obj.where=='buffer' and obj.holder==team:count+=1
		if count<8:return {'type':'drop','object':held,'p':transfer}
		return {}
	if rid%2==1:
		if held>=0:
			var o=objects[held]
			if o.kind=='M' and r.p.y>.85 and accessible(rid,Vector3(0,1.7,0)):
				return {'type':'mustika','object':held,'p':Vector3(0,1.805,0)}
			for s in range(towers.size()):
				if tower_locks[s]>=0 or field.spots[s][4] not in [-1,team]: continue
				var pos=field.spot_pos(s)
				if not accessible(rid,pos) or (field.spots[s][3]==2 and r.p.y<.85): continue
				var stack=towers[s]
				if (o.kind=='E' and stack.size()<2) or (o.kind=='S' and stack.size()==2):
					return {'type':'place','object':held,'spot':s,'p':pos}
		for s in range(towers.size()):
			if tower_locks[s]>=0 or towers[s].size()!=3 or field.spots[s][4] not in [-1,team]: continue
			var oid=towers[s][2]
			if objects[oid].face==team or objects[oid].lock>=0 or r.carry.size()>=capacity(rid): continue
			if accessible(rid,field.spot_pos(s)) and (field.spots[s][3]!=2 or r.p.y>.85):
				return {'type':'flip','object':oid,'spot':s,'p':field.spot_pos(s)}
	if r.carry.size()>=capacity(rid): return stair_context(rid)
	var best={}; var distance=INF
	for i in range(objects.size()):
		var o=objects[i]
		if o.lock>=0 or o.where not in ['ground','buffer']: continue
		if rid%2==1 and o.where!='buffer': continue
		if rid%2==0 and o.where!='ground': continue
		if o.kind=='E' and o.owner!=team: continue
		if o.where=='buffer' and o.holder!=team: continue
		if o.kind=='M' and not mandate[team]: continue
		if not accessible(rid,o.p): continue
		# Stacked stock: only the top block is reachable.
		var covered=false
		for other in objects:
			if other.where=='ground' and other.p.y>o.p.y+.1 and Vector2(other.p.x-o.p.x,other.p.z-o.p.z).length()<.1: covered=true
		if covered: continue
		var d=r.p.distance_to(o.p)
		if d<distance: distance=d;best={'type':'pick','object':i,'p':o.p}
	return best if not best.is_empty() else stair_context(rid)

func stair_context(rid: int) -> Dictionary:
	if finished or not robots[rid].job.is_empty():return {}
	var r=robots[rid]
	for i in range(field.stairs.size()):
		var stair=field.stairs[i]
		if stair.team!=int(rid/2) or (rid%2==0 and i>=2):continue
		for reverse in [false,true]:
			if reverse and i<2 and rid%2==1:continue
			var entry: Vector3=stair.b if reverse else stair.a
			var landing: Vector3=stair.a if reverse else stair.b
			if r.p.distance_to(entry)>.48:continue
			var blocked=false
			for j in range(robots.size()):
				if j==rid or (mode=='free' and j>=2):continue
				if robots[j].p.distance_to(landing)<.55 or robots[j].job.get('stair',-1)==i:blocked=true
			if not blocked:return {'type':'climb','stair':i,'p':entry,'from':r.p,'to':landing,'seconds':stair.seconds}
	return {}

func begin(rid: int, job: Dictionary):
	if job.is_empty() or not robots[rid].job.is_empty() or finished: return
	if job.type=='climb':
		var legal=stair_context(rid)
		if legal.is_empty() or legal.stair!=job.stair or legal.to!=job.to:return
		robots[rid].job=legal;robots[rid].left=legal.seconds;robots[rid].v=Vector3.ZERO
		var direction: Vector3=legal.to-legal.from
		robots[rid].yaw=atan2(-direction.x,-direction.z)
		return
	var oid=int(job.object)
	if objects[oid].lock>=0: return
	if job.has('spot'):
		if tower_locks[job.spot]>=0:return
		tower_locks[job.spot]=rid
	objects[oid].lock=rid
	robots[rid].job=job.duplicate(true)
	robots[rid].left=0.65 if job.type in ['pick','drop','give'] else 1.1
	if job.type=='flip':
		objects[oid].where='held';objects[oid].holder=rid
		towers[job.spot].erase(oid); robots[rid].carry.append(oid)
		update_score()

func step(dt: float):
	if finished: return
	tick+=1; elapsed+=dt
	# End state is sampled before completions at the buzzer.
	if mode!='free' and elapsed>=duration:
		elapsed=duration; finished=true; update_score(); decide_winner(); return
	for rid in range(robots.size()):
		var r=robots[rid]
		if r.job.is_empty(): continue
		r.left=maxf(0,r.left-dt)
		if r.job.type=='climb':
			var progress=clampf(1-r.left/r.job.seconds,0,1)
			var next: Vector3=r.job.from.lerp(r.job.to,progress)
			next.y=field.height(next)
			var blocked=false
			for j in range(robots.size()):
				if j!=rid and not (mode=='free' and j>=2) and robots[j].p.distance_to(next)<.49:blocked=true
			if blocked:r.left+=dt;continue
			r.p=next
		if r.left<=0: complete(rid)
	update_score()

func complete(rid: int):
	var r=robots[rid]; var j=r.job; var team=int(rid/2)
	if j.is_empty(): return
	if j.type=='climb':
		r.p=j.to;r.upper=true;r.job={};r.left=0
		return
	var oid=int(j.object); var o=objects[oid]
	match j.type:
		'pick':
			o.where='held';o.holder=rid;r.carry.append(oid)
		'drop','give':
			r.carry.erase(oid);o.where='buffer';o.holder=team
			var used=[]
			for a in objects:
				if a!=o and a.where=='buffer' and a.holder==team:used.append(a.slot)
			var slot=0
			while slot in used:slot+=1
			o.slot=slot
			o.p=field.transfer(team)+Vector3((slot%2)*.38-.19,.18+int(slot/4)*.35,(int(slot/2)%2)*.38-.19)
			if o.kind!='M' and not o.delivered[team]: transfer_points[team]+=5;o.delivered[team]=true
			if j.type=='give':
				var receiver=robots[j.receiver]
				if receiver.carry.size()<2 and receiver.job.is_empty() and Vector2(receiver.p.x-j.p.x,receiver.p.z-j.p.z).length()<.7:
					o.where='held';o.holder=j.receiver;receiver.carry.append(oid)
		'place','flip':
			r.carry.erase(oid); o.where='tower'; o.spot=j.spot; o.holder=-1
			if o.kind=='S': o.face=team
			else: o.owner=team
			o.p=field.spot_pos(j.spot)+Vector3(0,.175+towers[j.spot].size()*.35,0)
			if o.kind=='S': o.p.y-=.075
			towers[j.spot].append(oid)
		'mustika':
			r.carry.erase(oid);o.where='pillar';o.owner=team;o.p=j.p;o.holder=-1
	if j.has('spot'):tower_locks[j.spot]=-1
	o.lock=-1;r.job={};r.left=0
	events.append({'type':j.type,'team':team,'object':oid})
	if events.size()>24: events.pop_front()

func retry(rid: int):
	var r=robots[rid]
	for i in range(tower_locks.size()):
		if tower_locks[i]==rid:tower_locks[i]=-1
	for o in objects:
		if o.lock==rid: o.lock=-1
	for oid in r.carry:
		var o=objects[oid];o.where='ground';o.p=o.home;o.holder=-1;o.spot=-1
		if o.kind=='S':o.face=-1
	r.carry.clear();r.job={};r.v=Vector3.ZERO;r.left=0
	r.p=Vector3(-4.8 if rid<2 else 4.8,0,4.9)
	r.upper=false

func update_score():
	scores=transfer_points.duplicate()
	var count=[0,0];var shared=[0,0]
	for s in range(towers.size()):
		var level=int(field.spots[s][3])
		for n in range(towers[s].size()):
			var o=objects[towers[s][n]]
			if o.where!='tower': continue
			var t=int(o.face if o.kind=='S' else o.owner)
			scores[t]+=level*([10,20,40][n])
		if towers[s].size()==3:
			var t=int(objects[towers[s][2]].face);count[t]+=1
			if field.spots[s][4]==-1: shared[t]+=1
	for t in range(2):
		if count[t]>=2 and shared[t]>=1: mandate[t]=true
	for o in objects:
		if o.where=='pillar': scores[o.owner]+=250

func decide_winner():
	if scores[0]!=scores[1]: winner=0 if scores[0]>scores[1] else 1; return
	var keys=[[0,0,0,0],[0,0,0,0]]
	for o in objects:
		if o.where=='pillar': keys[o.owner][0]+=1
		if o.where=='tower':
			var t=int(o.face if o.kind=='S' else o.owner)
			if o.kind=='S': keys[t][1]+=1
			keys[t][2 if field.spots[o.spot][3]==2 else 3]+=1
	for i in range(4):
		if keys[0][i]!=keys[1][i]: winner=0 if keys[0][i]>keys[1][i] else 1; return
	winner=-1

func snapshot() -> Dictionary:
	var rs=[];var os=[]
	for r in robots:
		var d=r.duplicate(true);d.p=[r.p.x,r.p.y,r.p.z];d.v=[r.v.x,r.v.y,r.v.z]
		for key in ['p','from','to']:
			if d.job.has(key): d.job[key]=[d.job[key].x,d.job[key].y,d.job[key].z]
		rs.append(d)
	for o in objects:
		var d=o.duplicate(true);d.p=[o.p.x,o.p.y,o.p.z];d.home=[o.home.x,o.home.y,o.home.z];os.append(d)
	return {'robots':rs,'objects':os,'towers':towers,'tower_locks':tower_locks,'active':active,'scores':scores,'transfer':transfer_points,'mandate':mandate,'elapsed':elapsed,'finished':finished,'winner':winner,'tick':tick,'mode':mode}

func restore(s: Dictionary):
	robots=s.robots; objects=s.objects;towers=s.towers;tower_locks=s.tower_locks;active=s.active;scores=s.scores;transfer_points=s.transfer;mandate=s.mandate;elapsed=s.elapsed;finished=s.finished;winner=int(s.winner);tick=int(s.tick);mode=s.mode
	for i in range(towers.size()): towers[i]=towers[i].map(func(v):return int(v))
	scores=[int(scores[0]),int(scores[1])];active=[int(active[0]),int(active[1])]
	for r in robots:
		r.carry=r.carry.map(func(v): return int(v))
		r.p=Vector3(r.p[0],r.p[1],r.p[2]);r.v=Vector3(r.v[0],r.v[1],r.v[2]);r.selected=int(r.selected)
		for key in ['p','from','to']:
			if r.job.has(key): r.job[key]=Vector3(r.job[key][0],r.job[key][1],r.job[key][2])
	for o in objects:
		o.p=Vector3(o.p[0],o.p[1],o.p[2]);o.home=Vector3(o.home[0],o.home[1],o.home[2]);o.holder=int(o.holder);o.lock=int(o.lock);o.spot=int(o.spot);o.owner=int(o.owner);o.face=int(o.face);o.slot=int(o.slot)
