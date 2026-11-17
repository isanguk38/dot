extends SceneTree
var world: Node2D
var p: CharacterBody2D
var enemy: CharacterBody2D
var failures := 0
var capture := false

func _initialize() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func _reset() -> void:
	for effect in get_nodes_in_group("combat_fx"):
		effect.queue_free()
	for a in ["move_left","move_right","down","attack","uppercut","guard","jump","reset"]:
		Input.action_release(a)
	p.position = Vector2(100,220)
	p.reset_state()
	p.facing = 1
	enemy.home = Vector2(130,220)
	enemy.reset_target()
	enemy.ai_enabled = false
	world.combo_count = 0
	world.combo_timeout = 0.0
	await _frames(8)

func _shot(name: String) -> void:
	if capture:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://review/combat_expansion/%s.png" % name)

func _run() -> void:
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	p = world.player
	enemy = world.human
	for target in get_nodes_in_group("targets"):
		if target!=enemy:
			target.position = Vector2(1100,220)
	await _reset()
	_check(get_nodes_in_group("humans").size()==1,"exactly one humanoid sparring enemy exists")
	_check(not p.ANIMS.has("punch") and p.GROUND[0]=="jab","punch removed from player animations and X opener")
	_check(InputMap.action_get_events("guard")[0].physical_keycode==KEY_V,"V is guard")
	await _tap("attack")
	_check(p.action=="jab","basic X selects jab")
	await _frames(8)
	_check(enemy.hits==1 and enemy.health==110,"jab damages humanoid once")
	_check(enemy.state=="hurt" and enemy.sprite.animation=="hurt","humanoid plays hit recoil")
	await _shot("enemy_hurt_game")
	await _reset()
	Input.action_press("guard")
	await _frames(4)
	_check(p.guarding and p.sprite.animation=="guard","V holds raised-arm guard pose")
	enemy._start_attack()
	await _frames(28)
	_check(p.health==96 and p.last_hit_guarded,"front 12-damage punch deals four chip damage through guard")
	_check(not p.dead and p.reaction.is_empty(),"guarded punch does not trigger normal hitstun")
	await _shot("guard_chip_game")
	await _reset()
	var damage: int = p.take_damage(12,Vector2(130,220))
	_check(damage==12 and p.health==88 and p.reaction=="hurt","unguarded hit deals full damage and plays recoil")
	await _frames(10)
	await _shot("player_hurt_game")
	await _frames(20)
	_check(p.reaction.is_empty(),"player control returns after hitstun")
	await _reset()
	Input.action_press("guard")
	await _frames(4)
	damage = p.take_damage(12,Vector2(70,220))
	_check(damage==12 and not p.last_hit_guarded,"rear strike bypasses frontal guard")
	await _reset()
	Input.action_press("down")
	await _frames(4)
	await _tap("uppercut")
	await _frames(10)
	_check(enemy.state=="knockdown" and not enemy.dead,"DOWN+Z trips living humanoid")
	_check(enemy.body.shape.size.y==16,"fallen enemy uses low collision shape")
	await _frames(20)
	await _shot("enemy_knockdown_game")
	await _frames(70)
	_check(enemy.state=="idle" and enemy.body.shape.size.y==46,"tripped enemy gets up and restores standing body")
	await _reset()
	await _tap("uppercut")
	await _frames(12)
	var effect: Node2D = world.get_node_or_null("UppercutEffect")
	_check(enemy.state=="launched" and enemy.position.y<210,"uppercut launches human with airborne hit pose")
	_check(effect!=null and effect.get_parent()==world,"uppercut effect stays rooted in the stage instead of following the jumping player")
	if effect!=null:
		_check(is_equal_approx(effect.cast_origin.y,222.0),"uppercut begins two pixels below the caster's feet")
		_check(effect.sprite.flip_h and effect.position.x>effect.cast_origin.x,"right cast reverses original crescent and projects forward")
	await _shot("uppercut_right_game")
	await _reset()
	enemy.position = Vector2(70,220)
	p.facing = -1
	await _tap("uppercut")
	await _frames(12)
	effect = world.get_node_or_null("UppercutEffect")
	_check(effect!=null and not effect.sprite.flip_h and effect.position.x<effect.cast_origin.x,"left cast mirrors direction and origin")
	await _shot("uppercut_left_game")
	await _reset()
	enemy.ai_enabled = true
	await _frames(78)
	_check(enemy.attack_count>=1 and p.health<100,"enabled human AI attacks and hurts player in real combat")
	await _reset()
	p.take_damage(18,Vector2(130,220),true)
	_check(p.reaction=="knockdown","heavy unguarded hit knocks player down")
	await _frames(95)
	_check(p.reaction.is_empty() and p.get_node("Collision").shape.size.y==46,"player gets up after knockdown")
	await _reset()
	Input.action_press("guard")
	await _frames(4)
	p.health = 3
	p.take_damage(12,Vector2(130,220))
	_check(p.dead and p.health==0,"guard chip damage can kill instead of granting invulnerability")
	await _frames(48)
	_check(p.sprite.animation=="death" and p.sprite.frame==5,"player death finishes and holds prone frame")
	await _shot("player_death_game")
	await _tap("attack")
	_check(p.action.is_empty() and p.dead,"dead player cannot attack")
	await _tap("reset")
	_check(not p.dead and p.health==100 and p.collision_layer==4,"R revives player and restores collision")
	await _reset()
	enemy.take_hit(1,100.0)
	_check(enemy.dead and not enemy.can_receive_hit() and enemy.collision_layer==0,"dead enemy leaves active attack query layer")
	await _frames(48)
	_check(enemy.sprite.animation=="death" and enemy.sprite.frame==5,"enemy death holds complete prone body")
	await _shot("enemy_death_game")
	var previous_hits: int = enemy.hits
	enemy.take_hit(1,1.0)
	_check(enemy.hits==previous_hits,"corpse cannot accumulate combat hits")
	await _tap("reset")
	_check(not enemy.dead and enemy.health==120 and enemy.collision_layer==2,"R revives humanoid for repeated testing")
	await _reset()
	await _tap("enemy_ai")
	_check(enemy.ai_enabled,"F enables opponent AI")
	await _tap("enemy_ai")
	_check(not enemy.ai_enabled,"F disables opponent AI")
	await _shot("dojo_combat_game")
	print("HUMAN COMBAT RESULT: %d failures" % failures)
	quit(1 if failures else 0)
