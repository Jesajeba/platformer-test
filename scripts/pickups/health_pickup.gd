class_name HealthPickup
extends Pickup
## Heart that restores health. Only collected when the player is hurt; it stays put otherwise.

@export var heal_amount: int = 2


func can_collect(_player: Player) -> bool:
	return GameState.health < GameState.max_health


func _on_collected(_player: Player) -> void:
	GameState.heal(heal_amount)


func _physics_process(_delta: float) -> void:
	# Catch a player who was already standing here at full health and then got hurt.
	if not _collected and monitoring:
		for body: Node3D in get_overlapping_bodies():
			if body is Player:
				try_collect(body as Player)
