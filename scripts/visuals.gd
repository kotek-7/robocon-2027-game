class_name ArenaVisuals
extends RefCounted
const RED=Color('#ed174c')
const BLUE=Color('#0078dd')
const INK=Color('#20243e')
func sky_rotation(o: Dictionary) -> Vector3:
	if o.face>=0:return Vector3(0,0,PI if o.face==1 else 0)
	match o.get('sky_axis','N'):
		'N':return Vector3(-PI/2,0,0)
		'S':return Vector3(PI/2,0,0)
		'E':return Vector3(0,0,-PI/2)
		'W':return Vector3(0,0,PI/2)
	return Vector3.ZERO
