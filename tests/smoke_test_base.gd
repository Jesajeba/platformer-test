class_name SmokeTestBase
extends Node
## Shared harness for headless smoke tests. Subclasses override `_run()`.
## Loads `level_scene`, drives it with simulated input and quits with the failure count.

@export var level_scene: PackedScene = preload("res://scenes/levels/test_greybox.tscn")

var _failures: int = 0
var _level: Node3D
var _player: Player
var _camera: RailCamera


func _ready() -> void:
	_level = level_scene.instantiate() as Node3D
	add_child(_level)
	_player = _level.get_node("Player") as Player
	_camera = _level.get_node_or_null("RailCamera") as RailCamera
	await _run()
	Engine.time_scale = 1.0
	print("\n%s: %d failure(s)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(_failures)


func _run() -> void:
	pass


func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("[%s] %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail != "" and not ok else ""])


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i: int in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


## Presses an action at the start of a physics frame so the player sees it as just pressed.
func _press_action(action: StringName) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release(action)


## Presses jump (just pressed this frame) and leaves it held.
func _press_jump() -> void:
	await get_tree().physics_frame
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().process_frame


func _jump_and_measure_peak(hold_frames: int) -> float:
	await get_tree().physics_frame
	Input.action_press("jump")
	var peak: float = _player.global_position.y
	for i: int in 90:
		await get_tree().physics_frame
		if i == hold_frames:
			Input.action_release("jump")
		peak = maxf(peak, _player.global_position.y)
		if i > 3 and _player.is_on_floor():
			break
	Input.action_release("jump")
	return peak


## Taps forward so the player (and its attack hitbox) faces camera-forward, then lets it settle.
func _face_forward() -> void:
	Input.action_press("move_forward")
	await _frames(2)
	Input.action_release("move_forward")
	await _frames(25)


## Moves the player instantly and snaps the camera, without the respawn side effects.
func _teleport(pos: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	if _camera != null:
		_camera.snap_to_target()
