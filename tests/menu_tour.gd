extends SmokeTestBase
## Visual check of the menus: title, settings, pause, game over and results.
## Run windowed: godot --path . res://tests/menu_tour.tscn

var marks: Dictionary = {}
var _frame: int = 0


func _init() -> void:
	level_scene = null


func _process(_delta: float) -> void:
	_frame += 1


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var placeholder: Node = Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	GameState.start_new_run()
	SceneManager.change_scene(SceneManager.MAIN_MENU)
	await _settle(60)
	marks["title"] = _frame
	var menu: MainMenu = get_tree().current_scene as MainMenu
	menu.settings_button.pressed.emit()
	await _settle(30)
	marks["settings"] = _frame
	(menu.find_children("*", "SettingsMenu", true, false)[0] as SettingsMenu).close()
	menu.start_button.pressed.emit()
	await _settle(80)
	var level: Level = get_tree().current_scene as Level
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	level.pause_menu.open()
	await _settle(20)
	marks["pause"] = _frame
	level.pause_menu.close()
	GameState.health = 1
	level.player.take_damage(1, level.player.global_position + Vector3.RIGHT)
	await _settle(110)
	marks["game_over"] = _frame
	level.game_over_screen.retry_button.pressed.emit()
	await _settle(10)
	GameState.complete_level()
	await _settle(100)
	marks["results"] = _frame
	print("MARKS ", marks)


func _settle(frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame
