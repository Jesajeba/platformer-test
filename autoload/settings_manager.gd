extends Node
## Player settings: loaded from / saved to user://settings.cfg (ConfigFile) and applied immediately.
## Display (resolution, window mode, V-Sync, FPS cap), audio volumes, gameplay (camera smoothing,
## screen shake), graphics quality preset and control bindings.

signal settings_changed

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1680, 1050), Vector2i(1920, 1200),
]
const WINDOW_MODES: PackedStringArray = ["Windowed", "Fullscreen", "Borderless"]
const FPS_CAPS: Array[int] = [0, 30, 60, 120, 144, 240]
const QUALITY_NAMES: PackedStringArray = ["Low", "Medium", "High"]
const REBINDABLE_ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"attack", &"pause"]
const ACTION_NAMES: Dictionary = {
	&"move_forward": "Move Forward", &"move_back": "Move Back", &"move_left": "Move Left", &"move_right": "Move Right",
	&"jump": "Jump / Hover", &"attack": "Attack", &"pause": "Pause",
}
const JOY_BUTTON_NAMES: Dictionary = {
	0: "A / Cross", 1: "B / Circle", 2: "X / Square", 3: "Y / Triangle", 4: "Back / Share", 5: "Guide",
	6: "Start / Options", 7: "L3", 8: "R3", 9: "LB / L1", 10: "RB / R1", 11: "D-Pad Up", 12: "D-Pad Down",
	13: "D-Pad Left", 14: "D-Pad Right",
}

## Where settings are stored (tests point this elsewhere).
var settings_path: String = "user://settings.cfg"

# Display
var resolution_index: int = 0
var window_mode: int = 0
var vsync: bool = true
var fps_cap_index: int = 0
# Audio (linear 0..1)
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.8
# Gameplay
## Enables camera shake (RailCamera.shake()).
var screen_shake: bool = true
## 0 = snappy camera, 1 = floaty camera.
var camera_smoothing: float = 0.5
# Graphics
var quality: int = 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


## Changes one setting by name, applies it and saves.
func set_setting(setting: String, value: Variant) -> void:
	set(setting, value)
	camera_smoothing = clampf(camera_smoothing, 0.0, 1.0)
	apply_all()
	save_settings()
	settings_changed.emit()


#region Apply

func apply_all() -> void:
	apply_display()
	apply_audio()
	apply_graphics()


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.max_fps = FPS_CAPS[clampi(fps_cap_index, 0, FPS_CAPS.size() - 1)]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match window_mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var size: Vector2i = RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]
			var screen: Rect2i = DisplayServer.screen_get_usable_rect()
			size = size.min(screen.size)
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func apply_audio() -> void:
	_set_bus(&"Master", master_volume)
	_set_bus(&"Music", music_volume)
	_set_bus(&"SFX", sfx_volume)


func _set_bus(bus_name: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


## Quality preset: MSAA, shadow resolution/filtering, render scale, SSAO and glow.
func apply_graphics() -> void:
	var viewport: Viewport = get_tree().root
	match quality:
		0:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 1.0
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		_:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	for node: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = (node as WorldEnvironment).environment
		if environment != null:
			environment.ssao_enabled = quality >= 1
			environment.glow_enabled = quality >= 1

#endregion


#region Save / load

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "fps_cap_index", fps_cap_index)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("gameplay", "camera_smoothing", camera_smoothing)
	config.set_value("gameplay", "screen_shake", screen_shake)
	config.set_value("graphics", "quality", quality)
	for action: StringName in REBINDABLE_ACTIONS:
		var events: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			var data: Dictionary = event_to_dict(event)
			if not data.is_empty():
				events.append(data)
		config.set_value("controls", String(action), events)
	config.save(settings_path)


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	resolution_index = config.get_value("display", "resolution_index", resolution_index)
	window_mode = config.get_value("display", "window_mode", window_mode)
	vsync = config.get_value("display", "vsync", vsync)
	fps_cap_index = config.get_value("display", "fps_cap_index", fps_cap_index)
	master_volume = config.get_value("audio", "master", master_volume)
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	camera_smoothing = config.get_value("gameplay", "camera_smoothing", camera_smoothing)
	screen_shake = config.get_value("gameplay", "screen_shake", screen_shake)
	quality = config.get_value("graphics", "quality", quality)
	if config.has_section("controls"):
		for action: StringName in REBINDABLE_ACTIONS:
			var events: Array = config.get_value("controls", String(action), [])
			if events.is_empty() or not InputMap.has_action(action):
				continue
			InputMap.action_erase_events(action)
			for data: Dictionary in events:
				var event: InputEvent = dict_to_event(data)
				if event != null:
					InputMap.action_add_event(action, event)

#endregion


#region Controls

## Replaces the action's keyboard/mouse binding (or gamepad binding) with `event`.
func rebind(action: StringName, event: InputEvent) -> void:
	var gamepad: bool = is_gamepad_event(event)
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var replaced: bool = false
	for existing: InputEvent in events:
		if not replaced and is_gamepad_event(existing) == gamepad:
			InputMap.action_add_event(action, event)
			replaced = true
		else:
			InputMap.action_add_event(action, existing)
	if not replaced:
		InputMap.action_add_event(action, event)
	save_settings()
	settings_changed.emit()


func reset_controls() -> void:
	InputMap.load_from_project_settings()
	save_settings()
	settings_changed.emit()


func is_gamepad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


## Human-readable label for the first keyboard/mouse (or gamepad) binding of an action.
func get_binding_label(action: StringName, gamepad: bool) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if is_gamepad_event(event) == gamepad:
			return event_label(event)
	return "-"


func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Left Mouse"
			MOUSE_BUTTON_RIGHT:
				return "Right Mouse"
			MOUSE_BUTTON_MIDDLE:
				return "Middle Mouse"
		return "Mouse %d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return JOY_BUTTON_NAMES.get((event as InputEventJoypadButton).button_index, "Button %d" % (event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		var positive: bool = motion.axis_value > 0.0
		match motion.axis:
			JOY_AXIS_LEFT_X:
				return "Left Stick " + ("Right" if positive else "Left")
			JOY_AXIS_LEFT_Y:
				return "Left Stick " + ("Down" if positive else "Up")
			JOY_AXIS_RIGHT_X:
				return "Right Stick " + ("Right" if positive else "Left")
			JOY_AXIS_RIGHT_Y:
				return "Right Stick " + ("Down" if positive else "Up")
			JOY_AXIS_TRIGGER_LEFT:
				return "LT / L2"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT / R2"
		return "Axis %d" % motion.axis
	return event.as_text()


func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key: InputEventKey = event
		return {"type": "key", "physical_keycode": key.physical_keycode, "keycode": key.keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button_index": (event as InputEventMouseButton).button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		return {"type": "joy_axis", "axis": motion.axis, "value": signf(motion.axis_value)}
	return {}


func dict_to_event(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = data.get("physical_keycode", KEY_NONE)
			key.keycode = data.get("keycode", KEY_NONE)
			return key
		"mouse":
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = data.get("button_index", MOUSE_BUTTON_LEFT)
			return mouse
		"joy_button":
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.button_index = data.get("button_index", JOY_BUTTON_A)
			return button
		"joy_axis":
			var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion.axis = data.get("axis", JOY_AXIS_LEFT_X)
			motion.axis_value = data.get("value", 1.0)
			return motion
	return null

#endregion
