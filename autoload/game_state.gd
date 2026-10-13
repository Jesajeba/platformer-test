extends Node
## Global run state: current level, player health and the active checkpoint.
## Coins, collectibles and the level timer are added in later stages.

signal health_changed(current: int, maximum: int)
signal player_died
signal checkpoint_changed(checkpoint_transform: Transform3D)
signal level_started(level_id: String)
signal level_completed(level_id: String)

## Scene path of the level being played (empty outside levels).
var current_level: String = ""

var max_health: int = 5
var health: int = 5

var has_checkpoint: bool = false
var checkpoint_transform: Transform3D = Transform3D.IDENTITY


## Starts a fresh run of a level: checkpoint at the start point, full health.
func begin_level(level_id: String, start_transform: Transform3D) -> void:
	current_level = level_id
	set_checkpoint(start_transform)
	restore_health()
	level_started.emit(level_id)


func complete_level() -> void:
	level_completed.emit(current_level)


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


func set_checkpoint(xform: Transform3D) -> void:
	has_checkpoint = true
	checkpoint_transform = xform
	checkpoint_changed.emit(xform)


func clear_checkpoint() -> void:
	has_checkpoint = false
	checkpoint_transform = Transform3D.IDENTITY
