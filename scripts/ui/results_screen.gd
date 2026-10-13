class_name ResultsScreen
extends CanvasLayer
## Level-complete screen: time, coins, Lost Sprites found, best time; Replay or Main Menu.

var replay_button: Button
var menu_button: Button
var _root: Control
var _time_label: Label
var _coins_label: Label
var _sprites_label: Label
var _best_label: Label


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box: VBoxContainer = UiFactory.centered_panel(_root, Vector2(520, 0), 0.5)
	box.add_child(UiFactory.title("Level Complete!", 54))
	_time_label = UiFactory.title("", 30, Color(1, 1, 1))
	_coins_label = UiFactory.title("", 30, Color(1.0, 0.85, 0.35))
	_sprites_label = UiFactory.title("", 30, Color(1.0, 0.95, 0.65))
	_best_label = UiFactory.title("", 24, Color(0.7, 1.0, 0.7))
	for label: Label in [_time_label, _coins_label, _sprites_label, _best_label]:
		box.add_child(label)
	replay_button = UiFactory.button("Replay", _on_replay)
	menu_button = UiFactory.button("Main Menu", _on_menu)
	box.add_child(replay_button)
	box.add_child(menu_button)
	UiFactory.chain_focus_vertical([replay_button, menu_button])
	MenuSounds.wire(_root)
	visible = false


func is_open() -> bool:
	return visible


func get_summary() -> String:
	return "%s | %s | %s | %s" % [_time_label.text, _coins_label.text, _sprites_label.text, _best_label.text]


func open() -> void:
	var records: Dictionary = GameState.get_records(GameState.current_level)
	_time_label.text = "Time  %s" % GameState.format_time(GameState.level_time)
	_coins_label.text = "Coins  %d" % GameState.coins
	_sprites_label.text = "Lost Sprites  %d / %d" % [GameState.sprite_count(), GameState.sprites_total]
	var new_record: bool = absf(float(records["best_time"]) - GameState.level_time) < 0.001
	_best_label.text = "New best time!" if new_record else "Best  %s" % GameState.format_time(records["best_time"])
	visible = true
	get_tree().paused = true
	replay_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and UiFactory.recover_focus(event, replay_button):
		get_viewport().set_input_as_handled()


func _on_replay() -> void:
	SceneManager.start_new_game()


func _on_menu() -> void:
	SceneManager.go_to_main_menu()
