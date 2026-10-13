extends Node
## Player-facing settings. Stage 7 adds load/save (user://settings.cfg), the full
## option set and the settings menu; gameplay code reads the values from here.

signal settings_changed

## Enables camera shake (RailCamera.shake()).
var screen_shake: bool = true:
	set(value):
		screen_shake = value
		settings_changed.emit()

## 0 = snappy camera, 1 = floaty camera.
var camera_smoothing: float = 0.5:
	set(value):
		camera_smoothing = clampf(value, 0.0, 1.0)
		settings_changed.emit()
