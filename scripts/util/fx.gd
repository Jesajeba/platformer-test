class_name Fx
extends RefCounted
## One-shot particle effects (puffs, bursts). Each call spawns a CPUParticles3D that frees itself.


## Soft burst of round puffs, e.g. enemy death or landing dust.
static func puff(parent: Node, at: Vector3, color: Color = Color(1, 1, 1), amount: int = 14,
		size: float = 0.35, speed: float = 3.0, lifetime: float = 0.55) -> CPUParticles3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material

	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.6))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))

	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.mesh = mesh
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.3
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, 1.5, 0)
	particles.damping_min = 3.0
	particles.damping_max = 5.0
	particles.scale_amount_curve = scale_curve
	particles.color_ramp = fade
	return _spawn(parent, particles, at, lifetime)


## Fast burst of small chunks that fall with gravity, e.g. debris.
static func chunks(parent: Node, at: Vector3, color: Color, amount: int = 12, size: float = 0.25,
		speed: float = 6.0, lifetime: float = 0.9, extents: Vector3 = Vector3(0.4, 0.4, 0.4)) -> CPUParticles3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(size, size, size)
	mesh.material = material

	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.mesh = mesh
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = extents
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -18, 0)
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	return _spawn(parent, particles, at, lifetime)


static func _spawn(parent: Node, particles: CPUParticles3D, at: Vector3, lifetime: float) -> CPUParticles3D:
	if parent == null or not parent.is_inside_tree():
		particles.free()
		return null
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	# Safety net in case `finished` doesn't fire (e.g. the node is hidden).
	parent.get_tree().create_timer(lifetime + 1.0, false).timeout.connect(particles.queue_free)
	return particles
