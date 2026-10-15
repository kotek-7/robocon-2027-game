extends SceneTree
func _initialize():
	var network=ArenaNetwork.new();network.field=ArenaField.new()
	for humans in range(1,5):
		var code=network.create_room('2v2',true)
		var room=network.rooms[code]
		for seat in range(humans):
			var id=seat+1
			room.ids[seat]=id
			network.peers[id]={'room':code,'seat':seat,'ws':WebSocketPeer.new()}
		network.handle(1,{'type':'start_room'})
		assert(room.started)
		assert(room.cpu_seats.count(true)==4-humans)
		for seat in range(humans,4):assert(room.names[(seat%2)*2+int(seat/2)]=='CPU')
		room.match.finished=true
		for id in range(1,humans+1):network.handle(id,{'type':'rematch'})
		assert(not room.match.finished and room.cpu_seats.count(true)==4-humans)
		# Leaving host transfers start authority to a remaining player.
		room.started=false
		if humans>1:
			network.handle(1,{'type':'leave'})
			assert(room.host_seat==1)
			network.handle(2,{'type':'start_room'})
			assert(room.started)
		network.rooms.erase(code);network.peers.clear()
	print('PASS: 1-4 human rooms fill CPU seats, rematch without CPU votes, transfer host')
	network.free();quit()
