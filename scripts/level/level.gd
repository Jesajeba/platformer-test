class_name Level
extends Node3D
## Root script for a playable level. Places the player at the start point (or the
## active checkpoint when reloading the same level) and snaps the camera.

@export var player: Player
@export var start_point: Marker3D
@export var camera: RailCamera


func _ready() -> void:
	var level_id: String = scene_file_path
	if GameState.current_level != level_id or not GameState.has_checkpoint:
		GameState.begin_level(level_id, start_point.global_transform)
	if player != null:
		player.place_at_checkpoint()
	if camera != null:
		camera.snap_to_target()
	if player != null:
		# A death rolls collected items back to the checkpoint (pits don't).
		player.respawned.connect(GameState.revert_to_checkpoint)


func _process(delta: float) -> void:
	GameState.tick_level_time(delta)
