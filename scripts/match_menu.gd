extends PanelContainer
@export var desktop_theme: Theme
@export var mobile_theme: Theme

func configure(compact: bool):
	theme=mobile_theme if compact else desktop_theme
	custom_minimum_size.x=minf(560 if compact else 720,get_viewport_rect().size.x-32)
	$Content.add_theme_constant_override('separation',12 if compact else 24)
	$Content/Roster.configure(compact)
	if has_node('Content/Actions/Start'):
		$Content/Actions/Start.custom_minimum_size.y=44 if compact else 52
