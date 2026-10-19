extends HBoxContainer

func configure(compact: bool):
	custom_minimum_size.x=minf(520 if compact else 600,get_viewport_rect().size.x-24)
	for side in ['Red','Blue']:
		for slot in ['First','Second']:
			get_node(side+'/Rows/'+slot+'/Name').add_theme_font_size_override('font_size',16 if compact else 22)
			get_node(side+'/Rows/'+slot+'/Detail').add_theme_font_size_override('font_size',12 if compact else 14)

func show_members(members: Array, own_seat: int):
	for side in ['Red','Blue']:
		for slot in ['First','Second']:get_node(side+'/Rows/'+slot).visible=false
	for member in members:
		var side='Red' if int(member.team)==0 else 'Blue'
		var slot='First' if int(member.seat)<2 else 'Second'
		var row=get_node(side+'/Rows/'+slot)
		row.visible=true
		row.get_node('Name').text=str(member.nickname)
		var details=[str(member.role)]
		if int(member.seat)==own_seat:details.append('YOU')
		if member.get('host',false):details.append('HOST')
		if member.status=='open':details.append('OPEN SLOT')
		elif member.status=='reconnecting':details.append('RECONNECTING')
		row.get_node('Detail').text=' · '.join(details)
