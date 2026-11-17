extends StaticBody2D
# 공격 판정 확인용 임시 샌드백 (도트 아트 없음, 사각형)

const SIZE := Vector2(16, 34)

var rect: ColorRect


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = SIZE
	shape.shape = box
	shape.position = Vector2(0, -SIZE.y / 2)
	add_child(shape)
	rect = ColorRect.new()
	rect.color = Color(0.85, 0.45, 0.2)
	rect.size = SIZE
	rect.position = Vector2(-SIZE.x / 2, -SIZE.y)
	add_child(rect)


var hits := 0  # 맞은 횟수 (판정 확인용)


func take_hit(dir: int, power: float = 1.0) -> void:
	hits += 1
	var tween := create_tween()
	rect.color = Color.WHITE
	tween.tween_property(rect, "position:x", -SIZE.x / 2 + 5.0 * dir * power, 0.05)
	tween.tween_property(rect, "position:x", -SIZE.x / 2, 0.12)
	tween.parallel().tween_property(rect, "color", Color(0.85, 0.45, 0.2), 0.12)
