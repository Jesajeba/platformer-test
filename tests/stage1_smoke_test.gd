extends Node
## Headless smoke test for the Stage 1 player controller.
## Run: godot --headless --path . res://tests/stage1_smoke_test.tscn
## Drives the test greybox level with simulated input and exits with the failure count.

const LEVEL: PackedScene = preload("res://scenes/levels/test_greybox.tscn")

var _failures: int = 0
var _level: Node3D
var _player: Player


func _ready() -> void:
	_level = LEVEL.instantiate() as Node3D
	add_child(_level)
	_player = _level.get_node("Player") as Player
	await _run()
	print("\n%s: %d failure(s)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(_failures)


func _run() -> void:
	await _frames(20)
	_check("starts idle on floor", _player.get_state() == Player.State.IDLE and _player.is_on_floor())

	await _test_movement()
	await _test_jump_heights()
	await _test_coyote_time()
	await _test_hover_and_buffer()
	await _test_attack()
	await _test_damage()
	await _test_pit()
	await _test_death_and_respawn()


func _test_movement() -> void:
	_teleport(Vector3(0, 0.05, 4))
	Input.action_press("move_forward")
	await _frames(40)
	var vel: Vector3 = _player.velocity
	Input.action_release("move_forward")
	_check("forward input moves away from camera (-Z) at max speed", vel.z < -_player.max_speed * 0.95 and absf(vel.x) < 0.2, "vel=%s" % vel)
	_check("state is RUN while moving", _player.get_state() == Player.State.RUN)
	await _frames(30)
	_check("decelerates to idle", _player.get_state() == Player.State.IDLE, _player.get_state_name())


func _test_jump_heights() -> void:
	_teleport(Vector3(0, 0.05, 4))
	await _frames(5)
	var start_y: float = _player.global_position.y
	var peak: float = await _jump_and_measure_peak(60)
	_check("held jump reaches ~jump_height", absf(peak - start_y - _player.jump_height) < 0.3, "peak=%.2f" % (peak - start_y))

	await _frames(30)
	start_y = _player.global_position.y
	var tap_peak: float = await _jump_and_measure_peak(2)
	_check("tap jump is much lower than held jump", tap_peak - start_y < _player.jump_height * 0.6, "tap=%.2f" % (tap_peak - start_y))


func _test_coyote_time() -> void:
	# Walk off the left edge of Step1 (top at y=1, edge at x=3.5) and jump just after leaving it.
	_teleport(Vector3(4.2, 1.05, -6))
	await _frames(5)
	Input.action_press("move_left")
	var left_floor: bool = await _wait_until(func() -> bool: return _player.get_state() == Player.State.FALL, 60)
	Input.action_release("move_left")
	await _frames(3)
	await _press_jump()
	_check("coyote jump works just after walking off a ledge", left_floor and _player.get_state() == Player.State.JUMP and _player.velocity.y > 0.0, _player.get_state_name())
	Input.action_release("jump")
	await _wait_until(func() -> bool: return _player.is_on_floor(), 120)

	# Same thing from the high ledge (top y=5.3), waiting past coyote time: the press should hover.
	_teleport(Vector3(12.2, 5.35, -10.5))
	await _frames(5)
	Input.action_press("move_left")
	await _wait_until(func() -> bool: return _player.get_state() == Player.State.FALL, 60)
	Input.action_release("move_left")
	await _frames(int(_player.coyote_time * 60.0) + 4)
	await _press_jump()
	_check("late press (after coyote time) starts a hover", _player.get_state() == Player.State.HOVER, _player.get_state_name())
	Input.action_release("jump")
	await _wait_until(func() -> bool: return _player.is_on_floor(), 180)


func _test_hover_and_buffer() -> void:
	_teleport(Vector3(0, 0.05, 4))
	await _frames(5)
	# Full jump, then release at the peak and press again to hover.
	Input.action_press("jump")
	await _wait_until(func() -> bool: return _player.velocity.y <= 0.0, 60)
	Input.action_release("jump")
	await _frames(1)
	await _press_jump()
	_check("second press in the air starts hover", _player.get_state() == Player.State.HOVER, _player.get_state_name())
	await _frames(30)
	_check("hover falls slowly", _player.velocity.y > -_player.hover_fall_speed - 0.2 and _player.velocity.y < 0.0, "vy=%.2f" % _player.velocity.y)
	var hover_ended: bool = await _wait_until(func() -> bool: return _player.get_state() != Player.State.HOVER, int(_player.hover_duration * 60.0) + 10)
	_check("hover ends after hover_duration while held", hover_ended and not _player.is_on_floor(), _player.get_state_name())
	Input.action_release("jump")
	await _frames(1)
	await _press_jump()
	_check("hover can't be repeated before landing", _player.get_state() != Player.State.HOVER, _player.get_state_name())
	Input.action_release("jump")

	# Jump buffer: press jump just before landing, expect a jump on touchdown.
	await _wait_until(func() -> bool: return _player.global_position.y < 0.35 and _player.velocity.y < 0.0, 120)
	await _press_jump()
	Input.action_release("jump")
	var buffered: bool = await _wait_until(func() -> bool: return _player.get_state() == Player.State.JUMP, 10)
	_check("jump pressed just before landing is buffered", buffered, _player.get_state_name())
	await _wait_until(func() -> bool: return _player.is_on_floor(), 120)


func _test_attack() -> void:
	var hits: Array[Node] = []
	var on_hit: Callable = func(target: Node) -> void: hits.append(target)
	_player.hit_landed.connect(on_hit)
	var hit_stop: float = _player.hit_stop_duration
	_player.hit_stop_duration = 0.0

	# Dummy at (-5, 0, 4): stand 1.4 m in front of it and face it (-Z).
	_teleport(Vector3(-5, 0.05, 5.6))
	await _face_forward()
	await _press_action("attack")
	_check("attack enters ATTACK state", _player.get_state() == Player.State.ATTACK, _player.get_state_name())
	await _frames(15)
	_check("attack hits the training dummy", hits.any(func(n: Node) -> bool: return n is TrainingDummy), str(hits))
	await _frames(30)
	_check("attack returns to idle", _player.get_state() == Player.State.IDLE, _player.get_state_name())

	# Breakable wall at (10, 1.5, 1), 1 m thick: needs 2 hits.
	var wall: Node = _level.get_node("BreakableWall")
	_teleport(Vector3(10, 0.05, 2.4))
	await _face_forward()
	await _press_action("attack")
	await _frames(45)
	_check("wall survives first hit", is_instance_valid(wall))
	await _press_action("attack")
	await _frames(45)
	_check("wall breaks on second hit", not is_instance_valid(wall))

	# Hit-stop: slows time right after a hit and restores it after hit_stop_duration (real time).
	_player.hit_stop_duration = hit_stop
	_teleport(Vector3(-5, 0.05, 5.6))
	await _face_forward()
	await _press_action("attack")
	var slowed: bool = await _wait_until(func() -> bool: return Engine.time_scale < 1.0, 20)
	_check("hit-stop slows time on hit", slowed, "ts=%.2f" % Engine.time_scale)
	await get_tree().create_timer(hit_stop + 0.1, true, false, true).timeout
	_check("hit-stop restores time scale", is_equal_approx(Engine.time_scale, 1.0), "ts=%.2f" % Engine.time_scale)
	await _frames(30)
	_player.hit_landed.disconnect(on_hit)


func _test_damage() -> void:
	GameState.restore_health()
	await _frames(int(_player.invincibility_time * 60.0) + 5)
	# Hazard block at (5, 0.25, 5): drop onto it.
	_teleport(Vector3(5, 1.0, 5))
	var hurt: bool = await _wait_until(func() -> bool: return _player.get_state() == Player.State.HURT, 30)
	_check("hazard damages the player", hurt and GameState.health == GameState.max_health - 1, "hp=%d" % GameState.health)
	_check("player is invincible after damage", _player.is_invincible())
	_check("player is knocked back", Vector2(_player.velocity.x, _player.velocity.z).length() > 1.0 or _player.velocity.y > 0.0)
	_teleport(Vector3(5, 1.0, 5))
	await _frames(15)
	_check("invincibility prevents repeat damage", GameState.health == GameState.max_health - 1, "hp=%d" % GameState.health)
	await _wait_until(func() -> bool: return not _player.is_invincible(), 120)
	_teleport(Vector3(0, 0.05, 4))
	await _frames(10)


func _test_pit() -> void:
	var hp_before: int = GameState.health
	_teleport(Vector3(0, 2.0, -17))  # Above the 4 m gap.
	var respawned: bool = await _wait_until(func() -> bool: return _player.global_position.distance_to(GameState.checkpoint_transform.origin) < 0.5, 180)
	_check("falling in a pit respawns at the checkpoint", respawned, "pos=%s" % _player.global_position)
	_check("pit costs pit_damage hearts", GameState.health == hp_before - _player.pit_damage, "hp=%d" % GameState.health)
	await _wait_until(func() -> bool: return not _player.is_invincible(), 120)


func _test_death_and_respawn() -> void:
	GameState.health = 1
	_teleport(Vector3(5, 1.0, 5))
	var dead: bool = await _wait_until(func() -> bool: return _player.get_state() == Player.State.DEAD, 30)
	_check("losing the last heart kills the player", dead, _player.get_state_name())
	var back: bool = await _wait_until(func() -> bool: return _player.get_state() != Player.State.DEAD, int(_player.respawn_delay * 60.0) + 20)
	_check("player respawns after respawn_delay", back)
	_check("respawn restores full health", GameState.health == GameState.max_health, "hp=%d" % GameState.health)
	_check("respawn is at the checkpoint", _player.global_position.distance_to(GameState.checkpoint_transform.origin) < 0.5)


#region Helpers

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("[%s] %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail != "" and not ok else ""])


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i: int in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


## Presses an action at the start of a physics frame so the player sees it as just pressed.
func _press_action(action: StringName) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release(action)


func _press_jump() -> void:
	await get_tree().physics_frame
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().process_frame


func _jump_and_measure_peak(hold_frames: int) -> float:
	await get_tree().physics_frame
	Input.action_press("jump")
	var peak: float = _player.global_position.y
	for i: int in 90:
		await get_tree().physics_frame
		if i == hold_frames:
			Input.action_release("jump")
		peak = maxf(peak, _player.global_position.y)
		if i > 3 and _player.is_on_floor():
			break
	Input.action_release("jump")
	return peak


## Taps forward so the player (and its attack hitbox) faces -Z, then lets it settle.
func _face_forward() -> void:
	Input.action_press("move_forward")
	await _frames(2)
	Input.action_release("move_forward")
	await _frames(25)


func _teleport(pos: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	(_level.get_node("FollowCamera") as FollowCamera).snap_to_target()

#endregion
