extends SmokeTestBase
## Headless smoke test for Stage 5: pickups, HUD, checkpoint item snapshots, breakables, audio.
## Run: godot --headless --path . res://tests/stage5_collectibles_test.tscn

const MOSSLING: PackedScene = preload("res://scenes/enemies/mossling.tscn")

var _hud: Hud


func _init() -> void:
	level_scene = load("res://scenes/levels/level_ruins.tscn")


func _run() -> void:
	await _frames(10)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	_hud = _level.get_node("Hud") as Hud
	(_level as Level).use_game_over_screen = false  # Deaths auto-respawn; Stage 7 tests the Game Over screen.
	_test_level_contents()
	_test_sounds()
	_test_hud_initial()
	await _test_coin()
	await _test_hearts()
	await _test_lost_sprite()
	await _test_checkpoint_revert()
	await _test_pit_keeps_items()
	await _test_breakable_wall()
	await _test_enemy_drops()
	await _test_boss_bar()
	_check("level timer is running", GameState.level_time > 1.0 and GameState.level_running, "%.1f s" % GameState.level_time)


func _coins() -> Array[Coin]:
	var result: Array[Coin] = []
	for node: Node in _level.get_node("Pickups/Coins").get_children():
		result.append(node as Coin)
	return result


## Places the player so a pickup at `pos` overlaps them, and waits a moment.
func _touch(pos: Vector3, ground_y: float) -> void:
	_teleport(Vector3(pos.x, ground_y + 0.05, pos.z))
	await _frames(6)


func _test_level_contents() -> void:
	var coins: Array[Coin] = _coins()
	_check("level has plenty of coins (100+)", coins.size() >= 100, str(coins.size()))
	_check("level has 3 Lost Sprites with ids 1-3", _level.find_children("*", "LostSprite", true, false).size() == 3)
	_check("level has health pickups", _level.find_children("*", "HealthPickup", true, false).size() >= 3)
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var buried: PackedStringArray = PackedStringArray()
	for coin: Coin in coins:
		var query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
		query.position = coin.global_position
		query.collision_mask = 1
		if not space.intersect_point(query).is_empty():
			buried.append("%s" % coin.global_position)
	_check("no coin is buried inside geometry", buried.is_empty(), ", ".join(buried))


func _test_sounds() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for sound: StringName in [&"coin", &"sprite", &"heal", &"checkpoint", &"wall_break", &"stone_hit", &"jump",
			&"hover", &"attack", &"hit", &"hurt", &"enemy_death", &"spore_fire", &"land", &"ui_move", &"ui_select", &"ui_back"]:
		var stream: AudioStream = AudioManager.get_stream(sound)
		if stream == null or (stream is AudioStreamWAV and (stream as AudioStreamWAV).data.size() < 100):
			missing.append(String(sound))
	_check("every placeholder sound builds", missing.is_empty(), ", ".join(missing))
	_check("audio buses exist (Music, SFX, UI)", AudioServer.get_bus_index(&"Music") > 0 and AudioServer.get_bus_index(&"SFX") > 0 and AudioServer.get_bus_index(&"UI") > 0)


func _test_hud_initial() -> void:
	_check("HUD shows 5 hearts, all full", _hud.get_heart_count() == 5 and _hud.get_filled_hearts() == 5)
	_check("HUD coin counter starts at 0", (_hud.get_node("Root/TopLeft/Coins/Label") as Label).text == "0")
	_check("HUD sprite counter shows 0/3", (_hud.get_node("Root/TopLeft/Sprites/Label") as Label).text == "0/3")
	_check("boss bar is hidden outside the boss fight", not (_hud.get_node("Root/BossPanel") as Control).visible)


func _test_coin() -> void:
	var coin: Coin = _coins()[0]
	await _touch(coin.global_position, 0.0)
	_check("touching a coin collects it", GameState.coins == 1 and coin.is_collected())
	_check("coin plays its sound", AudioManager.last_played == &"coin")
	_check("HUD coin counter updates", (_hud.get_node("Root/TopLeft/Coins/Label") as Label).text == "1")
	await _frames(20)
	_check("collected coin disappears", not coin.visible)


func _test_hearts() -> void:
	var heart: HealthPickup = _level.get_node("Pickups/Hearts/Heart1") as HealthPickup
	GameState.damage(3)
	await _frames(3)
	_check("HUD hearts drop with damage", _hud.get_filled_hearts() == 2)
	GameState.restore_health()
	await _touch(heart.global_position, 2.0)
	_check("heart isn't used up at full health", not heart.is_collected())
	GameState.damage(3)
	await _frames(5)
	_check("heart heals when the player is hurt (+2)", heart.is_collected() and GameState.health == 4, "hp=%d" % GameState.health)
	_check("HUD hearts refill", _hud.get_filled_hearts() == 4)
	GameState.restore_health()


func _test_lost_sprite() -> void:
	var sprite: LostSprite = _level.find_child("LostSprite1", true, false) as LostSprite
	await _touch(sprite.global_position, 0.0)
	_check("touching a Lost Sprite collects it", GameState.sprite_count() == 1 and sprite.is_collected())
	_check("Lost Sprite plays its sound", AudioManager.last_played == &"sprite")
	_check("HUD sprite counter shows 1/3", (_hud.get_node("Root/TopLeft/Sprites/Label") as Label).text == "1/3")


func _test_checkpoint_revert() -> void:
	var checkpoint: Checkpoint = _level.find_child("Checkpoint1", true, false) as Checkpoint
	await _touch(checkpoint.get_spawn_transform().origin, 2.0)
	_check("checkpoint plays its sound", AudioManager.last_played == &"checkpoint")
	var coins_at_checkpoint: int = GameState.coins
	var first_coin: Coin = _coins()[0]

	# Collect a coin and a Lost Sprite after the checkpoint...
	var later_coin: Coin = null
	for coin: Coin in _coins():
		if absf(coin.global_position.z + 80.0) < 0.1 and coin.global_position.x > 14.0 and coin.global_position.x < 16.0:
			later_coin = coin
			break
	await _touch(later_coin.global_position, 2.0)
	var sprite3: LostSprite = _level.find_child("LostSprite3", true, false) as LostSprite
	await _touch(sprite3.global_position, 14.0)
	_check("collected a coin and a sprite after the checkpoint", GameState.coins == coins_at_checkpoint + 1 and GameState.sprite_count() == 2)

	# ...then die.
	GameState.health = 1
	_player.take_damage(1, _player.global_position + Vector3.RIGHT)
	await _wait_until(func() -> bool: return _player.get_state() == Player.State.IDLE and _player.global_position.distance_to(checkpoint.get_spawn_transform().origin) < 0.5, 180)
	await _frames(3)
	_check("death reverts coins to the checkpoint", GameState.coins == coins_at_checkpoint, "%d vs %d" % [GameState.coins, coins_at_checkpoint])
	_check("death reverts sprites to the checkpoint", GameState.sprite_count() == 1)
	_check("coin collected after the checkpoint reappears", not later_coin.is_collected() and later_coin.visible and later_coin.monitoring)
	_check("Lost Sprite collected after the checkpoint reappears", not sprite3.is_collected() and sprite3.visible)
	_check("coin collected before the checkpoint stays collected", first_coin.is_collected() and not first_coin.visible)
	_check("HUD reflects the reverted counts", (_hud.get_node("Root/TopLeft/Sprites/Label") as Label).text == "1/3")
	await _wait_until(func() -> bool: return not _player.is_invincible(), 150)


func _test_pit_keeps_items() -> void:
	var coin: Coin = null
	for candidate: Coin in _coins():
		if not candidate.is_collected() and candidate.global_position.z < -33.0 and candidate.global_position.z > -44.0:
			coin = candidate
			break
	await _touch(coin.global_position, 2.0)
	var coins: int = GameState.coins
	_teleport(Vector3(3, 3, -60))  # Into the hover gap, beside the coin arc.
	var checkpoint_pos: Vector3 = GameState.checkpoint_transform.origin
	await _wait_until(func() -> bool: return _player.global_position.distance_to(checkpoint_pos) < 0.5, 180)
	await _frames(3)
	_check("falling in a pit keeps collected items", GameState.coins == coins and coin.is_collected())
	await _wait_until(func() -> bool: return not _player.is_invincible(), 150)
	GameState.restore_health()


func _test_breakable_wall() -> void:
	var wall: BreakableWall = _level.find_child("BlockingWall", true, false) as BreakableWall
	var particles_before: int = _level.find_children("*", "CPUParticles3D", true, false).size()
	wall.take_hit(1, wall.global_position + Vector3(-2, 0, 0), 9.0)
	_check("first hit on a wall plays a stone hit", AudioManager.last_played == &"stone_hit")
	wall.take_hit(1, wall.global_position + Vector3(-2, 0, 0), 9.0)
	await _frames(2)
	_check("breaking a wall plays the break sound", AudioManager.last_played == &"wall_break")
	_check("breaking a wall throws debris and dust", _level.find_children("*", "CPUParticles3D", true, false).size() >= particles_before + 2)
	await _frames(30)
	_check("broken wall is removed", not is_instance_valid(wall))


func _test_enemy_drops() -> void:
	_teleport(Vector3(0, 0.05, -2))
	await _frames(5)
	var mossling: Mossling = MOSSLING.instantiate() as Mossling
	mossling.detect_range = 0.0
	_level.add_child(mossling)
	mossling.global_position = Vector3(3, 0.1, -6)
	await _frames(5)
	var coins_before: int = GameState.coins
	mossling.take_hit(5, mossling.global_position + Vector3.LEFT, 0.0)
	await _frames(2)
	var drops: Array[Coin] = []
	for node: Node in _level.get_children():
		if node is Coin:
			drops.append(node as Coin)
	_check("defeated enemy drops coin pickups (not instant coins)", drops.size() == mossling.coin_reward and GameState.coins == coins_before, "drops=%d" % drops.size())
	await _frames(90)
	var landed: bool = drops.all(func(c: Variant) -> bool: return is_instance_valid(c) and absf((c as Coin).global_position.y - 0.6) < 0.2)
	_check("dropped coins land on the ground", landed)
	_check("dropped coins aren't tracked by checkpoints", drops.all(func(c: Variant) -> bool: return is_instance_valid(c) and not (c as Coin).persistent))
	for coin: Coin in drops:
		await _touch(coin.global_position, 0.0)
	_check("dropped coins can be collected", GameState.coins == coins_before + drops.size(), "%d" % GameState.coins)


func _test_boss_bar() -> void:
	var panel: Control = _hud.get_node("Root/BossPanel") as Control
	var bar: ProgressBar = _hud.get_node("Root/BossPanel/Bar") as ProgressBar
	GameState.start_boss("King Mossback", 30)
	await _frames(3)
	_check("boss bar appears when the boss fight starts", panel.visible and (_hud.get_node("Root/BossPanel/Name") as Label).text == "King Mossback")
	GameState.set_boss_health(15, 30)
	await _frames(30)
	_check("boss bar tracks boss health", absf(bar.value - 15.0) < 0.5, "%.1f" % bar.value)
	GameState.end_boss(true)
	await _frames(120)
	_check("boss bar hides after the fight", not panel.visible)
