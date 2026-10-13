class_name KingMossback
extends EnemyBase
## Boss: King Mossback, king of the ruins. Three phases chosen by remaining health:
##   1: ground slam (shockwave ring to jump over) and Mossling summons.
##   2: spore barrages with gaps to weave through, and a charge that stuns him if he hits a pillar.
##   3: faster combos of the earlier attacks (the arena hazards are run by BossArena).
## He only takes damage in the vulnerable window after each attack (dizzy stars, gold glow,
## "Attack!" label). Hits outside a window clank off.

signal phase_changed(phase: int)
signal defeated
signal vulnerability_changed(vulnerable: bool)

enum State { INACTIVE, IDLE, SLAM_WINDUP, SUMMON_WINDUP, BARRAGE_WINDUP, BARRAGE, CHARGE_WINDUP, CHARGE,
	VULNERABLE, PHASE_TRANSITION, DEFEATED }
enum Attack { SLAM, SUMMON, BARRAGE, CHARGE }

## Attack combos per phase, cycled in order. Each inner list runs back to back; the vulnerable
## window comes after the last attack in the list.
const PATTERNS: Dictionary = {
	1: [[Attack.SLAM], [Attack.SUMMON], [Attack.SLAM]],
	2: [[Attack.BARRAGE], [Attack.CHARGE], [Attack.SLAM], [Attack.CHARGE]],
	3: [[Attack.SLAM, Attack.CHARGE], [Attack.BARRAGE, Attack.SLAM], [Attack.CHARGE, Attack.BARRAGE]],
}

@export var display_name: String = "King Mossback"
@export var subtitle: String = "King of the Ruins"

@export_group("Phases")
@export var phase2_health: int = 8
@export var phase3_health: int = 4
@export var phase_transition_time: float = 1.6

@export_group("Movement")
@export var walk_speed: float = 2.2
@export var acceleration: float = 10.0
## Pause between attack combos.
@export var idle_time: float = 1.2
## He stops walking when this close to the player.
@export var personal_space: float = 4.0

@export_group("Vulnerability")
## Hits allowed per vulnerable window before he recovers early.
@export var max_hits_per_window: int = 3

@export_group("Ground Slam")
@export var slam_windup: float = 1.0
@export var slam_vulnerable_time: float = 2.6
@export var shockwave_scene: PackedScene
@export var shockwave_speed: float = 9.0
@export var shockwave_max_radius: float = 16.0

@export_group("Summon")
@export var summon_windup: float = 0.9
@export var summon_scene: PackedScene
@export var summon_count: int = 2
@export var max_summons: int = 3
@export var summon_radius: float = 9.0
@export var summon_vulnerable_time: float = 1.6

@export_group("Spore Barrage")
@export var projectile_scene: PackedScene
@export var barrage_windup: float = 0.9
@export var barrage_waves: int = 3
@export var barrage_count: int = 14
## Consecutive spores left out of each ring so there's a gap to slip through.
@export var barrage_gap: int = 3
@export var barrage_wave_interval: float = 0.75
@export var barrage_speed: float = 5.0
@export var barrage_height: float = 1.0
@export var barrage_vulnerable_time: float = 2.2

@export_group("Charge")
@export var charge_windup: float = 1.1
@export var charge_speed: float = 13.0
@export var charge_max_time: float = 2.4
@export var stun_time: float = 3.5
@export var charge_miss_vulnerable_time: float = 1.4

@export_group("Phase 3")
## Wind-ups are divided by this in phase 3.
@export var phase3_speed: float = 1.35
## Vulnerable windows are multiplied by this in phase 3.
@export var phase3_vulnerable_scale: float = 0.8

@export_group("Defeat")
@export var defeat_slowmo_duration: float = 1.4
@export_range(0.05, 1.0) var defeat_slowmo_scale: float = 0.3
@export var defeat_coin_count: int = 10

var phase: int = 1
var _state: State = State.INACTIVE
var _state_time: float = 0.0
var _attack_queue: Array[Attack] = []
var _pattern_index: int = 0
var _hits_this_window: int = 0
var _window_time: float = 0.0
var _charge_direction: Vector3 = Vector3.FORWARD
var _waves_fired: int = 0
var _home: Transform3D
var _arena_center: Vector3
var _arena_radius: float = 12.5
var _summons: Array[Node] = []
var _anim_time: float = 0.0
var _defeat_tween: Tween
var _gold: StandardMaterial3D

@onready var _arm_left: Node3D = $Visual/ArmLeft
@onready var _arm_right: Node3D = $Visual/ArmRight
@onready var _stars: Node3D = $Visual/DizzyStars
@onready var _vulnerable_label: Label3D = $VulnerableLabel
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	super()
	remove_from_group("enemies")
	add_to_group("boss")
	_home = global_transform
	_arena_center = global_position
	_stars.visible = false
	_vulnerable_label.visible = false
	set_physics_process(true)


## Tells the boss about its arena (center on the floor, usable radius).
func setup_arena(center: Vector3, radius: float) -> void:
	_arena_center = center
	_arena_radius = radius


func get_state() -> State:
	return _state


func is_vulnerable() -> bool:
	return _state == State.VULNERABLE


func begin_fight() -> void:
	_pattern_index = 0
	_set_state(State.IDLE)


## Puts the boss back on his throne at full health (after the player dies).
func reset_fight() -> void:
	if _defeat_tween != null:
		_defeat_tween.kill()
	health = max_health
	phase = 1
	_dead = false
	_attack_queue.clear()
	collision_layer = 132
	_collision.disabled = false
	_contact_area.monitoring = true
	_visual.visible = true
	_visual.scale = Vector3.ONE
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	global_transform = _home
	velocity = Vector3.ZERO
	clear_minions()
	_set_state(State.INACTIVE)


func clear_minions() -> void:
	for summon: Node in _summons:
		if is_instance_valid(summon):
			summon.queue_free()
	_summons.clear()
	for group_name: StringName in [&"boss_projectiles", &"boss_hazards"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			node.queue_free()


## Starts a specific attack immediately (used by tests and for tuning).
func start_attack(attack: Attack) -> void:
	_attack_queue = [attack]
	_start_next_attack()


## Opens a vulnerable window immediately (used by tests and for tuning).
func force_vulnerable(seconds: float) -> void:
	_enter_vulnerable(seconds, false)


#region State machine

func _set_state(new_state: State) -> void:
	var was_vulnerable: bool = _state == State.VULNERABLE
	_state = new_state
	_state_time = 0.0
	if new_state != State.VULNERABLE and was_vulnerable:
		_stars.visible = false
		_vulnerable_label.visible = false
		contact_enabled = true
		set_telegraph(0.0)
		vulnerability_changed.emit(false)
	if new_state == State.IDLE or new_state == State.INACTIVE:
		set_telegraph(0.0)


func _ai_process(delta: float) -> void:
	_state_time += delta
	_prune_summons()
	match _state:
		State.INACTIVE:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
		State.IDLE:
			_process_idle(delta)
		State.SLAM_WINDUP:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			_face(_flat_direction_to_player())
			set_telegraph(_state_time / _windup(slam_windup))
			if _state_time >= _windup(slam_windup):
				_do_slam()
		State.SUMMON_WINDUP:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			set_telegraph(_state_time / _windup(summon_windup))
			if _state_time >= _windup(summon_windup):
				_do_summon()
		State.BARRAGE_WINDUP:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			set_telegraph(_state_time / _windup(barrage_windup))
			if _state_time >= _windup(barrage_windup):
				_waves_fired = 0
				_set_state(State.BARRAGE)
		State.BARRAGE:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			var due: int = int(_state_time / _windup(barrage_wave_interval)) + 1
			while _waves_fired < mini(due, barrage_waves):
				_fire_wave(_waves_fired)
				_waves_fired += 1
			if _waves_fired >= barrage_waves and _state_time >= _windup(barrage_wave_interval) * barrage_waves:
				_attack_finished(barrage_vulnerable_time)
		State.CHARGE_WINDUP:
			_move(Vector3.ZERO, 0.0, acceleration * 2.0, delta)
			var windup: float = _windup(charge_windup)
			if _state_time < windup - 0.25:
				_face(_flat_direction_to_player())  # Aim locks in for the last moment.
			set_telegraph(_state_time / windup)
			if _state_time >= windup:
				_charge_direction = _facing
				AudioManager.play_sfx(&"attack", 0.0, 2.0)
				_set_state(State.CHARGE)
		State.CHARGE:
			_process_charge()
		State.VULNERABLE:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			set_telegraph(0.0)
			_apply_overlay(null if fmod(_state_time, 0.5) < 0.25 else _gold_overlay())
			if _state_time >= _window_time or (_hits_this_window >= max_hits_per_window and _state_time > 0.35):
				_set_state(State.IDLE)
		State.PHASE_TRANSITION:
			_move(Vector3.ZERO, 0.0, acceleration, delta)
			set_telegraph(0.5 + 0.5 * sin(_state_time * 20.0))
			if _state_time >= phase_transition_time:
				_set_state(State.IDLE)


func _process_idle(delta: float) -> void:
	var to_player: Vector3 = _flat_direction_to_player()
	_face(to_player)
	var distance: float = _distance_to_player()
	_move(to_player if distance > personal_space else Vector3.ZERO, walk_speed, acceleration, delta)
	if _state_time >= idle_time / (phase3_speed if phase >= 3 else 1.0) and _player_targetable():
		var patterns: Array = PATTERNS[phase]
		var combo: Array = patterns[_pattern_index % patterns.size()]
		_pattern_index += 1
		_attack_queue.assign(combo)
		if _attack_queue.has(Attack.SUMMON) and _alive_summons() >= max_summons:
			_attack_queue.assign([Attack.SLAM])
		_start_next_attack()


func _start_next_attack() -> void:
	if _attack_queue.is_empty():
		_set_state(State.IDLE)
		return
	var attack: Attack = _attack_queue.pop_front()
	match attack:
		Attack.SLAM:
			_set_state(State.SLAM_WINDUP)
		Attack.SUMMON:
			_show_alert(0.6)
			_set_state(State.SUMMON_WINDUP)
		Attack.BARRAGE:
			_set_state(State.BARRAGE_WINDUP)
		Attack.CHARGE:
			_set_state(State.CHARGE_WINDUP)


## Called when an attack completes: continue the combo, or open the vulnerable window.
func _attack_finished(vulnerable_time: float) -> void:
	if _attack_queue.is_empty():
		_enter_vulnerable(vulnerable_time, false)
	else:
		_start_next_attack()


func _enter_vulnerable(seconds: float, stunned: bool) -> void:
	_attack_queue.clear()
	_set_state(State.VULNERABLE)
	_window_time = seconds * (phase3_vulnerable_scale if phase >= 3 else 1.0)
	_hits_this_window = 0
	contact_enabled = false
	_stars.visible = true
	_vulnerable_label.visible = true
	_vulnerable_label.text = "Dizzy! Attack!" if stunned else "Attack!"
	vulnerability_changed.emit(true)


func _windup(seconds: float) -> float:
	return seconds / (phase3_speed if phase >= 3 else 1.0)

#endregion


#region Attacks

func _do_slam() -> void:
	set_telegraph(0.0)
	if shockwave_scene != null:
		var wave: Shockwave = shockwave_scene.instantiate() as Shockwave
		wave.speed = shockwave_speed * (1.15 if phase >= 3 else 1.0)
		wave.max_radius = shockwave_max_radius
		get_parent().add_child(wave)
		wave.global_position = Vector3(global_position.x, _arena_center.y, global_position.z)
	Fx.puff(get_parent(), global_position + _facing * 2.0, Color(0.85, 0.78, 0.62), 18, 1.0, 4.0, 0.7)
	Fx.chunks(get_parent(), global_position + _facing * 2.0, Color(0.55, 0.5, 0.42), 10, 0.3, 6.0)
	AudioManager.play_sfx(&"wall_break", 0.0, 2.0)
	_shake_camera(0.6, 0.35)
	_attack_finished(slam_vulnerable_time)


func _do_summon() -> void:
	set_telegraph(0.0)
	AudioManager.play_sfx(&"spore_fire", 0.0, 2.0)
	if summon_scene != null:
		var spawn_count: int = mini(summon_count, max_summons - _alive_summons())
		var away: float = atan2(-(_player.global_position - _arena_center).z, -(_player.global_position - _arena_center).x) if _player != null else 0.0
		for i: int in spawn_count:
			var angle: float = away + (float(i) - (spawn_count - 1) * 0.5) * 0.9
			var spawn: Vector3 = _arena_center + Vector3(cos(angle), 0.0, sin(angle)) * summon_radius + Vector3.UP * 0.3
			var minion: EnemyBase = summon_scene.instantiate() as EnemyBase
			minion.coin_reward = 1
			get_parent().add_child(minion)
			minion.global_position = spawn
			if minion is Mossling:
				(minion as Mossling).detect_range = 30.0
				(minion as Mossling).lose_range = 40.0
			_summons.append(minion)
			Fx.puff(get_parent(), spawn + Vector3.UP * 0.5, Color(0.5, 0.8, 0.4), 12, 0.5, 3.0)
	_attack_finished(summon_vulnerable_time)


func _fire_wave(wave_index: int) -> void:
	if projectile_scene == null:
		return
	AudioManager.play_sfx(&"spore_fire", 0.1)
	var offset: float = wave_index * PI / barrage_count + randf() * 0.2
	var gap_start: int = randi() % barrage_count
	var origin: Vector3 = Vector3(global_position.x, _arena_center.y + barrage_height, global_position.z)
	for i: int in barrage_count:
		if posmod(i - gap_start, barrage_count) < barrage_gap:
			continue
		var angle: float = offset + TAU * i / barrage_count
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var spore: SporeProjectile = projectile_scene.instantiate() as SporeProjectile
		spore.add_to_group("boss_projectiles")
		get_parent().add_child(spore)
		spore.launch(origin + direction * 2.3, direction * barrage_speed, 1, 5.0)


func _process_charge() -> void:
	var speed: float = charge_speed * (1.15 if phase >= 3 else 1.0)
	velocity.x = _charge_direction.x * speed
	velocity.z = _charge_direction.z * speed
	if _state_time > 0.05:
		for i: int in get_slide_collision_count():
			var collider: Object = get_slide_collision(i).get_collider()
			if collider is Node and (collider as Node).is_in_group("boss_pillar"):
				_crash()
				return
	var ahead: Vector3 = global_position + _charge_direction * 2.5 - _arena_center
	ahead.y = 0.0
	if ahead.length() > _arena_radius or _state_time >= charge_max_time:
		velocity.x = 0.0
		velocity.z = 0.0
		_attack_finished(charge_miss_vulnerable_time)


func _crash() -> void:
	velocity = -_charge_direction * 4.0 + Vector3.UP * 3.0
	_shake_camera(0.8, 0.4)
	AudioManager.play_sfx(&"wall_break", 0.0, 3.0)
	Fx.chunks(get_parent(), global_position + _charge_direction * 2.0 + Vector3.UP * 2.0, Color(0.7, 0.65, 0.55), 16, 0.35, 7.0)
	_enter_vulnerable(stun_time, true)

#endregion


#region Damage

func take_hit(damage: int, source_position: Vector3, _knockback: float) -> void:
	if _dead or _state == State.DEFEATED or _hit_timer > 0.0:
		return
	if _state != State.VULNERABLE:
		# Clank: no damage outside a vulnerable window.
		_hit_timer = 0.2
		AudioManager.play_sfx(&"stone_hit", 0.1)
		Fx.chunks(get_parent(), source_position.lerp(global_position, 0.6) + Vector3.UP, Color(0.6, 0.58, 0.55), 4, 0.15, 4.0, 0.5)
		return
	health -= damage
	_hits_this_window += 1
	_hit_timer = hit_invulnerability
	_flash_timer = flash_time
	damaged.emit(damage)
	AudioManager.play_sfx(&"hit")
	_shake_camera(0.35, 0.2)
	GameState.set_boss_health(maxi(health, 0), max_health)
	if health <= 0:
		_defeat()
	elif phase == 1 and health <= phase2_health or phase == 2 and health <= phase3_health:
		_change_phase(phase + 1)


func _change_phase(new_phase: int) -> void:
	phase = new_phase
	_attack_queue.clear()
	_pattern_index = 0
	_set_state(State.PHASE_TRANSITION)
	_show_alert(phase_transition_time)
	_shake_camera(0.7, phase_transition_time * 0.6)
	AudioManager.play_sfx(&"hurt", 0.0, 3.0)
	phase_changed.emit(phase)


func _defeat() -> void:
	_set_state(State.DEFEATED)
	_dead = true
	contact_enabled = false
	_contact_area.set_deferred("monitoring", false)
	_collision.set_deferred("disabled", true)
	clear_minions()
	HitStop.apply(get_tree(), defeat_slowmo_duration, defeat_slowmo_scale)
	_shake_camera(1.0, 1.2)
	AudioManager.play_sfx(&"enemy_death", 0.0, 4.0)

	_defeat_tween = create_tween()
	for i: int in 4:
		_defeat_tween.tween_callback(func() -> void:
			Fx.chunks(get_parent(), global_position + Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 3.5), randf_range(-1.5, 1.5)),
				Color(0.6, 0.55, 0.45), 14, 0.4, 7.0, 1.2)
			Fx.puff(get_parent(), global_position + Vector3.UP * 2.0, Color(0.6, 0.85, 0.45), 12, 0.8, 4.0, 0.8))
		_defeat_tween.tween_interval(0.3)
	_defeat_tween.tween_property(_visual, "rotation:x", deg_to_rad(-25.0), 0.6)
	_defeat_tween.parallel().tween_property(_visual, "position:y", -1.5, 1.0).set_ease(Tween.EASE_IN)
	_defeat_tween.tween_property(_visual, "scale", Vector3(1.3, 0.1, 1.3), 0.4)
	_defeat_tween.tween_callback(_finish_defeat)


func _finish_defeat() -> void:
	_visual.visible = false
	Fx.puff(get_parent(), global_position + Vector3.UP, Color(0.9, 0.85, 0.7), 24, 1.2, 5.0, 1.0)
	if coin_scene != null:
		for i: int in defeat_coin_count:
			var coin: Node3D = coin_scene.instantiate() as Node3D
			coin.set("persistent", false)
			get_parent().add_child(coin)
			var angle: float = TAU * i / defeat_coin_count
			coin.global_position = global_position + Vector3(cos(angle), 1.5, sin(angle))
			if coin.has_method("pop"):
				coin.call("pop", Vector3(cos(angle), 0.0, sin(angle)))
	defeated.emit()

#endregion


#region Helpers and visuals

func _alive_summons() -> int:
	return _summons.filter(func(n: Node) -> bool: return is_instance_valid(n) and not (n as EnemyBase).is_dead()).size()


func _prune_summons() -> void:
	_summons = _summons.filter(func(n: Node) -> bool: return is_instance_valid(n))


func _shake_camera(strength: float, duration: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("shake"):
		camera.call("shake", strength, duration)


func _gold_overlay() -> StandardMaterial3D:
	if _gold == null:
		_gold = StandardMaterial3D.new()
		_gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_gold.albedo_color = Color(1.0, 0.85, 0.2, 0.45)
	return _gold


func _update_visual(delta: float) -> void:
	_anim_time += delta
	var left_target: Vector3 = Vector3(-2.3, 1.4, -0.5)
	var right_target: Vector3 = Vector3(2.3, 1.4, -0.5)
	var body_tilt: float = 0.0
	match _state:
		State.IDLE:
			var sway: float = sin(_anim_time * 3.0) * 0.15
			left_target.y += sway
			right_target.y -= sway
		State.SLAM_WINDUP:
			var t: float = clampf(_state_time / _windup(slam_windup), 0.0, 1.0)
			left_target = left_target.lerp(Vector3(-1.4, 5.0, -0.6), t)
			right_target = right_target.lerp(Vector3(1.4, 5.0, -0.6), t)
			body_tilt = 0.15 * t
		State.SUMMON_WINDUP:
			right_target = Vector3(1.8, 4.8, -0.4)
		State.BARRAGE_WINDUP, State.BARRAGE:
			left_target = Vector3(-2.8, 2.6, 0.2)
			right_target = Vector3(2.8, 2.6, 0.2)
			body_tilt = 0.12
		State.CHARGE_WINDUP:
			body_tilt = -0.25
			_visual.position.x = sin(_anim_time * 40.0) * 0.06
		State.CHARGE:
			body_tilt = -0.35
			left_target = Vector3(-1.8, 1.0, -1.6)
			right_target = Vector3(1.8, 1.0, -1.6)
		State.VULNERABLE:
			left_target = Vector3(-1.8, 0.6, -1.4)
			right_target = Vector3(1.8, 0.6, -1.4)
			body_tilt = -0.2
			_stars.rotation.y += 4.0 * delta
		State.PHASE_TRANSITION:
			left_target = Vector3(-2.2, 4.5, 0.0)
			right_target = Vector3(2.2, 4.5, 0.0)
			_visual.position.x = sin(_anim_time * 50.0) * 0.08
	if _state != State.CHARGE_WINDUP and _state != State.PHASE_TRANSITION and _state != State.DEFEATED:
		_visual.position.x = 0.0
	var blend: float = 1.0 - exp(-10.0 * delta)
	_arm_left.position = _arm_left.position.lerp(left_target, blend)
	_arm_right.position = _arm_right.position.lerp(right_target, blend)
	if _state != State.DEFEATED:
		_visual.rotation.x = lerpf(_visual.rotation.x, body_tilt, blend)

#endregion
