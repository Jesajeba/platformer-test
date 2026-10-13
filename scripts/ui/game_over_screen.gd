class_name GameOverScreen
extends CanvasLayer
## Shown when the player is defeated: Retry (from the last checkpoint) or Quit to Menu.

signal retry_requested

var retry_button: Button
var quit_button: Button
var _root: Control


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box: VBoxContainer = UiFactory.centered_panel(_root, Vector2(460, 0), 0.65)
	box.add_child(UiFactory.title("Game Over", 56, Color(1.0, 0.45, 0.5)))
	box.add_child(UiFactory.title("Try again from the last checkpoint?", 22, Color(0.95, 0.92, 0.85)))
	retry_button = UiFactory.button("Retry", _on_retry)
	quit_button = UiFactory.button("Quit to Menu", _on_quit)
	box.add_child(retry_button)
	box.add_child(quit_button)
	UiFactory.chain_focus_vertical([retry_button, quit_button])
	MenuSounds.wire(_root)
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true
	retry_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and UiFactory.recover_focus(event, retry_button):
		get_viewport().set_input_as_handled()


func _on_retry() -> void:
	visible = false
	get_tree().paused = false
	retry_requested.emit()


func _on_quit() -> void:
	SceneManager.go_to_main_menu()
