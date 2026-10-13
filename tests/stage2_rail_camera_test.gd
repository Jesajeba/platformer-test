extends SmokeTestBase
## Headless smoke test for the Stage 2 rail camera.
## Run: godot --headless --path . res://tests/stage2_rail_camera_test.tscn


func _run() -> void:
	await _frames(20)
	await _test_start_framing()
	await _test_blending()
	await _test_tracking_speed_and_lag()
	await _test_curve()
	await _test_side_scroller()
	await _test_collision()
	await _test_locked_arena()
	await _test_no_backward()
	await _test_shake()
	await _test_debug_overlay()


func _test_start_framing() -> void:
	_teleport(Vector3(0, 0.05, 4))
	await _frames(5)
	# Rail point z=4, look-ahead 2 m forward, offset 5.5 up / 9 back.
	var expected: Vector3 = Vector3(0, 5.5, 11)
	_check("start key: camera sits behind and above the player", _camera.global_position.distance_to(expected) < 0.5, "cam=%s" % _camera.global_position)
	var to_player: Vector3 = (_player.global_position - _camera.global_position).normalized()
	_check("camera looks toward the player", -_camera.global_basis.z.dot(to_player) > 0.95)


func _test_blending() -> void:
	# Start key at offset 0, Angled34 at 22 with an 8 m blend: z = -8 is halfway through the blend.
	_teleport(Vector3(0, 0.05, -8))
	await _frames(3)
	var blend: float = _camera.get_debug_blend()
	_check("blend weight is ~0.5 halfway through a key's blend-in", absf(blend - 0.5) < 0.05, "blend=%.2f" % blend)
	_check("blended camera is between the two keys' side offsets", _camera.global_position.x > 1.0 and _camera.global_position.x < 5.0, "x=%.2f" % _camera.global_position.x)


func _test_tracking_speed_and_lag() -> void:
	_teleport(Vector3(0, 0.05, 4))
	await _frames(5)
	var before: float = _camera.get_progress()
	# Move the player 27 m along the rail without snapping the camera.
	_player.global_position = Vector3(0, 0.05, -23)
	_player.reset_physics_interpolation()
	await _frames(1)
	var after: float = _camera.get_progress()
	var target: float = _camera.get_target_progress()
	_check("camera respects max lag distance", after >= target - _camera.max_lag_distance - 0.01, "progress=%.1f target=%.1f" % [after, target])
	await _frames(1)
	var step: float = _camera.get_progress() - after
	_check("camera respects max rail speed", step <= _camera.rail_max_speed / 60.0 + 0.01, "step=%.3f" % step)
	await _frames(120)
	_check("camera catches up with the player", absf(_camera.get_progress() - _camera.get_target_progress()) < 0.3)
	_check("progress started from the player's old position", before < 7.0, "before=%.1f" % before)


func _test_curve() -> void:
	# Middle of the 90-degree arc.
	_teleport(Vector3(4.2, 0.05, -51.6))
	await _frames(5)
	var forward: Vector3 = -_camera.global_basis.z
	forward.y = 0.0
	var rail_dir: Vector3 = Vector3(1, 0, -1).normalized()
	_check("on the curve, the camera faces along the rail direction", forward.normalized().dot(rail_dir) > 0.6, "fwd=%s" % forward.normalized())


func _test_side_scroller() -> void:
	_teleport(Vector3(22, 0.05, -55))
	await _frames(5)
	_check("side-scroller key: camera is off to the side", absf(_camera.global_position.z - (-43.0)) < 0.6 and absf(_camera.global_position.x - (22.0 + 3.0)) < 1.0, "cam=%s" % _camera.global_position)
	Input.action_press("move_right")
	await _frames(30)
	var vel: Vector3 = _player.velocity
	Input.action_release("move_right")
	_check("camera-relative input: 'right' runs along the side-scrolling path (+X)", vel.x > _player.max_speed * 0.9 and absf(vel.z) < _player.max_speed * 0.3, "vel=%s" % vel)
	await _frames(20)


func _test_collision() -> void:
	# A wall stands between the side-scroller camera and the player at x=26.
	_teleport(Vector3(26, 0.05, -55))
	await _frames(5)
	_check("camera is pulled in front of a blocking wall", _camera.global_position.z < -50.0, "cam z=%.2f" % _camera.global_position.z)
	_teleport(Vector3(20.5, 0.05, -55))
	await _frames(90)
	_check("camera moves back out once clear", _camera.global_position.z > -44.0, "cam z=%.2f" % _camera.global_position.z)


func _test_locked_arena() -> void:
	var lock_point: Vector3 = _level.get_node("CameraPoints/ArenaCamera").global_position
	_teleport(Vector3(48, 0.05, -55))
	await _frames(5)
	_check("boss arena key locks the camera position", _camera.global_position.distance_to(lock_point) < 0.3, "cam=%s" % _camera.global_position)
	_teleport(Vector3(52, 0.05, -51))
	await _frames(60)
	_check("locked camera stays put while the player moves", _camera.global_position.distance_to(lock_point) < 0.3)


func _test_no_backward() -> void:
	_camera.allow_backward = false
	_teleport(Vector3(38, 0.05, -55))
	await _frames(5)
	var furthest: float = _camera.get_progress()
	_player.global_position = Vector3(22, 0.05, -55)
	await _frames(90)
	_check("with allow_backward off, the camera doesn't move back", _camera.get_progress() >= furthest - 0.05, "progress=%.1f furthest=%.1f" % [_camera.get_progress(), furthest])
	_camera.allow_backward = true
	_teleport(Vector3(0, 0.05, 4))
	await _frames(5)


func _test_shake() -> void:
	_camera.shake(1.0, 0.4)
	var moved: bool = await _wait_until(func() -> bool: return absf(_camera.h_offset) + absf(_camera.v_offset) > 0.01, 10)
	_check("shake() offsets the camera", moved)
	await _frames(40)
	_check("shake settles back to zero", is_zero_approx(_camera.h_offset) and is_zero_approx(_camera.v_offset))

	SettingsManager.screen_shake = false
	_camera.shake(1.0, 0.4)
	await _frames(5)
	_check("shake respects the screen-shake setting", is_zero_approx(_camera.h_offset) and is_zero_approx(_camera.v_offset))
	SettingsManager.screen_shake = true

	_player.take_damage(1, _player.global_position + Vector3(1, 0, 0))
	var damage_shake: bool = await _wait_until(func() -> bool: return absf(_camera.h_offset) + absf(_camera.v_offset) > 0.001, 10)
	_check("player damage shakes the camera", damage_shake)
	GameState.restore_health()
	await _wait_until(func() -> bool: return not _player.is_invincible(), 120)


func _test_debug_overlay() -> void:
	var overlay: RailDebugOverlay = _level.get_node("RailDebugOverlay") as RailDebugOverlay
	_check("debug overlay starts hidden", not overlay.enabled)
	var event: InputEventAction = InputEventAction.new()
	event.action = "debug_toggle"
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(3)
	await get_tree().process_frame
	_check("F3 (debug_toggle) shows the overlay", overlay.enabled)
	_check("overlay draws the rail", overlay._mesh.get_surface_count() > 0)
	_check("overlay text lists the keys", overlay._label.text.contains("SideScroller") and overlay._label.text.contains("blend"))
