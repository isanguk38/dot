extends CharacterBody2D
## Launchable practice target. Collides with terrain, not with the player.
const SIZE := Vector2(18,38)
var home := Vector2.ZERO
var hits := 0
var freeze := 0.0
var stun := 0.0
var flash := 0.0
var rect: ColorRect
var label: Label

func _ready() -> void:
	add_to_group("targets")
	home = position
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = SIZE
	shape.shape = box
	shape.position = Vector2(0,-SIZE.y/2)
	add_child(shape)
	rect = ColorRect.new()
	rect.position = Vector2(-SIZE.x/2,-SIZE.y)
	rect.size = SIZE
	rect.color = Color("ce7a43")
	add_child(rect)
	var stripe := ColorRect.new()
	stripe.position = Vector2(2,12)
	stripe.size = Vector2(14,3)
	stripe.color = Color("6c3f32")
	rect.add_child(stripe)
	label = Label.new()
	label.position = Vector2(-14,-52)
	label.add_theme_font_size_override("font_size",10)
	add_child(label)

func _physics_process(delta: float) -> void:
	if freeze > 0.0:
		freeze -= delta
		return
	flash = maxf(0,flash-delta)
	stun = maxf(0,stun-delta)
	rect.color = Color.WHITE if flash>0 else Color("ce7a43")
	velocity.y += 700.0*delta
	velocity.x = move_toward(velocity.x,0.0,delta*(100.0 if not is_on_floor() else 260.0))
	move_and_slide()
	label.text = "%d HIT" % hits if hits>0 else ""
	if position.y>420:
		reset_target()

func take_hit(direction: int,power: float=1.0,launcher: bool=false,aerial: bool=false,finisher: bool=false,_trip: bool=false) -> void:
	hits += 1
	freeze = 0.065 if launcher or finisher else 0.042
	flash = 0.10
	stun = 0.65
	if launcher:
		velocity = Vector2(direction*48.0,-325.0)
	elif aerial:
		velocity = Vector2(direction*(100.0 if finisher else 40.0),-115.0 if not finisher else 110.0)
	else:
		velocity.x = direction*(95.0 if finisher else 35.0)*power
		if not is_on_floor():
			velocity.y = -110.0

func reset_target() -> void:
	position = home
	velocity = Vector2.ZERO
	hits = 0
	freeze = 0.0
	flash = 0.0
