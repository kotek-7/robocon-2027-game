@tool
class_name ArenaTitle
extends VBoxContainer
@export var desktop_size = Vector2(540, 260)
@export var mobile_size = Vector2(370, 132)

func set_compact(value: bool):
	custom_minimum_size=mobile_size if value else desktop_size
	$Emblem.custom_minimum_size.y=28 if value else 48
