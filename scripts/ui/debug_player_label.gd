extends Label
## Small on-screen readout for tuning the player controller in the test scene.

@export var player: Player


func _process(_delta: float) -> void:
	if player == null:
		return
	var horizontal: float = Vector2(player.velocity.x, player.velocity.z).length()
	text = "State: %s\nHP: %d/%d\nSpeed: %.1f   Vertical: %.1f\nHover left: %.2f s\nFPS: %d" % [
		player.get_state_name(),
		GameState.health,
		GameState.max_health,
		horizontal,
		player.velocity.y,
		player.get_hover_time_left(),
		Engine.get_frames_per_second(),
	]
