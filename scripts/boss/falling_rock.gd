class_name FallingRock
extends Node3D
## A rock that drops from the sky after a warning marker on the ground (phase 3 arena hazard).

@export var warning_time: float = 1.3
@export var drop_height: float = 16.0
@export var radius: float = 1.6
@export var damage: int = 1

var _time: float = 0.0
var _landed: bool = false

@onready var _marker: MeshInstance3D = $Marker
@onready var _rock: Node3D = $Rock


func _ready() -> void:
	add_to_group("boss_hazards")
	_marker.scale = Vector3(radius, 1.0, radius)
	_rock.position.y = drop_height


func _process(delta: float) -> void:
	if _landed:
		return
	_time += delta
	var t: float = clampf(_time / warning_time, 0.0, 1.0)
	# The marker pulses faster as the rock gets closer.
	_marker.transparency = 0.15 + 0.35 * (0.5 + 0.5 * sin(_time * lerpf(6.0, 22.0, t)))
	# The rock hangs high, then drops quickly in the last part of the warning.
	var fall: float = clampf((t - 0.55) / 0.45, 0.0, 1.0)
	_rock.position.y = lerpf(drop_height, 0.6, fall * fall)
	if t >= 1.0:
		_land()


func _land() -> void:
	_landed = true
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player != null:
		var offset: Vector3 = player.global_position - global_position
		if Vector2(offset.x, offset.z).length() < radius + 0.3 and offset.y < 2.5 and offset.y > -1.0:
			player.take_damage(damage, global_position)
	Fx.chunks(get_parent(), global_position + Vector3.UP * 0.5, Color(0.5, 0.45, 0.4), 10, 0.35, 6.0, 0.9)
	Fx.puff(get_parent(), global_position + Vector3.UP * 0.3, Color(0.85, 0.8, 0.7), 10, 0.8, 3.0, 0.6)
	AudioManager.play_sfx(&"stone_hit", 0.1)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("shake"):
		camera.call("shake", 0.25, 0.2)
	queue_free()
