extends SmokeTestBase
## Headless smoke test for the Stage 3 level (Overgrown Ruins).
## Run: godot --headless --path . res://tests/stage3_level_test.tscn

## Longest gap the player can reliably clear with jump + hover.
const MAX_GAP: float = 8.5
## Highest ledge the player can reliably jump onto.
const MAX_STEP_UP: float = 2.3


func _init() -> void:
	level_scene = load("res://scenes/levels/level_ruins.tscn")


func _run() -> void:
	await _frames(10)
	_test_level_start()
	_test_route()
	_test_contents()
	_test_encounters()
	# The remaining checks exercise level mechanics; enemies are covered by the Stage 4 test.
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	_test_camera_segments_static()
	await _test_camera_segments()
	await _test_thorns()
	await _test_moving_platform()
	await _test_crumbling_platform()
	await _test_checkpoints_and_pits()
	await _test_gates_and_goal()


func _test_level_start() -> void:
	var start: Marker3D = _level.get_node("StartPoint") as Marker3D
	_check("player starts at the start point", _player.global_position.distance_to(start.global_position) < 0.5, "pos=%s" % _player.global_position)
	_check("level start sets the checkpoint to the start point", GameState.checkpoint_transform.origin.distance_to(start.global_position) < 0.01)
	_check("level is registered in GameState", GameState.current_level == "res://scenes/levels/level_ruins.tscn", GameState.current_level)
	_check("player starts with full health", GameState.health == GameState.max_health)


## Walks the camera rail, raycasting for static ground, and checks every gap and step on the route.
func _test_route() -> void:
	var rail: Path3D = _level.get_node("CameraRail") as Path3D
	var curve: Curve3D = rail.curve
	var length: float = curve.get_baked_length()
	print("  rail length: %.0f m" % length)
	_check("level route is a reasonable length (250-450 m)", length > 250.0 and length < 450.0, "%.0f m" % length)

	var movers: Array[MovingPlatform] = []
	for node: Node in _level.find_children("*", "MovingPlatform", true, false):
		movers.append(node as MovingPlatform)

	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var step: float = 0.5
	var last_ground: Vector3 = Vector3.INF
	var gap_start: Vector3 = Vector3.INF
	var problems: PackedStringArray = PackedStringArray()
	var gaps: PackedStringArray = PackedStringArray()
	var offset: float = 0.0
	while offset <= length:
		var p: Vector3 = rail.global_transform * curve.sample_baked(offset, true)
		var hit: Vector3 = _static_ground_below(space, p + Vector3.UP * 6.0)
		if hit == Vector3.INF:
			if gap_start == Vector3.INF and last_ground != Vector3.INF:
				gap_start = last_ground
		else:
			if gap_start != Vector3.INF:
				# Sampling every step meters overestimates a gap by up to one step.
				var gap: float = Vector2(hit.x - gap_start.x, hit.z - gap_start.z).length() - step
				var rise: float = hit.y - gap_start.y
				var spanned: bool = _spanned_by_mover(movers, gap_start, hit)
				gaps.append("%.1fm%s@(%.0f,%.0f)" % [gap, " [mover]" if spanned else "", gap_start.x, gap_start.z])
				if (gap > MAX_GAP or rise > MAX_STEP_UP) and not spanned:
					problems.append("gap %.1f m, rise %.1f m at (%.0f, %.0f, %.0f)" % [gap, rise, gap_start.x, gap_start.y, gap_start.z])
				gap_start = Vector3.INF
			elif last_ground != Vector3.INF and hit.y - last_ground.y > MAX_STEP_UP and not _spanned_by_mover(movers, last_ground, hit):
				problems.append("step up %.1f m at (%.0f, %.0f, %.0f)" % [hit.y - last_ground.y, hit.x, hit.y, hit.z])
			last_ground = hit
		offset += step
	print("  gaps along the route: %s" % ", ".join(gaps))
	_check("every gap/step on the route is passable (jump, hover or moving platform)", problems.is_empty(), "; ".join(problems))
	_check("route has a variety of gaps", gaps.size() >= 8, str(gaps.size()))


## Nearest static ground (GreyboxBlock or crumbling platform) below `from`, ignoring walls, gates and movers.
func _static_ground_below(space: PhysicsDirectSpaceState3D, from: Vector3) -> Vector3:
	var exclude: Array[RID] = [_player.get_rid()]
	for attempt: int in 6:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1, exclude)
		var result: Dictionary = space.intersect_ray(query)
		if result.is_empty():
			return Vector3.INF
		var collider: Object = result["collider"]
		if collider is GreyboxBlock or collider is CrumblingPlatform:
			return result["position"]
		exclude.append(result["rid"])
	return Vector3.INF


func _spanned_by_mover(movers: Array[MovingPlatform], a: Vector3, b: Vector3) -> bool:
	var mid: Vector3 = (a + b) * 0.5
	for mover: MovingPlatform in movers:
		var start: Vector3 = mover._origin
		var sweep: AABB = AABB(start - mover.size * 0.5, mover.size).merge(AABB(start + mover.travel - mover.size * 0.5, mover.size))
		var flat: AABB = AABB(Vector3(sweep.position.x, -1000, sweep.position.z), Vector3(sweep.size.x, 2000, sweep.size.z))
		if flat.grow(1.0).has_point(mid):
			return true
	return false


func _test_contents() -> void:
	var checkpoints: Array[Node] = _level.find_children("*", "Checkpoint", true, false)
	_check("level has at least 3 checkpoints", checkpoints.size() >= 3, str(checkpoints.size()))
	var walls: Array[Node] = _level.find_children("*", "BreakableWall", true, false)
	_check("level has breakable walls (secrets, shortcut, obstacle)", walls.size() >= 4, str(walls.size()))
	_check("level has moving platforms", _level.find_children("*", "MovingPlatform", true, false).size() >= 3)
	_check("level has crumbling platforms", _level.find_children("*", "CrumblingPlatform", true, false).size() >= 6)
	_check("level has thorn hazards", _level.find_children("*", "ThornPatch", true, false).size() >= 4)
	_check("level has 3 Lost Sprites", _level.find_children("*", "LostSprite", true, false).size() == 3)
	_check("level has a kill plane", _level.get_node_or_null("KillPlane") is KillPlane)
	_check("level has entrance and exit gates", _level.find_children("*", "Gate", true, false).size() == 2)


## Enemy placement (Stage 4): counts, introduction order, and every enemy standing on ground.
func _test_encounters() -> void:
	var rail: Path3D = _level.get_node("CameraRail") as Path3D
	var enemies: Array[EnemyBase] = []
	for node: Node in _level.find_children("*", "EnemyBase", true, false):
		enemies.append(node as EnemyBase)
	var counts: Dictionary = {"Mossling": 0, "Sporeling": 0, "Snapthorn": 0}
	var by_offset: Array = []
	var floating: PackedStringArray = PackedStringArray()
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	for enemy: EnemyBase in enemies:
		var type_name: String = enemy.get_script().get_global_name()
		counts[type_name] = counts.get(type_name, 0) + 1
		by_offset.append([rail.curve.get_closest_offset(rail.to_local(enemy.global_position)), type_name])
		var from: Vector3 = enemy.global_position + Vector3.UP * 0.3
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.0, 1, [enemy.get_rid()])
		if space.intersect_ray(query).is_empty():
			floating.append(str(enemy.get_path()))
	print("  enemies: %s" % counts)
	_check("several of each enemy type", counts["Mossling"] >= 4 and counts["Sporeling"] >= 3 and counts["Snapthorn"] >= 3, str(counts))
	_check("every enemy stands on ground", floating.is_empty(), ", ".join(floating))

	by_offset.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var first_seen: Dictionary = {}
	for entry: Array in by_offset:
		if not first_seen.has(entry[1]):
			first_seen[entry[1]] = entry[0]
	_check("enemy types are introduced in order: Mossling, Sporeling, Snapthorn",
		first_seen["Mossling"] < first_seen["Sporeling"] and first_seen["Sporeling"] < first_seen["Snapthorn"], str(first_seen))
	var alone: bool = true
	for type_name: String in first_seen:
		for entry: Array in by_offset:
			if entry[1] != type_name and absf(entry[0] - first_seen[type_name]) < 12.0:
				alone = false
	_check("each enemy type's first appearance is alone (no other type within 12 m)", alone)


func _test_camera_segments_static() -> void:
	_check("camera rail has a key per segment plus extras", _camera.get_keys().size() >= 6, str(_camera.get_keys().size()))


func _test_camera_segments() -> void:
	var expected: Array = [
		[Vector3(0, 0.05, -10), "Courtyard"],
		[Vector3(50, 2.05, -80), "Colonnade"],
		[Vector3(135, 10.05, -80), "Stairway"],
		[Vector3(199, 10.05, -80), "SunkenGarden"],
		[Vector3(270, 10.05, -80), "ThroneArena"],
	]
	for entry: Array in expected:
		_teleport(entry[0])
		await _frames(3)
		_check("camera segment '%s' is active at %s" % [entry[1], entry[0]], _camera._debug_key_a == entry[1], _camera._debug_key_a)
	var lock_point: Vector3 = _level.get_node("CameraPoints/ArenaCamera").global_position
	_check("arena camera is locked", _camera.global_position.distance_to(lock_point) < 0.5)


func _test_thorns() -> void:
	_teleport(Vector3(0, 0.05, -10))
	await _frames(5)
	GameState.restore_health()
	var thorns: Node3D = _level.get_node("Geometry/S1_Courtyard/ThornsB") as Node3D
	_teleport(thorns.global_position + Vector3(0, 0.6, 0))
	var hurt: bool = await _wait_until(func() -> bool: return GameState.health < GameState.max_health, 20)
	_check("thorns hurt the player", hurt)
	await _wait_until(func() -> bool: return not _player.is_invincible() and _player.is_on_floor(), 150)
	GameState.restore_health()


func _test_moving_platform() -> void:
	var platform: MovingPlatform = _level.get_node("Geometry/S2_Colonnade/MovingPlatformA") as MovingPlatform
	_teleport(platform.global_position + Vector3(0, 0.35, 0))
	await _frames(10)
	var start_player: Vector3 = _player.global_position
	var start_platform: Vector3 = platform.global_position
	await _frames(90)
	var platform_moved: float = platform.global_position.x - start_platform.x
	var player_moved: float = _player.global_position.x - start_player.x
	_check("moving platform moves", absf(platform_moved) > 1.0, "moved %.2f" % platform_moved)
	_check("player rides the moving platform", absf(player_moved - platform_moved) < 0.3 and _player.is_on_floor(), "platform %.2f player %.2f" % [platform_moved, player_moved])


func _test_crumbling_platform() -> void:
	var crumbling: CrumblingPlatform = _level.get_node("Geometry/S2_Colonnade/Crumbling1") as CrumblingPlatform
	_teleport(crumbling.global_position + Vector3(0, 0.35, 0))
	await _frames(5)
	_check("crumbling platform starts shaking when stood on", crumbling.get_phase() == CrumblingPlatform.Phase.SHAKING)
	var fell: bool = await _wait_until(func() -> bool: return crumbling.get_phase() == CrumblingPlatform.Phase.FALLEN, int(crumbling.crumble_delay * 60.0) + 10)
	_check("crumbling platform falls after its delay", fell)
	var back: bool = await _wait_until(func() -> bool: return crumbling.get_phase() == CrumblingPlatform.Phase.SOLID, int(crumbling.respawn_time * 60.0) + 60)
	_check("crumbling platform comes back", back)
	await _wait_until(func() -> bool: return not _player.is_invincible(), 150)
	GameState.restore_health()


func _test_checkpoints_and_pits() -> void:
	for i: int in range(1, 5):
		var checkpoint: Checkpoint = _level.find_child("Checkpoint%d" % i, true, false) as Checkpoint
		_teleport(checkpoint.get_spawn_transform().origin)
		await _frames(5)
		_check("checkpoint %d activates on touch" % i, checkpoint.is_active())
		_check("checkpoint %d becomes the respawn point" % i, GameState.checkpoint_transform.origin.distance_to(checkpoint.get_spawn_transform().origin) < 0.01)
	# Fall into the hover gap of the courtyard: respawn at the latest checkpoint (4).
	GameState.restore_health()
	var latest: Vector3 = GameState.checkpoint_transform.origin
	_teleport(Vector3(0, 3, -60))
	var respawned: bool = await _wait_until(func() -> bool: return _player.global_position.distance_to(latest) < 0.5, 180)
	_check("falling into a pit respawns at the latest checkpoint", respawned, "pos=%s" % _player.global_position)
	await _wait_until(func() -> bool: return not _player.is_invincible(), 150)
	GameState.restore_health()


func _test_gates_and_goal() -> void:
	var entrance: Gate = _level.find_child("EntranceGate", true, false) as Gate
	var exit_gate: Gate = _level.find_child("ExitGate", true, false) as Gate
	_check("arena entrance gate starts open", entrance.is_open())
	_check("arena exit gate starts closed", not exit_gate.is_open())
	var bars: Node3D = exit_gate.get_node("Bars") as Node3D
	var closed_y: float = bars.position.y
	exit_gate.open()
	await _frames(int(exit_gate.move_duration * 60.0) + 10)
	_check("gate bars slide down when opened", bars.position.y < closed_y - exit_gate.open_depth + 0.05, "y=%.2f" % bars.position.y)

	var completed: Array[String] = []
	var on_complete: Callable = func(level_id: String) -> void: completed.append(level_id)
	GameState.level_completed.connect(on_complete)
	var goal: Node3D = _level.find_child("LevelGoal", true, false) as Node3D
	_teleport(goal.global_position + Vector3(0, 0.1, 0))
	await _frames(5)
	_check("reaching the goal completes the level", completed.size() == 1)
	GameState.level_completed.disconnect(on_complete)
