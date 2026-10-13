extends SmokeTestBase
## Headless smoke test for Stage 4 enemies, spawned into the test greybox.
## Run: godot --headless --path . res://tests/stage4_enemy_test.tscn

const MOSSLING: PackedScene = preload("res://scenes/enemies/mossling.tscn")
const SPORELING: PackedScene = preload("res://scenes/enemies/sporeling.tscn")
const SNAPTHORN: PackedScene = preload("res://scenes/enemies/snapthorn.tscn")
const SPORE: PackedScene = preload("res://scenes/enemies/spore_projectile.tscn")


func _run() -> void:
	await _frames(10)
	await _test_mossling_detect_and_chase()
	await _test_facing()
	await _test_mossling_telegraphed_lunge()
	await _test_damage_knockback_death()
	await _test_player_attack_kills()
	await _test_mossling_stays_on_ledge()
	await _test_sporeling_shoots()
	await _test_sporeling_keeps_distance()
	await _test_projectile_timeout()
	await _test_snapthorn()
	await _test_sleeping()


func _spawn(scene: PackedScene, pos: Vector3, yaw_degrees: float = 0.0) -> EnemyBase:
	var enemy: EnemyBase = scene.instantiate() as EnemyBase
	enemy.rotation_degrees.y = yaw_degrees
	_level.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _reset_player(pos: Vector3) -> void:
	GameState.restore_health()
	_teleport(pos)
	await _wait_until(func() -> bool: return not _player.is_invincible() and _player.is_on_floor(), 150)
	_teleport(pos)
	await _frames(2)


func _test_mossling_detect_and_chase() -> void:
	await _reset_player(Vector3(0, 0.05, 6))
	var mossling: Mossling = _spawn(MOSSLING, Vector3(0, 0.1, -6)) as Mossling
	await _frames(60)
	_check("mossling ignores a distant player", mossling.get_state() in [Mossling.State.IDLE, Mossling.State.PATROL], Mossling.State.keys()[mossling.get_state()])
	_teleport(Vector3(0, 0.05, -1))
	var alerted: bool = await _wait_until(func() -> bool: return mossling.get_state() == Mossling.State.ALERT, 20)
	_check("mossling notices the player (alert '!')", alerted and mossling._alert_label.visible)
	var start_distance: float = mossling.global_position.distance_to(_player.global_position)
	var chasing: bool = await _wait_until(func() -> bool: return mossling.get_state() == Mossling.State.CHASE, 60)
	await _frames(15)
	_check("mossling chases the player", chasing and mossling.global_position.distance_to(_player.global_position) < start_distance - 0.3)
	mossling.queue_free()


## World-space direction the enemy's model is facing (its front is -Z).
func _model_forward(enemy: EnemyBase) -> Vector3:
	var forward: Vector3 = -(enemy.get_node("Visual") as Node3D).global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _test_facing() -> void:
	await _reset_player(Vector3(0, 0.05, 6))
	# Placed at 180 degrees = facing +Z, toward the player standing at +Z.
	var mossling: Mossling = _spawn(MOSSLING, Vector3(0, 0.1, -2), 180.0) as Mossling
	mossling.detect_range = 0.0
	await _frames(3)
	_check("an enemy placed at 180 degrees faces that way (not backwards)", _model_forward(mossling).dot(Vector3(0, 0, 1)) > 0.95, str(_model_forward(mossling)))
	mossling.detect_range = 12.0
	await _wait_until(func() -> bool: return mossling.get_state() == Mossling.State.CHASE, 90)
	await _frames(20)
	var to_player: Vector3 = (_player.global_position - mossling.global_position) * Vector3(1, 0, 1)
	_check("a chasing Mossling faces the player", _model_forward(mossling).dot(to_player.normalized()) > 0.9)
	var lunged: bool = await _wait_until(func() -> bool: return mossling.get_state() == Mossling.State.LUNGE, 240)
	to_player = (_player.global_position - mossling.global_position) * Vector3(1, 0, 1)
	_check("a lunging Mossling dashes face first", lunged and _model_forward(mossling).dot(mossling._lunge_direction) > 0.8)
	mossling.queue_free()
	GameState.restore_health()


func _test_mossling_telegraphed_lunge() -> void:
	await _reset_player(Vector3(0, 0.05, 0))
	var mossling: Mossling = _spawn(MOSSLING, Vector3(0, 0.1, -4)) as Mossling
	var saw_windup: Array[bool] = [false]
	var hurt_before_windup: Array[bool] = [false]
	var hp: int = GameState.health
	for i: int in 240:
		await get_tree().physics_frame
		if mossling.get_state() == Mossling.State.WINDUP:
			saw_windup[0] = true
		if GameState.health < hp:
			hurt_before_windup[0] = not saw_windup[0]
			break
	_check("mossling winds up (telegraph) before its lunge", saw_windup[0])
	_check("mossling lunge damages the player", GameState.health < hp)
	_check("no damage before the telegraph", not hurt_before_windup[0])
	mossling.queue_free()


func _test_damage_knockback_death() -> void:
	await _reset_player(Vector3(0, 0.05, 6))
	var mossling: Mossling = _spawn(MOSSLING, Vector3(4, 0.1, 6)) as Mossling
	await _frames(5)
	var deaths: Array[EnemyBase] = []
	mossling.died.connect(func(enemy: EnemyBase) -> void: deaths.append(enemy))
	var coins: int = GameState.coins
	mossling.take_hit(1, mossling.global_position + Vector3(-1, 0, 0), 9.0)
	await _frames(1)
	_check("hit enemy is knocked back away from the attacker", mossling.velocity.x > 2.0, "vel=%s" % mossling.velocity)
	_check("hit enemy flashes", mossling._meshes[0].material_overlay != null)
	_check("mossling survives one hit (2 HP)", not mossling.is_dead() and mossling.health == 1)
	await _frames(15)
	mossling.take_hit(1, mossling.global_position + Vector3(-1, 0, 0), 9.0)
	_check("mossling dies on the second hit", mossling.is_dead() and deaths.size() == 1)
	var drops: int = _level.get_children().filter(func(n: Node) -> bool: return n is Coin).size()
	_check("defeated enemy drops its coin reward", drops == mossling.coin_reward and GameState.coins == coins, "drops=%d" % drops)
	var puffs: int = _level.find_children("*", "CPUParticles3D", true, false).size()
	_check("death spawns a puff", puffs > 0)
	await _frames(30)
	_check("dead enemy is removed", not is_instance_valid(mossling))


func _test_player_attack_kills() -> void:
	await _reset_player(Vector3(-2, 0.05, 0))
	var mossling: Mossling = _spawn(MOSSLING, Vector3(-2, 0.1, -1.6)) as Mossling
	mossling.detect_range = 0.0  # Keep it still for this test.
	await _face_forward()
	_teleport(Vector3(-2, 0.05, 0))
	mossling.global_position = Vector3(-2, 0.1, -1.6)
	await _press_action("attack")
	await _frames(20)
	_check("player attack damages the enemy", is_instance_valid(mossling) and mossling.health == 1)
	await _frames(25)
	# The first hit knocked it back; bring it back into reach.
	mossling.global_position = Vector3(-2, 0.1, -1.6)
	mossling.velocity = Vector3.ZERO
	await _frames(2)
	await _press_action("attack")
	await _frames(20)
	_check("second player attack defeats it", not is_instance_valid(mossling) or mossling.is_dead())
	await _frames(30)


func _test_mossling_stays_on_ledge() -> void:
	# SmallPlatform: 2x2, top at y=1.4, centered (-3, -11).
	await _reset_player(Vector3(-3, 0.05, -15.5))
	var mossling: Mossling = _spawn(MOSSLING, Vector3(-3, 1.5, -11)) as Mossling
	await _frames(150)
	_check("chasing mossling doesn't walk off its ledge", mossling.global_position.y > 1.2, "y=%.2f" % mossling.global_position.y)
	mossling.queue_free()


func _test_sporeling_shoots() -> void:
	await _reset_player(Vector3(0, 0.05, 0))
	var sporeling: Sporeling = _spawn(SPORELING, Vector3(0, 0.1, -8)) as Sporeling
	sporeling.retreat_distance = 0.0
	sporeling.approach_distance = 99.0
	sporeling.strafe_speed = 0.0
	var saw_windup: bool = false
	var hp: int = GameState.health
	for i: int in 240:
		await get_tree().physics_frame
		if sporeling.get_state() == Sporeling.State.WINDUP:
			saw_windup = true
		if sporeling.get_shots_fired() > 0:
			sporeling.fire_interval = 99.0  # Only one spore in flight for the next checks.
			break
	_check("sporeling winds up before firing", saw_windup)
	_check("sporeling fires a projectile", sporeling.get_shots_fired() > 0 and _level.find_children("*", "SporeProjectile", true, false).size() > 0)
	var hit: bool = await _wait_until(func() -> bool: return GameState.health < hp, 150)
	_check("spore hits a player who doesn't dodge", hit)
	await _frames(2)
	_check("spore despawns on hit", _level.find_children("*", "SporeProjectile", true, false).is_empty())
	sporeling.queue_free()


func _test_sporeling_keeps_distance() -> void:
	await _reset_player(Vector3(0, 0.05, 0))
	var sporeling: Sporeling = _spawn(SPORELING, Vector3(0, 0.1, -2.5)) as Sporeling
	sporeling.fire_interval = 99.0
	await _frames(20)
	var start: float = Vector2(sporeling.global_position.x - _player.global_position.x, sporeling.global_position.z - _player.global_position.z).length()
	await _frames(90)
	var after: float = Vector2(sporeling.global_position.x - _player.global_position.x, sporeling.global_position.z - _player.global_position.z).length()
	_check("sporeling backs away when the player is close", after > start + 1.0, "%.1f -> %.1f" % [start, after])
	sporeling.queue_free()


func _test_projectile_timeout() -> void:
	var spore: SporeProjectile = SPORE.instantiate() as SporeProjectile
	_level.add_child(spore)
	spore.launch(Vector3(0, 6, 0), Vector3(0, 0, 1), 1, 0.5)
	await _frames(20)
	_check("spore still flying before its lifetime ends", is_instance_valid(spore))
	await _frames(25)
	_check("spore despawns after its lifetime", not is_instance_valid(spore))


func _test_snapthorn() -> void:
	await _reset_player(Vector3(-2, 0.05, 2))
	var plant: Snapthorn = _spawn(SNAPTHORN, Vector3(-2, 0.1, -4)) as Snapthorn
	await _frames(30)
	_check("snapthorn stays dormant while the player is out of reach", plant.get_state() == Snapthorn.State.DORMANT)
	_teleport(Vector3(-2, 0.05, -5.8))
	var hp: int = GameState.health
	var saw_windup: bool = false
	for i: int in 90:
		await get_tree().physics_frame
		if plant.get_state() == Snapthorn.State.WINDUP:
			saw_windup = true
		if GameState.health < hp:
			break
	_check("snapthorn telegraphs before snapping", saw_windup)
	_check("snapthorn snap hurts the player", GameState.health < hp)
	var pos: Vector3 = plant.global_position
	plant.take_hit(1, pos + Vector3(0, 0, 1), 9.0)
	await _frames(10)
	_check("snapthorn is rooted (no knockback)", plant.global_position.distance_to(pos) < 0.05)
	# Let it die properly: the death squash must not touch any physics shape (Jolt scale errors).
	await _frames(15)
	plant.take_hit(1, pos + Vector3(0, 0, 1), 9.0)
	_check("snapthorn dies on its second hit", plant.is_dead())
	await _frames(40)
	_check("dead snapthorn is removed after its death animation", not is_instance_valid(plant))


func _test_sleeping() -> void:
	await _reset_player(Vector3(0, 0.05, 4))
	var far: Mossling = _spawn(MOSSLING, Vector3(0, 30, -150)) as Mossling
	await _frames(30)
	_check("far-away enemy sleeps (no gravity/AI)", absf(far.global_position.y - 30.0) < 0.01)
	far.queue_free()
