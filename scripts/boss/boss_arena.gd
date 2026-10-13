class_name BossArena
extends Node3D
## Runs the King Mossback fight: entrance trigger, intro (gate closes, camera move, name card),
## phase-3 arena changes (outer platforms crumble, falling rocks), reset when the player dies,
## and the victory (exit gate opens).

signal fight_started
signal fight_reset
signal boss_defeated

enum State { WAITING, INTRO, FIGHTING, DEFEATED }

@export var boss: KingMossback
@export var player: Player
@export var camera: RailCamera
@export var entrance_gate: Gate
@export var exit_gate: Gate
@export var trigger: Area3D
## Respawn point for deaths during the fight (inside the arena, by the entrance).
@export var entrance_spawn: Marker3D
@export var arena_center: Marker3D
@export var intro_camera_point: Marker3D
@export var intro_look_point: Marker3D
@export var outer_platforms: Node3D
@export var rock_scene: PackedScene

@export_group("Arena")
@export var arena_radius: float = 12.5

@export_group("Intro")
@export var intro_duration: float = 2.8
## Shorter intro used when the fight restarts after a death.
@export var restart_intro_duration: float = 1.2

@export_group("Falling Rocks")
@export var rock_interval: float = 1.6
## Chance that a rock targets the player's position instead of a random spot.
@export_range(0.0, 1.0) var rock_targeted_chance: float = 0.5

@export_group("Victory")
@export var exit_open_delay: float = 2.5

var _state: State = State.WAITING
var _rock_timer: float = 0.0
var _rocks_active: bool = false
var _platform_transforms: Dictionary = {}
var _name_card: BossNameCard
var _intro_tween: Tween
var _platform_tweens: Array[Tween] = []


func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)
	boss.setup_arena(arena_center.global_position, arena_radius)
	boss.phase_changed.connect(_on_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)
	for platform: Node in outer_platforms.get_children():
		_platform_transforms[platform] = (platform as Node3D).transform
	_name_card = BossNameCard.new()
	add_child(_name_card)


func get_state() -> State:
	return _state


func get_name_card() -> BossNameCard:
	return _name_card


func _process(delta: float) -> void:
	if _state != State.FIGHTING or not _rocks_active:
		return
	_rock_timer -= delta
	if _rock_timer <= 0.0:
		_rock_timer = rock_interval
		_drop_rock()


#region Fight flow

func _on_trigger_body_entered(body: Node3D) -> void:
	if body is Player and _state == State.WAITING:
		_start_fight(intro_duration, true)


func _start_fight(duration: float, first_time: bool) -> void:
	_state = State.INTRO
	entrance_gate.close()
	if first_time:
		# Deaths during the fight respawn at the arena entrance. (Not re-set on restarts, so the
		# checkpoint snapshot stays the one from when the fight began.)
		GameState.set_checkpoint(entrance_spawn.global_transform)
	GameState.start_boss(boss.display_name, boss.max_health)
	player.controls_enabled = false
	if first_time and camera != null:
		camera.set_override(intro_camera_point.global_position, intro_look_point.global_position, 45.0)
	_name_card.show_card(boss.display_name, boss.subtitle, maxf(duration - 0.6, 0.4))
	AudioManager.play_sfx(&"hurt", 0.0, 2.0)
	if _intro_tween != null:
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_interval(duration)
	_intro_tween.tween_callback(_begin_combat)


func _begin_combat() -> void:
	if camera != null:
		camera.clear_override()
	player.controls_enabled = true
	_state = State.FIGHTING
	boss.begin_fight()
	fight_started.emit()


func _on_phase_changed(phase: int) -> void:
	if phase >= 3:
		_crumble_platforms()
		_rocks_active = true
		_rock_timer = rock_interval


func _on_player_died() -> void:
	if _state != State.INTRO and _state != State.FIGHTING:
		return
	# Reset everything; the fight restarts when the player respawns at the entrance.
	if _intro_tween != null:
		_intro_tween.kill()
	if camera != null:
		camera.clear_override()
	_rocks_active = false
	boss.reset_fight()
	_restore_platforms()
	GameState.set_boss_health(boss.max_health, boss.max_health)
	_state = State.WAITING
	fight_reset.emit()


func _on_player_respawned() -> void:
	if _state == State.WAITING and GameState.checkpoint_transform.origin.distance_to(entrance_spawn.global_position) < 0.1:
		_start_fight(restart_intro_duration, false)


func _on_boss_defeated() -> void:
	_state = State.DEFEATED
	_rocks_active = false
	for node: Node in get_tree().get_nodes_in_group("boss_hazards"):
		node.queue_free()
	GameState.end_boss(true)
	var tween: Tween = create_tween()
	tween.tween_interval(exit_open_delay)
	tween.tween_callback(func() -> void:
		exit_gate.open()
		entrance_gate.open())
	boss_defeated.emit()

#endregion


#region Arena hazards

func _drop_rock() -> void:
	if rock_scene == null:
		return
	var center: Vector3 = arena_center.global_position
	var target: Vector3
	if randf() < rock_targeted_chance and player != null:
		target = Vector3(player.global_position.x, center.y, player.global_position.z)
	else:
		var angle: float = randf() * TAU
		target = center + Vector3(cos(angle), 0.0, sin(angle)) * sqrt(randf()) * (arena_radius - 1.0)
	var offset: Vector3 = target - center
	if Vector2(offset.x, offset.z).length() > arena_radius - 0.5:
		return
	var rock: Node3D = rock_scene.instantiate() as Node3D
	add_child(rock)
	rock.global_position = target


func _crumble_platforms() -> void:
	for platform: Node in outer_platforms.get_children():
		var block: GreyboxBlock = platform as GreyboxBlock
		if block == null:
			continue
		# Shake for ~0.6 s (after a small random delay), then drop away.
		var x: float = block.position.x
		var tween: Tween = block.create_tween()
		_platform_tweens.append(tween)
		tween.tween_interval(randf() * 0.4)
		for i: int in 6:
			tween.tween_property(block, "position:x", x + 0.1, 0.05)
			tween.tween_property(block, "position:x", x - 0.1, 0.05)
		tween.tween_callback(func() -> void:
			_set_block_solid(block, false)
			Fx.chunks(self, block.global_position + Vector3.UP * 2.0, Color(0.8, 0.72, 0.58), 14, 0.35, 5.0, 1.0))
		tween.tween_property(block, "position:y", block.position.y - 12.0, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func() -> void: block.visible = false)


func _restore_platforms() -> void:
	for tween: Tween in _platform_tweens:
		if tween.is_valid():
			tween.kill()
	_platform_tweens.clear()
	for platform: Node in _platform_transforms:
		var block: GreyboxBlock = platform as GreyboxBlock
		block.transform = _platform_transforms[platform]
		block.visible = true
		_set_block_solid(block, true)


func _set_block_solid(block: GreyboxBlock, solid: bool) -> void:
	block.collision_layer = 1 if solid else 0

#endregion
