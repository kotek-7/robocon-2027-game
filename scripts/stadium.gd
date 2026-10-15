class_name ArenaStadium
extends Node3D

var clock=0.0
var balloons: Array=[]
var crowd: MultiMeshInstance3D
var crowd_poses: Array=[]
@export_group("Crowd")
@export var crowd_bounce_height = 0.055
@export var crowd_bounce_speed = 3.0
@export_group("Balloons")
@export var balloon_sway = Vector2(0.12, 0.18)
@export var balloon_speed = Vector2(0.5, 0.9)
var next_burst = 0

func _ready():
	crowd=$Crowd
	# Each instance owns its animated buffers.
	crowd.multimesh=copy_instances(crowd.multimesh)
	for i in range(crowd.multimesh.instance_count):
		crowd_poses.append(crowd.multimesh.get_instance_transform(i).origin)
	for anchor in get_children():
		if anchor.name.begins_with('Balloon'):
			balloons.append({'node':anchor,'home':anchor.position})

func copy_instances(source: MultiMesh) -> MultiMesh:
	var result=MultiMesh.new()
	result.transform_format=source.transform_format
	result.use_colors=source.use_colors
	result.mesh=source.mesh
	result.instance_count=source.instance_count
	result.visible_instance_count=source.visible_instance_count
	for i in range(source.instance_count):
		result.set_instance_transform(i,source.get_instance_transform(i))
		result.set_instance_color(i,source.get_instance_color(i))
	return result

func burst(pos: Vector3, tint: Color, count=14):
	var effects=$Effects.get_children()
	var effect: CPUParticles3D=effects[next_burst]
	next_burst=(next_burst+1)%effects.size()
	effect.global_position=pos
	effect.amount=count
	effect.color=tint
	effect.restart()
	effect.emitting=true

func _process(dt):
	clock+=dt
	for b in balloons:b.node.position=b.home+Vector3(sin(clock*balloon_speed.x+b.home.x)*balloon_sway.x,sin(clock*balloon_speed.y+b.home.z)*balloon_sway.y,0)
	for i in range(crowd_poses.size()):
		var p: Vector3=crowd_poses[i];p.y+=maxf(0,sin(clock*crowd_bounce_speed+i*.7))*crowd_bounce_height
		crowd.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,p))
