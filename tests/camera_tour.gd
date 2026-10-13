extends SmokeTestBase
## Visual check of the rail camera: visits each camera segment of the test greybox with
## the debug overlay on. Run windowed (optionally with --write-movie) and watch:
##   godot --path . res://tests/camera_tour.tscn

const STOPS: Array[Vector3] = [
	Vector3(0, 0.05, 4),       # Start: behind
	Vector3(0, 0.05, -8),      # Blending into Angled34
	Vector3(0, 0.05, -37),     # PulledBack, on the island after the hover gap
	Vector3(4.2, 0.05, -51.6), # Curve34 on the arc
	Vector3(22, 0.05, -55),    # SideScroller
	Vector3(26, 0.05, -55),    # SideScroller, camera pulled in by the wall
	Vector3(48, 0.05, -55),    # BossArena (locked)
]

@export var frames_per_stop: int = 40


func _run() -> void:
	(_level.get_node("RailDebugOverlay") as RailDebugOverlay).enabled = true
	for stop: Vector3 in STOPS:
		_teleport(stop)
		await _frames(frames_per_stop)
