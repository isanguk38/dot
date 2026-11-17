extends Node2D
## Mirrored rising crescent rooted on the ground under the casting player's feet.
var direction := 1
var cast_origin := Vector2.ZERO
var age := 0.0
var sprite: Sprite2D

func _ready() -> void:
	add_to_group("combat_fx")
	name = "UppercutEffect"
	position = cast_origin+Vector2(direction*4.0,0)
	z_index = 20
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/fx/uppercut.png")
	sprite.hframes = 8
	# Reverse the reviewed arc for a right-facing cast; mirror with player facing.
	sprite.flip_h = direction>0
	sprite.offset.y = -26.0
	sprite.scale = Vector2(2,2)
	add_child(sprite)

func _process(delta: float) -> void:
	age += delta
	position.x = cast_origin.x+direction*(4.0+age*24.0)
	position.y = cast_origin.y-age*60.0
	sprite.frame = mini(7,int(age*24.0))
	if age>=8.0/24.0:
		queue_free()
