@tool
extends AudioStreamPlayer

@export_tool_button("試聴", "Play") var preview: Callable = audition
@export_tool_button("停止", "Stop") var stop_preview: Callable = stop

func audition():
	if stream:play()
