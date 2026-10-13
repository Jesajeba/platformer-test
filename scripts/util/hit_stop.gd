class_name HitStop
extends RefCounted
## Briefly slows the whole game (Engine.time_scale) to sell the weight of a hit.
## Overlapping calls extend the current stop instead of stacking.

static var _active: bool = false
static var _end_msec: int = 0


static func apply(tree: SceneTree, duration: float, time_scale: float = 0.05) -> void:
	if duration <= 0.0 or tree == null:
		return
	var end_msec: int = Time.get_ticks_msec() + int(duration * 1000.0)
	_end_msec = maxi(_end_msec, end_msec)
	_active = true
	Engine.time_scale = clampf(time_scale, 0.01, 1.0)
	# ignore_time_scale = true, otherwise the timer itself would be slowed down.
	var timer: SceneTreeTimer = tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void: _try_finish())


static func _try_finish() -> void:
	if _active and Time.get_ticks_msec() >= _end_msec - 1:
		_active = false
		Engine.time_scale = 1.0
