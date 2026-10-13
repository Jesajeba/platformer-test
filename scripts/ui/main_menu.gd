class_name MainMenu
extends Control
## Title screen: Start, Continue (only with a save), Settings, Quit, plus best records.

const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")

var start_button: Button
var continue_button: Button
var settings_button: Button
var quit_button: Button
var _buttons: Array[Control] = []
var _settings: SettingsMenu
var _time: float = 0.0
var _mascot: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	_mascot = _make_mascot()
	column.add_child(_mascot)
	column.add_child(UiFactory.title("OVERGROWN RUINS", 76))
	var subtitle: Label = UiFactory.title("a tiny 3D platformer", 26, Color(0.95, 0.95, 0.85))
	column.add_child(subtitle)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	column.add_child(spacer)

	start_button = UiFactory.button("Start", _on_start)
	continue_button = UiFactory.button("Continue", _on_continue)
	settings_button = UiFactory.button("Settings", _on_settings)
	quit_button = UiFactory.button("Quit", _on_quit)
	for button: Button in [start_button, continue_button, settings_button, quit_button]:
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(button)
	continue_button.disabled = not GameState.has_progress()
	if continue_button.disabled:
		continue_button.focus_mode = Control.FOCUS_NONE  # Keyboard/gamepad navigation skips it.
	_buttons = [start_button, continue_button, settings_button, quit_button]
	if continue_button.disabled:
		UiFactory.chain_focus_vertical([start_button, settings_button, quit_button])
	else:
		UiFactory.chain_focus_vertical(_buttons)

	var records: Dictionary = GameState.get_records(SceneManager.FIRST_LEVEL)
	var record_text: String = "Best: %s   Lost Sprites %d/3   Coins %d" % [GameState.format_time(records["best_time"]), records["best_sprites"], records["best_coins"]] \
		if records["completed"] else "Find the 3 Lost Sprites and defeat King Mossback!"
	var record_label: Label = UiFactory.title(record_text, 22, Color(1, 0.95, 0.75))
	column.add_child(record_label)

	MenuSounds.wire(self)
	(func() -> void: UiFactory.focus_first(_buttons)).call_deferred()
	AudioManager.play_music(&"menu")


func _process(delta: float) -> void:
	_time += delta
	_mascot.position.y = sin(_time * 2.2) * 6.0
	_mascot.rotation = sin(_time * 1.3) * 0.06


func _unhandled_input(event: InputEvent) -> void:
	if not is_settings_open() and UiFactory.recover_focus(event, start_button):
		get_viewport().set_input_as_handled()


func _on_start() -> void:
	SceneManager.start_new_game()


func _on_continue() -> void:
	SceneManager.continue_game()


func _on_settings() -> void:
	_settings = SETTINGS_SCENE.instantiate() as SettingsMenu
	add_child(_settings)
	_settings.closed.connect(func() -> void: settings_button.grab_focus())


func _on_quit() -> void:
	AudioManager.quit_game()


func is_settings_open() -> bool:
	return is_instance_valid(_settings)


func _build_background() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.55, 0.78, 0.95))
	gradient.set_color(1, Color(0.32, 0.55, 0.28))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var background: TextureRect = TextureRect.new()
	background.texture = texture
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(background)
	# Rolling hills.
	var hills: Control = Control.new()
	hills.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hills.draw.connect(func() -> void:
		var s: Vector2 = hills.size
		hills.draw_circle(Vector2(s.x * 0.15, s.y * 1.05), s.x * 0.35, Color(0.27, 0.48, 0.22))
		hills.draw_circle(Vector2(s.x * 0.85, s.y * 1.1), s.x * 0.4, Color(0.24, 0.44, 0.2))
		hills.draw_circle(Vector2(s.x * 0.5, s.y * 1.25), s.x * 0.45, Color(0.3, 0.52, 0.25)))
	hills.resized.connect(hills.queue_redraw)
	add_child(hills)


## A little pink puffball drawn in code.
func _make_mascot() -> Control:
	var mascot: Control = Control.new()
	mascot.custom_minimum_size = Vector2(120, 110)
	mascot.pivot_offset = Vector2(60, 60)
	mascot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mascot.draw.connect(func() -> void:
		var c: Vector2 = Vector2(60, 55)
		mascot.draw_circle(c + Vector2(-26, 42), 18, Color(0.86, 0.16, 0.3))
		mascot.draw_circle(c + Vector2(26, 42), 18, Color(0.86, 0.16, 0.3))
		mascot.draw_circle(c, 48, Color(1.0, 0.66, 0.78))
		mascot.draw_circle(c + Vector2(-44, 8), 13, Color(1.0, 0.66, 0.78))
		mascot.draw_circle(c + Vector2(44, 8), 13, Color(1.0, 0.66, 0.78))
		for side: float in [-1.0, 1.0]:
			mascot.draw_rect(Rect2(c + Vector2(side * 13 - 5, -22), Vector2(10, 24)), Color(0.08, 0.1, 0.25))
			mascot.draw_circle(c + Vector2(side * 27, 6), 7, Color(1.0, 0.42, 0.55)))
	return mascot
