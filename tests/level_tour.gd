extends SmokeTestBase
## Visual tour of the Overgrown Ruins level: stops at each segment and secret.
## Run windowed (optionally with --write-movie):
##   godot --path . res://tests/level_tour.tscn

const STOPS: Array[Vector3] = [
	Vector3(0, 0.05, 2),         # Courtyard start
	Vector3(-6, 0.05, -12),      # Secret wall 1 (left)
	Vector3(0, 2.05, -42),       # Terrace, gaps ahead
	Vector3(20, 2.05, -80),      # Colonnade: thorns, gap
	Vector3(56, 2.05, -80),      # Colonnade: crumbling bridge
	Vector3(110, 5.05, -80),     # Stairway
	Vector3(136, 10.05, -80),    # Lift up the cliff
	Vector3(184, 10.05, -80),    # Sunken garden islands
	Vector3(250, 10.05, -80),    # Arena approach
	Vector3(270, 10.05, -75),    # Throne arena
	Vector3(198, 10.05, -88),    # Shortcut corridor (near wall fades out)
	Vector3(53, 2.05, -81.6),    # Colonnade, behind a pillar stump
	Vector3(272, 10.05, -90.5),  # Arena, behind the boss by the throne (orbit camera)
	Vector3(281, 10.05, -76),    # Arena, east side (orbit camera)
]

@export var frames_per_stop: int = 40


func _init() -> void:
	level_scene = load("res://scenes/levels/level_ruins.tscn")


func _run() -> void:
	for stop: Vector3 in STOPS:
		_teleport(stop)
		await _frames(frames_per_stop)
