class_name ArenaTitle
extends Control
var compact=false
var font: Font
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=load('res://assets/Fredoka-Semibold.ttf');resized.connect(queue_redraw)
func line_at(label: String, y: float, font_size: int, color: Color, outline=5):
	var x=(size.x-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)/2
	var pos=Vector2(x,y)
	draw_string_outline(font,pos+Vector2(0,4),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,outline+2,Color('#4b20a5'))
	draw_string_outline(font,pos,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,outline,Color('#20243e'))
	draw_string(font,pos,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _draw():
	if not font:return
	var scale_factor=.7 if compact else 1.25
	draw_set_transform(Vector2(size.x/2,0),0,Vector2.ONE*scale_factor)
	# A gold Mustika with orbital bands crowns the competition lettering.
	draw_circle(Vector2(0,20),15,Color('#20243e'));draw_circle(Vector2(0,18),12,Color('#ffda16'))
	draw_arc(Vector2(0,18),23,-.3,PI+.3,32,Color('#fffaf0'),3,true)
	for side in [-1,1]:
		draw_polyline(PackedVector2Array([Vector2(side*36,16),Vector2(side*43,7),Vector2(side*45,20)]),Color('#ffda16'),3,true)
	draw_set_transform(Vector2.ZERO)
	line_at('Robocon 2027',85*scale_factor,42 if compact else 80,Color('#fffaf0'),3 if compact else 6)
	line_at('The Pursuit of',119*scale_factor,20 if compact else 34,Color('#12bfe7'),2 if compact else 4)
	line_at('Mustika Nusantara',165*scale_factor,34 if compact else 58,Color('#ffda16'),3 if compact else 5)
