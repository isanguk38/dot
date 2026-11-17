extends CharacterBody2D
## Movement, buffered combat, guarding and damage reactions.
signal hit_landed(point: Vector2, launcher: bool, finisher: bool)
signal uppercut_cast(direction: int)

const SPEED := 150.0
const CROUCH_SPEED := 65.0
const STAND_HEIGHT := 46.0
const CROUCH_HEIGHT := 30.0
const ACCEL := 1600.0
const GRAVITY := 880.0
const JUMP_SPEED := -330.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const FRAME_SIZE := 64
const COMBO_WINDOW := 0.30
const ANIMS := {
	"idle": {"file":"idle", "fps":6.0, "frames":[0,1,2,3], "loop":true},
	"run": {"file":"run", "fps":16.0, "frames":[0,1,2,3,4,5,6,7], "loop":true},
	"jump": {"file":"jump", "fps":12.0, "frames":[0,1,2,3,4,5,6,7], "loop":false},
	"double_jump": {"file":"double_jump", "fps":22.0, "frames":[0,1,2,3,4,5,6,7], "loop":false},
	"jab": {"file":"jab", "fps":24.0, "frames":[1,2,3,5,7], "loop":false},
	"kick": {"file":"kick", "fps":22.0, "frames":[1,2,3,4,5,6,7], "loop":false},
	"uppercut": {"file":"uppercut", "fps":22.0, "frames":[1,2,3,4,5,6,7], "loop":false},
	"backstep": {"file":"backstep", "fps":24.0, "frames":[1,2,3,4,5,6,7], "loop":false},
	"air_1": {"file":"air_combo", "fps":22.0, "frames":[0,1,2,2,3], "loop":false},
	"air_2": {"file":"air_combo", "fps":22.0, "frames":[3,4,4,5], "loop":false},
	"air_3": {"file":"air_combo", "fps":20.0, "frames":[5,6,6,7], "loop":false},
	"crouch_idle": {"file":"crouch_idle", "fps":6.0, "frames":[0,1,2,3], "loop":true},
	"crouch_walk": {"file":"crouch_walk", "fps":10.0, "frames":[0,1,2,3,4,5,6,7], "loop":true},
	"crouch_jab": {"file":"crouch_combo", "fps":20.0, "frames":[0,1,2,3], "loop":false},
	"crouch_kick": {"file":"crouch_combo", "fps":18.0, "frames":[4,5,6,7], "loop":false},
	"guard": {"file":"guard", "fps":10.0, "frames":[0,1,2,3], "loop":false},
	"hurt": {"file":"hurt", "fps":22.0, "frames":[0,1,2,3,4,5], "loop":false},
	"death": {"file":"death", "fps":10.0, "frames":[0,1,2,3,4,5], "loop":false},
	"knockdown": {"file":"knockdown", "fps":12.0, "frames":[0,1,2,3,4,5,6,7], "loop":false},
}
const GROUND := ["jab","jab","kick"]
const AIR := ["air_1","air_2","air_3"]
const ACTIVE_FRAME := {"jab":1,"kick":2,"uppercut":3,"air_1":2,"air_2":1,"air_3":1,"crouch_jab":2,"crouch_kick":1}
const MAX_HEALTH := 100
const GUARD_DAMAGE_FACTOR := 0.30

@onready var sprite: AnimatedSprite2D = $Sprite
var facing := 1
var action := ""
var action_time := 0.0
var freeze := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var backstep_buffer := 0.0
var uppercut_buffer := 0.0
var low_kick_buffer := 0.0
var crouching := false
var queued_attack := false
var ground_step := -1
var air_step := -1
var combo_timer := 0.0
var air_jumps := 1
var hit_fired := false
var connected := false
var flip_time := 0.0
var hit_count := 0
var health := MAX_HEALTH
var dead := false
var guarding := false
var guard_recoil := 0.0
var invulnerable := 0.0
var reaction := ""
var reaction_time := 0.0
var down_time := 0.0
var last_damage := 0
var last_hit_guarded := false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	$Collision.shape = $Collision.shape.duplicate()
	_setup_input()
	sprite.sprite_frames = _build_frames()
	$Hitbox.monitoring = false
	add_to_group("player")
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	invulnerable = maxf(0,invulnerable-delta)
	guard_recoil = maxf(0,guard_recoil-delta)
	if not dead and reaction.is_empty():
		_poll_input()
	# Read inputs even during hitstop, so the next strike can be buffered.
	if freeze > 0.0:
		freeze -= delta
		return
	if dead or not reaction.is_empty():
		_update_reaction(delta)
		return
	jump_buffer -= delta
	backstep_buffer -= delta
	uppercut_buffer -= delta
	low_kick_buffer -= delta
	combo_timer -= delta
	if combo_timer <= 0.0 and action.is_empty():
		ground_step = -1
	if is_on_floor():
		coyote = COYOTE_TIME
		air_jumps = 1
		if action.is_empty():
			air_step = -1
	else:
		coyote -= delta
		velocity.y += GRAVITY * delta
	_update_crouch()
	var can_cancel := action.is_empty() or (hit_fired and action_time > _active_time() + 0.045)
	guarding = Input.is_action_pressed("guard") and is_on_floor() and can_cancel
	if guarding:
		_clear_action()
		jump_buffer = 0.0
		uppercut_buffer = 0.0
		low_kick_buffer = 0.0
		backstep_buffer = 0.0
	if backstep_buffer > 0.0 and is_on_floor() and can_cancel:
		if _can_stand():
			_start_backstep()
		else:
			backstep_buffer = 0.0
	elif low_kick_buffer > 0.0 and is_on_floor() and can_cancel:
		_set_crouching(true)
		_start_action("crouch_kick")
		low_kick_buffer = 0.0
	elif uppercut_buffer > 0.0 and is_on_floor() and can_cancel and _can_stand():
		_set_crouching(false)
		_start_action("uppercut")
		uppercut_buffer = 0.0
	elif jump_buffer > 0.0 and can_cancel:
		if coyote > 0.0 and _can_stand():
			_set_crouching(false)
			_clear_action()
			velocity.y = JUMP_SPEED
			jump_buffer = 0.0
			coyote = 0.0
		elif not is_on_floor() and air_jumps > 0 and _can_stand():
			_set_crouching(false)
			_clear_action()
			air_jumps -= 1
			velocity.y = -285.0
			jump_buffer = 0.0
			flip_time = 8.0 / 22.0
	if queued_attack and action.is_empty():
		_start_chain()
	var direction := Input.get_axis("move_left","move_right")
	if action == "backstep":
		velocity.x = -facing * 210.0
	elif not action.is_empty():
		velocity.x = move_toward(velocity.x, 0.0, delta * 480.0)
	else:
		var move_speed := 35.0 if guarding else (CROUCH_SPEED if crouching else SPEED)
		velocity.x = move_toward(velocity.x, direction * move_speed, ACCEL * delta)
		if direction != 0.0:
			facing = 1 if direction > 0 else -1
	if not action.is_empty():
		_update_action(delta)
	move_and_slide()
	if is_on_floor() and action.begins_with("air_"):
		_clear_action()
	if action.is_empty():
		_update_locomotion(delta)
	sprite.flip_h = facing < 0
	# Geometry already contains forward lean. No sprite skew or nonuniform scaling.
	sprite.skew = 0.0

func _poll_input() -> void:
	if Input.is_action_pressed("guard") and is_on_floor():
		queued_attack = false
		return
	if Input.is_action_just_pressed("attack"):
		queued_attack = true
	if Input.is_action_just_pressed("uppercut"):
		if Input.is_action_pressed("down"):
			low_kick_buffer = 0.20
		else:
			uppercut_buffer = 0.20
	if Input.is_action_just_pressed("jump"):
		if Input.is_action_pressed("down"):
			backstep_buffer = 0.15
		else:
			jump_buffer = JUMP_BUFFER
	if Input.is_action_just_released("jump") and velocity.y < -80.0 and action.is_empty() and flip_time <= 0:
		velocity.y *= 0.65

func _start_chain() -> void:
	queued_attack = false
	flip_time = 0.0
	if is_on_floor():
		if crouching:
			ground_step = -1
			_start_action("crouch_jab")
			return
		ground_step = (ground_step + 1) % 3
		_start_action(GROUND[ground_step])
	else:
		if air_step >= 2:
			return
		air_step += 1
		_start_action(AIR[air_step])
		velocity.y = minf(velocity.y, -80.0)

func _start_action(name: String) -> void:
	action = name
	action_time = 0.0
	hit_fired = false
	connected = false
	flip_time = 0.0
	_set_pose(name,0)
	if name.begins_with("crouch_"):
		velocity.x = 0.0
	elif is_on_floor() and name != "uppercut":
		velocity.x = facing * (100.0 if name == "kick" else 65.0)

func _start_backstep() -> void:
	_set_crouching(false)
	queued_attack = false
	backstep_buffer = 0.0
	jump_buffer = 0.0
	ground_step = -1
	_start_action("backstep")
	velocity = Vector2(-facing * 210.0,-145.0)
	coyote = 0.0

func _active_time() -> float:
	if not ACTIVE_FRAME.has(action):
		return 1000.0
	return float(ACTIVE_FRAME[action]) / float(ANIMS[action].fps)

func _update_action(delta: float) -> void:
	action_time += delta
	var definition: Dictionary = ANIMS[action]
	var count: int = definition.frames.size()
	var frame := mini(int(action_time * float(definition.fps)),count-1)
	_set_pose(action,frame)
	if ACTIVE_FRAME.has(action) and not hit_fired and action_time >= _active_time():
		hit_fired = true
		_perform_hit()
	if action_time >= count / float(definition.fps):
		if action == "backstep" and not is_on_floor():
			return
		var finished := action
		action = ""
		combo_timer = COMBO_WINDOW
		if finished == "kick" or finished.begins_with("crouch_"):
			ground_step = -1
		if queued_attack and finished != "backstep":
			_start_chain()

func _perform_hit() -> void:
	var launcher := action == "uppercut"
	if launcher:
		uppercut_cast.emit(facing)
	var aerial := action.begins_with("air_")
	var low := action.begins_with("crouch_")
	var finisher := action == "kick" or action == "air_3" or action == "crouch_kick"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(38,54) if launcher else (Vector2(38,22) if low else Vector2(38,34))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 2
	var hit_height := -10.0 if action == "crouch_kick" else (-20.0 if low else -29.0)
	query.transform = Transform2D(0.0,global_position + Vector2(facing*25.0,hit_height))
	var results := get_world_2d().direct_space_state.intersect_shape(query,16)
	for result in results:
		var target: Object = result.collider
		if target.has_method("take_hit"):
			if target.has_method("can_receive_hit") and not target.can_receive_hit():
				continue
			target.take_hit(facing,2.0 if finisher else 1.0,launcher,aerial,finisher,action == "crouch_kick")
			connected = true
			hit_count += 1
			hit_landed.emit(target.global_position+Vector2(0,-24),launcher,finisher)
	if connected:
		freeze = 0.065 if launcher or finisher else 0.042
		if launcher:
			velocity.y = -300.0
			velocity.x = facing * 70.0
			air_step = -1
		elif aerial:
			velocity.y = -85.0 if not finisher else -30.0
			velocity.x = facing * 48.0

func _clear_action() -> void:
	action = ""
	hit_fired = false
	queued_attack = false
	flip_time = 0.0

func reset_state() -> void:
	_clear_action()
	freeze = 0.0
	jump_buffer = 0.0
	backstep_buffer = 0.0
	uppercut_buffer = 0.0
	low_kick_buffer = 0.0
	_set_crouching(false)
	ground_step = -1
	air_step = -1
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	dead = false
	guarding = false
	reaction = ""
	reaction_time = 0.0
	down_time = 0.0
	invulnerable = 0.0
	guard_recoil = 0.0
	collision_layer = 4
	sprite.modulate = Color.WHITE
	for child in get_children():
		if child.is_in_group("combat_fx"):
			child.queue_free()

func _update_locomotion(delta: float) -> void:
	if is_on_floor():
		flip_time = 0.0
		if guarding:
			_set_pose("crouch_idle" if crouching else "guard",0 if crouching else (2 if guard_recoil>0 else 1))
		elif crouching:
			sprite.speed_scale = clampf(absf(velocity.x)/CROUCH_SPEED,0.6,1.2) if absf(velocity.x)>10 else 1.0
			sprite.play("crouch_walk" if absf(velocity.x)>10 else "crouch_idle")
		elif absf(velocity.x)>10:
			sprite.play("run")
			sprite.speed_scale = clampf(absf(velocity.x)/SPEED,0.6,1.2)
		else:
			sprite.speed_scale = 1.0
			sprite.play("idle")
	elif flip_time > 0.0:
		flip_time -= delta
		_set_pose("double_jump",mini(7,int((8.0/22.0-flip_time)*22.0)))
	else:
		_set_pose("jump",4 if velocity.y < -80 else (5 if velocity.y < 80 else 6))

func _set_pose(name: String,index: int) -> void:
	sprite.animation = name
	sprite.pause()
	sprite.frame = index

func _update_crouch() -> void:
	var wants_crouch := Input.is_action_pressed("down") and is_on_floor()
	if action.begins_with("crouch_"):
		wants_crouch = true
	elif not action.is_empty():
		wants_crouch = false
	if wants_crouch:
		_set_crouching(true)
	elif crouching and _can_stand():
		_set_crouching(false)

func _set_crouching(value: bool) -> void:
	crouching = value
	var shape: RectangleShape2D = $Collision.shape
	shape.size.y = CROUCH_HEIGHT if value else STAND_HEIGHT
	$Collision.position.y = -shape.size.y/2.0

func _can_stand() -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(13.5,STAND_HEIGHT-0.5)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform = Transform2D(0.0,global_position+Vector2(0,-STAND_HEIGHT/2.0))
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func take_damage(amount: int,origin: Vector2,trip: bool=false) -> int:
	if dead or invulnerable>0.0:
		return 0
	var from_front := (origin.x-global_position.x)*facing >= 0.0
	var blocked := guarding and Input.is_action_pressed("guard") and is_on_floor() and from_front
	var damage := maxi(1,int(ceil(amount*GUARD_DAMAGE_FACTOR))) if blocked else amount
	health = maxi(0,health-damage)
	last_damage = damage
	last_hit_guarded = blocked
	invulnerable = 0.22
	_clear_action()
	var push := -1.0 if origin.x>global_position.x else 1.0
	if health<=0:
		dead = true
		guarding = false
		reaction = "death"
		reaction_time = 0.0
		_set_body_height(14.0)
		collision_layer = 0
		velocity.x = push*80.0
		_set_pose("death",0)
	elif blocked:
		guard_recoil = 0.16
		freeze = 0.035
		velocity.x = push*25.0
		_set_pose("crouch_idle" if crouching else "guard",0 if crouching else 2)
	else:
		guarding = false
		facing = 1 if origin.x>=global_position.x else -1
		reaction = "knockdown" if trip else "hurt"
		reaction_time = 0.0
		down_time = 0.0
		freeze = 0.045
		velocity.x = push*(95.0 if trip else 70.0)
		if trip:
			_set_body_height(16.0)
			velocity.y = -105.0
		_set_pose(reaction,0)
	sprite.flip_h = facing<0
	return damage

func _set_body_height(height: float) -> void:
	var body: RectangleShape2D = $Collision.shape
	body.size.y = height
	$Collision.position.y = -height/2.0

func _update_reaction(delta: float) -> void:
	reaction_time += delta
	velocity.y += GRAVITY*delta
	velocity.x = move_toward(velocity.x,0.0,delta*220.0)
	move_and_slide()
	if reaction == "death":
		_set_pose("death",mini(5,int(reaction_time*10.0)))
	elif reaction == "hurt":
		if crouching and not _can_stand():
			_set_pose("crouch_idle",0)
		else:
			_set_pose("hurt",mini(5,int(reaction_time*22.0)))
		if reaction_time>=0.28:
			reaction = ""
	elif reaction == "knockdown":
		if is_on_floor() and reaction_time>0.10:
			down_time += delta
			_set_pose("knockdown",4 if down_time<0.50 else mini(7,5+int((down_time-0.50)*10.0)))
			if down_time>0.82 and _can_stand():
				reaction = ""
				_set_crouching(false)
		else:
			_set_pose("knockdown",mini(3,int(reaction_time*15.0)))

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name: String in ANIMS:
		var info: Dictionary = ANIMS[anim_name]
		var sheet: Texture2D = load("res://assets/ninja/%s.png" % info.file)
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name,info.fps)
		frames.set_animation_loop(anim_name,info.loop)
		for i: int in info.frames:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i*FRAME_SIZE,0,FRAME_SIZE,FRAME_SIZE)
			frames.add_frame(anim_name,atlas)
	return frames

func _setup_input() -> void:
	var binds := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],
		"jump":[KEY_C,KEY_SPACE],"attack":[KEY_X],"uppercut":[KEY_Z],"down":[KEY_DOWN,KEY_S],"reset":[KEY_R],"guard":[KEY_V],"enemy_ai":[KEY_F]}
	for action_name: String in binds:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		for key: Key in binds[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action_name,event)
