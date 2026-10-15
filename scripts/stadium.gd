class_name ArenaStadium
extends Node3D

var art=ArenaVisuals.new()
var clock=0.0
var balloons: Array=[]
var crowd: MultiMeshInstance3D
var crowd_poses: Array=[]
var confetti: MultiMeshInstance3D
var sparks: Array=[]
var random=RandomNumberGenerator.new()
var palette=[Color('#ffda16'),Color('#ed174c'),Color('#0078dd'),Color('#20db93'),Color('#9b4dff')]
var batch=SurfaceTool.new()

func block(size: Vector3, color: Color, pos: Vector3):
	var mesh=BoxMesh.new();mesh.size=size
	var arrays=mesh.surface_get_arrays(0)
	var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		batch.set_color(color);batch.set_normal(normals[index]);batch.add_vertex(vertices[index]+pos)

func instances(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var node=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new()
	node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_colors=true
	node.multimesh.mesh=mesh;node.multimesh.instance_count=count
	var material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=.85
	node.material_override=material;add_child(node);return node

func _ready():
	random.seed=2027
	batch.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Everything outside the official floor is visual scenery, with no collision.
	block(Vector3(17,.5,17),Color('#35206f'),Vector3(0,-.64,0))
	for side in [-1,1]:
		for row in range(3):
			var extent=6.15+row*.65;var y=-.15+row*.32
			block(Vector3(12,.32,.6),palette[(row+2)%5],Vector3(0,y,side*extent))
			block(Vector3(.6,.32,12),palette[(row+2)%5],Vector3(side*extent,y,0))
		for k in range(20):
			var x=-5.7+k*.6
			block(Vector3(.5,.16,.16),palette[k%5],Vector3(x,.13,side*5.7))
			block(Vector3(.16,.16,.5),palette[k%5],Vector3(side*5.7,.13,x))
	# Thin tread nosings sit on the CAD surfaces; they do not change stair geometry.
	for side in [-1,1]:
		for i in range(4):
			block(Vector3(.97,.009,.035),Color('#fffaf0'),Vector3(side*3.5,.15*(i+1)+.009,2.685-i*.3))
		for i in range(2):
			block(Vector3(.035,.009,.97),Color('#fffaf0'),Vector3(side*(1.785-i*.3),.75+i*.15+.009,0))
		# Level edges and their vertical faces remain aligned with the CAD.
		block(Vector3(.035,.012,.96),Color('#fffaf0'),Vector3(side*1.48,.912,1.0))
		block(Vector3(.035,.012,.96),Color('#fffaf0'),Vector3(side*1.48,.912,-1.0))
	var scenery=MeshInstance3D.new();scenery.mesh=batch.commit()
	var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.85
	scenery.material_override=mat;add_child(scenery)
	var capsule=CapsuleMesh.new();capsule.radius=.11;capsule.height=.32;capsule.radial_segments=8;capsule.rings=3
	crowd=instances(capsule,160)
	for i in range(160):
		var side=i/40;var row=(i%40)/20;var along=-5.5+(i%20)*.58
		var p=Vector3(along,.32+row*.32,6.15+row*.65)
		if side==1:p.z=-p.z
		elif side==2:p=Vector3(p.z,p.y,along)
		elif side==3:p=Vector3(-p.z,p.y,along)
		crowd_poses.append(p);crowd.multimesh.set_instance_color(i,palette[i%5])
	for i in range(8):
		var anchor=Node3D.new();add_child(anchor)
		var angle=TAU*i/8+.2;anchor.position=Vector3(sin(angle)*10,3.5+(i%3)*.6,cos(angle)*10)
		var balloon=art.ball(anchor,.6,palette[i%5],Vector3.ZERO);balloon.scale=Vector3(.8,1.2,.8)
		balloon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.capsule(anchor,.015,1.5,Color('#fffaf0'),Vector3(0,-1.45,0))
		balloons.append({'node':anchor,'home':anchor.position})
	# Inflated arches frame the venue without occupying the robot's camera space.
	for z in [-9.0,9.0]:
		var ring=TorusMesh.new();ring.inner_radius=2.6;ring.outer_radius=2.95;ring.rings=32;ring.ring_segments=8
		art.mesh(self,ring,Color('#ffda16'),Vector3(0,1.2,z)).rotation.x=PI/2
	var cube=BoxMesh.new();cube.size=Vector3(.045,.018,.08)
	confetti=instances(cube,80);confetti.multimesh.visible_instance_count=0

func burst(pos: Vector3, color: Color, count=14):
	for i in range(mini(count,80-sparks.size())):
		sparks.append({'p':pos,'v':Vector3(random.randf_range(-1,1),random.randf_range(1.2,2.5),random.randf_range(-1,1)), 'age':0.0,'color':color if i%3 else Color('#ffda16'),'spin':random.randf_range(-5,5)})

func _process(dt):
	clock+=dt
	for b in balloons:b.node.position=b.home+Vector3(sin(clock*.5+b.home.x)*.12,sin(clock*.9+b.home.z)*.18,0)
	for i in range(crowd_poses.size()):
		var p: Vector3=crowd_poses[i];p.y+=maxf(0,sin(clock*3+i*.7))*.055
		crowd.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,p))
	for i in range(sparks.size()-1,-1,-1):
		var s=sparks[i];s.age+=dt;s.v.y-=3.5*dt;s.p+=s.v*dt
		if s.age>1.1:sparks.remove_at(i)
	confetti.multimesh.visible_instance_count=sparks.size()
	for i in range(sparks.size()):
		var s=sparks[i];var basis=Basis.from_euler(Vector3(s.age*s.spin,s.age*2,0)).scaled(Vector3.ONE*(1-s.age/1.4))
		confetti.multimesh.set_instance_transform(i,Transform3D(basis,s.p));confetti.multimesh.set_instance_color(i,s.color)
