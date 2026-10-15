extends Node3D

@export var position_smoothing = 20.0
@export var rotation_smoothing = 12.0
@export var pulse_scale = Vector3(1.14, 0.86, 1.14)
@export var pulse_recovery = 12.0
var rest_scale: Vector3

func _ready():
	rest_scale=scale

func update_pose(target: Vector3, orientation: Vector3, rotate_object: bool, pulse: bool, dt: float):
	position=position.lerp(target,1-exp(-position_smoothing*dt))
	if rotate_object:quaternion=quaternion.slerp(Quaternion.from_euler(orientation),1-exp(-rotation_smoothing*dt))
	if pulse:scale=rest_scale*pulse_scale
	scale=scale.lerp(rest_scale,1-exp(-pulse_recovery*dt))
