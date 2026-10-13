extends Node
## Global run state: current level, player health, coins, Lost Sprites, collected items,
## the active checkpoint (with a snapshot of what was collected), the level timer and boss status.

signal health_changed(current: int, maximum: int)
signal player_died
signal checkpoint_changed(checkpoint_transform: Transform3D)
signal level_started(level_id: String)
signal level_completed(level_id: String)
signal coins_changed(total: int)
signal sprites_changed(collected: int, total: int)
## Collected items were rolled back to the checkpoint snapshot (after a death).
signal items_reverted
signal boss_started(boss_name: String, max_health: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_ended(defeated: bool)

## Scene path of the level being played (empty outside levels).
var current_level: String = ""
## True while the level timer runs (between level start and completion).
var level_running: bool = false
var level_time: float = 0.0

var max_health: int = 5
var health: int = 5

var coins: int = 0
var sprites_total: int = 3
## Ids of collected Lost Sprites.
var sprite_ids: Array[int] = []
## Ids (node paths) of collected persistent pickups.
var collected: Dictionary = {}

var has_checkpoint: bool = false
var checkpoint_transform: Transform3D = Transform3D.IDENTITY

var _snapshot: Dictionary = {}


## Starts a fresh run of a level: checkpoint at the start point, full health, nothing collected.
func begin_level(level_id: String, start_transform: Transform3D) -> void:
	current_level = level_id
	coins = 0
	sprite_ids.clear()
	collected.clear()
	level_time = 0.0
	level_running = true
	set_checkpoint(start_transform)
	restore_health()
	coins_changed.emit(coins)
	sprites_changed.emit(sprite_ids.size(), sprites_total)
	level_started.emit(level_id)


func complete_level() -> void:
	level_running = false
	level_completed.emit(current_level)


func tick_level_time(delta: float) -> void:
	if level_running:
		level_time += delta


#region Health

func setup_health(maximum: int) -> void:
	max_health = maxi(maximum, 1)
	health = max_health
	health_changed.emit(health, max_health)


## Removes health and returns what is left.
func damage(amount: int) -> int:
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		player_died.emit()
	return health


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func restore_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)

#endregion


#region Collectibles

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func is_collected(item_id: String) -> bool:
	return collected.has(item_id)


func mark_collected(item_id: String) -> void:
	if item_id != "":
		collected[item_id] = true


func collect_sprite(sprite_id: int) -> void:
	if not sprite_ids.has(sprite_id):
		sprite_ids.append(sprite_id)
	sprites_changed.emit(sprite_ids.size(), sprites_total)


func sprite_count() -> int:
	return sprite_ids.size()

#endregion


#region Checkpoints

## Sets the respawn point and snapshots what has been collected so far.
func set_checkpoint(xform: Transform3D) -> void:
	has_checkpoint = true
	checkpoint_transform = xform
	_snapshot = {
		"coins": coins,
		"sprite_ids": sprite_ids.duplicate(),
		"collected": collected.duplicate(),
	}
	checkpoint_changed.emit(xform)


## Rolls collected items back to the last checkpoint (called when the player dies).
func revert_to_checkpoint() -> void:
	if _snapshot.is_empty():
		return
	coins = _snapshot["coins"]
	sprite_ids.assign(_snapshot["sprite_ids"])
	collected = (_snapshot["collected"] as Dictionary).duplicate()
	coins_changed.emit(coins)
	sprites_changed.emit(sprite_ids.size(), sprites_total)
	items_reverted.emit()


func clear_checkpoint() -> void:
	has_checkpoint = false
	checkpoint_transform = Transform3D.IDENTITY
	_snapshot = {}

#endregion


#region Boss

func start_boss(boss_name: String, boss_max_health: int) -> void:
	boss_started.emit(boss_name, boss_max_health)
	boss_health_changed.emit(boss_max_health, boss_max_health)


func set_boss_health(current: int, maximum: int) -> void:
	boss_health_changed.emit(current, maximum)


func end_boss(defeated: bool) -> void:
	boss_ended.emit(defeated)

#endregion
