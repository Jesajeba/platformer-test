class_name Pickup
extends Area3D
## Base for collectibles: bobbing/spinning visual, collection on touch, and checkpoint
## persistence. Persistent pickups (placed in the level) are remembered by id; after a death
## they reappear if they were collected after the last checkpoint.
##
## Subclasses override `_on_collected(player)` and optionally `can_collect(player)`.

signal collected(pickup: Pickup)

@export_group("Pickup")
## Placed pickups are persistent; spawned ones (enemy coin drops) are not.
@export var persistent: bool = true
@export var collect_sound: StringName = &""
@export var collect_puff_color: Color = Color(1.0, 0.85, 0.3)

@export_group("Motion")
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.5
@export var spin_speed: float = 2.5

var _collected: bool = false
var _time: float = 0.0
var _visual_base_y: float = 0.0
var _item_id: String = ""
## After reappearing (checkpoint revert) a pickup can't be collected for a moment, so a player
## whose last overlap is still being reported doesn't instantly grab it again.
var _collect_block: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	monitorable = false
	_visual_base_y = _visual.position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	if persistent:
		_item_id = str(get_path())
		GameState.items_reverted.connect(_on_items_reverted)
		if GameState.is_collected(_item_id):
			_set_present(false)
			_collected = true


func _process(delta: float) -> void:
	_time += delta
	if _collect_block > 0.0:
		_collect_block = maxf(_collect_block - delta, 0.0)
		if _collect_block == 0.0 and not _collected and monitoring:
			for body: Node3D in get_overlapping_bodies():
				_on_body_entered(body)
	_visual.position.y = _visual_base_y + sin(_time * bob_speed) * bob_height
	_visual.rotation.y += spin_speed * delta


func is_collected() -> bool:
	return _collected


func get_item_id() -> String:
	return _item_id


## Whether the player may pick this up right now (e.g. hearts only when hurt).
func can_collect(_player: Player) -> bool:
	return true


func try_collect(player: Player) -> bool:
	if _collected or _collect_block > 0.0 or not can_collect(player):
		return false
	_collected = true
	GameState.mark_collected(_item_id)
	_on_collected(player)
	if collect_sound != &"":
		AudioManager.play_sfx(collect_sound)
	Fx.puff(get_parent(), global_position + Vector3.UP * 0.3, collect_puff_color, 10, 0.22, 3.0, 0.4)
	collected.emit(self)
	_play_collect_animation()
	return true


func _on_collected(_player: Player) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		try_collect(body as Player)


func _play_collect_animation() -> void:
	set_deferred("monitoring", false)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.5, 1.5, 1.5), 0.08)
	tween.tween_property(_visual, "scale", Vector3.ZERO, 0.12)
	if persistent:
		tween.tween_callback(func() -> void: visible = false)
	else:
		tween.tween_callback(queue_free)


func _set_present(present: bool) -> void:
	visible = present
	set_deferred("monitoring", present)
	if present:
		_visual.scale = Vector3.ONE
		_collect_block = 0.5


func _on_items_reverted() -> void:
	if _collected and not GameState.is_collected(_item_id):
		_collected = false
		_set_present(true)
