class_name HitStop
extends RefCounted
## Briefly slows the whole game (Engine.time_scale) to sell the weight of a hit.
## A new hit-stop replaces any running one; only the latest one restores the time scale.

static var _generation: int = 0


static func apply(tree: SceneTree, duration: float, time_scale: float = 0.05) -> void:
	if duration <= 0.0 or tree == null:
		return
	_generation += 1
	var generation: int = _generation
	Engine.time_scale = clampf(time_scale, 0.01, 1.0)
	# ignore_time_scale = true, otherwise the timer itself would be slowed down.
	var timer: SceneTreeTimer = tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void:
		if generation == _generation:
			Engine.time_scale = 1.0
	)


## Cancels any running hit-stop immediately (e.g. when changing scenes).
static func cancel() -> void:
	_generation += 1
	Engine.time_scale = 1.0
