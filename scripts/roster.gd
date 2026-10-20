extends HBoxContainer

func configure(compact: bool):
	for side in ['Red','Blue']:
		var surface=get_node(side).get_theme_stylebox('panel').duplicate()
		for edge in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:surface.set_content_margin(edge,16 if compact else 24)
		get_node(side).add_theme_stylebox_override('panel',surface)
	for side in ['Red','Blue']:
		for slot in ['First','Second']:
			get_node(side+'/Rows/'+slot+'/Identity/Name').add_theme_font_size_override('font_size',20 if compact else 28)

func show_members(members: Array, own_seat: int):
	for member in members:
		if int(member.seat)==own_seat:
			move_child(get_node('Red' if int(member.team)==0 else 'Blue'),0)
			break
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
		row.modulate.a=0.45 if member.status in ['open','reconnecting'] else 1.0
		row.tooltip_text='Reconnecting' if member.status=='reconnecting' else ''
