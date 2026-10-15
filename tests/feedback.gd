extends SceneTree
var failures=0
func check(ok: bool, message: String):
	print(('PASS: ' if ok else 'FAIL: ')+message)
	if not ok:failures+=1
func _initialize():call_deferred('run')
func hold(m: MatchState, rid: int, ids: Array):
	m.robots[rid].carry=ids
	for oid in ids:m.objects[oid].where='held';m.objects[oid].holder=rid
func run():
	var f=ArenaField.new();var m=MatchState.new(f);m.reset('free')
	var ai=ArenaCPU.new();var retries=0
	for i in range(1800):
		var cmd=ai.command(m,0,1.0/60,1)
		if cmd.get('retry',false):retries+=1
		m.command_robot(1,cmd,1.0/60);m.step(1.0/60)
	check(retries==0 and m.robots[1].p.distance_to(f.transfer(0))<1.0,'BR waits for 30 seconds without retrying')
	m.objects[0].where='buffer';m.objects[0].holder=0;m.objects[0].p=f.transfer(0)
	for i in range(90):m.command_robot(1,ai.command(m,0,1.0/60,1),1.0/60);m.step(1.0/60)
	check(m.robots[1].carry.has(0) or m.objects[0].where=='tower','waiting BR resumes when cargo arrives')
	m.reset('free');ai=ArenaCPU.new();hold(m,1,[0]);var recovers=false
	for i in range(240):
		# A real destination, but deliberately prevent locomotion.
		if ai.command(m,0,1.0/60,1).get('retry',false):recovers=true
	check(recovers,'blocked travel still has retry recovery')
	m.reset('free');ai=ArenaCPU.new();hold(m,1,[40,41]);m.robots[1].p=f.transfer(0)+Vector3(.65,0,0)
	m.objects[0].where='buffer';m.objects[0].holder=0;m.objects[0].p=f.transfer(0)
	retries=0
	for i in range(300):
		if ai.command(m,0,1.0/60,1).get('retry',false):retries+=1
	check(retries==0,'full BR with no compatible tower waits even when buffer has items')
	m.reset('free');hold(m,1,[40,0]);m.robots[1].p=f.spot_pos(0)+Vector3(.5,0,0)
	m.command_robot(1,{'select':1},0)
	check(m.robots[1].selected==0,'legacy cargo selection input is ignored')
	ai=ArenaCPU.new()
	var auto_cmd=ai.command(m,0,1.0/60,1)
	check(auto_cmd.get('act',false) and not auto_cmd.has('select'),'CPU uses compatible cargo without cycling selection')
	var ctx=m.context(1)
	check(ctx.get('object')==0 and ctx.get('type')=='place','Earth is automatically chosen for an empty tower')
	check(m.robots[1].selected==0,'target preview does not mutate authoritative selection')
	m.command_robot(1,{'act':true},0)
	check(m.selected(1)==0 and not m.events.any(func(e):return e.type=='select'),'placement switches cargo silently')
	m.step(1.2)
	check(m.towers[0]==[0] and m.scores[0]==10,'automatic placement completes and scores')
	m.reset('free');hold(m,1,[0,40]);m.robots[1].p=f.spot_pos(0)+Vector3(.5,0,0)
	for oid in [1,2]:m.objects[oid].where='tower';m.objects[oid].spot=0;m.towers[0].append(oid)
	check(m.context(1).get('object')==40,'Sky is automatically chosen for a two-high tower')
	m.tower_locks[0]=3
	check(m.context(1).get('type')!='place','automatic selection respects tower locks')
	m.reset('free');hold(m,1,[0,52]);m.robots[1].p=Vector3(.65,.9,0)
	check(m.context(1).get('type')=='mustika' and m.context(1).get('object')==52,'pillar automatically chooses Mustika')
	# A full BR rotates cargo using the normal action, without extra delivery points.
	m.reset('free');hold(m,1,[0,1]);m.robots[1].p=f.transfer(0)+Vector3(.5,0,0)
	m.objects[2].where='buffer';m.objects[2].holder=0;m.objects[2].p=f.transfer(0)
	check(m.context(1).get('type')=='return','full BR offers return at its transfer area')
	m.command_robot(1,{'act':true},0);m.step(.7)
	check(m.objects[0].where=='buffer' and m.robots[1].carry==[1] and m.scores[0]==0,'normal action returns one object with no delivery points')
	check(m.context(1).get('object')==2 and m.context(1).get('type')=='pick','fresh buffer cargo precedes the just-returned object')
	m.command_robot(1,{'act':true},0);m.step(.7)
	check(m.robots[1].carry==[1,2] and m.context(1).get('object')==1,'round robin advances to the next carried object')
	m.command_robot(1,{'act':true},0);m.step(.7)
	check(m.context(1).get('object')==0,'older returned cargo is retrieved before newly returned cargo')
	var returned_copy=MatchState.new(f);returned_copy.restore(JSON.parse_string(JSON.stringify(m.snapshot())))
	check(returned_copy.context(1).get('object')==0,'round robin ordering survives network snapshots')
	hold(m,1,[3,4]);m.robots[1].p=f.transfer(1)
	check(m.return_context(1).is_empty(),'BR cannot return into the opponent transfer area')
	m.robots[1].p=f.transfer(0)+Vector3(.5,0,0)
	for oid in range(5,13):m.objects[oid].where='buffer';m.objects[oid].holder=0
	check(m.return_context(1).is_empty(),'full buffer blocks return')
	# Real event boundaries: retry, mandate completion, offering and both teams' scores.
	m.reset('free')
	var hud=load('res://scenes/ui/hud.tscn').instantiate();root.add_child(hud);hud.match_state=m
	var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,9,12);camera.look_at(Vector3.ZERO)
	var feedback=hud.get_node('Feedback');feedback.prime(m)
	m.retry(0)
	for entry in [[0,0],[1,0],[40,0],[2,4],[3,4],[41,4]]:
		var o=m.objects[entry[0]];o.where='tower';o.spot=entry[1];o.owner=0;o.face=0;m.towers[entry[1]].append(entry[0])
	m.update_score(1)
	hold(m,1,[52]);m.robots[1].p=Vector3(.65,.9,0);m.begin(1,m.context(1));m.step(1.2)
	m.transfer_points[1]=5;m.update_score(2)
	var copy=MatchState.new(f);copy.restore(JSON.parse_string(JSON.stringify(m.snapshot())))
	feedback.observe(copy,camera,hud,false,.016)
	var texts=feedback.effects.map(func(e):return e.node.get_node('Label').text)
	check(texts.has('リトライ！') and texts.has('マンデート！') and texts.has('奉納！'),'actual match events produce all three Japanese bubbles')
	check(feedback.effects.any(func(e):return e.rid==1 and e.node.get_node('Label').text=='マンデート！'),'mandate identifies the achieving BR through JSON snapshots')
	check(texts.has('+140') and texts.has('+250') and texts.has('+5'),'score popups carry exact positive deltas for both teams')
	check(feedback.effects.filter(func(e):return e.team>=0).all(func(e):return e.node.get_node('Particles').emitting),'score popups emit particles')
	var count=feedback.effects.size();feedback.observe(copy,camera,hud,false,.016)
	check(feedback.effects.size()==count,'repeated snapshot does not duplicate feedback')
	feedback.observe(copy,camera,hud,false,3)
	check(feedback.effects.is_empty(),'transient feedback expires')
	feedback.prime(copy);feedback.observe(copy,camera,hud,false,.016)
	check(feedback.effects.is_empty(),'reconnect baseline skips historical feedback')
	copy.emit_event('retry',2);feedback.observe(copy,camera,hud,true,.016);feedback.observe(copy,camera,hud,false,.016)
	check(feedback.effects.is_empty(),'paused events do not replay')
	hud.queue_free();camera.queue_free();await process_frame
	quit(1 if failures else 0)
