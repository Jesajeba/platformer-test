class_name PauseMenu
extends CanvasLayer
## Pause menu (Esc / Start): Resume, Settings, Restart from checkpoint, Main menu.
## Pauses the tree; this node keeps processing (PROCESS_MODE_ALWAYS).

signal opened
signal closed

const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")

var resume_button: Button
var settings_button: Button
var restart_button: Button
var menu_button: Button
var _root: Control
var _buttons: Array[Control] = []
var _settings: SettingsMenu


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box: VBoxContainer = UiFactory.centered_panel(_root, Vector2(440, 0))
	box.add_child(UiFactory.title("Paused", 52))
	resume_button = UiFactory.button("Resume", close)
	settings_button = UiFactory.button("Settings", _on_settings)
	restart_button = UiFactory.button("Restart from Checkpoint", _on_restart)
	menu_button = UiFactory.button("Main Menu", _on_main_menu)
	_buttons = [resume_button, settings_button, restart_button, menu_button]
	for button: Control in _buttons:
		box.add_child(button)
	UiFactory.chain_focus_vertical(_buttons)
	MenuSounds.wire(_root)
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true
	AudioManager.play_ui(&"ui_select")
	resume_button.grab_focus()
	opened.emit()


func close() -> void:
	if is_instance_valid(_settings):
		_settings.close()
	visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_instance_valid(_settings):
		return
	if UiFactory.recover_focus(event, resume_button):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui(&"ui_back")
		close()


func _on_settings() -> void:
	_settings = SETTINGS_SCENE.instantiate() as SettingsMenu
	_root.add_child(_settings)
	_settings.closed.connect(func() -> void: settings_button.grab_focus())


func _on_restart() -> void:
	GameState.restart_from_checkpoint()
	SceneManager.reload_current()


func _on_main_menu() -> void:
	SceneManager.go_to_main_menu()
