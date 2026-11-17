extends SceneTree
## Integration exercise against real player physics, collision queries and targets.
var world: Node2D
var p: CharacterBody2D
var target: CharacterBody2D
var failures := 0
var capture := false

func _initialize() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _tap(action_name: String) -> void:
	Input.action_press(action_name)
	await _frames(2)
	Input.action_release(action_name)
	await _frames(1)

func _check(condition: bool,message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _wait_action(name: String,limit: int=90) -> bool:
	for i in limit:
		if p.action == name:
			return true
		await physics_frame
	return false

func _wait_step(step: int,limit: int=90) -> bool:
	for i in limit:
		if p.ground_step == step:
			return true
		await physics_frame
	return false

func _reset() -> void:
	for a in ["attack","uppercut","jump","down","move_left","move_right","guard"]:
		Input.action_release(a)
	p.position = Vector2(100,220)
	p.reset_state()
	p.facing = 1
	target.home = Vector2(130,220)
	target.reset_target()
	world.combo_timeout = 0.0
	world.combo_count = 0
	await _frames(8)

func _shot(name: String) -> void:
	if capture:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://review/approved/%s.png" % name)

func _run() -> void:
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.human.ai_enabled = false
	p = world.player
	target = get_first_node_in_group("targets")
	await _reset()
	_check(InputMap.action_get_events("attack")[0].physical_keycode == KEY_X,"X is basic attack")
	_check(InputMap.action_get_events("uppercut")[0].physical_keycode == KEY_Z,"Z is uppercut")
	_check(InputMap.action_get_events("jump")[0].physical_keycode == KEY_C,"C is jump")
	_check(p.sprite.sprite_frames.get_frame_count("run") == 8,"eight run frames imported")
	await _tap("attack")
	_check(p.action == "jab","X starts with jab, not removed punch")
	await _tap("attack")
	_check(await _wait_step(1),"buffered X chains into second jab")
	await _tap("attack")
	_check(await _wait_action("kick"),"buffered X chains into finisher")
	await _frames(45)
	_check(target.hits == 3,"ground chain hits target exactly three times")
	await _shot("game_ground_combo")
	await _reset()
	await _tap("uppercut")
	await _tap("attack")
	_check(await _wait_action("air_1"),"uppercut buffered X becomes aerial strike")
	_check(target.position.y < 200,"uppercut launches actual physics target")
	_check(p.position.y < 210,"player follows launcher into air")
	await _tap("attack")
	_check(await _wait_action("air_2"),"aerial second strike chains")
	await _tap("attack")
	_check(await _wait_action("air_3"),"aerial third strike chains")
	await _frames(8)
	_check(target.hits == 4,"launcher plus three aerial hits connect")
	await _shot("game_air_combo")
	await _reset()
	Input.action_press("down")
	await _tap("jump")
	_check(p.action == "backstep","DOWN+C starts backstep, not jump")
	await _frames(12)
	_check(p.position.x < 75 and p.facing == 1,"backstep moves backward without turning")
	Input.action_release("down")
	await _frames(35)
	_check(p.action.is_empty() and p.is_on_floor(),"backstep returns to controllable grounded state")
	await _reset()
	await _tap("jump")
	await _frames(8)
	await _tap("jump")
	_check(p.flip_time > 0 and p.air_jumps == 0,"second C performs one somersault air jump")
	await _reset()
	p.position = Vector2(60,220)
	Input.action_press("move_right")
	await _frames(12)
	_check(p.velocity.x > 100 and p.sprite.animation == "run","movement plays new run loop")
	await _shot("game_run")
	Input.action_release("move_right")
	await _reset()
	Input.action_press("down")
	await _frames(4)
	_check(p.crouching and p.get_node("Collision").shape.size.y == 30,"DOWN shrinks body collision while feet stay anchored")
	await _tap("attack")
	_check(p.action == "crouch_jab","DOWN+X selects only low jab")
	await _frames(20)
	_check(target.hits == 1 and p.action.is_empty(),"low jab ends without automatic low kick")
	await _tap("uppercut")
	_check(p.action == "crouch_kick","DOWN+Z selects low kick, not uppercut")
	await _frames(5)
	await _shot("game_crouch_kick")
	await _frames(20)
	_check(target.hits == 2 and p.is_on_floor(),"low kick connects without launching player")
	Input.action_press("move_right")
	await _frames(10)
	_check(absf(p.velocity.x)<=65.1 and p.sprite.animation == "crouch_walk","crouch direction moves at reduced speed with dedicated animation")
	await _reset()
	p.position = Vector2(320,220)
	Input.action_press("move_right")
	await _frames(36)
	_check(p.position.x < 344,"standing body is blocked by low tunnel entrance")
	Input.action_press("down")
	await _frames(90)
	_check(p.position.x>400 and p.position.x<460 and p.crouching,"crouched body travels through real low-clearance tunnel")
	await _tap("jump")
	_check(p.action != "backstep" and p.crouching,"backstep cannot expand body into tunnel ceiling")
	Input.action_release("down")
	await _frames(3)
	_check(p.crouching and p.get_node("Collision").shape.size.y == 30,"releasing DOWN under ceiling keeps crouched collision")
	await _shot("game_crouch_tunnel")
	await _frames(45)
	_check(p.position.x>470 and not p.crouching,"leaving tunnel restores standing body when clear")
	Input.action_release("move_right")
	print("COMBAT SMOKE RESULT: %d failures" % failures)
	quit(1 if failures else 0)
