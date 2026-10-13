class_name Level
extends Node3D
## Root script for a playable level. Places the player at the start point (or the active
## checkpoint when continuing/restarting the same level), runs the level timer, autosaves at
## checkpoints, and owns the pause menu, game over screen and results screen.

@export var player: Player
@export var start_point: Marker3D
@export var camera: RailCamera
@export var music: StringName = &"level"

@export_group("Menus")
@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
@export var game_over_scene: PackedScene = preload("res://scenes/ui/game_over_screen.tscn")
@export var results_scene: PackedScene = preload("res://scenes/ui/results_screen.tscn")
## Show the Game Over screen (Retry / Quit) when the player is defeated. When off, the player
## respawns at the checkpoint automatically.
@export var use_game_over_screen: bool = true:
	set(value):
		use_game_over_screen = value
		if player != null:
			player.auto_respawn = not value
## Pause between touching the goal and the results screen.
@export var results_delay: float = 1.2

var pause_menu: PauseMenu
var game_over_screen: GameOverScreen
var results_screen: ResultsScreen


func _ready() -> void:
	var level_id: String = scene_file_path
	if GameState.current_level != level_id or not GameState.has_checkpoint:
		GameState.begin_level(level_id, start_point.global_transform)
	if player != null:
		player.place_at_checkpoint()
		player.auto_respawn = not use_game_over_screen
		# A death rolls collected items back to the checkpoint (pits don't).
		player.respawned.connect(GameState.revert_to_checkpoint)
		player.died.connect(_on_player_died)
	if camera != null:
		camera.snap_to_target()

	pause_menu = pause_menu_scene.instantiate() as PauseMenu
	add_child(pause_menu)
	game_over_screen = game_over_scene.instantiate() as GameOverScreen
	add_child(game_over_screen)
	game_over_screen.retry_requested.connect(_on_retry)
	results_screen = results_scene.instantiate() as ResultsScreen
	add_child(results_screen)

	GameState.checkpoint_changed.connect(func(_xform: Transform3D) -> void: GameState.save_progress())
	GameState.level_completed.connect(_on_level_completed)
	GameState.save_progress()
	SettingsManager.apply_graphics()
	AudioManager.play_music(music)


func _process(delta: float) -> void:
	GameState.tick_level_time(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and can_pause():
		get_viewport().set_input_as_handled()
		pause_menu.open()


func can_pause() -> bool:
	return not get_tree().paused and not SceneManager.is_busy() and not game_over_screen.is_open() \
		and not results_screen.is_open() and player != null and player.get_state() != Player.State.DEAD


func _on_player_died() -> void:
	if not use_game_over_screen:
		return
	await get_tree().create_timer(player.respawn_delay, false).timeout
	if is_inside_tree() and player.get_state() == Player.State.DEAD:
		game_over_screen.open()


func _on_retry() -> void:
	player.respawn()


func _on_level_completed(_level_id: String) -> void:
	if player != null:
		player.controls_enabled = false
	AudioManager.stop_music()
	AudioManager.play_sfx(&"victory", 0.0)
	await get_tree().create_timer(results_delay, false).timeout
	if is_inside_tree():
		results_screen.open()
