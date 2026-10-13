class_name EnemyBase
extends CharacterBody3D
## Shared enemy behaviour: health, hit reaction (flash, knockback, stun), contact damage,
## death puff and rewards, gravity, ledge avoidance and sleeping when the player is far away.
##
## Subclasses implement `_ai_process(delta)` (and optionally `_on_hurt()` / `_update_visual(delta)`).
## Expected children: `Visual` (Node3D with the meshes) and `ContactArea` (Area3D, mask = player).

signal damaged(amount: int)
signal died(enemy: EnemyBase)

@export_group("Health")
@export var max_health: int = 2
@export var hit_stun_time: float = 0.3
## Brief invulnerability after a hit so one swing can't hit twice.
@export var hit_invulnerability: float = 0.15
## 0 = rooted in place, 1 = full knockback from attacks.
@export_range(0.0, 2.0) var knockback_multiplier: float = 1.0
@export var flash_time: float = 0.12

@export_group("Contact")
@export var contact_damage: int = 1
@export var contact_enabled: bool = true

@export_group("Movement")
@export var gravity: float = 30.0
@export var max_fall_speed: float = 25.0
@export var turn_speed: float = 10.0
## Stop instead of walking off ledges.
@export var avoid_edges: bool = true
@export var edge_check_distance: float = 0.7
## Drops deeper than this count as a ledge to avoid.
@export var edge_check_depth: float = 0.8

@export_group("Rewards")
@export var coin_reward: int = 2
## Optional coin pickup scene; without one, coins are added straight to GameState.
@export var coin_scene: PackedScene
@export var death_puff_color: Color = Color(0.95, 0.95, 0.9)

@export_group("Activation")
## The enemy sleeps (no AI or physics) while the player is further away than this.
@export var active_distance: float = 45.0

var health: int = 0
var _player: Player
var _facing: Vector3 = Vector3.FORWARD
var _dead: bool = false
var _stun_timer: float = 0.0
var _hit_timer: float = 0.0
var _flash_timer: float = 0.0
var _flash_material: StandardMaterial3D
var _telegraph_material: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _alert_label: Label3D

@onready var _visual: Node3D = $Visual
@onready var _contact_area: Area3D = $ContactArea


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_facing = -global_basis.z
	_facing.y = 0.0
	_facing = _facing.normalized() if _facing.length_squared() > 0.001 else Vector3.FORWARD
	_visual.rotation.y = atan2(-_facing.x, -_facing.z)
	for node: Node in _visual.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)

	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 1, 1, 0.85)
	_telegraph_material = StandardMaterial3D.new()
	_telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_material.albedo_color = Color(1.0, 0.45, 0.1, 0.0)

	_alert_label = Label3D.new()
	_alert_label.text = "!"
	_alert_label.font_size = 96
	_alert_label.outline_size = 18
	_alert_label.modulate = Color(1.0, 0.85, 0.2)
	_alert_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_label.no_depth_test = true
	_alert_label.position = Vector3(0, 2.0, 0)
	_alert_label.visible = false
	add_child(_alert_label)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null or global_position.distance_to(_player.global_position) > active_distance:
		return

	_stun_timer = maxf(_stun_timer - delta, 0.0)
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	_update_flash(delta)

	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)
	if _stun_timer > 0.0:
		var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 12.0 * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	else:
		_ai_process(delta)
	move_and_slide()

	if contact_enabled and _stun_timer <= 0.0 and not _player_attack_has_priority():
		for body: Node3D in _contact_area.get_overlapping_bodies():
			if body is Player:
				(body as Player).take_damage(contact_damage, global_position)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-_facing.x, -_facing.z), 1.0 - exp(-turn_speed * delta))
	_update_visual(delta)


#region Hit interface

func take_hit(damage: int, source_position: Vector3, knockback: float) -> void:
	if _dead or _hit_timer > 0.0:
		return
	health -= damage
	_hit_timer = hit_invulnerability
	_flash_timer = flash_time
	damaged.emit(damage)

	var away: Vector3 = global_position - source_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.001 else -_facing
	velocity = away * knockback * knockback_multiplier + Vector3.UP * knockback * 0.35 * knockback_multiplier
	_stun_timer = hit_stun_time
	set_telegraph(0.0)
	_on_hurt()
	if health <= 0:
		_die()


func is_dead() -> bool:
	return _dead


func _die() -> void:
	_dead = true
	_contact_area.set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	_alert_label.visible = false
	died.emit(self)
	Fx.puff(get_parent(), global_position + Vector3.UP * 0.6, death_puff_color, 16, 0.45, 3.5)
	_drop_rewards()
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.4, 0.4, 1.4), 0.08)
	tween.tween_property(_visual, "scale", Vector3.ZERO, 0.18).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _drop_rewards() -> void:
	if coin_reward <= 0:
		return
	if coin_scene == null:
		GameState.add_coins(coin_reward)
		return
	for i: int in coin_reward:
		var coin: Node3D = coin_scene.instantiate() as Node3D
		get_parent().add_child(coin)
		var angle: float = TAU * float(i) / float(coin_reward)
		coin.global_position = global_position + Vector3(cos(angle), 1.0, sin(angle)) * 0.6
		if coin.has_method("pop"):
			coin.call("pop", Vector3(cos(angle), 0.0, sin(angle)))

#endregion


#region Overridables

## Per-frame behaviour while awake and not stunned.
func _ai_process(_delta: float) -> void:
	pass


## Called when hit (before death is checked). Cancel attacks here.
func _on_hurt() -> void:
	pass


## Per-frame visual animation (squash, bob...).
func _update_visual(_delta: float) -> void:
	pass

#endregion


#region Helpers for subclasses

func _distance_to_player() -> float:
	if _player == null:
		return INF
	var d: Vector3 = _player.global_position - global_position
	d.y *= 0.5  # Height differences matter less than horizontal distance.
	return d.length()


func _flat_direction_to_player() -> Vector3:
	if _player == null:
		return _facing
	var d: Vector3 = _player.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else _facing


## The player's swing beats contact damage: while attacking, enemies in front of the player can't hurt by touch.
func _player_attack_has_priority() -> bool:
	if _player == null or _player.get_state() != Player.State.ATTACK:
		return false
	var to_enemy: Vector3 = global_position - _player.global_position
	to_enemy.y = 0.0
	return to_enemy.length_squared() < 0.0001 or to_enemy.normalized().dot(_player.get_facing()) > 0.2


func _player_targetable() -> bool:
	return _player != null and _player.get_state() != Player.State.DEAD


## True if nothing solid blocks the line from this enemy to the player.
func _can_see_player(eye_height: float = 0.8) -> bool:
	if _player == null:
		return false
	var from: Vector3 = global_position + Vector3.UP * eye_height
	var to: Vector3 = _player.global_position + Vector3.UP * 0.6
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Accelerates horizontally toward `direction * speed`, stopping at ledges if `avoid_edges`.
func _move(direction: Vector3, speed: float, acceleration: float, delta: float) -> void:
	var target: Vector3 = direction * speed
	if avoid_edges and direction.length_squared() > 0.001 and is_on_floor() and _is_edge_ahead(direction):
		target = Vector3.ZERO
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _is_edge_ahead(direction: Vector3) -> bool:
	var from: Vector3 = global_position + direction.normalized() * edge_check_distance + Vector3.UP * 0.5
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (0.5 + edge_check_depth), 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _face(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_facing = direction.normalized()


func _show_alert(duration: float = 0.6) -> void:
	_alert_label.visible = true
	_alert_label.scale = Vector3(0.3, 0.3, 0.3)
	var tween: Tween = create_tween()
	tween.tween_property(_alert_label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration)
	tween.tween_callback(func() -> void: _alert_label.visible = false)


## Orange glow overlay for wind-ups (0 = off, 1 = full).
func set_telegraph(amount: float) -> void:
	_telegraph_material.albedo_color.a = clampf(amount, 0.0, 1.0) * 0.6
	if _flash_timer <= 0.0:
		_apply_overlay(_telegraph_material if amount > 0.0 else null)


func _update_flash(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		_apply_overlay(_flash_material if _flash_timer > 0.0 else null)


func _apply_overlay(material: Material) -> void:
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = material

#endregion
