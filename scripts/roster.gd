extends HBoxContainer

func configure(compact: bool):
	for side in ['Red','Blue']:
		for slot in ['First','Second']:
			get_node(side+'/Rows/'+slot+'/Identity/Name').add_theme_font_size_override('font_size',16 if compact else 22)
			get_node(side+'/Rows/'+slot+'/Detail').add_theme_font_size_override('font_size',12 if compact else 14)

func show_members(members: Array, own_seat: int):
	for side in ['Red','Blue']:
		for slot in ['First','Second']:get_node(side+'/Rows/'+slot).visible=false
	for member in members:
		var side='Red' if int(member.team)==0 else 'Blue'
		var slot='First' if int(member.seat)<2 else 'Second'
		var row=get_node(side+'/Rows/'+slot)
		row.visible=true
		row.get_node('Identity/Name').text=str(member.nickname)
		row.get_node('Identity/Self').visible=int(member.seat)==own_seat
		row.get_node('Identity/Host').visible=member.get('host',false)
		row.get_node('Detail').text=str(member.role)
		row.modulate.a=0.45 if member.status in ['open','reconnecting'] else 1.0
		row.tooltip_text='Reconnecting' if member.status=='reconnecting' else ''
