class_name TrainingDummy
extends StaticBody3D
## Test target for tuning the attack. Never dies; wobbles away from hits and flashes.

@export_group("Reaction")
## Lean speed (radians/s) added per unit of attack knockback.
@export var lean_impulse_per_knockback: float = 0.6
@export var spring_stiffness: float = 140.0
@export var spring_damping: float = 9.0
@export var flash_time: float = 0.1
@export var flash_material: Material

var _lean: Vector2 = Vector2.ZERO
var _lean_velocity: Vector2 = Vector2.ZERO
var _flash_timer: float = 0.0

@onready var _pivot: Node3D = $Pivot
@onready var _body_mesh: MeshInstance3D = $Pivot/Body


func _physics_process(delta: float) -> void:
	var accel: Vector2 = -_lean * spring_stiffness - _lean_velocity * spring_damping
	_lean_velocity += accel * delta
	_lean += _lean_velocity * delta
	# rotation.x tips the top toward +Z, rotation.z tips it toward -X.
	_pivot.rotation = Vector3(_lean.y, 0.0, -_lean.x)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_body_mesh.material_override = null


func take_hit(_damage: int, source_position: Vector3, knockback: float) -> void:
	var away: Vector3 = global_position - source_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD
	_lean_velocity += Vector2(away.x, away.z) * knockback * lean_impulse_per_knockback
	_flash_timer = flash_time
	_body_mesh.material_override = flash_material
