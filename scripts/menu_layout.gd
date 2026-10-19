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
