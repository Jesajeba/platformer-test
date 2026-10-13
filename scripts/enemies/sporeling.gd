class_name Sporeling
extends EnemyBase
## Shooter. Keeps its distance from the player, backs off (or strafes at ledges) when
## crowded, and fires slow, dodgeable spores on a timer after a visible wind-up.

enum State { IDLE, ALERT, COMBAT, WINDUP, COOLDOWN }

@export_group("Detection")
@export var detect_range: float = 13.0
@export var lose_range: float = 20.0

@export_group("Spacing")
## Backs away when the player is closer than this.
@export var retreat_distance: float = 4.5
## Walks closer when the player is further than this.
@export var approach_distance: float = 10.0
@export var move_speed: float = 2.6
@export var strafe_speed: float = 1.6
@export var strafe_switch_time: float = 1.6
@export var acceleration: float = 14.0

@export_group("Shooting")
@export var projectile_scene: PackedScene
@export var attack_range: float = 12.0
@export var fire_interval: float = 2.2
@export var windup_time: float = 0.7
@export var projectile_speed: float = 6.0
@export var projectile_damage: int = 1
@export var projectile_lifetime: float = 4.0
@export var muzzle_height: float = 1.0

var _state: State = State.IDLE
var _state_time: float = 0.0
var _fire_timer: float = 1.0
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _anim_time: float = 0.0
var _shots_fired: int = 0

@onready var _cap: Node3D = $Visual/Cap


func get_state() -> State:
	return _state


func get_shots_fired() -> int:
	return _shots_fired


func _set_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	match new_state:
		State.ALERT:
			_show_alert(0.5)
		State.COOLDOWN:
			set_telegraph(0.0)
			_fire_timer = fire_interval


func _ai_process(delta: float) -> void:
	_state_time += delta
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	var distance: float = _distance_to_player()
	var targetable: bool = _player_targetable()

	match _state:
		State.IDLE:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			if targetable and distance < detect_range:
				_set_state(State.ALERT)
		State.ALERT:
			_face(_flat_direction_to_player())
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			if _state_time >= 0.5:
				_fire_timer = minf(_fire_timer, 0.6)
				_set_state(State.COMBAT)
		State.COMBAT, State.COOLDOWN:
			if not targetable or distance > lose_range:
				_set_state(State.IDLE)
				return
			var to_player: Vector3 = _flat_direction_to_player()
			_face(to_player)
			_keep_distance(to_player, distance, delta)
			# Backing off takes priority over shooting when the player is crowding it.
			if _fire_timer <= 0.0 and distance >= retreat_distance and distance <= attack_range and _can_see_player(muzzle_height):
				_set_state(State.WINDUP)
		State.WINDUP:
			_face(_flat_direction_to_player())
			_move(Vector3.ZERO, 0.0, acceleration * 2.0, delta)
			set_telegraph(_state_time / windup_time)
			if _state_time >= windup_time:
				_fire()
				_set_state(State.COOLDOWN)


func _keep_distance(to_player: Vector3, distance: float, delta: float) -> void:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = strafe_switch_time
		_strafe_sign = -_strafe_sign
	var side: Vector3 = to_player.cross(Vector3.UP) * _strafe_sign
	if distance < retreat_distance:
		var away: Vector3 = -to_player
		if _is_edge_ahead(away):
			# Cornered at a ledge: slide sideways instead.
			if _is_edge_ahead(side):
				side = -side
			_move(side, move_speed, acceleration, delta)
		else:
			_move((away + side * 0.4).normalized(), move_speed, acceleration, delta)
	elif distance > approach_distance:
		_move(to_player, move_speed, acceleration, delta)
	else:
		if _is_edge_ahead(side):
			_strafe_sign = -_strafe_sign
			side = -side
		_move(side, strafe_speed, acceleration, delta)


func _fire() -> void:
	if projectile_scene == null or _player == null:
		return
	var projectile: SporeProjectile = projectile_scene.instantiate() as SporeProjectile
	get_parent().add_child(projectile)
	var muzzle: Vector3 = global_position + Vector3.UP * muzzle_height + _facing * 0.6
	var aim: Vector3 = _player.global_position + Vector3.UP * 0.6
	projectile.launch(muzzle, (aim - muzzle).normalized() * projectile_speed, projectile_damage, projectile_lifetime)
	_shots_fired += 1
	AudioManager.play_sfx(&"spore_fire")
	_cap.scale = Vector3(0.8, 1.3, 0.8)


func _on_hurt() -> void:
	if _state == State.WINDUP:
		_set_state(State.COOLDOWN)
	elif _state == State.IDLE:
		_set_state(State.ALERT)


func _update_visual(delta: float) -> void:
	_anim_time += delta
	var cap_target: Vector3 = Vector3.ONE
	var body_target: Vector3 = Vector3.ONE
	if _state == State.WINDUP:
		var t: float = clampf(_state_time / windup_time, 0.0, 1.0)
		cap_target = Vector3(1.0 + 0.35 * t, 1.0 - 0.2 * t, 1.0 + 0.35 * t)
		_cap.position.x = sin(_anim_time * 55.0) * 0.03 * t
	else:
		_cap.position.x = 0.0
		var sway: float = sin(_anim_time * 2.5) * 0.03
		body_target = Vector3(1.0 - sway, 1.0 + sway, 1.0 - sway)
	_cap.scale = _cap.scale.lerp(cap_target, 1.0 - exp(-12.0 * delta))
	_visual.scale = _visual.scale.lerp(body_target, 1.0 - exp(-10.0 * delta))
