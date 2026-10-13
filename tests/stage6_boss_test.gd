extends SmokeTestBase
## Headless smoke test for Stage 6: the King Mossback boss fight.
## Run: godot --headless --path . res://tests/stage6_boss_test.tscn

const FLOOR_Y: float = 10.0

var _arena: BossArena
var _boss: KingMossback
var _center: Vector3


func _init() -> void:
	level_scene = load("res://scenes/levels/level_ruins.tscn")


func _run() -> void:
	await _frames(10)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	_arena = _level.get_node("BossArena") as BossArena
	(_level as Level).use_game_over_screen = false  # Deaths auto-respawn; Stage 7 tests the Game Over screen.
	_boss = _arena.boss
	_center = _arena.arena_center.global_position
	await _frames(2)

	await _test_intro()
	_boss.idle_time = 999.0  # Only the attacks the test starts.
	await _test_clank()
	await _test_slam_and_vulnerable()
	await _test_jump_over_shockwave()
	await _test_summon()
	await _test_phase2_and_barrage()
	await _test_charge()
	await _test_phase3()
	await _test_death_resets_fight()
	await _test_defeat()


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FLOOR_Y + 0.05, z)


func _heal() -> void:
	GameState.restore_health()


func _place_boss(pos: Vector3) -> void:
	_boss.global_position = Vector3(pos.x, FLOOR_Y + 0.1, pos.z)
	_boss.velocity = Vector3.ZERO
	await _frames(3)


## Hits the boss `count` times, waiting out his short hit invulnerability between hits.
func _hit_boss(count: int) -> void:
	for i: int in count:
		_boss.take_hit(1, _boss.global_position + Vector3(0, 0, 3), 9.0)
		await _frames(12)


func _test_intro() -> void:
	_teleport(_ground(256.5, -80))
	await _frames(5)
	_check("arena waits for the player", _arena.get_state() == BossArena.State.WAITING and _boss.get_state() == KingMossback.State.INACTIVE)
	_teleport(_ground(259.5, -80))
	await _frames(5)
	_check("entering the arena starts the intro", _arena.get_state() == BossArena.State.INTRO)
	_check("entrance gate closes behind the player", not _arena.entrance_gate.is_open())
	_check("intro: player controls are locked", not _player.controls_enabled)
	_check("intro: camera moves to the boss", _camera.has_override())
	_check("intro: name card shows", _arena.get_name_card().is_showing())
	_check("boss health bar appears", (_level.get_node("Hud/Root/BossPanel") as Control).visible)
	_check("deaths now respawn at the arena entrance", GameState.checkpoint_transform.origin.distance_to(_arena.entrance_spawn.global_position) < 0.01)
	await _frames(int(_arena.intro_duration * 60.0) + 15)
	_check("after the intro the fight begins", _arena.get_state() == BossArena.State.FIGHTING and _boss.get_state() != KingMossback.State.INACTIVE)
	_check("controls return after the intro", _player.controls_enabled and not _camera.has_override())


func _test_clank() -> void:
	await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.IDLE, 300)
	var hp: int = _boss.health
	_boss.take_hit(1, _boss.global_position + Vector3(0, 0, 3), 9.0)
	_check("hits outside a vulnerable window clank off", _boss.health == hp and AudioManager.last_played == &"stone_hit")


func _test_slam_and_vulnerable() -> void:
	_heal()
	await _place_boss(_center)
	_teleport(_ground(_center.x + 6.0, _center.z))
	await _frames(2)
	var hp: int = GameState.health
	_boss.start_attack(KingMossback.Attack.SLAM)
	_check("slam starts with a wind-up (telegraph)", _boss.get_state() == KingMossback.State.SLAM_WINDUP)
	var waved: bool = await _wait_until(func() -> bool: return not get_tree().get_nodes_in_group("boss_hazards").is_empty(), 90)
	_check("slam sends out a shockwave", waved)
	var hurt: bool = await _wait_until(func() -> bool: return GameState.health < hp, 90)
	_check("shockwave hurts a player standing in its path", hurt)
	_check("boss is vulnerable after the slam", _boss.is_vulnerable())
	_check("vulnerability is shown (dizzy stars + 'Attack!')", _boss.get_node("Visual/DizzyStars").visible and _boss.get_node("VulnerableLabel").visible)
	var boss_hp: int = _boss.health
	await _hit_boss(4)
	_check("vulnerable boss takes damage", _boss.health < boss_hp)
	_check("only %d hits count per window" % _boss.max_hits_per_window, _boss.health == boss_hp - _boss.max_hits_per_window, "hp %d -> %d" % [boss_hp, _boss.health])
	var bar: ProgressBar = _level.get_node("Hud/Root/BossPanel/Bar") as ProgressBar
	await _frames(20)
	_check("HUD boss bar follows his health", absf(bar.value - _boss.health) < 0.5, "%.1f vs %d" % [bar.value, _boss.health])
	await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.IDLE, 200)
	await _wait_until(func() -> bool: return not _player.is_invincible(), 150)


func _test_jump_over_shockwave() -> void:
	_heal()
	await _place_boss(_center)
	_teleport(_ground(_center.x - 7.0, _center.z))
	await _frames(5)
	_boss.start_attack(KingMossback.Attack.SLAM)
	await _wait_until(func() -> bool: return not get_tree().get_nodes_in_group("boss_hazards").is_empty(), 120)
	var wave: Shockwave = get_tree().get_nodes_in_group("boss_hazards")[0] as Shockwave
	await _wait_until(func() -> bool: return not is_instance_valid(wave) or wave.get_radius() > 7.0 - 2.2, 120)
	await _press_jump()
	await _frames(30)
	Input.action_release("jump")
	_check("jumping over the shockwave avoids damage", GameState.health == GameState.max_health, "hp=%d" % GameState.health)
	await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.IDLE, 240)


func _test_summon() -> void:
	_boss.start_attack(KingMossback.Attack.SUMMON)
	await _frames(int(_boss.summon_windup * 60.0) + 10)
	var minions: int = _boss._summons.filter(func(n: Node) -> bool: return is_instance_valid(n)).size()
	_check("summon brings in Mosslings", minions == _boss.summon_count, str(minions))
	_boss.clear_minions()
	await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.IDLE, 200)


func _test_phase2_and_barrage() -> void:
	var phases: Array[int] = []
	_boss.phase_changed.connect(func(p: int) -> void: phases.append(p))
	while _boss.phase == 1:
		_boss.force_vulnerable(5.0)
		await _hit_boss(1)
	_check("phase 2 starts at %d health" % _boss.phase2_health, phases.has(2) and _boss.health <= _boss.phase2_health)
	_check("phase change has a transition (roar)", _boss.get_state() == KingMossback.State.PHASE_TRANSITION)
	await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.IDLE, 200)

	_heal()
	_teleport(_ground(_center.x - 10.0, _center.z - 6.0))
	_boss.start_attack(KingMossback.Attack.BARRAGE)
	await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.BARRAGE, 120)
	await _frames(2)
	var first_wave: int = get_tree().get_nodes_in_group("boss_projectiles").size()
	_check("barrage ring has a gap to weave through", first_wave > 0 and first_wave < _boss.barrage_count, "%d of %d" % [first_wave, _boss.barrage_count])
	var max_seen: int = first_wave
	for i: int in 150:
		max_seen = maxi(max_seen, get_tree().get_nodes_in_group("boss_projectiles").size())
		await get_tree().physics_frame
	_check("barrage fires several waves", max_seen >= first_wave * 2, str(max_seen))
	await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.IDLE, 300)
	await _wait_until(func() -> bool: return not _player.is_invincible(), 150)


func _test_charge() -> void:
	# A pillar stands at 45 degrees, 8 m from the center: put the player right behind it.
	_heal()
	var dir: Vector3 = Vector3(cos(PI * 0.25), 0, sin(PI * 0.25))
	await _place_boss(_center)
	var behind_pillar: Vector3 = _center + dir * 11.0
	_teleport(_ground(behind_pillar.x, behind_pillar.z))
	await _frames(30)
	_boss.start_attack(KingMossback.Attack.CHARGE)
	var charged: bool = await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.CHARGE, 120)
	var stunned: bool = await _wait_until(func() -> bool: return _boss.is_vulnerable(), 120)
	_check("charge winds up, then charges", charged)
	_check("charging into a pillar stuns him", stunned and (_boss.get_node("VulnerableLabel") as Label3D).text.begins_with("Dizzy"))
	await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.IDLE, 300)

	# No pillar in the way: he stops at the arena edge and is only briefly open.
	await _place_boss(_center)
	_teleport(_ground(_center.x, _center.z + 10.0))
	await _frames(30)
	_boss.start_attack(KingMossback.Attack.CHARGE)
	var missed: bool = await _wait_until(func() -> bool: return _boss.is_vulnerable(), 300)
	var offset: Vector3 = _boss.global_position - _center
	_check("a missed charge stops at the arena edge", missed and Vector2(offset.x, offset.z).length() <= _arena.arena_radius, "%.1f m" % Vector2(offset.x, offset.z).length())
	_check("a missed charge still leaves a (short) opening", (_boss.get_node("VulnerableLabel") as Label3D).text == "Attack!")
	await _wait_until(func() -> bool: return _boss.get_state() == KingMossback.State.IDLE, 300)
	await _wait_until(func() -> bool: return not _player.is_invincible(), 150)


func _test_phase3() -> void:
	await _place_boss(_center)
	_teleport(_ground(_center.x - 6.0, _center.z))
	while _boss.phase == 2:
		_boss.force_vulnerable(5.0)
		await _hit_boss(1)
	_check("phase 3 starts at %d health" % _boss.phase3_health, _boss.phase == 3 and _boss.health <= _boss.phase3_health)
	_check("phase 3 wind-ups are faster", _boss._windup(1.0) < 1.0)
	await _frames(150)
	var platforms: Array[Node] = _arena.outer_platforms.get_children()
	_check("phase 3: outer platforms crumble away", platforms.all(func(p: Node) -> bool: return (p as GreyboxBlock).collision_layer == 0))
	var rocks_seen: bool = await _wait_until(func() -> bool: return _arena.get_children().any(func(n: Node) -> bool: return n is FallingRock), 200)
	_check("phase 3: rocks fall with ground markers", rocks_seen)

	_heal()
	await _wait_until(func() -> bool: return not _player.is_invincible(), 150)
	var rock: FallingRock = (load("res://scenes/boss/falling_rock.tscn") as PackedScene).instantiate() as FallingRock
	_arena.add_child(rock)
	rock.global_position = Vector3(_player.global_position.x, FLOOR_Y, _player.global_position.z)
	var hp: int = GameState.health
	var hit: bool = await _wait_until(func() -> bool: return GameState.health < hp, 120)
	_check("a falling rock hurts a player under it", hit)
	await _wait_until(func() -> bool: return not _player.is_invincible(), 150)


func _test_death_resets_fight() -> void:
	GameState.health = 1
	_player.take_damage(1, _player.global_position + Vector3.RIGHT)
	await _frames(5)
	_check("player death resets the boss", _boss.health == _boss.max_health and _boss.phase == 1)
	_check("player death restores the arena platforms", _arena.outer_platforms.get_children().all(func(p: Node) -> bool: return (p as GreyboxBlock).collision_layer == 1 and (p as Node3D).visible))
	_check("player death clears hazards and summons", get_tree().get_nodes_in_group("boss_hazards").is_empty())
	var respawned: bool = await _wait_until(func() -> bool: return _player.get_state() != Player.State.DEAD, 150)
	await _frames(3)
	_check("player respawns at the arena entrance", respawned and _player.global_position.distance_to(_arena.entrance_spawn.global_position) < 0.5)
	_check("the fight restarts (short intro)", _arena.get_state() == BossArena.State.INTRO)
	_check("entrance gate stays shut", not _arena.entrance_gate.is_open())
	await _wait_until(func() -> bool: return _arena.get_state() == BossArena.State.FIGHTING, 200)
	_check("fight is back on", _arena.get_state() == BossArena.State.FIGHTING)
	_boss.idle_time = 999.0


func _test_defeat() -> void:
	var ended: Array[bool] = []
	GameState.boss_ended.connect(func(defeated: bool) -> void: ended.append(defeated))
	_boss.phase = 3
	_boss.health = 1
	_boss.force_vulnerable(5.0)
	_boss.take_hit(1, _boss.global_position + Vector3(0, 0, 3), 9.0)
	await _frames(2)
	_check("final hit defeats the boss", _boss.get_state() == KingMossback.State.DEFEATED)
	_check("defeat plays in slow motion", Engine.time_scale < 1.0)
	var done: bool = await _wait_until(func() -> bool: return ended.size() == 1, 600)
	_check("defeat sequence finishes (collapse, boss_ended)", done and ended[0])
	await _frames(10)
	_check("defeated boss leaves a burst of coins", _arena.get_children().filter(func(n: Node) -> bool: return n is Coin).size() >= 5)
	var opened: bool = await _wait_until(func() -> bool: return _arena.exit_gate.is_open(), int((_arena.exit_open_delay + 1.0) * 60.0))
	_check("exit gate opens after the boss falls", opened)

	var completed: Array[String] = []
	GameState.level_completed.connect(func(level_id: String) -> void: completed.append(level_id))
	var goal: Node3D = _level.find_child("LevelGoal", true, false) as Node3D
	await _frames(70)
	_teleport(goal.global_position + Vector3(0, 0.1, 0))
	await _frames(5)
	_check("the open exit leads to the level goal", completed.size() == 1)
