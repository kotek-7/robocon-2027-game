@tool
extends PanelContainer

## An uneven rounded balloon with the same soft shadow palette as the HUD.
@export var fill_color=Color('#fffaf0'):
	set(value):
		fill_color=value;queue_redraw()
@export var shadow_color=Color(0.17,0.1,0.3,0.16):
	set(value):
		shadow_color=value;queue_redraw()
@export var shadow_offset=Vector2(0,4):
	set(value):
		shadow_offset=value;queue_redraw()

func _ready():
	resized.connect(queue_redraw)

func _draw():
	var w=size.x;var h=size.y
	if w<1 or h<1:return
	# Keep the slanted edges outside the text's margins. The tail is part of
	# the same outline, so no horizontal seam crosses its white interior.
	var corners=PackedVector2Array([
		Vector2(1,h*.36),Vector2(w*.23,1),Vector2(w*.82,3),
		Vector2(w-1,h*.43),Vector2(w-6,h-2),
		Vector2(w*.59,h-3),Vector2(w*.51,h+5),Vector2(w*.45,h-3),
		Vector2(8,h-3),Vector2(4,h*.7)
	])
	# Small softened corners echo the HUD panels without losing the uneven shape.
	var points=PackedVector2Array()
	for i in range(corners.size()):
		var corner=corners[i]
		var before=corner.move_toward(corners[posmod(i-1,corners.size())],minf(4.0,corner.distance_to(corners[posmod(i-1,corners.size())])*.4))
		var after=corner.move_toward(corners[(i+1)%corners.size()],minf(4.0,corner.distance_to(corners[(i+1)%corners.size()])*.4))
		for step in range(5):
			var t=step/4.0
			points.append(before.lerp(corner,t).lerp(corner.lerp(after,t),t))
	# Sample a small blur kernel instead of a hard duplicate silhouette.
	var weights=[1.0,4.0,6.0,4.0,1.0]
	for y in range(5):
		for x in range(5):
			var shadow=PackedVector2Array()
			var offset=shadow_offset+Vector2(x-2,y-2)*2.0
			for point in points:shadow.append(point+offset)
			var tint=shadow_color
			tint.a*=weights[x]*weights[y]/256.0
			draw_colored_polygon(shadow,tint)
	draw_colored_polygon(points,fill_color)
