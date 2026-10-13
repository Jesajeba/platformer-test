class_name SettingsMenu
extends Control
## Settings overlay shared by the main menu and the pause menu. Every change is applied and
## saved immediately (SettingsManager). Works while the game is paused.

signal closed

var _focusables: Array[Control] = []
var _binding_buttons: Dictionary = {}  # "action|pad" -> Button
var _capture_action: StringName = &""
var _capture_gamepad: bool = false
var _first: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = UiFactory.centered_panel(self, Vector2(820, 640), 0.6)
	box.add_child(UiFactory.title("Settings", 44))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 480)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var resolutions: PackedStringArray = PackedStringArray()
	for r: Vector2i in SettingsManager.RESOLUTIONS:
		resolutions.append("%d x %d" % [r.x, r.y])
	var fps_caps: PackedStringArray = PackedStringArray()
	for cap: int in SettingsManager.FPS_CAPS:
		fps_caps.append("Unlimited" if cap == 0 else str(cap))

	_heading(list, "Display")
	_first = _option(list, "Resolution", resolutions, SettingsManager.resolution_index, "resolution_index")
	_option(list, "Window Mode", SettingsManager.WINDOW_MODES, SettingsManager.window_mode, "window_mode")
	_check(list, "V-Sync", SettingsManager.vsync, "vsync")
	_option(list, "FPS Cap", fps_caps, SettingsManager.fps_cap_index, "fps_cap_index")
	_heading(list, "Audio")
	_slider(list, "Master Volume", SettingsManager.master_volume, "master_volume")
	_slider(list, "Music Volume", SettingsManager.music_volume, "music_volume")
	_slider(list, "SFX Volume", SettingsManager.sfx_volume, "sfx_volume")
	_heading(list, "Gameplay")
	_slider(list, "Camera Smoothing", SettingsManager.camera_smoothing, "camera_smoothing")
	_check(list, "Screen Shake", SettingsManager.screen_shake, "screen_shake")
	_heading(list, "Graphics")
	_option(list, "Quality", SettingsManager.QUALITY_NAMES, SettingsManager.quality, "quality")
	_heading(list, "Controls")
	var header: HBoxContainer = _row(list, "Action")
	header.add_child(_fixed_label("Keyboard / Mouse", 220))
	header.add_child(_fixed_label("Gamepad", 220))
	for action: StringName in SettingsManager.REBINDABLE_ACTIONS:
		var row: HBoxContainer = _row(list, SettingsManager.ACTION_NAMES[action])
		for gamepad: bool in [false, true]:
			var bind: Button = Button.new()
			bind.custom_minimum_size = Vector2(220, 48)
			bind.pressed.connect(_begin_capture.bind(action, gamepad))
			row.add_child(bind)
			_binding_buttons["%s|%s" % [action, gamepad]] = bind
			_focusables.append(bind)
	_refresh_bindings()

	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 20)
	box.add_child(footer)
	var reset: Button = UiFactory.button("Reset Controls", _on_reset_controls, 260)
	var back: Button = UiFactory.button("Back", close, 200)
	footer.add_child(reset)
	footer.add_child(back)
	_focusables.append(reset)
	_focusables.append(back)
	MenuSounds.wire(self)
	_first.call_deferred("grab_focus")


func close() -> void:
	closed.emit()
	queue_free()


func is_capturing() -> bool:
	return _capture_action != &""


func _unhandled_input(event: InputEvent) -> void:
	if not is_capturing() and event.is_action_pressed("ui_cancel"):
		AudioManager.play_ui(&"ui_back")
		get_viewport().set_input_as_handled()
		close()


func _input(event: InputEvent) -> void:
	if not is_capturing():
		return
	var captured: InputEvent = _normalize(event)
	if captured == null:
		return
	get_viewport().set_input_as_handled()
	if captured is InputEventKey and (captured as InputEventKey).physical_keycode == KEY_ESCAPE and _capture_action != &"pause":
		_end_capture()  # Escape cancels (except when binding Pause itself).
		return
	if SettingsManager.is_gamepad_event(captured) != _capture_gamepad:
		return
	SettingsManager.rebind(_capture_action, captured)
	_end_capture()


## Starts waiting for a new key/button for `action` (used by the binding buttons; public for tests).
func begin_capture(action: StringName, gamepad: bool) -> void:
	_begin_capture(action, gamepad)


func _begin_capture(action: StringName, gamepad: bool) -> void:
	_capture_action = action
	_capture_gamepad = gamepad
	(_binding_buttons["%s|%s" % [action, gamepad]] as Button).text = "Press a button..." if gamepad else "Press a key..."


func _end_capture() -> void:
	var button: Button = _binding_buttons["%s|%s" % [_capture_action, _capture_gamepad]]
	_capture_action = &""
	_refresh_bindings()
	button.call_deferred("grab_focus")


func _refresh_bindings() -> void:
	for key: String in _binding_buttons:
		var parts: PackedStringArray = key.split("|")
		(_binding_buttons[key] as Button).text = SettingsManager.get_binding_label(StringName(parts[0]), parts[1] == "true")


func _on_reset_controls() -> void:
	SettingsManager.reset_controls()
	_refresh_bindings()


## Keeps only fresh presses we can bind, rebuilt without device/modifier noise.
func _normalize(event: InputEvent) -> InputEvent:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = (event as InputEventKey).physical_keycode
		if key.physical_keycode == KEY_NONE:
			key.keycode = (event as InputEventKey).keycode
		return key
	if event is InputEventMouseButton and event.is_pressed():
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = (event as InputEventMouseButton).button_index
		return mouse
	if event is InputEventJoypadButton and event.is_pressed():
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = (event as InputEventJoypadButton).button_index
		return button
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = (event as InputEventJoypadMotion).axis
		motion.axis_value = signf((event as InputEventJoypadMotion).axis_value)
		return motion
	return null


#region Row builders

func _heading(list: VBoxContainer, text: String) -> void:
	var label: Label = UiFactory.label(text, 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	list.add_child(label)


func _row(list: VBoxContainer, text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_fixed_label(text, 270))
	list.add_child(row)
	return row


func _fixed_label(text: String, width: float) -> Label:
	var label: Label = UiFactory.label(text, 22)
	label.custom_minimum_size = Vector2(width, 0)
	return label


func _option(list: VBoxContainer, text: String, items: PackedStringArray, selected: int, setting: String) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(320, 48)
	for item: String in items:
		option.add_item(item)
	option.select(clampi(selected, 0, items.size() - 1))
	option.item_selected.connect(func(index: int) -> void: SettingsManager.set_setting(setting, index))
	_row(list, text).add_child(option)
	_focusables.append(option)
	return option


func _check(list: VBoxContainer, text: String, value: bool, setting: String) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.button_pressed = value
	check.toggled.connect(func(on: bool) -> void: SettingsManager.set_setting(setting, on))
	_row(list, text).add_child(check)
	_focusables.append(check)
	return check


func _slider(list: VBoxContainer, text: String, value: float, setting: String) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.custom_minimum_size = Vector2(320, 32)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundf(value * 100.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var readout: Label = _fixed_label("%d%%" % int(slider.value), 70)
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = "%d%%" % int(v)
		SettingsManager.set_setting(setting, v / 100.0))
	var row: HBoxContainer = _row(list, text)
	row.add_child(slider)
	row.add_child(readout)
	_focusables.append(slider)
	return slider

#endregion
