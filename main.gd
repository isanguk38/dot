extends Node2D

const PLAYER := preload("res://player.tscn")
const DUMMY := preload("res://dummy.gd")
const HUMAN := preload("res://enemy.gd")
const UPPERCUT_FX := preload("res://uppercut_fx.gd")
const SURFACE := preload("res://stage_surface.gd")
const SPAWN := Vector2(60, 220)
const LEVEL_WIDTH := 1600
const FALL_LIMIT := 420.0

# 발판 (x, y, 너비, 높이) — y는 윗면
const PLATFORMS: Array[Rect2] = [
	Rect2(0, 220, 520, 80),
	Rect2(580, 220, 420, 80),
	Rect2(1070, 220, 530, 80),
	Rect2(200, 170, 80, 10),
	Rect2(320, 130, 80, 10),
	Rect2(640, 165, 100, 10),
	Rect2(800, 120, 90, 10),
	Rect2(1180, 160, 110, 10),
	# 36px clearance above the floor: standing body cannot fit, crouch can.
	Rect2(350, 154, 110, 30),
]
const DUMMIES: Array[Vector2] = [Vector2(150, 220), Vector2(900, 220), Vector2(1235, 160)]

var player: CharacterBody2D
var combo_label: Label
var combo_count := 0
var combo_timeout := 0.0
var shake := 0.0
var elapsed := 0.0
var human: CharacterBody2D
var health_label: Label


func _ready() -> void:
	var scenery := CanvasLayer.new()
	scenery.layer = -20
	add_child(scenery)
	var background := Sprite2D.new()
	background.texture = preload("res://assets/background/dojo_night.png")
	background.centered = false
	scenery.add_child(background)
	for r in PLATFORMS:
		_add_platform(r)
	for p in DUMMIES:
		var d: CharacterBody2D = DUMMY.new()
		d.position = p
		add_child(d)
	player = PLAYER.instantiate()
	player.position = SPAWN
	add_child(player)
	player.hit_landed.connect(_on_hit)
	player.uppercut_cast.connect(_spawn_uppercut)
	human = HUMAN.new()
	human.name = "DojoOpponent"
	human.position = Vector2(300,220)
	add_child(human)
	var cam: Camera2D = player.get_node("Camera")
	cam.limit_left = 0
	cam.limit_right = LEVEL_WIDTH
	cam.limit_bottom = 270
	var hud := CanvasLayer.new()
	add_child(hud)
	var help := Label.new()
	help.text = "ARROWS / AD  MOVE    X  JAB COMBO    Z  UPPERCUT\nC  JUMP / DOUBLE JUMP    DOWN + C  BACKSTEP    R  RESET\nDOWN  CROUCH / MOVE    DOWN + X  JAB    DOWN + Z  LOW KICK\nV  GUARD (CHIP DAMAGE)    F  TOGGLE OPPONENT AI"
	help.position = Vector2(10,7)
	help.add_theme_font_size_override("font_size",10)
	hud.add_child(help)
	combo_label = Label.new()
	combo_label.position = Vector2(355,13)
	combo_label.add_theme_font_size_override("font_size",18)
	combo_label.add_theme_color_override("font_color",Color("f3cf71"))
	hud.add_child(combo_label)
	health_label = Label.new()
	health_label.position = Vector2(10,62)
	health_label.add_theme_font_size_override("font_size",10)
	health_label.add_theme_color_override("font_color",Color("ecd6b3"))
	hud.add_child(health_label)
	var tunnel_hint := Label.new()
	tunnel_hint.position = Vector2(351,142)
	tunnel_hint.text = "HOLD DOWN"
	tunnel_hint.add_theme_font_size_override("font_size",8)
	add_child(tunnel_hint)


func _physics_process(delta: float) -> void:
	elapsed += delta
	combo_timeout -= delta
	if combo_timeout <= 0.0:
		combo_count = 0
		combo_label.text = ""
	shake = maxf(0,shake-delta*12.0)
	var cam: Camera2D = player.get_node("Camera")
	cam.offset = Vector2(sin(elapsed*110.0),cos(elapsed*140.0))*shake
	health_label.text = "HP %d/100    OPPONENT %d/120    AI %s" % [player.health,human.health,"ON" if human.ai_enabled else "OFF"]
	if player.dead:
		health_label.text = "DEFEATED - PRESS R TO RESET"
	elif human.dead:
		health_label.text += "    DEFEATED / R TO REVIVE"
	if Input.is_action_just_pressed("enemy_ai"):
		human.ai_enabled = not human.ai_enabled
		if not human.ai_enabled and human.state=="attack":
			human._state("idle")
	if Input.is_action_just_pressed("reset"):
		player.position = SPAWN
		player.reset_state()
		for target in get_tree().get_nodes_in_group("targets"):
			target.reset_target()
		combo_timeout = 0.0
		for effect in get_tree().get_nodes_in_group("combat_fx"):
			effect.queue_free()
	if player.position.y > FALL_LIMIT:
		player.position = SPAWN
		player.reset_state()

func _on_hit(_point: Vector2,launcher: bool,finisher: bool) -> void:
	combo_count += 1
	combo_timeout = 1.15
	combo_label.text = "%d HIT" % combo_count
	shake = 1.7 if launcher or finisher else 0.8

func _spawn_uppercut(direction: int) -> void:
	var effect := UPPERCUT_FX.new()
	effect.direction = direction
	effect.cast_origin = player.global_position+Vector2(0,2)
	add_child(effect)


func _add_platform(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = r.position
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	shape.position = r.size / 2
	body.add_child(shape)
	var surface := SURFACE.new()
	surface.size = r.size
	surface.kind = "stone" if r.size.y>=40 else ("roof" if r.size.y==30 else "wood")
	body.add_child(surface)
	add_child(body)
