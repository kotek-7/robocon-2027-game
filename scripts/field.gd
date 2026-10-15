class_name ArenaField
extends RefCounted

const STEP = 0.2
const N = 55
var raw: Dictionary
var spots: Array
var heights = PackedFloat32Array()
var solid = PackedByteArray()
var graphs: Array = []
# Entry/landing centers are on the CAD floor, outside the stair footprint.
var stairs: Array = [
	{'a':Vector3(-3.4,0,3.0),'b':Vector3(-3.4,.6,1.4),'seconds':3.0,'team':0},
	{'a':Vector3(3.4,0,3.0),'b':Vector3(3.4,.6,1.4),'seconds':3.0,'team':1},
	{'a':Vector3(-2.2,.6,0),'b':Vector3(-1.2,.9,0),'seconds':2.0,'team':0},
	{'a':Vector3(2.2,.6,0),'b':Vector3(1.2,.9,0),'seconds':2.0,'team':1},
]

func on_stairs(p: Vector3) -> bool:
	return (abs(p.x)>2.78 and abs(p.x)<4.22 and p.z>1.62 and p.z<2.92) or (abs(p.x)>1.38 and abs(p.x)<2.02 and abs(p.z)<.72)


func _init():
	raw = JSON.parse_string(FileAccess.get_file_as_string('res://assets/field.json'))
	spots = JSON.parse_string(FileAccess.get_file_as_string('res://assets/spots.json'))
	for spot in spots:
		spot[3]=int(spot[3]);spot[4]=int(spot[4])
	heights.resize(N*N)
	heights.fill(-10.0)
	solid.resize(N*N)
	var mesh = raw.meshes[0]
	var p = mesh.positions
	var indices = mesh.indices
	for face in mesh.faces:
		var col = face.color
		var obstacle = col[0] < 0.2 and col[1] < 0.1 and col[2] < 0.1
		for t in range(int(face.first), int(face.last)+1):
			var a = vec(p,indices[t*3]); var b = vec(p,indices[t*3+1]); var c = vec(p,indices[t*3+2])
			var det = (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
			if abs(det)<0.00001: continue
			var x0 = clampi(int(floor((min(a.x,min(b.x,c.x))+5.4)/STEP)),0,N-1)
			var x1 = clampi(int(ceil((max(a.x,max(b.x,c.x))+5.4)/STEP)),0,N-1)
			var z0 = clampi(int(floor((min(a.z,min(b.z,c.z))+5.4)/STEP)),0,N-1)
			var z1 = clampi(int(ceil((max(a.z,max(b.z,c.z))+5.4)/STEP)),0,N-1)
			for z in range(z0,z1+1):
				for x in range(x0,x1+1):
					var px = -5.4+x*STEP; var pz = -5.4+z*STEP
					var u = ((b.z-c.z)*(px-c.x)+(c.x-b.x)*(pz-c.z))/det
					var v = ((c.z-a.z)*(px-c.x)+(a.x-c.x)*(pz-c.z))/det
					if u < -0.001 or v < -0.001 or u+v>1.001: continue
					var y = u*a.y+v*b.y+(1-u-v)*c.y
					var k = z*N+x
					if y >= heights[k]-0.001:
						heights[k] = y
						solid[k] = 1 if obstacle else 0
	for rid in range(4):
		var g = AStar3D.new()
		for k in range(N*N):
			var q = grid_pos(k)
			if can_move(q,q,rid): g.add_point(k,q)
		for k in g.get_point_ids():
			for offset in [1,N]:
				var j = k+offset
				if j>=N*N or (offset==1 and k/N != j/N): continue
				if g.has_point(j) and abs(heights[k]-heights[j])<=0.17: g.connect_points(k,j)
		for i in range(stairs.size()):
			var stair=stairs[i]
			if stair.team!=int(rid/2) or (rid%2==0 and i>=2):continue
			var a=cell(stair.a);var b=cell(stair.b)
			if g.has_point(a) and g.has_point(b):g.connect_points(a,b,i>=2 or rid%2==0)
		graphs.append(g)

static func vec(p: Array, i: int) -> Vector3:
	return Vector3(p[i*3],p[i*3+1],p[i*3+2])

func cell(p: Vector3) -> int:
	return clampi(roundi((p.z+5.4)/STEP),0,N-1)*N+clampi(roundi((p.x+5.4)/STEP),0,N-1)

func grid_pos(k: int) -> Vector3:
	return Vector3(-5.4+(k%N)*STEP,heights[k],-5.4+int(k/N)*STEP)

func height(p: Vector3) -> float:
	return heights[cell(p)]

func valid(p: Vector3, rid: int) -> bool:
	if abs(p.x)>5.2 or abs(p.z)>5.2: return false
	var k = cell(p)
	if solid[k] or heights[k]<-0.01 or heights[k]>0.92: return false
	var y = heights[k]
	var team = int(rid/2)
	var own = p.x<0 if team==0 else p.x>0
	var shared = (abs(p.x)<0.5 and (p.z>4.05 or (p.z<-3.4 and p.z>-4.35))) if y<0.1 else (y>0.85 or abs(p.z)>2.52)
	if not own and not shared: return false
	if rid%2==0 and y>0.55 and (abs(p.x)<3.0 or abs(p.x)>4.0 or p.z>1.8): return false
	if abs(p.x)<0.25 and not shared: return false
	return true

func can_move(a: Vector3, b: Vector3, rid: int) -> bool:
	if on_stairs(b) or not valid(b,rid) or abs(height(b)-height(a))>0.17: return false
	for v in [Vector3(.21,0,0),Vector3(-.21,0,0),Vector3(0,0,.21),Vector3(0,0,-.21)]:
		if not valid(b+v,rid) or height(b+v)-height(b)>0.17: return false
	return true

func route(from: Vector3, to: Vector3, rid: int) -> PackedVector3Array:
	var g: AStar3D = graphs[rid]
	if g.get_point_count()==0: return PackedVector3Array()
	return g.get_point_path(g.get_closest_point(from),g.get_closest_point(to))

func transfer(team: int) -> Vector3:
	return Vector3(-3.5 if team==0 else 3.5,0.6,1.3)

func spot_pos(i: int) -> Vector3:
	return Vector3(spots[i][0],spots[i][1],spots[i][2])
