extends SmokeTestBase
## Headless smoke test for Stage 7: main menu, settings, pause menu, save/continue,
## restart from checkpoint, game over, results screen and scene fades.
## Run: godot --headless --path . res://tests/stage7_menus_test.tscn

const LEVEL_PATH: String = "res://scenes/levels/level_ruins.tscn"


func _init() -> void:
	level_scene = null


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame  # The root can't take new children while it's setting up.
	# Let SceneManager swap scenes without freeing this test node.
	var placeholder: Node = Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	GameState.start_new_run()

	await _test_main_menu()
	await _test_gamepad_menus()
	await _test_settings()
	await _test_start_and_pause()
	await _test_checkpoint_save_and_restart()
	await _test_game_over()
	await _test_continue()
	await _test_results()


#region Helpers

func _go(path: String) -> void:
	SceneManager.change_scene(path)
	await _wait_scene()


func _wait_scene() -> void:
	await _frames(2)
	await _wait_until(func() -> bool: return not SceneManager.is_busy(), 240)
	await _frames(2)


func _scene() -> Node:
	return get_tree().current_scene


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _ui_action(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	var release: InputEventAction = InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


func _level_node() -> Level:
	return _scene() as Level


func _prepare_level() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	_player = _level_node().player
	_camera = _level_node().camera
	_level = _level_node()
	await _frames(3)

#endregion


func _test_main_menu() -> void:
	await _go(SceneManager.MAIN_MENU)
	var menu: MainMenu = _scene() as MainMenu
	_check("main menu loads through the scene fade", menu != null)
	_check("menu has Start, Continue, Settings and Quit", menu.start_button.text == "Start" and menu.continue_button.text == "Continue"
		and menu.settings_button.text == "Settings" and menu.quit_button.text == "Quit")
	_check("first button (Start) is focused on open", _focused() == menu.start_button)
	_check("Continue is disabled without a save", menu.continue_button.disabled)
	await _ui_action(&"ui_down")
	_check("keyboard/gamepad navigation skips the disabled Continue", _focused() == menu.settings_button, str(_focused()))
	await _ui_action(&"ui_up")
	_check("navigation moves back up to Start", _focused() == menu.start_button)


## Presses a gamepad button (A = 0, B = 1, D-pad up/down = 11/12) as a real controller would.
func _pad(button: JoyButton) -> void:
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = button
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	var release: InputEventJoypadButton = InputEventJoypadButton.new()
	release.button_index = button
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


func _test_gamepad_menus() -> void:
	var menu: MainMenu = _scene() as MainMenu
	menu.start_button.grab_focus()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check("gamepad: D-pad moves focus in the main menu", _focused() == menu.settings_button, str(_focused()))
	await _pad(JOY_BUTTON_A)
	_check("gamepad: A presses the focused button (opens Settings)", menu.is_settings_open())
	var settings: SettingsMenu = menu.find_children("*", "SettingsMenu", true, false)[0] as SettingsMenu
	await _frames(2)
	var back: Button = settings.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "Back")[0]
	var reached: bool = false
	for i: int in 40:
		await _pad(JOY_BUTTON_DPAD_DOWN)
		if _focused() == back or (_focused() is Button and (_focused() as Button).text == "Reset Controls"):
			reached = true
			break
	_check("gamepad: D-pad reaches the bottom buttons of Settings", reached, str(_focused()))
	settings.find_children("*", "OptionButton", true, false)[0].call("grab_focus")
	await _pad(JOY_BUTTON_DPAD_UP)
	_check("gamepad: up from the first setting wraps to the bottom buttons", _focused() is Button and ((_focused() as Button).text == "Back" or (_focused() as Button).text == "Reset Controls"), str(_focused()))
	await _pad(JOY_BUTTON_B)
	_check("gamepad: B backs out of Settings", not menu.is_settings_open() and _focused() == menu.settings_button)

	get_viewport().gui_release_focus()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check("gamepad: navigation recovers focus after it was lost", _focused() == menu.start_button, str(_focused()))


func _test_settings() -> void:
	var menu: MainMenu = _scene() as MainMenu
	menu.settings_button.grab_focus()
	await _ui_action(&"ui_accept")
	_check("Settings opens from the main menu", menu.is_settings_open())
	var settings: SettingsMenu = menu.find_children("*", "SettingsMenu", true, false)[0] as SettingsMenu
	await _frames(2)
	_check("settings focuses its first control", settings.is_ancestor_of(_focused()))

	var sliders: Array[Node] = settings.find_children("*", "HSlider", true, false)
	(sliders[0] as HSlider).value = 50.0  # Master volume.
	await _frames(1)
	var master_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))
	_check("master volume slider applies immediately (linear -> dB)", absf(master_db - linear_to_db(0.5)) < 0.1, "%.2f dB" % master_db)
	var checks: Array[Node] = settings.find_children("*", "CheckButton", true, false)
	var shake_check: CheckButton = checks[checks.size() - 1] as CheckButton
	shake_check.button_pressed = false
	_check("screen shake toggle applies", not SettingsManager.screen_shake)
	var config: ConfigFile = ConfigFile.new()
	config.load(SettingsManager.settings_path)
	_check("settings are saved to the settings file", absf(float(config.get_value("audio", "master", 0.0)) - 0.5) < 0.01 and config.get_value("gameplay", "screen_shake", true) == false)

	settings.begin_capture(&"jump", false)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	_check("rebinding: jump can be bound to K", SettingsManager.get_binding_label(&"jump", false) == "K")
	config.load(SettingsManager.settings_path)
	_check("rebinding is saved", str(config.get_value("controls", "jump", [])).contains(str(KEY_K)))
	var reset: Button = settings.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "Reset Controls")[0]
	reset.pressed.emit()
	_check("reset to default restores jump = Space", SettingsManager.get_binding_label(&"jump", false) == "Space")

	SettingsManager.set_setting("master_volume", 0.8)
	SettingsManager.set_setting("screen_shake", true)
	await _ui_action(&"ui_cancel")
	await _frames(2)
	_check("ui_cancel closes settings and returns focus", not menu.is_settings_open() and _focused() == menu.settings_button)


func _test_start_and_pause() -> void:
	var menu: MainMenu = _scene() as MainMenu
	menu.start_button.pressed.emit()
	await _wait_scene()
	_check("Start loads the level", _scene() is Level and GameState.current_level == LEVEL_PATH)
	await _prepare_level()
	_check("starting a level creates a save to continue from", GameState.has_save() and GameState.has_progress())

	await _ui_action(&"pause")
	var pause: PauseMenu = _level_node().pause_menu
	_check("pause action opens the pause menu and pauses the game", pause.is_open() and get_tree().paused)
	_check("pause menu focuses Resume", _focused() == pause.resume_button)
	_check("pause menu has Settings, Restart and Main Menu", pause.settings_button != null and pause.restart_button != null and pause.menu_button != null)
	var time_before: float = GameState.level_time
	await _frames(30)
	_check("the level timer stops while paused", is_equal_approx(GameState.level_time, time_before))
	pause.settings_button.pressed.emit()
	await _frames(2)
	_check("settings open from the pause menu (while paused)", pause.find_children("*", "SettingsMenu", true, false).size() == 1 and get_tree().paused)
	await _ui_action(&"ui_cancel")
	await _ui_action(&"ui_cancel")
	_check("ui_cancel resumes the game", not pause.is_open() and not get_tree().paused)

	# Same flow on a gamepad.
	await _pad(JOY_BUTTON_START)
	_check("gamepad: Start opens the pause menu", pause.is_open() and _focused() == pause.resume_button)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_check("gamepad: A opens Settings from the pause menu", pause.find_children("*", "SettingsMenu", true, false).size() == 1)
	await _pad(JOY_BUTTON_B)
	await _frames(2)
	_check("gamepad: B backs out of Settings to the pause menu", pause.is_open() and pause.find_children("*", "SettingsMenu", true, false).is_empty()
		and _focused() == pause.settings_button)
	await _pad(JOY_BUTTON_B)
	_check("gamepad: B resumes the game", not pause.is_open() and not get_tree().paused)


func _test_checkpoint_save_and_restart() -> void:
	# Collect the first coin before the checkpoint so the save has something to restore.
	var first_coin: Coin = _level.get_node("Pickups/Coins").get_child(0) as Coin
	_teleport(Vector3(first_coin.global_position.x, 0.05, first_coin.global_position.z))
	await _frames(6)
	var checkpoint: Checkpoint = _level.find_child("Checkpoint1", true, false) as Checkpoint
	var checkpoint_pos: Vector3 = checkpoint.get_spawn_transform().origin
	_teleport(checkpoint_pos)
	await _frames(6)
	var config: ConfigFile = ConfigFile.new()
	config.load(GameState.save_path)
	var saved: Transform3D = config.get_value("progress", "checkpoint", Transform3D.IDENTITY)
	_check("reaching a checkpoint autosaves it", saved.origin.distance_to(checkpoint.get_spawn_transform().origin) < 0.01)
	var coins_at_checkpoint: int = GameState.coins

	# Grab a coin past the checkpoint, then restart from the checkpoint via the pause menu.
	var coin: Coin = null
	for node: Node in _level.get_node("Pickups/Coins").get_children():
		if (node as Coin).global_position.x > 14.0 and absf((node as Coin).global_position.z + 80.0) < 0.1:
			coin = node as Coin
			break
	_teleport(Vector3(coin.global_position.x, 2.05, coin.global_position.z))
	await _frames(6)
	_check("collected a coin after the checkpoint", GameState.coins == coins_at_checkpoint + 1)
	await _ui_action(&"pause")
	_level_node().pause_menu.restart_button.pressed.emit()
	await _wait_scene()
	await _prepare_level()
	_check("restart from checkpoint reloads the level at the checkpoint", _player.global_position.distance_to(checkpoint_pos) < 0.5)
	_check("restart from checkpoint rolls items back", GameState.coins == coins_at_checkpoint)
	_check("game is unpaused after the restart", not get_tree().paused)


func _test_game_over() -> void:
	GameState.health = 1
	_player.take_damage(1, _player.global_position + Vector3.RIGHT)
	var shown: bool = await _wait_until(func() -> bool: return _level_node().game_over_screen.is_open(), int(_player.respawn_delay * 60.0) + 30)
	var screen: GameOverScreen = _level_node().game_over_screen
	_check("defeat shows the Game Over screen", shown and get_tree().paused)
	_check("Game Over focuses Retry", _focused() == screen.retry_button)
	_check("Game Over offers Quit to Menu", screen.quit_button.text == "Quit to Menu")
	await _ui_action(&"ui_accept")
	await _frames(5)
	_check("Retry respawns at the checkpoint with full health", not get_tree().paused and _player.get_state() != Player.State.DEAD
		and GameState.health == GameState.max_health and _player.global_position.distance_to(GameState.checkpoint_transform.origin) < 0.5)


func _test_continue() -> void:
	var checkpoint_pos: Vector3 = GameState.checkpoint_transform.origin
	await _ui_action(&"pause")
	_level_node().pause_menu.menu_button.pressed.emit()
	await _wait_scene()
	var menu: MainMenu = _scene() as MainMenu
	_check("Main Menu from the pause menu returns to the title screen", menu != null and not get_tree().paused)
	_check("Continue is enabled when a save exists", not menu.continue_button.disabled)
	GameState.start_new_run()  # Forget the in-memory run: Continue must come from the save file.
	menu.continue_button.pressed.emit()
	await _wait_scene()
	await _prepare_level()
	_check("Continue loads the saved checkpoint", _scene() is Level and _player.global_position.distance_to(checkpoint_pos) < 0.5)
	var first_coin: Coin = _level.get_node("Pickups/Coins").get_child(0) as Coin
	_check("Continue restores collected items", GameState.collected.size() == 1 and first_coin.is_collected() and not first_coin.visible and GameState.level_time > 0.0, str(GameState.collected.keys()))


func _test_results() -> void:
	var goal: Node3D = _level.find_child("LevelGoal", true, false) as Node3D
	_teleport(goal.global_position + Vector3(0, 0.1, 0))
	var results: ResultsScreen = _level_node().results_screen
	var shown: bool = await _wait_until(func() -> bool: return results.is_open(), int(_level_node().results_delay * 60.0) + 40)
	_check("reaching the goal shows the results screen", shown and get_tree().paused)
	_check("results show time, coins, sprites and best time", results.get_summary().contains("Time") and results.get_summary().contains("Coins")
		and results.get_summary().contains("Lost Sprites") and results.get_summary().contains("New best time!"), results.get_summary())
	_check("results focus Replay", _focused() == results.replay_button)
	var records: Dictionary = GameState.get_records(LEVEL_PATH)
	_check("completion saves records (best time, sprites, coins)", records["completed"] and records["best_time"] < INF)
	_check("completion clears the in-progress run", not GameState.has_progress())

	results.menu_button.pressed.emit()
	await _wait_scene()
	var menu: MainMenu = _scene() as MainMenu
	_check("results -> Main Menu", menu != null)
	_check("title screen shows the best record", menu.find_children("*", "Label", true, false).any(func(l: Node) -> bool: return (l as Label).text.begins_with("Best:")))
	_check("Continue is disabled after finishing the level", menu.continue_button.disabled)

	menu.start_button.pressed.emit()
	await _wait_scene()
	await _prepare_level()
	_level_node().results_screen.replay_button.pressed.emit()  # Replay starts a fresh run, same as Start.
	await _wait_scene()
	await _prepare_level()
	_check("Replay starts the level fresh", _player.global_position.distance_to((_level.get_node("StartPoint") as Marker3D).global_position) < 0.5 and GameState.coins == 0)
