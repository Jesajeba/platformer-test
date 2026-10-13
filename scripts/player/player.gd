class_name Player
extends CharacterBody3D
## Player controller: camera-relative movement, variable jump with coyote time and
## jump buffering, a once-per-airtime hover, a melee attack, health and respawn.
##
## Hit interface: anything with `take_hit(damage: int, source_position: Vector3, knockback: float)`
## can be hit by the attack. Hazards and enemies call `take_damage()` on the player.

signal state_changed(new_state: State)
signal jumped
signal hover_started
signal attack_started
signal hit_landed(target: Node)
signal damaged(amount: int)
signal died
signal respawned
## Emitted after any instant position change (respawn, pit) so cameras can snap.
signal teleported

enum State { IDLE, RUN, JUMP, FALL, HOVER, ATTACK, HURT, DEAD }

@export_group("Movement")
@export var max_speed: float = 7.0
@export var acceleration: float = 45.0
@export var deceleration: float = 60.0
@export var air_acceleration: float = 28.0
@export var air_deceleration: float = 12.0
## How quickly the model turns toward the move direction (higher = snappier).
@export var turn_speed: float = 14.0
## Horizontal speed below which the player counts as idle.
@export var idle_speed_threshold: float = 0.4

@export_group("Jump")
## Peak height of a full (held) jump, in meters.
@export var jump_height: float = 2.6
## Seconds to reach the peak of a full jump. Gravity is derived from height and time.
@export var jump_time_to_peak: float = 0.38
@export var fall_gravity_multiplier: float = 1.6
## Upward velocity kept when jump is released early (lower = shorter tap jumps).
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.45
@export var max_fall_speed: float = 30.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Hover")
## Maximum hover time per airtime. Hover lasts while jump is held.
@export var hover_duration: float = 1.2
@export var hover_fall_speed: float = 1.4
## How fast vertical speed settles to the hover fall speed.
@export var hover_vertical_acceleration: float = 30.0
## Small upward pop when the hover starts.
@export var hover_entry_lift: float = 2.0
@export_range(0.0, 1.5) var hover_speed_multiplier: float = 0.8

@export_group("Attack")
@export var attack_damage: int = 1
@export var attack_windup: float = 0.05
@export var attack_active_time: float = 0.14
@export var attack_recovery: float = 0.12
## Extra delay after the recovery before the next attack can start.
@export var attack_cooldown: float = 0.12
@export var attack_knockback: float = 9.0
## Forward burst of speed when attacking on the ground.
@export var attack_lunge_speed: float = 5.0
@export_range(0.0, 1.0) var attack_move_multiplier: float = 0.3
## Gravity scale while attacking in the air (gives a little hang time).
@export_range(0.0, 1.0) var attack_air_gravity_scale: float = 0.4
@export var hit_stop_duration: float = 0.07
@export_range(0.01, 1.0) var hit_stop_time_scale: float = 0.05
@export var swipe_arc_degrees: float = 140.0

@export_group("Health")
@export var max_health: int = 5
@export var invincibility_time: float = 1.2
@export var blink_interval: float = 0.07
@export var hurt_knockback: float = 7.0
@export var hurt_knockback_up: float = 5.0
@export var hurt_stun_time: float = 0.35
## Hearts lost when falling into a pit (then respawn at the checkpoint).
@export var pit_damage: int = 1
@export var respawn_delay: float = 1.2

@export_group("Visuals")
@export var squash_return_speed: float = 12.0
@export var jump_stretch: Vector3 = Vector3(0.75, 1.3, 0.75)
@export var land_squash: Vector3 = Vector3(1.35, 0.65, 1.35)
## Fall speed that produces the full landing squash.
@export var land_squash_full_speed: float = 14.0
@export var hover_puff_scale: Vector3 = Vector3(1.3, 1.2, 1.3)
@export var idle_breathe_amount: float = 0.03
@export var idle_breathe_speed: float = 3.0
@export var run_bob_amount: float = 0.08
@export var run_cycle_speed: float = 2.2
@export var foot_swing: float = 0.18

var _state: State = State.IDLE
var _state_time: float = 0.0
var _anim_time: float = 0.0
var _facing: Vector3 = Vector3.FORWARD

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jump_rising: bool = false
var _can_hover: bool = true
var _hover_timer: float = 0.0

var _attack_cooldown_timer: float = 0.0
var _hit_targets: Array[Node] = []

var _invincible_timer: float = 0.0
var _was_on_floor: bool = true
var _pre_move_velocity_y: float = 0.0

var _foot_left_base: Vector3
var _foot_right_base: Vector3
var _arm_right_base: Vector3

@onready var _visual: Node3D = $Visual
@onready var _squash: Node3D = $Visual/Squash
@onready var _foot_left: Node3D = $Visual/Squash/FootLeft
@onready var _foot_right: Node3D = $Visual/Squash/FootRight
@onready var _arm_right: Node3D = $Visual/Squash/ArmRight
@onready var _hitbox: Area3D = $Visual/AttackHitbox
@onready var _swipe_pivot: Node3D = $Visual/SwipePivot


func _ready() -> void:
	GameState.setup_health(max_health)
	if not GameState.has_checkpoint:
		GameState.set_checkpoint(global_transform)
	_facing = -global_basis.z
	_foot_left_base = _foot_left.position
	_foot_right_base = _foot_right.position
	_arm_right_base = _arm_right.position
	_swipe_pivot.visible = false


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	var move_dir: Vector3 = _get_move_direction() if _has_control() else Vector3.ZERO
	if move_dir.length_squared() > 0.01:
		_facing = move_dir.normalized()

	match _state:
		State.IDLE, State.RUN:
			_state_grounded(delta, move_dir)
		State.JUMP, State.FALL:
			_state_airborne(delta, move_dir)
		State.HOVER:
			_state_hover(delta, move_dir)
		State.ATTACK:
			_state_attack(delta, move_dir)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			_state_dead(delta)

	_pre_move_velocity_y = velocity.y
	if _state != State.DEAD:
		move_and_slide()
	_check_floor_transitions()
	_update_visuals(delta)


#region Public API

func get_state() -> State:
	return _state


func get_state_name() -> String:
	return str(State.keys()[_state])


func is_invincible() -> bool:
	return _invincible_timer > 0.0 or _state == State.DEAD


func get_hover_time_left() -> float:
	return _hover_timer if _state == State.HOVER else 0.0


## Called by hazards and enemies.
func take_damage(amount: int, source_position: Vector3) -> void:
	if is_invincible():
		return
	damaged.emit(amount)
	if GameState.damage(amount) <= 0:
		_die()
		return
	var away: Vector3 = global_position - source_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = -_facing
	velocity = away.normalized() * hurt_knockback + Vector3.UP * hurt_knockback_up
	_invincible_timer = invincibility_time
	_set_state(State.HURT)


## Called by kill planes / pits.
func fall_out() -> void:
	if _state == State.DEAD:
		return
	damaged.emit(pit_damage)
	if GameState.damage(pit_damage) <= 0:
		_die()
		return
	_respawn_at_checkpoint()
	_invincible_timer = invincibility_time


## Moves the player to the active checkpoint without the respawn effects (level start).
func place_at_checkpoint() -> void:
	_respawn_at_checkpoint()


func respawn() -> void:
	GameState.restore_health()
	_respawn_at_checkpoint()
	_invincible_timer = invincibility_time
	respawned.emit()

#endregion


#region States

func _state_grounded(delta: float, move_dir: Vector3) -> void:
	_apply_horizontal(move_dir, max_speed, acceleration, deceleration, delta)
	_apply_gravity(delta)

	if _jump_buffer_timer > 0.0:
		_do_jump()
		return
	if _try_attack():
		return
	if not is_on_floor():
		_set_state(State.FALL)
		return

	var speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = move_dir != Vector3.ZERO or speed > idle_speed_threshold
	_set_state(State.RUN if moving else State.IDLE)


func _state_airborne(delta: float, move_dir: Vector3) -> void:
	_apply_horizontal(move_dir, max_speed, air_acceleration, air_deceleration, delta)

	# Variable jump height: releasing jump while rising cuts the upward velocity.
	if _jump_rising:
		if velocity.y <= 0.0:
			_jump_rising = false
		elif not Input.is_action_pressed("jump"):
			velocity.y *= jump_cut_multiplier
			_jump_rising = false
	_apply_gravity(delta)

	if Input.is_action_just_pressed("jump"):
		if _coyote_timer > 0.0:
			_do_jump()
			return
		if _can_hover:
			_start_hover()
			return
		# Otherwise the press stays buffered and fires on landing.
	if _try_attack():
		return
	_set_state(State.JUMP if velocity.y > 0.0 else State.FALL)


func _state_hover(delta: float, move_dir: Vector3) -> void:
	_hover_timer -= delta
	_apply_horizontal(move_dir, max_speed * hover_speed_multiplier, air_acceleration, air_deceleration, delta)
	velocity.y = move_toward(velocity.y, -hover_fall_speed, hover_vertical_acceleration * delta)

	if _try_attack():
		return
	if _hover_timer <= 0.0 or not Input.is_action_pressed("jump"):
		_set_state(State.FALL)


func _state_attack(delta: float, move_dir: Vector3) -> void:
	var grounded: bool = is_on_floor()
	var accel: float = acceleration if grounded else air_acceleration
	_apply_horizontal(move_dir, max_speed * attack_move_multiplier, accel, deceleration * 0.5, delta)
	_apply_gravity(delta, 1.0 if grounded else attack_air_gravity_scale)

	var active_start: float = attack_windup
	var active_end: float = attack_windup + attack_active_time
	var active: bool = _state_time >= active_start and _state_time < active_end
	_swipe_pivot.visible = active
	if active:
		var t: float = (_state_time - active_start) / maxf(attack_active_time, 0.001)
		var half_arc: float = deg_to_rad(swipe_arc_degrees) * 0.5
		_swipe_pivot.rotation.y = lerpf(half_arc, -half_arc, t)
		_process_attack_hits()

	if _state_time >= active_end + attack_recovery:
		_attack_cooldown_timer = attack_cooldown
		_set_state(_free_state())


func _state_hurt(delta: float) -> void:
	_apply_horizontal(Vector3.ZERO, 0.0, 0.0, air_deceleration, delta)
	_apply_gravity(delta)
	if _state_time >= hurt_stun_time:
		_set_state(_free_state())


func _state_dead(_delta: float) -> void:
	velocity = Vector3.ZERO
	if _state_time >= respawn_delay:
		respawn()

#endregion


#region State helpers

func _set_state(new_state: State) -> void:
	if new_state == _state:
		return
	var old_state: State = _state
	_state = new_state
	_state_time = 0.0

	if old_state == State.ATTACK:
		_swipe_pivot.visible = false
	if old_state == State.DEAD:
		_visual.scale = Vector3.ONE

	match new_state:
		State.HOVER:
			_hover_timer = hover_duration
			_can_hover = false
			_jump_rising = false
			velocity.y = maxf(velocity.y, hover_entry_lift)
			_jump_buffer_timer = 0.0
			hover_started.emit()
		State.ATTACK:
			_hit_targets.clear()
			_jump_rising = false
			if is_on_floor():
				velocity.x = _facing.x * attack_lunge_speed
				velocity.z = _facing.z * attack_lunge_speed
			attack_started.emit()
		State.HURT:
			_jump_rising = false
		State.DEAD:
			_jump_rising = false
			velocity = Vector3.ZERO

	state_changed.emit(new_state)


func _free_state() -> State:
	if is_on_floor():
		return State.IDLE
	return State.JUMP if velocity.y > 0.0 else State.FALL


func _has_control() -> bool:
	return _state != State.HURT and _state != State.DEAD


func _do_jump() -> void:
	velocity.y = _jump_velocity()
	_jump_rising = true
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_squash.scale = jump_stretch
	_set_state(State.JUMP)
	jumped.emit()


func _start_hover() -> void:
	_set_state(State.HOVER)


func _try_attack() -> bool:
	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_set_state(State.ATTACK)
		return true
	return false


func _process_attack_hits() -> void:
	var landed: bool = false
	var targets: Array[Node] = []
	targets.append_array(_hitbox.get_overlapping_bodies())
	targets.append_array(_hitbox.get_overlapping_areas())
	for target: Node in targets:
		if target == self or _hit_targets.has(target):
			continue
		if target.has_method("take_hit"):
			_hit_targets.append(target)
			target.take_hit(attack_damage, global_position, attack_knockback)
			hit_landed.emit(target)
			landed = true
	if landed:
		HitStop.apply(get_tree(), hit_stop_duration, hit_stop_time_scale)


func _die() -> void:
	_invincible_timer = 0.0
	_set_state(State.DEAD)
	died.emit()


func _respawn_at_checkpoint() -> void:
	var xform: Transform3D = GameState.checkpoint_transform
	global_position = xform.origin
	velocity = Vector3.ZERO
	_facing = -xform.basis.z
	_facing.y = 0.0
	_facing = _facing.normalized() if _facing.length_squared() > 0.001 else Vector3.FORWARD
	_visual.rotation.y = atan2(-_facing.x, -_facing.z)
	_can_hover = true
	_jump_rising = false
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_set_state(State.IDLE)
	reset_physics_interpolation()
	teleported.emit()


func _check_floor_transitions() -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_on_floor:
		_on_landed()
	elif not on_floor and _was_on_floor and velocity.y <= 0.0:
		# Walked off a ledge: allow a late jump for a moment.
		_coyote_timer = coyote_time
	_was_on_floor = on_floor


func _on_landed() -> void:
	_can_hover = true
	_jump_rising = false
	_coyote_timer = 0.0
	var impact: float = clampf(-_pre_move_velocity_y / maxf(land_squash_full_speed, 0.01), 0.2, 1.0)
	_squash.scale = Vector3.ONE.lerp(land_squash, impact)
	if _state == State.JUMP or _state == State.FALL or _state == State.HOVER:
		_set_state(State.IDLE)


func _tick_timers(delta: float) -> void:
	_state_time += delta
	_anim_time += delta
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)

#endregion


#region Physics helpers

## Converts stick/WASD input into a world direction relative to the active camera,
## flattened onto the ground plane. Magnitude follows the analog stick (0..1).
func _get_move_direction() -> Vector3:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input == Vector2.ZERO:
		return Vector3.ZERO

	var right: Vector3 = Vector3.RIGHT
	var forward: Vector3 = Vector3.FORWARD
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var cam_basis: Basis = camera.global_basis
		right = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z)
		forward = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z)
		# Looking straight down: use the camera's up vector as "forward" instead.
		if forward.length_squared() < 0.0001:
			forward = Vector3(cam_basis.y.x, 0.0, cam_basis.y.z)
		right = right.normalized()
		forward = forward.normalized()

	var direction: Vector3 = right * input.x - forward * input.y
	return direction.limit_length(1.0)


func _apply_horizontal(move_dir: Vector3, speed: float, accel: float, decel: float, delta: float) -> void:
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target: Vector3 = move_dir * speed
	var rate: float = accel if move_dir != Vector3.ZERO else decel
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _apply_gravity(delta: float, gravity_scale: float = 1.0) -> void:
	var gravity: float = _jump_gravity()
	if velocity.y < 0.0:
		gravity *= fall_gravity_multiplier
	velocity.y = maxf(velocity.y - gravity * gravity_scale * delta, -max_fall_speed)


func _jump_gravity() -> float:
	return 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)


func _jump_velocity() -> float:
	return 2.0 * jump_height / jump_time_to_peak

#endregion


#region Visuals

func _update_visuals(delta: float) -> void:
	var blend: float = 1.0 - exp(-squash_return_speed * delta)

	if _state == State.DEAD:
		_visual.rotation.y += 14.0 * delta
		_visual.scale = _visual.scale.lerp(Vector3(0.1, 0.1, 0.1), 1.0 - exp(-4.0 * delta))
		_squash.visible = true
		return

	var target_yaw: float = atan2(-_facing.x, -_facing.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	var target_scale: Vector3 = Vector3.ONE
	var speed_ratio: float = clampf(Vector2(velocity.x, velocity.z).length() / maxf(max_speed, 0.01), 0.0, 1.0)
	var foot_phase: float = 0.0
	match _state:
		State.IDLE:
			var breathe: float = sin(_anim_time * idle_breathe_speed) * idle_breathe_amount
			target_scale = Vector3(1.0 - breathe * 0.5, 1.0 + breathe, 1.0 - breathe * 0.5)
		State.RUN:
			var bob: float = absf(sin(_anim_time * run_cycle_speed * TAU * 0.5)) * run_bob_amount * speed_ratio
			target_scale = Vector3(1.0 - bob * 0.5, 1.0 + bob, 1.0 - bob * 0.5)
			foot_phase = sin(_anim_time * run_cycle_speed * TAU * 0.5) * speed_ratio
		State.JUMP:
			target_scale = Vector3(0.92, 1.1, 0.92)
		State.FALL:
			target_scale = Vector3(1.04, 0.97, 1.04)
		State.HOVER:
			var wobble: float = sin(_anim_time * 10.0) * 0.04
			target_scale = hover_puff_scale + Vector3(wobble, -wobble, wobble)
		State.ATTACK:
			target_scale = Vector3(1.1, 0.92, 1.1)
		State.HURT:
			target_scale = Vector3(1.15, 0.85, 1.15)
	_squash.scale = _squash.scale.lerp(target_scale, blend)

	_foot_left.position = _foot_left_base + Vector3(0.0, 0.0, -foot_phase * foot_swing)
	_foot_right.position = _foot_right_base + Vector3(0.0, 0.0, foot_phase * foot_swing)
	var punch: Vector3 = Vector3(0.0, 0.0, -0.35) if _swipe_pivot.visible else Vector3.ZERO
	_arm_right.position = _arm_right.position.lerp(_arm_right_base + punch, 1.0 - exp(-30.0 * delta))

	# Damage blink.
	if _invincible_timer > 0.0:
		_squash.visible = fmod(_invincible_timer, blink_interval * 2.0) < blink_interval
	else:
		_squash.visible = true

#endregion
