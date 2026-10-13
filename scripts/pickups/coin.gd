class_name Coin
extends Pickup
## Gold coin. Placed coins sit and spin; dropped coins (from enemies) pop out, land,
## and blink away after a while if not collected.

@export var value: int = 1
@export_group("Dropped Coins")
@export var drop_gravity: float = 22.0
@export var drop_lifetime: float = 10.0
@export var hover_height: float = 0.6

var _velocity: Vector3 = Vector3.ZERO
var _flying: bool = false
var _life: float = -1.0


func _on_collected(_player: Player) -> void:
	GameState.add_coins(value)


## Launches a dropped coin outward and up (called right after spawning).
func pop(direction: Vector3) -> void:
	_velocity = direction.normalized() * 2.5 + Vector3.UP * 6.0
	_flying = true
	_life = drop_lifetime


func _physics_process(delta: float) -> void:
	if _flying:
		_velocity.y -= drop_gravity * delta
		var step: Vector3 = _velocity * delta
		if _velocity.y < 0.0:
			var from: Vector3 = global_position
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (hover_height - step.y), 1)
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				global_position = (hit["position"] as Vector3) + Vector3.UP * hover_height
				_flying = false
				return
		global_position += step
	if _life > 0.0:
		_life -= delta
		if _life < 2.0:
			_visual.visible = fmod(_life, 0.2) < 0.12
		if _life <= 0.0 and not _collected:
			queue_free()
