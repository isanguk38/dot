extends Node2D

const PLAYER := preload("res://player.tscn")
const DUMMY := preload("res://dummy.gd")
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
]
const DUMMIES: Array[Vector2] = [Vector2(440, 220), Vector2(900, 220), Vector2(1235, 160)]

var player: CharacterBody2D


func _ready() -> void:
	for r in PLATFORMS:
		_add_platform(r)
	for p in DUMMIES:
		var d: StaticBody2D = DUMMY.new()
		d.position = p
		add_child(d)
	player = PLAYER.instantiate()
	player.position = SPAWN
	add_child(player)
	var cam: Camera2D = player.get_node("Camera")
	cam.limit_left = 0
	cam.limit_right = LEVEL_WIDTH
	cam.limit_bottom = 270


func _physics_process(_delta: float) -> void:
	if player.position.y > FALL_LIMIT:
		player.position = SPAWN
		player.velocity = Vector2.ZERO


func _add_platform(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = r.position
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	shape.position = r.size / 2
	body.add_child(shape)
	var fill := ColorRect.new()
	fill.color = Color(0.17, 0.16, 0.3)
	fill.size = r.size
	body.add_child(fill)
	var top := ColorRect.new()
	top.color = Color(0.36, 0.78, 0.82)
	top.size = Vector2(r.size.x, 2)
	body.add_child(top)
	add_child(body)
