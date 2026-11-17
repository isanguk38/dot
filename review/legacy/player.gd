extends CharacterBody2D

const SPEED := 140.0
const ACCEL := 1400.0
const JUMP_VELOCITY := -340.0
const DOUBLE_JUMP_VELOCITY := -300.0
const MAX_AIR_JUMPS := 1
const GRAVITY := 900.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.1
const FRAME_SIZE := 64
const HITBOX_REACH := 18.0
const RUN_LEAN := 0.22  # 달릴 때 상체를 앞으로 기울이는 정도(라디안)
const COMBO_WINDOW := 0.3  # 한 타가 끝난 뒤 다음 타로 이어갈 수 있는 시간

# 스프라이트 시트(가로 스트립, 한 칸 64x64) -> 애니메이션 정의
# "frames"를 주면 시트에서 그 칸만 그 순서대로 사용 (같은 칸 반복 = 그 자세 유지)
const ANIMS := {
	"idle": {"file": "res://assets/player/idle.png", "fps": 8.0, "loop": true},
	# 0번 칸은 서 있는 자세라 달리기에서 제외
	"run": {"file": "res://assets/player/run.png", "fps": 16.0, "loop": true, "frames": [1, 2, 3, 4, 5, 6, 7]},
	"jump": {"file": "res://assets/player/jump.png", "fps": 8.0, "loop": false},
	"double_jump": {"file": "res://assets/player/double_jump.png", "fps": 16.0, "loop": false, "frames": [3, 4, 5, 6]},
	"punch": {"file": "res://assets/player/punch.png", "fps": 16.0, "loop": false, "frames": [3, 4, 4, 5]},
	"jab": {"file": "res://assets/player/attack.png", "fps": 18.0, "loop": false, "frames": [1, 2, 2, 3]},
	"kick": {"file": "res://assets/player/kick.png", "fps": 16.0, "loop": false, "frames": [2, 3, 4, 4, 5, 6]},
}
# 콤보 순서: 정권 지르기 -> 잽 -> 돌려차기
# hit_frame: 판정이 나가는 재생 프레임, lunge: 지상에서 앞으로 내딛는 속도, power: 타격 세기
const COMBO := [
	{"anim": "punch", "hit_frame": 1, "lunge": 90.0, "power": 1.0},
	{"anim": "jab", "hit_frame": 1, "lunge": 50.0, "power": 0.7},
	{"anim": "kick", "hit_frame": 2, "lunge": 120.0, "power": 2.0},
]
# jump 시트에서 공중 자세로 쓸 프레임
const JUMP_RISE := 4
const JUMP_APEX := 5
const JUMP_FALL := 6

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox

var facing := 1
var coyote := 0.0
var jump_buffer := 0.0
var air_jumps := MAX_AIR_JUMPS
var flipping := false  # 더블점프 공중제비 재생 중
var attacking := false
var combo_step := -1
var combo_queued := false
var combo_timer := 0.0


func _ready() -> void:
	_setup_input()
	sprite.sprite_frames = _build_frames()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		coyote = COYOTE_TIME
		air_jumps = MAX_AIR_JUMPS
		flipping = false
	else:
		coyote -= delta
		velocity.y += GRAVITY * delta

	_handle_jump(delta)
	_handle_attack(delta)

	var dir := Input.get_axis("move_left", "move_right")
	if attacking and on_floor:
		dir = 0.0
	velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
	if dir != 0.0 and not attacking:
		facing = 1 if dir > 0.0 else -1

	move_and_slide()
	_update_visuals()


func _handle_jump(delta: float) -> void:
	jump_buffer -= delta
	var pressed := Input.is_action_just_pressed("jump")
	if pressed:
		jump_buffer = JUMP_BUFFER
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
	elif pressed and air_jumps > 0:
		air_jumps -= 1
		velocity.y = DOUBLE_JUMP_VELOCITY
		jump_buffer = 0.0
		_end_attack()
		flipping = true
		sprite.play("double_jump")
	# 점프 키를 일찍 떼면 낮게 뜀
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45


func _handle_attack(delta: float) -> void:
	if not attacking:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = -1
	if not Input.is_action_just_pressed("attack"):
		return
	if attacking:
		combo_queued = true  # 재생 중에 누르면 다음 타 예약
	else:
		_start_attack(combo_step + 1)


func _start_attack(step: int) -> void:
	combo_step = step % COMBO.size()
	combo_queued = false
	attacking = true
	flipping = false
	var move: Dictionary = COMBO[combo_step]
	if is_on_floor():
		velocity.x = move.lunge * facing
	sprite.play(move.anim)


func _end_attack() -> void:
	attacking = false
	combo_queued = false
	combo_step = -1


func _update_visuals() -> void:
	sprite.flip_h = facing < 0
	hitbox.position.x = HITBOX_REACH * facing
	var lean := 0.0
	if is_on_floor() and not attacking:
		lean = RUN_LEAN * velocity.x / SPEED
	sprite.skew = lerpf(sprite.skew, lean, 0.3)
	if attacking or flipping:
		return
	if not is_on_floor():
		sprite.animation = "jump"
		sprite.pause()
		if velocity.y < -80.0:
			sprite.frame = JUMP_RISE
		elif velocity.y < 80.0:
			sprite.frame = JUMP_APEX
		else:
			sprite.frame = JUMP_FALL
	elif absf(velocity.x) > 10.0:
		sprite.play("run")
	else:
		sprite.play("idle")


func _on_frame_changed() -> void:
	if not attacking:
		return
	var move: Dictionary = COMBO[combo_step]
	if sprite.animation == move.anim and sprite.frame == move.hit_frame:
		for body in hitbox.get_overlapping_bodies():
			if body != self and body.has_method("take_hit"):
				body.take_hit(facing, move.power)


func _on_animation_finished() -> void:
	if flipping:
		flipping = false
	elif attacking:
		if combo_queued and combo_step < COMBO.size() - 1:
			_start_attack(combo_step + 1)
		else:
			attacking = false
			combo_queued = false
			# 막타였으면 콤보 초기화, 아니면 잠깐 이어갈 기회를 줌
			if combo_step == COMBO.size() - 1:
				combo_step = -1
			else:
				combo_timer = COMBO_WINDOW


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name: String in ANIMS:
		var info: Dictionary = ANIMS[anim_name]
		var sheet: Texture2D = load(info.file)
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, info.fps)
		frames.set_animation_loop(anim_name, info.loop)
		var cells: Array = info.get("frames", range(sheet.get_width() / FRAME_SIZE))
		for i: int in cells:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
			frames.add_frame(anim_name, atlas)
	return frames


func _setup_input() -> void:
	var binds := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"attack": [KEY_J, KEY_Z],
	}
	for action: String in binds:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
