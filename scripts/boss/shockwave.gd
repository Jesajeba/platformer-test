class_name Shockwave
extends Node3D
## Expanding ground ring from King Mossback's slam. Hurts a player standing on the ground
## where the ring passes; jumping over it is safe.

@export var speed: float = 9.0
@export var max_radius: float = 16.0
## Width of the damaging band.
@export var band_width: float = 1.1
## The player is safe if their feet are higher than this above the ground.
@export var safe_height: float = 0.6
@export var damage: int = 1

var _radius: float = 0.5
var _hit: bool = false
var _mesh: TorusMesh

@onready var _ring: MeshInstance3D = $Ring


func _ready() -> void:
	add_to_group("boss_hazards")
	_mesh = (_ring.mesh as TorusMesh).duplicate() as TorusMesh
	_ring.mesh = _mesh
	_update_mesh()


func _physics_process(delta: float) -> void:
	_radius += speed * delta
	_update_mesh()
	if not _hit:
		var player: Player = get_tree().get_first_node_in_group("player") as Player
		if player != null:
			var offset: Vector3 = player.global_position - global_position
			var distance: float = Vector2(offset.x, offset.z).length()
			# The wave's origin sits on the ground (read every frame: it may be placed after _ready).
			var feet_height: float = player.global_position.y - global_position.y
			if absf(distance - _radius) < band_width * 0.5 and feet_height < safe_height and feet_height > -1.0:
				_hit = true
				player.take_damage(damage, global_position)
	if _radius >= max_radius:
		queue_free()


func get_radius() -> float:
	return _radius


func _update_mesh() -> void:
	_mesh.inner_radius = maxf(_radius - band_width * 0.5, 0.05)
	_mesh.outer_radius = _radius + band_width * 0.5
	var fade: float = clampf(1.0 - _radius / max_radius, 0.0, 1.0)
	_ring.transparency = 1.0 - fade
