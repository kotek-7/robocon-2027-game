class_name ArenaCPU
extends RefCounted
var path=PackedVector3Array()
var goal=Vector3(999,999,999)
var last_rid=-1
var stuck=0.0
var previous=Vector3.ZERO
var next_flip=0.0

func command(m: MatchState, team: int, dt: float, fixed_rid: int = -1) -> Dictionary:
	var tr=team*2;var br=tr+1
	var buffer=[]
	for i in range(m.objects.size()):
		if m.objects[i].where=='buffer' and m.objects[i].holder==team: buffer.append(i)
	var rid=int(m.active[team])
	var buildable=[]
	for oid in m.robots[br].carry:
		if m.objects[oid].kind=='M':buildable.append(oid);continue
		for s in range(m.towers.size()):
			if m.field.spots[s][4] not in [-1,team]:continue
			var n=m.towers[s].size()
			if (m.objects[oid].kind=='E' and n<2) or (m.objects[oid].kind=='S' and n==2):
				buildable.append(oid);break
	var br_work=not buildable.is_empty() or (not buffer.is_empty() and m.robots[br].carry.size()<2)
	var flip_spot=-1
	if m.elapsed>=next_flip and m.robots[br].carry.is_empty():
		for s in range(m.towers.size()):
			if m.field.spots[s][4]==-1 and m.towers[s].size()==3 and m.objects[m.towers[s][2]].face!=team and m.tower_locks[s]<0:
				if m.robots[br].p.distance_to(m.field.spot_pos(s))<3:flip_spot=s;break
	var parking=not buffer.is_empty() and m.robots[tr].carry.is_empty() and m.robots[tr].p.y>.1
	if rid==tr and not parking and (not m.robots[tr].job.is_empty() or m.robots[tr].carry.is_empty()) and br_work and m.robots[br].job.is_empty(): rid=br
	elif rid==br and (not m.robots[br].job.is_empty() or not br_work) and m.robots[tr].job.is_empty(): rid=tr
	if flip_spot>=0 and m.robots[br].job.is_empty():rid=br
	if fixed_rid>=0:rid=fixed_rid
	var cmd={'switch':fixed_rid<0 and rid!=m.active[team],'x':0.0,'z':0.0}
	var r=m.robots[rid]
	if not r.job.is_empty(): return cmd
	var target=Vector3(999,999,999)
	var wanted=-1
	if rid%2==0:
		if parking: target=Vector3(-4.6 if team==0 else 4.6,0,3.0)
		elif not r.carry.is_empty(): target=m.field.transfer(team)
		else:
			var needed_sky=0
			for s in range(m.towers.size()):
				if m.towers[s].size()==2 and m.field.spots[s][4] in [-1,team]: needed_sky+=1
			for o in m.objects:
				if o.kind=='S' and ((o.where=='buffer' and o.holder==team) or (o.where=='held' and o.holder in [tr,br])):needed_sky-=1
			var kind='M' if m.mandate[team] and m.objects[52].where=='ground' else ('S' if needed_sky>0 else 'E')
			var best=INF
			for i in range(m.objects.size()):
				var o=m.objects[i]
				if o.kind!=kind or o.where!='ground' or o.lock>=0 or (kind=='E' and o.owner!=team): continue
				var distance=r.p.distance_to(o.p)
				if distance<best: best=distance;target=o.p;wanted=i
	else:
		if not buildable.is_empty():
			if m.selected(rid) not in buildable:
				cmd.select=1;return cmd
			var oid=m.selected(rid);var o=m.objects[oid]
			if o.kind=='M': target=Vector3(0,.9,0)
			else:
				var best=INF
				for s in range(m.towers.size()):
					if m.field.spots[s][4] not in [-1,team]: continue
					var n=m.towers[s].size()
					if not ((o.kind=='E' and n<2) or (o.kind=='S' and n==2)): continue
					var p=m.field.spot_pos(s)
					var weight=r.p.distance_to(p)-n*2
					if m.field.spots[s][4]==-1: weight-=1
					if weight<best:best=weight;target=p
		elif flip_spot>=0:target=m.field.spot_pos(flip_spot)
		elif not buffer.is_empty(): target=m.objects[buffer[0]].p
		else:
			target=m.field.transfer(team)+Vector3(.65 if team==0 else -.65,0,0)
			for s in range(m.towers.size()):
				if m.towers[s].size()==3 and m.objects[m.towers[s][2]].face!=team and m.field.spots[s][4]==-1:
					target=m.field.spot_pos(s);break
	if target.x==999: return cmd
	var ctx=m.context(rid)
	if not ctx.is_empty() and ctx.type!='climb' and (ctx.type!='pick' or wanted<0 or m.objects[ctx.object].kind==m.objects[wanted].kind):
		if ctx.type=='flip':next_flip=m.elapsed+6
		cmd.act=true;return cmd
	if target.distance_to(goal)>.25 or last_rid!=rid or path.is_empty():
		path=m.field.route(r.p,target,rid);goal=target;last_rid=rid
	while path.size()>1 and Vector2(path[0].x-r.p.x,path[0].z-r.p.z).length()<.18 and abs(path[0].y-r.p.y)<.08: path.remove_at(0)
	if not path.is_empty():
		var stair=m.stair_context(rid)
		if not stair.is_empty():
			for waypoint in path:
				if waypoint.distance_to(stair.to)<.15:
					cmd.act=true;path.clear();return cmd
				if waypoint.distance_to(r.p)>2:break
		var d: Vector3=(path[0]-r.p);d.y=0
		if d.length()>.06: d=d.normalized();cmd.x=d.x;cmd.z=d.z
	if r.p.distance_to(previous)<.002: stuck+=dt
	else: stuck=0
	previous=r.p
	if stuck>2.5:
		path.clear();stuck=0;cmd.retry=true
	return cmd
