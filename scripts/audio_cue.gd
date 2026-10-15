@tool
extends "res://scripts/audio_preview.gd"

## Event identifier used by match/UI logic. Keep this stable when renaming the node.
@export var event: StringName
## Disable this event without deleting its configuration.
@export var enabled = true
