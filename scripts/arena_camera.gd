extends Camera3D

@export_group("Follow")
@export_range(1.0, 12.0) var follow_distance = 4.0
@export var target_height = 0.45
@export_range(0.1, 30.0) var target_smoothing = 12.0
@export_range(0.1, 30.0) var camera_smoothing = 8.0
@export var floor_clearance = 0.45
@export_group("Overview")
@export var overview_position = Vector3(0, 14, 6)
@export_group("Title orbit")
@export var title_target = Vector3(0, 0.2, 0)
@export var orbit_radius = 10.0
@export var orbit_height = 10.0
@export var orbit_speed = 0.025
@export var orbit_start_angle = 0.65
var follow_target = Vector3.ZERO
var clock = 0.0

func update_view(dt: float, robot_position: Vector3, field: ArenaField, title: bool, overview: bool, yaw: float, pitch: float):
	clock+=dt
	var target=robot_position+Vector3(0,target_height,0)
	var desired: Vector3
	if title:
		target=title_target
		desired=Vector3(orbit_radius*sin(orbit_start_angle+clock*orbit_speed),orbit_height,orbit_radius*cos(orbit_start_angle+clock*orbit_speed))
	elif overview:
		target=Vector3.ZERO;desired=overview_position
	else:
		follow_target=follow_target.lerp(target,1-exp(-target_smoothing*dt));target=follow_target
		desired=target+Vector3(0,sin(pitch)*follow_distance,cos(pitch)*follow_distance).rotated(Vector3.UP,yaw)
		for n in range(1,9):
			var point=target.lerp(desired,n/8.0)
			if abs(point.x)<5.4 and abs(point.z)<5.4:desired.y=max(desired.y,field.height(point)+floor_clearance)
	position=position.lerp(desired,1-exp(-camera_smoothing*dt));look_at(target)

# Keep a finite screen direction even across the camera plane.
func nameplate_position(point: Vector3) -> Vector2:
	var local=global_transform.affine_inverse()*point
	if local.z < -0.05:
		return unproject_position(point)
	var direction=Vector2(local.x,-local.y)
	if direction.length_squared()<0.0001:direction=Vector2.DOWN
	var viewport_size=get_viewport().get_visible_rect().size
	return viewport_size/2+direction.normalized()*viewport_size.length()
