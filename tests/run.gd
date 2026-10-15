extends SceneTree
var failed=0
var checks=0
func check(ok: bool, name: String):
	checks+=1
	if not ok: failed+=1;printerr('FAIL: ',name)
	else:print('PASS: ',name)
func _initialize():
	var f=ArenaField.new();var m=MatchState.new(f);m.reset('cpu')
	check(m.objects.size()==53,'53 competition objects')
	check(f.spots.size()==10,'ten CAD building spots')
	check(abs(f.height(Vector3(1,.9,1))-.9)<.01,'L2 height')
	check(not f.valid(Vector3(-2,.6,2),0),'TR cannot enter L1')
	check(not f.valid(Vector3(4,0,4),0),'opponent territory blocked')
	check(not f.can_move(Vector3(-5,0,4),Vector3(-5.4,0,4),0),'field boundary stops driving')
	check(not f.can_move(Vector3(2.2,.6,0),Vector3(1.2,.9,0),1),'large vertical step cannot be crossed directly')
	check(not m.accessible(0,Vector3(0,0,0)),'interaction cannot reach distant objects')
	check(f.route(m.robots[0].p,f.transfer(0),0).size()>1,'TR start to transfer route')
	check(f.route(m.robots[1].p,Vector3(-.6,.9,0),1).size()>1,'BR start to L2 route')
	m.robots[0].p=f.transfer(0)
	m.robots[0].carry=[0];m.objects[0].where='held';m.objects[0].holder=0
	m.begin(0,m.context(0));m.step(.7)
	check(m.scores[0]==5,'delivery scores 5')
	m.objects[0].where='held';m.robots[0].carry=[0]
	m.begin(0,m.context(0));m.step(.7)
	check(m.scores[0]==5,'same block cannot score delivery twice')
	m.reset('cpu')
	for entry in [[0,0,0],[1,0,0],[40,0,0],[2,4,0],[3,4,0],[41,4,0]]:
		var o=m.objects[entry[0]];o.where='tower';o.spot=entry[1];o.owner=entry[2];o.face=entry[2];m.towers[entry[1]].append(entry[0])
	m.update_score()
	check(m.scores[0]==140,'two L1 complete towers score 140')
	check(m.mandate[0],'own and shared tower unlock Mustika')
	m.objects[41].face=1;m.update_score()
	check(m.scores==[100,40],'flip preserves Earth ownership')
	check(m.mandate[0],'mandate retained after flip')
	m.robots[3].p=Vector3(.5,.6,-2.75)
	m.begin(3,{'type':'flip','object':41,'spot':4,'p':f.spot_pos(4)})
	m.update_score()
	check(m.scores[1]==0,'held flipping block excluded')
	m.elapsed=179.9;m.step(.2)
	check(m.finished and m.scores[1]==0,'buzzer precedes action completion')
	var wire=JSON.parse_string(JSON.stringify(m.snapshot()));var copy=MatchState.new(f);copy.restore(wire)
	check(copy.scores==m.scores and copy.objects.size()==53,'snapshot roundtrip')
	m.reset('free');m.step(200)
	check(not m.finished,'free mode unlimited')
	m.reset('cpu');m.robots[0].carry=[52];m.objects[52].where='held';m.objects[52].holder=0;m.retry(0)
	check(m.objects[52].where=='ground' and m.objects[52].p==m.objects[52].home,'retry returns Mustika')
	m.reset('cpu');m.robots[0].p=Vector3(-4.8,0,-4.4)
	m.begin(0,m.context(0));m.switch_robot(0);m.step(.7)
	check(m.active[0]==1 and m.robots[0].carry.size()==1 and m.robots[1].carry.is_empty(),'switch lets an existing job finish without starting another')
	m.reset('cpu')
	m.robots[0].p=f.transfer(0);m.robots[1].p=f.transfer(0)+Vector3(.5,0,0)
	m.robots[0].carry=[0];m.objects[0].where='held';m.objects[0].holder=0
	m.begin(0,m.context(0));m.step(.7)
	check(m.robots[1].carry==[0] and m.scores[0]==5,'direct handover is atomic and scores')
	m.reset('cpu')
	m.begin(0,{'type':'pick','object':40,'p':m.objects[40].p})
	m.begin(2,{'type':'pick','object':40,'p':m.objects[40].p})
	check(m.robots[2].job.is_empty(),'same object cannot be reserved twice')
	m.reset('cpu')
	m.robots[1].carry=[0];m.robots[3].carry=[20]
	m.begin(1,{'type':'place','object':0,'spot':4,'p':f.spot_pos(4)})
	m.begin(3,{'type':'place','object':20,'spot':4,'p':f.spot_pos(4)})
	check(m.robots[3].job.is_empty(),'same tower cannot receive simultaneous placements')
	m.retry(1)
	check(m.tower_locks[4]==-1,'retry releases tower reservation')
	m.reset('cpu');m.robots[0].carry=[0,1,2]
	check(m.context(0).is_empty(),'full TR cannot pick a fourth object')
	m.reset('cpu');m.scores=[20,10];m.decide_winner()
	check(m.winner==0,'higher score wins')
	m.reset('free');m.active[0]=1;m.robots[1].p=f.stairs[0].a
	check(not f.can_move(Vector3(-3.4,0,3),Vector3(-3.4,0,2.8),1),'driving cannot enter stair footprint')
	m.robots[0].p=f.stairs[0].a
	check(m.stair_context(0).get('type','')=='climb','TR can use GND to transfer stairs')
	m.robots[0].p=Vector3(-4.8,0,4.9)
	var climb=m.context(1)
	check(climb.get('type','')=='climb' and climb.seconds==3.0,'GND to L1 has explicit three-second operation')
	m.command(0,{'act':true},1.0/60)
	m.step(1.0)
	var during=m.robots[1].p
	m.command(0,{'x':1,'z':1},.5)
	check(m.robots[1].p==during,'steering cannot cancel or move a climbing robot')
	var climbing_wire=JSON.parse_string(JSON.stringify(m.snapshot()));var restored=MatchState.new(f);restored.restore(climbing_wire)
	check(restored.robots[1].job.to==f.stairs[0].b and restored.robots[1].left==2.0,'active stair operation survives network snapshot')
	m.switch_robot(0);m.step(1.9)
	check(not m.robots[1].job.is_empty(),'climb does not finish early after robot switch')
	m.step(.11)
	check(m.robots[1].p==f.stairs[0].b and m.robots[1].job.is_empty(),'inactive robot finishes at L1 landing')
	check(m.stair_context(1).is_empty(),'L1 to GND descent remains forbidden')
	m.active[0]=1;m.robots[1].p=f.stairs[2].a;m.robots[1].carry=[0,1]
	climb=m.stair_context(1);m.begin(1,climb);m.step(2.01)
	check(m.robots[1].p==f.stairs[2].b and m.robots[1].carry==[0,1],'two-second L2 ascent preserves full cargo')
	m.begin(1,m.stair_context(1));m.step(2.01)
	check(m.robots[1].p==f.stairs[2].a,'L2 to L1 uses timed descent')
	m.begin(1,m.stair_context(1));m.step(.3);m.retry(1)
	check(m.robots[1].job.is_empty() and m.robots[1].p.y==0,'retry releases a stair operation')
	m.robots[1].p=f.stairs[0].a;m.robots[0].p=f.stairs[0].b
	check(m.stair_context(1).is_empty(),'occupied landing prevents stair operation')
	m.reset('cpu');m.robots[1].p=f.stairs[0].a;m.begin(1,m.stair_context(1));m.elapsed=179.9;m.step(.2)
	check(m.finished and not m.robots[1].job.is_empty(),'buzzer stops an unfinished climb')
	var view=load("res://scenes/world/field.tscn").instantiate()
	var arrays=view.mesh.surface_get_arrays(0);var hard_top=false;var hard_side=false
	for normal in arrays[Mesh.ARRAY_NORMAL]:
		if normal.y>.999:hard_top=true
		if abs(normal.y)<.001:hard_side=true
	check(hard_top and hard_side,'CAD mesh retains flat top and vertical face normals')
	view.free()
	m.reset('free')
	var stock_ok=true;var columns={}
	for i in range(40):
		var o=m.objects[i];var x=abs(o.p.x)
		stock_ok=stock_ok and x-.175>=3.5 and x+.175<=5.45 and o.p.z-.175>=-5.45 and o.p.z+.175<=-4.5
		stock_ok=stock_ok and (is_equal_approx(o.p.y,.175) or is_equal_approx(o.p.y,.525))
		var key=Vector2(o.p.x,o.p.z);columns[key]=columns.get(key,0)+1
	check(stock_ok and columns.size()==20 and columns.values().all(func(n):return n==2),'Earth stock has ten two-high columns per team inside CAD storage')
	check(m.objects[40].sky_axis=='N' and m.objects[42].sky_axis=='S' and m.objects[43].sky_axis=='E','Sky orientation follows Figure 4')
	var sky_ok=true
	for i in range(40,52):
		var o=m.objects[i];var x=roundi(o.p.x/.24)+2;var z=roundi((o.p.z-4.6073)/.24)+2
		sky_ok=sky_ok and (x+z)%2==0 and not (x==2 and z==2)
		var normal=Basis.from_euler(ArenaVisuals.new().sky_rotation(o))*Vector3.UP
		sky_ok=sky_ok and abs(normal.y)<.001
	check(sky_ok,'Sky blocks occupy even checkerboard cells, leave center empty and start sideways')
	m.active[0]=0;m.robots[0].p=f.stairs[0].a;m.begin(0,m.stair_context(0));m.step(3.01)
	check(m.robots[0].p==f.stairs[0].b,'TR completes stairs into transfer area')
	m.begin(0,m.stair_context(0));m.step(3.01)
	check(m.robots[0].p==f.stairs[0].a,'TR returns to ground by stairs')
	m.robots[0].p=f.stairs[2].a
	check(m.stair_context(0).is_empty(),'TR still cannot use L2 stairs')
	check(f.valid(Vector3(-3.5,.3,-1),1) and f.can_move(Vector3(-3.4,.3,-1),Vector3(-3.4,.3,-.9),1),'BR ramp passage is open')
	m.robots[0].carry=[40];m.objects[40].face=1;m.retry(0)
	check(m.objects[40].face==-1 and m.objects[40].sky_axis=='N','retry restores Sky initial sideways orientation')
	var ai=ArenaCPU.new();m.reset('cpu')
	for i in range(10801):
		m.command(1,ai.command(m,1,1.0/60),1.0/60);m.step(1.0/60)
	check(m.finished,'CPU completes natural 180 second simulation')
	check(m.scores[1]>30,'CPU constructs towers without debug positioning')
	check(m.mandate[1] and m.objects[52].where=='pillar','CPU continues through multiple towers and Mustika')
	print('CPU SCORE ',m.scores,' active ',m.active,' positions ',m.robots[2].p,' ',m.robots[3].p)
	m.reset('cpu')
	var pilots=[ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new()]
	var human_start: Vector3=m.robots[0].p
	for tick in range(360):
		for rid in [1,2,3]:m.command_robot(rid,pilots[rid].command(m,int(rid/2),1.0/60,rid),1.0/60)
		m.step(1.0/60)
	check(m.robots[0].p==human_start and m.active[0]==0,'partner AI never moves or switches the human robot')
	check(m.robots[1].p.distance_to(Vector3(-4.05,0,4.9))>.5,'idle BR partner approaches transfer area')
	m.switch_robot(0);var br_start: Vector3=m.robots[1].p
	for tick in range(120):
		m.command_robot(0,pilots[0].command(m,0,1.0/60,0),1.0/60);m.step(1.0/60)
	check(m.robots[0].p.distance_to(human_start)>.5 and m.robots[1].p==br_start and m.active[0]==1,'switch hands TR to AI and BR to human')
	m.reset('cpu');pilots=[ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new(),ArenaCPU.new()]
	for tick in range(10801):
		for rid in [2,3]:m.command_robot(rid,pilots[rid].command(m,1,1.0/60,rid),1.0/60)
		m.step(1.0/60)
	print('DUAL CPU SCORE ',m.scores)
	check(m.finished and m.scores[1]>100,'two simultaneous CPU pilots complete a match and construct towers')
	check(ArenaProfile.clean_name('  はる  7  ')=='はる 7','nickname permits Japanese and normalizes spaces')
	check(ArenaProfile.clean_name('CPU')=='Pilot' and ArenaProfile.clean_name('\n\t')=='Pilot','reserved and empty names receive safe defaults')
	check(ArenaProfile.clean_name('abc\u202edef').length()==6 and ArenaProfile.clean_name('abcdefghijklmnopqr').length()==16,'nickname excludes bidi overrides and enforces length')
	m.reset('free');m.command(0,{'switch':true},1.0/60);m.retry(1)
	var event_copy=MatchState.new(f);event_copy.restore(m.snapshot())
	check(event_copy.events.size()==2 and event_copy.event_seq==2 and event_copy.events[1].type=='retry','authoritative audio events survive snapshots in sequence')
	for n in range(80):m.emit_event('pick',0)
	check(m.events.size()==64 and m.events[0].id==19 and m.events.back().id==82,'audio history is bounded with monotonic event IDs')
	print('RESULT ',checks-failed,'/',checks)
	quit(1 if failed else 0)
