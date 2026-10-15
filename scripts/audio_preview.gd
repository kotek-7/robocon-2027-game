@tool
extends AudioStreamPlayer

@export_tool_button("Preview", "Play") var preview: Callable = audition
@export_tool_button("Stop", "Stop") var stop_preview: Callable = stop

func audition():
	if stream:play()
