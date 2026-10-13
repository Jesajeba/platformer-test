class_name Snapthorn
extends EnemyBase
## Stationary thorn plant. When the player comes within reach it rears back and glows
## (telegraph), then snaps forward, hurting anything in front of it, and rests.

enum State { DORMANT, WINDUP, SNAP, COOLDOWN }

@export_group("Snap Attack")
@export var trigger_range: float = 3.6
@export var windup_time: float = 0.65
@export var snap_time: float = 0.3
@export var cooldown_time: float = 1.4
@export var snap_damage: int = 1
## How far forward the head reaches when it snaps.
@export var snap_reach: float = 1.4

var _state: State = State.DORMANT
var _state_time: float = 0.0
var _anim_time: float = 0.0
var _head_rest: Vector3
var _snaps: int = 0

@onready var _head: Node3D = $Visual/Head
@onready var _snap_area: Area3D = $Visual/SnapArea


func _ready() -> void:
	super()
	_head_rest = _head.position
	_snap_area.monitoring = true


func get_state() -> State:
	return _state


func get_snap_count() -> int:
	return _snaps


func _set_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	match new_state:
		State.SNAP:
			_snaps += 1
			set_telegraph(0.0)
		State.COOLDOWN, State.DORMANT:
			set_telegraph(0.0)


func _ai_process(delta: float) -> void:
	_state_time += delta
	velocity.x = 0.0
	velocity.z = 0.0
	var distance: float = _distance_to_player()

	match _state:
		State.DORMANT:
			if _player_targetable() and distance < trigger_range:
				_face(_flat_direction_to_player())
				_set_state(State.WINDUP)
		State.WINDUP:
			_face(_flat_direction_to_player())
			set_telegraph(_state_time / windup_time)
			if _state_time >= windup_time:
				_set_state(State.SNAP)
		State.SNAP:
			for body: Node3D in _snap_area.get_overlapping_bodies():
				if body is Player:
					(body as Player).take_damage(snap_damage, global_position)
			if _state_time >= snap_time:
				_set_state(State.COOLDOWN)
		State.COOLDOWN:
			if _state_time >= cooldown_time:
				_set_state(State.DORMANT)


func _on_hurt() -> void:
	if _state == State.WINDUP:
		_set_state(State.COOLDOWN)


func _update_visual(delta: float) -> void:
	_anim_time += delta
	var target: Vector3 = _head_rest
	var head_scale: Vector3 = Vector3.ONE
	match _state:
		State.DORMANT:
			target = _head_rest + Vector3(0, sin(_anim_time * 2.0) * 0.05, 0)
		State.WINDUP:
			var t: float = clampf(_state_time / windup_time, 0.0, 1.0)
			target = _head_rest + Vector3(sin(_anim_time * 50.0) * 0.05 * t, 0.25 * t, 0.5 * t)
			head_scale = Vector3.ONE * (1.0 + 0.2 * t)
		State.SNAP:
			target = _head_rest + Vector3(0, -0.2, -snap_reach)
			head_scale = Vector3(1.25, 0.8, 1.25)
		State.COOLDOWN:
			head_scale = Vector3(0.95, 0.95, 0.95)
	var speed: float = 40.0 if _state == State.SNAP else 10.0
	_head.position = _head.position.lerp(target, 1.0 - exp(-speed * delta))
	_head.scale = _head.scale.lerp(head_scale, 1.0 - exp(-speed * delta))
