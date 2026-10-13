extends CanvasLayer
## Scene changes with a fade to black. Also the entry points for starting/continuing a game.

signal scene_changed(path: String)

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const FIRST_LEVEL: String = "res://scenes/levels/level_ruins.tscn"

@export var fade_time: float = 0.35

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func is_busy() -> bool:
	return _busy


## Fades out, swaps the scene, fades back in. Unpauses the game and resets time scale.
func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var out: Tween = create_tween()
	out.tween_property(_fade, "color:a", 1.0, fade_time)
	await out.finished
	get_tree().paused = false
	HitStop.cancel()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back: Tween = create_tween()
	back.tween_property(_fade, "color:a", 0.0, fade_time)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	scene_changed.emit(path)


func reload_current() -> void:
	var current: Node = get_tree().current_scene
	if current != null:
		change_scene(current.scene_file_path)


func go_to_main_menu() -> void:
	change_scene(MAIN_MENU)


func start_new_game() -> void:
	GameState.start_new_run()
	change_scene(FIRST_LEVEL)


## Loads the saved run; falls back to a new game if there's nothing to continue.
func continue_game() -> void:
	var level: String = GameState.continue_from_save()
	if level == "":
		start_new_game()
	else:
		change_scene(level)
