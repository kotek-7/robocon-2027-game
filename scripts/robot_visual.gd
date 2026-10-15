extends Node3D

@export_group("Movement")
@export var position_smoothing = 22.0
@export var rotation_smoothing = 15.0
@export var body_smoothing = 12.0
@export var driving_lean = 0.035
@export var driving_bob_height = 0.012
@export var driving_bob_speed = 12.0
@export_group("Climbing")
@export var ascent_lean = -0.13
@export var descent_lean = 0.10
@export var climb_bob_height = 0.035
@export var climb_bob_speed = 10.0
@export_group("Title idle")
@export var idle_bob_height = 0.035
@export var idle_bob_speed = 2.0
@onready var body: Node3D = $Body
var rest_position: Vector3
var rest_rotation: Vector3

func _ready():
	rest_position=body.position;rest_rotation=body.rotation

func update_pose(state: Dictionary, dt: float, clock: float, title: bool, phase: float):
	position=position.lerp(state.p,1-exp(-position_smoothing*dt))
	rotation.y=lerp_angle(rotation.y,state.yaw,1-exp(-rotation_smoothing*dt))
	body.rotation.x=lerpf(body.rotation.x,rest_rotation.x-state.v.length()*driving_lean,1-exp(-body_smoothing*dt))
	body.position.y=rest_position.y+sin(clock*driving_bob_speed)*driving_bob_height*state.v.length()
	if state.job.get('type','')=='climb':
		body.rotation.x=rest_rotation.x+(ascent_lean if state.job.to.y>state.job.from.y else descent_lean)
		body.position.y=rest_position.y+abs(sin(clock*climb_bob_speed))*climb_bob_height
	if title:body.position.y=rest_position.y+sin(clock*idle_bob_speed+phase)*idle_bob_height
