class_name ArenaVisuals
extends RefCounted
const RED=Color('#ed174c')
const BLUE=Color('#0078dd')
const INK=Color('#20243e')
var materials={}

func material(color: Color) -> StandardMaterial3D:
	var key=color.to_html()
	if materials.has(key): return materials[key]
	var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.72
	materials[key]=m;return m

func mesh(parent: Node3D, shape: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var n=MeshInstance3D.new();n.mesh=shape;n.material_override=material(color);n.position=pos;parent.add_child(n);return n

func box(parent: Node3D, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var b=BoxMesh.new();b.size=size;return mesh(parent,b,color,pos)

func ball(parent: Node3D, radius: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var s=SphereMesh.new();s.radius=radius;s.height=radius*2;s.radial_segments=20;s.rings=10;return mesh(parent,s,color,pos)

func capsule(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var c=CapsuleMesh.new();c.radius=radius;c.height=height;c.radial_segments=20;c.rings=6;return mesh(parent,c,color,pos)

func robot(rid: int) -> Node3D:
	var root=Node3D.new();var body=Node3D.new();root.add_child(body);body.name='Body'
	var color=RED if rid<2 else BLUE
	capsule(body,.25,.55,color,Vector3(0,.35,0))
	var face=capsule(body,.16,.34,INK,Vector3(0,.42,-.18));face.rotation.z=PI/2;face.scale.z=.42
	for x in [-.075,.075]:
		capsule(body,.027,.08,Color('#fffaf0'),Vector3(x,.44,-.253))
	for x in [-.24,.24]:
		for z in [-.15,.15]:
			var wheel=mesh(body,CylinderMesh.new(),INK,Vector3(x,.12,z));wheel.mesh.top_radius=.11;wheel.mesh.bottom_radius=.11;wheel.mesh.height=.09;wheel.rotation.z=PI/2
	if rid%2==0:
		box(body,Vector3(.48,.07,.32),color.lightened(.08),Vector3(0,.18,.3))
		for x in [-.18,.18]: capsule(body,.045,.32,color,Vector3(x,.2,-.32)).rotation.x=PI/2
	else:
		capsule(body,.055,.65,Color('#fffaf0'),Vector3(.22,.68,.08))
		capsule(body,.055,.65,Color('#fffaf0'),Vector3(-.22,.68,.08))
		box(body,Vector3(.48,.08,.18),color,Vector3(0,.91,.08))
	# Team badge: one pip for red, two for blue. Role silhouettes remain distinct.
	for j in range(1 if rid<2 else 2): ball(body,.04,Color('#fffaf0'),Vector3((j-.5)*.11,.65,0))
	return root

func object(kind: String, owner: int) -> Node3D:
	var root=Node3D.new()
	if kind=='M':
		ball(root,.105,Color('#ffda16'),Vector3.ZERO)
		var ring=TorusMesh.new();ring.inner_radius=.105;ring.outer_radius=.12;ring.rings=20;ring.ring_segments=8
		mesh(root,ring,Color('#fffaf0'),Vector3.ZERO).rotation.z=PI/4
	elif kind=='S':
		box(root,Vector3(.2,.1,.2),RED,Vector3(0,.05,0))
		box(root,Vector3(.2,.1,.2),BLUE,Vector3(0,-.05,0))
		box(root,Vector3(.12,.004,.025),Color('#fffaf0'),Vector3(0,.102,0))
	else:
		var color=RED if owner==0 else BLUE
		box(root,Vector3(.35,.35,.35),color,Vector3.ZERO)
		box(root,Vector3(.352,.045,.352),Color('#fffaf0'),Vector3(0,0,0))
	return root
