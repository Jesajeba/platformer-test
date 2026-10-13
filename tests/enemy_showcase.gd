extends SmokeTestBase
## Visual check: all three enemy types in the test greybox, idle and then attacking.
## Run windowed: godot --path . res://tests/enemy_showcase.tscn

const MOSSLING: PackedScene = preload("res://scenes/enemies/mossling.tscn")
const SPORELING: PackedScene = preload("res://scenes/enemies/sporeling.tscn")
const SNAPTHORN: PackedScene = preload("res://scenes/enemies/snapthorn.tscn")


func _run() -> void:
	_teleport(Vector3(0, 0.05, 6))
	var mossling: Mossling = _spawn(MOSSLING, Vector3(-2.5, 0.1, 1)) as Mossling
	var sporeling: Sporeling = _spawn(SPORELING, Vector3(0.5, 0.1, -1)) as Sporeling
	var snapthorn: Snapthorn = _spawn(SNAPTHORN, Vector3(3, 0.1, 2)) as Snapthorn
	for enemy: EnemyBase in [mossling, sporeling, snapthorn]:
		enemy.contact_enabled = false
	sporeling.retreat_distance = 0.0
	mossling.detect_range = 0.0
	await _frames(40)
	# Close in so everything reacts.
	mossling.detect_range = 8.0
	_teleport(Vector3(0.5, 0.05, 3.2))
	await _frames(120)


func _spawn(scene: PackedScene, pos: Vector3) -> EnemyBase:
	var enemy: EnemyBase = scene.instantiate() as EnemyBase
	enemy.rotation_degrees.y = 180.0
	_level.add_child(enemy)
	enemy.global_position = pos
	return enemy
