extends VBoxContainer
@export var desktop_theme: Theme
@export var mobile_theme: Theme
@export var desktop_button_height = 58.0
@export var mobile_button_height = 44.0

func configure(compact: bool):
	theme=mobile_theme if compact else desktop_theme
	for child in get_children():
		if child is Button:
			child.custom_minimum_size.y=mobile_button_height if compact else desktop_button_height
		if child is ArenaTitle:
			child.theme=theme
			child.set_compact(compact)

	if has_node('Roster'):
		$Roster.configure(compact)
	if has_node('Header/Code'):
		$Heading.visible=not compact
		$Header/Code.add_theme_font_size_override('font_size',26 if compact else 36)
		for button in [$Actions/Start,$Actions/Cancel]:
			button.custom_minimum_size.y=mobile_button_height if compact else desktop_button_height
