class_name Mossling
extends EnemyBase
## Chaser. Wanders near its spawn until the player comes close, shows "!", chases,
## then crouches (telegraph) and lunges. Gives up when the player gets far away.

enum State { IDLE, PATROL, ALERT, CHASE, WINDUP, LUNGE, RECOVER, RETURN }

@export_group("Detection")
@export var detect_range: float = 8.0
@export var lose_range: float = 15.0

@export_group("Patrol")
@export var patrol_radius: float = 3.0
@export var patrol_speed: float = 1.6
@export var idle_time_min: float = 1.0
@export var idle_time_max: float = 2.5

@export_group("Chase")
@export var chase_speed: float = 4.2
@export var acceleration: float = 18.0
@export var alert_time: float = 0.5

@export_group("Lunge Attack")
@export var lunge_range: float = 2.6
@export var windup_time: float = 0.55
@export var lunge_speed: float = 9.0
@export var lunge_time: float = 0.28
@export var recover_time: float = 0.7

var _state: State = State.IDLE
var _state_time: float = 0.0
var _home: Vector3
var _patrol_target: Vector3
var _idle_duration: float = 1.5
var _lunge_direction: Vector3 = Vector3.FORWARD
var _anim_time: float = 0.0


func _ready() -> void:
	super()
	_home = global_position
	_idle_duration = randf_range(idle_time_min, idle_time_max)


func get_state() -> State:
	return _state


func _set_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	match new_state:
		State.ALERT:
			_show_alert(alert_time)
			velocity.y = 4.0  # Little surprised hop.
		State.IDLE:
			_idle_duration = randf_range(idle_time_min, idle_time_max)
		State.PATROL:
			var angle: float = randf() * TAU
			_patrol_target = _home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.5, patrol_radius)
		State.LUNGE:
			_lunge_direction = _flat_direction_to_player()
			_face(_lunge_direction)
			set_telegraph(0.0)
		State.RECOVER:
			set_telegraph(0.0)


func _ai_process(delta: float) -> void:
	_state_time += delta
	var distance: float = _distance_to_player()
	var targetable: bool = _player_targetable()

	match _state:
		State.IDLE:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			if targetable and distance < detect_range:
				_set_state(State.ALERT)
			elif _state_time > _idle_duration:
				_set_state(State.PATROL)
		State.PATROL:
			var to_target: Vector3 = _patrol_target - global_position
			to_target.y = 0.0
			_face(to_target)
			_move(to_target.normalized(), patrol_speed, acceleration, delta)
			if targetable and distance < detect_range:
				_set_state(State.ALERT)
			elif to_target.length() < 0.4 or _state_time > 4.0:
				_set_state(State.IDLE)
		State.ALERT:
			_face(_flat_direction_to_player())
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			if _state_time >= alert_time:
				_set_state(State.CHASE)
		State.CHASE:
			var direction: Vector3 = _flat_direction_to_player()
			_face(direction)
			_move(direction, chase_speed, acceleration, delta)
			if not targetable or distance > lose_range:
				_set_state(State.RETURN)
			elif distance < lunge_range and is_on_floor():
				_set_state(State.WINDUP)
		State.WINDUP:
			_face(_flat_direction_to_player())
			_move(Vector3.ZERO, 0.0, acceleration * 2.0, delta)
			set_telegraph(_state_time / windup_time)
			if _state_time >= windup_time:
				_set_state(State.LUNGE)
		State.LUNGE:
			var lunge: Vector3 = _lunge_direction * lunge_speed
			if avoid_edges and _is_edge_ahead(_lunge_direction):
				lunge = Vector3.ZERO
			velocity.x = lunge.x
			velocity.z = lunge.z
			if _state_time >= lunge_time:
				_set_state(State.RECOVER)
		State.RECOVER:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			if _state_time >= recover_time:
				_set_state(State.CHASE if targetable and distance < lose_range else State.RETURN)
		State.RETURN:
			var to_home: Vector3 = _home - global_position
			to_home.y = 0.0
			_face(to_home)
			_move(to_home.normalized(), patrol_speed * 1.5, acceleration, delta)
			if targetable and distance < detect_range * 0.8:
				_set_state(State.CHASE)
			elif to_home.length() < 0.5 or _state_time > 8.0:
				_set_state(State.IDLE)


func _on_hurt() -> void:
	if _state == State.WINDUP or _state == State.LUNGE:
		_set_state(State.RECOVER)
	elif _state == State.IDLE or _state == State.PATROL or _state == State.RETURN:
		_set_state(State.CHASE)


func _update_visual(delta: float) -> void:
	_anim_time += delta
	var target: Vector3 = Vector3.ONE
	match _state:
		State.IDLE:
			var breathe: float = sin(_anim_time * 3.0) * 0.04
			target = Vector3(1.0 - breathe, 1.0 + breathe, 1.0 - breathe)
		State.PATROL, State.RETURN, State.CHASE:
			var hop: float = absf(sin(_anim_time * (14.0 if _state == State.CHASE else 8.0))) * 0.12
			target = Vector3(1.0 - hop * 0.5, 1.0 + hop, 1.0 - hop * 0.5)
		State.WINDUP:
			var t: float = clampf(_state_time / windup_time, 0.0, 1.0)
			target = Vector3(1.0 + 0.3 * t, 1.0 - 0.35 * t, 1.0 + 0.3 * t)
			_visual.position.x = sin(_anim_time * 60.0) * 0.04 * t
		State.LUNGE:
			target = Vector3(0.8, 0.9, 1.35)
		State.RECOVER:
			target = Vector3(1.1, 0.9, 1.1)
	if _state != State.WINDUP:
		_visual.position.x = 0.0
	_visual.scale = _visual.scale.lerp(target, 1.0 - exp(-14.0 * delta))
