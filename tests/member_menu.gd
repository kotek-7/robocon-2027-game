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
		var roster=scene.menu.get_node('Content/Roster')
		assert(roster.get_node('Red/Rows/First/Identity/Name').text=='Same Name')
		assert(not roster.get_node('Red/Rows/First/Identity/Self').visible)
		assert(roster.get_node('Red/Rows/First/Identity/Host').visible)
		assert(roster.get_node('Blue/Rows/First/Identity/Self').visible)
		assert(roster.get_node('Blue/Rows/Second').modulate.a<0.5)
		assert(not scene.menu.get_node('Content/Actions/Start').visible)
		assert(scene.menu.get_node('Content/Actions/Waiting').visible)
		scene.network_message({'type':'lobby','count':3,'capacity':4,'host':true,'members':members()})
		assert(scene.menu.get_node('Content/Actions/Start').visible and not scene.menu.get_node('Content/Actions/Start').disabled)
		assert(not scene.menu.get_node('Content/Actions/Waiting').visible)
		assert(scene.menu.size.y<=root.content_scale_size.y)
		assert(scene.menu.size.x<=root.content_scale_size.x)
		var changed=members();changed[2].nickname='CPU';changed[2].status='open'
		scene.network_message({'type':'lobby','count':2,'capacity':4,'host':false,'members':changed})
		assert(roster.get_node('Red/Rows/Second/Identity/Name').text=='CPU')
		# 1v1 has two people, not four duplicated robot labels.
		network.sent.clear()
		scene.network_message({'type':'joined','team':1,'seat':1,'room':'auto','private':false,'members':members().slice(0,2)})
		roster=scene.menu.get_node('Content/Roster')
		assert(not roster.get_node('Red/Rows/Second').visible)
		assert(scene.info.text=='3' and network.sent.is_empty())
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
