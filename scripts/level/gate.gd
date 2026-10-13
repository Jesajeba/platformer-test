class_name Gate
extends Node3D
## Stone gateway with bars that slide into the ground to open.
## Used for the boss arena entrance (closes behind the player) and exit (opens on victory).

signal opened
signal closed

@export var start_open: bool = false
@export_group("Motion")
@export var open_depth: float = 4.2
@export var move_duration: float = 1.0

var _is_open: bool = false
var _closed_y: float = 0.0
var _tween: Tween

@onready var _bars: AnimatableBody3D = $Bars


func _ready() -> void:
	_closed_y = _bars.position.y
	_is_open = start_open
	_bars.position.y = _closed_y - open_depth if start_open else _closed_y


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_move_bars(_closed_y - open_depth)
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_move_bars(_closed_y)
	closed.emit()


func _move_bars(target_y: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_bars, "position:y", target_y, move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
