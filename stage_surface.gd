extends Node2D
## Pixel-aligned stone paving and cedar beams; shares terrain collision dimensions.
var size := Vector2.ZERO
var kind := "stone"

func _draw() -> void:
	if kind=="stone":
		draw_rect(Rect2(Vector2.ZERO,size),Color("24292e"))
		for row in range(0,int(size.y),12):
			for col in range(-24,int(size.x)+24,24):
				var shift := 12 if (row/12)%2 else 0
				var left := maxf(0,col+shift)
				var right := minf(size.x,col+shift+23)
				if right<=left:
					continue
				var color := Color("39434a") if (col/24+row/12)%3 else Color("323d43")
				draw_rect(Rect2(left,row+1,right-left,10),color)
				draw_line(Vector2(left+1,row+1),Vector2(right-1,row+1),Color("536066"))
		draw_rect(Rect2(0,0,size.x,2),Color("77817b"))
		for x in range(4,int(size.x),31):
			draw_rect(Rect2(x,2,7,2),Color("3d6456"))
	else:
		draw_rect(Rect2(Vector2.ZERO,size),Color("2c2224"))
		draw_rect(Rect2(0,2,size.x,maxf(1,size.y-4)),Color("54403a"))
		for x in range(0,int(size.x),16):
			draw_line(Vector2(x,2),Vector2(x,size.y-2),Color("2a2024"))
			draw_rect(Rect2(x+3,4,8,1),Color("6a5040"))
			draw_rect(Rect2(x+1,2,1,1),Color("9a8060"))
		draw_rect(Rect2(0,0,size.x,2),Color("8a7560"))
		if kind=="roof":
			for x in range(-4,int(size.x),12):
				draw_rect(Rect2(maxi(0,x),-5,mini(11,int(size.x)-maxi(0,x)),5),Color("263440"))
				draw_line(Vector2(maxi(0,x),-5),Vector2(minf(size.x,x+10),-5),Color("53616b"))
