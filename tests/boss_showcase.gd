extends SmokeTestBase
## Visual check of the boss fight: intro, slam + shockwave, vulnerable window, barrage, charge
## into a pillar and phase 3 rocks. Run windowed: godot --path . res://tests/boss_showcase.tscn

## Frame numbers (at 60 fps) where each beat is on screen, for --write-movie captures.
var marks: Dictionary = {}
var _frame: int = 0


func _init() -> void:
	level_scene = load("res://scenes/levels/level_ruins.tscn")


func _physics_process(_delta: float) -> void:
	_frame += 1


func _run() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	var arena: BossArena = _level.get_node("BossArena") as BossArena
	var boss: KingMossback = arena.boss
	var center: Vector3 = arena.arena_center.global_position
	_teleport(Vector3(259.5, 10.05, -80))
	await _frames(70)
	_mark("intro")
	await _frames(int(arena.intro_duration * 60.0))
	boss.idle_time = 999.0
	_teleport(Vector3(center.x - 6, 10.05, center.z + 3))
	boss.start_attack(KingMossback.Attack.SLAM)
	await _frames(45)
	_mark("slam_windup")
	await _frames(25)
	_mark("shockwave")
	await _frames(40)
	_mark("vulnerable")
	await _wait_until(func() -> bool: return boss.get_state() == KingMossback.State.IDLE, 300)
	GameState.restore_health()
	boss.start_attack(KingMossback.Attack.BARRAGE)
	await _frames(80)
	_mark("barrage")
	await _wait_until(func() -> bool: return boss.get_state() == KingMossback.State.IDLE, 400)
	boss.phase = 3
	boss.phase_changed.emit(3)
	await _frames(120)
	_mark("phase3_rocks")
	print("MARKS ", marks)


func _mark(beat: String) -> void:
	marks[beat] = _frame
