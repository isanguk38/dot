extends CharacterBody2D
## Stationary dojo sparring opponent: telegraphed attacks, launch, trip and death.
const MAX_HEALTH := 120
const DEFINITIONS := {"idle":4,"attack":8,"hurt":8,"knockdown":8,"death":6}
var health := MAX_HEALTH
var dead := false
var ai_enabled := true
var hits := 0
var facing := -1
var home := Vector2.ZERO
var state := "idle"
var state_time := 0.0
var down_time := 0.0
var freeze := 0.0
var flash := 0.0
var cooldown := 0.8
var attack_fired := false
var attack_count := 0
var heavy_attack := false
var sprite: AnimatedSprite2D
var body: CollisionShape2D

func _ready() -> void:
	add_to_group("targets")
	add_to_group("humans")
	home = position
	collision_layer = 2
	collision_mask = 1
	body = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(16,46)
	body.shape = box
	body.position.y = -23
	add_child(body)
	sprite = AnimatedSprite2D.new()
	sprite.offset.y = -32
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation: String in DEFINITIONS:
		frames.add_animation(animation)
		frames.set_animation_loop(animation,animation=="idle")
		frames.set_animation_speed(animation,6.0)
		var texture: Texture2D = load("res://assets/enemy/%s.png" % animation)
		for i in int(DEFINITIONS[animation]):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i*64,0,64,64)
			frames.add_frame(animation,atlas)
	sprite.sprite_frames = frames
	add_child(sprite)
	sprite.flip_h = true
	sprite.play("idle")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if freeze>0.0:
		freeze -= delta
		return
	state_time += delta
	cooldown -= delta
	flash = maxf(0,flash-delta)
	sprite.modulate = Color(1.4,1.4,1.4) if flash>0.0 else Color.WHITE
	velocity.y += 700.0*delta
	velocity.x = move_toward(velocity.x,0.0,delta*(100.0 if not is_on_floor() else 240.0))
	move_and_slide()
	if dead:
		_pose("death",mini(5,int(state_time*10.0)))
	elif state=="hurt":
		_pose("hurt",mini(3,int(state_time*18.0)))
		if state_time>0.24:
			_state("idle")
	elif state=="launched":
		_pose("hurt",4 if velocity.y < -45 else (5 if velocity.y<70 else 6))
		if is_on_floor() and state_time>0.12:
			_state("knockdown")
			down_time = 0.0
			_height(16)
	elif state=="knockdown":
		if is_on_floor() and state_time>0.10:
			down_time += delta
			_pose("knockdown",4 if down_time<0.55 else mini(7,5+int((down_time-0.55)*10.0)))
			if down_time>0.88 and _can_stand():
				_height(46)
				_state("idle")
				cooldown = 0.6
		else:
			_pose("knockdown",mini(3,int(state_time*15.0)))
	elif state=="attack":
		_pose("attack",mini(7,int(state_time*14.0)))
		if not attack_fired and state_time>=4.0/14.0:
			attack_fired = true
			_attack()
		if state_time>=8.0/14.0:
			_state("idle")
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player != null and not player.dead:
			var distance: float = player.global_position.x-global_position.x
			facing = 1 if distance>=0 else -1
			if ai_enabled and absf(distance)<56 and absf(player.global_position.y-global_position.y)<30 and cooldown<=0.0:
				_start_attack()
		if state=="idle":
			sprite.play("idle")
	sprite.flip_h = facing<0
	queue_redraw()
	if position.y>420:
		reset_target()

func _draw() -> void:
	draw_rect(Rect2(-18,-61,36,4),Color("1a1724"))
	draw_rect(Rect2(-18,-61,36.0*health/MAX_HEALTH,4),Color("ce6b67"))
	draw_line(Vector2(-18,-56),Vector2(18,-56),Color("6c4652"))

func _start_attack() -> void:
	_state("attack")
	heavy_attack = attack_count%3 == 2
	attack_count += 1
	attack_fired = false
	cooldown = 1.2

func _attack() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34,32)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 4
	query.transform = Transform2D(0.0,global_position+Vector2(facing*25.0,-27))
	for result in get_world_2d().direct_space_state.intersect_shape(query,4):
		var player: Object = result.collider
		if player.has_method("take_damage"):
			var dealt: int = player.take_damage(18 if heavy_attack else 12,global_position,heavy_attack)
			if dealt>0:
				freeze = 0.045

func can_receive_hit() -> bool:
	return not dead

func take_hit(direction: int,power: float=1.0,launcher: bool=false,aerial: bool=false,finisher: bool=false,trip: bool=false) -> void:
	if dead:
		return
	health = maxi(0,health-(14 if launcher else int(10.0*power)))
	hits += 1
	facing = -direction
	flash = 0.07
	freeze = 0.065 if launcher or finisher else 0.042
	attack_fired = true
	cooldown = 0.7
	if health<=0:
		dead = true
		_state("death")
		collision_layer = 0
		_height(14)
		velocity.x = direction*85.0
	elif trip:
		_state("knockdown")
		down_time = 0.0
		_height(16)
		velocity = Vector2(direction*75.0,-105.0)
	elif launcher:
		_state("launched")
		velocity = Vector2(direction*48.0,-325.0)
	elif aerial:
		_state("launched")
		velocity = Vector2(direction*(100.0 if finisher else 40.0),110.0 if finisher else -115.0)
	elif state=="knockdown":
		velocity.x = direction*35.0
	else:
		_state("hurt" if is_on_floor() else "launched")
		velocity.x = direction*(95.0 if finisher else 35.0)*power
		if not is_on_floor():
			velocity.y = -110.0
	queue_redraw()

func _state(value: String) -> void:
	state = value
	state_time = 0.0

func _pose(animation: String,index: int) -> void:
	sprite.animation = animation
	sprite.pause()
	sprite.frame = index

func _height(height: float) -> void:
	var box: RectangleShape2D = body.shape
	box.size.y = height
	body.position.y = -height/2.0

func _can_stand() -> bool:
	var box := RectangleShape2D.new()
	box.size = Vector2(15.5,45.5)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.collision_mask = 1
	query.transform = Transform2D(0.0,global_position+Vector2(0,-23))
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func reset_target() -> void:
	position = home
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	dead = false
	hits = 0
	freeze = 0.0
	flash = 0.0
	attack_count = 0
	cooldown = 0.8
	down_time = 0.0
	collision_layer = 2
	_height(46)
	_state("idle")
	queue_redraw()
