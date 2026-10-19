extends SceneTree

class TestNetwork extends ArenaNetwork:
	var sent=[]
	func send(packet: Dictionary):sent.append(packet)

func _initialize():call_deferred('run')

func members():
	return [
		{'seat':0,'team':0,'role':'TR','nickname':'Same Name','status':'connected','host':true},
		{'seat':1,'team':1,'role':'TR','nickname':'Same Name','status':'connected','host':false},
		{'seat':2,'team':0,'role':'BR','nickname':'あいうえおかきくけこさしすせそた','status':'connected','host':false},
		{'seat':3,'team':1,'role':'BR','nickname':'CPU','status':'open','host':false}]

func run():
	var scene=load('res://main.tscn').instantiate();root.add_child(scene)
	await process_frame
	var network=TestNetwork.new();scene.add_child(network);scene.net=network
	for compact in [false,true]:
		root.content_scale_size=Vector2i(568,320) if compact else Vector2i(1280,720)
		scene.touch_mode=compact
		scene.network_message({'type':'joined','team':1,'seat':1,'room':'ABC123','private':true,'members':members()})
		scene.network_message({'type':'lobby','count':3,'capacity':4,'host':false,'members':members()})
		for i in range(5):await process_frame
		var roster=scene.menu.get_node('Roster')
		assert(roster.get_node('Red/Rows/First/Name').text=='Same Name')
		assert(not 'YOU' in roster.get_node('Red/Rows/First/Detail').text)
		assert('HOST' in roster.get_node('Red/Rows/First/Detail').text)
		assert('YOU' in roster.get_node('Blue/Rows/First/Detail').text)
		assert('OPEN SLOT' in roster.get_node('Blue/Rows/Second/Detail').text)
		assert(not scene.menu.get_node('Actions/Start').visible and scene.menu.get_node('Actions/Waiting').visible)
		assert(scene.menu.size.y<=root.content_scale_size.y)
		var changed=members();changed[2].nickname='CPU';changed[2].status='open'
		scene.network_message({'type':'lobby','count':2,'capacity':4,'host':false,'members':changed})
		assert(roster.get_node('Red/Rows/Second/Name').text=='CPU')
		# 1v1 has two people, not four duplicated robot labels.
		network.sent.clear()
		scene.network_message({'type':'joined','team':1,'seat':1,'room':'auto','private':false,'members':members().slice(0,2)})
		roster=scene.menu.get_node('Roster')
		assert(not roster.get_node('Red/Rows/Second').visible)
		assert(scene.info.text=='STARTING IN 3' and network.sent.is_empty())
		if compact:
			await create_timer(3.2).timeout
			assert(network.sent==[{'type':'ready'}] and scene.mode!='online')
			scene.network_message({'type':'ready','started':true})
			assert(scene.mode=='online')
		else:
			scene.show_online()
			await create_timer(3.2).timeout
			assert(not network.sent.any(func(packet):return packet.type=='ready'))
			scene.show_title()
	print('PASS: team rosters, identity, departures, compact bounds, delayed ready and stale timer cancellation')
	scene.queue_free();await process_frame;quit()
