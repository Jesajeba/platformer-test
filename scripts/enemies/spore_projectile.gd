class_name SporeProjectile
extends Area3D
## Slow spore fired by a Sporeling. Flies straight, hurts the player on touch and
## pops on anything solid or when its lifetime runs out.

@export var pop_color: Color = Color(0.75, 0.45, 0.95)

var _velocity: Vector3 = Vector3.ZERO
var _damage: int = 1
var _life: float = 4.0
var _popped: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(from: Vector3, velocity: Vector3, damage: int, lifetime: float) -> void:
	global_position = from
	_velocity = velocity
	_damage = damage
	_life = lifetime


func _physics_process(delta: float) -> void:
	if _popped:
		return
	global_position += _velocity * delta
	rotation.y += 6.0 * delta
	_life -= delta
	if _life <= 0.0:
		pop()


func pop() -> void:
	if _popped:
		return
	_popped = true
	Fx.puff(get_parent(), global_position, pop_color, 8, 0.25, 2.0, 0.35)
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is EnemyBase:
		return
	if body is Player:
		(body as Player).take_damage(_damage, global_position)
	pop()
