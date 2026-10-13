@tool
class_name ThornPatch
extends DamageArea
## A patch of thorns covering `size` (x/z footprint, y height). Builds its own
## thorn meshes and damage volume. Thorns hurt on touch and knock the player back.

@export_group("Thorns")
@export var size: Vector3 = Vector3(2.0, 0.8, 2.0):
	set(value):
		size = value.max(Vector3(0.3, 0.1, 0.3))
		_rebuild()
@export var thorn_material: Material:
	set(value):
		thorn_material = value
		_rebuild()
@export var base_material: Material:
	set(value):
		base_material = value
		_rebuild()
## Distance between thorns.
@export var spacing: float = 0.55:
	set(value):
		spacing = maxf(value, 0.2)
		_rebuild()
@export var seed_value: int = 1:
	set(value):
		seed_value = value
		_rebuild()

var _visual: Node3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	monitorable = false
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)

	# Low tangle of vines at the base.
	if base_material != null:
		var base: MeshInstance3D = MeshInstance3D.new()
		var base_mesh: BoxMesh = BoxMesh.new()
		base_mesh.size = Vector3(size.x, 0.15, size.z)
		base_mesh.material = base_material
		base.mesh = base_mesh
		base.position.y = 0.075
		_visual.add_child(base)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.16
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 1
	cone.material = thorn_material
	var count_x: int = maxi(int(size.x / spacing), 1)
	var count_z: int = maxi(int(size.z / spacing), 1)
	for ix: int in count_x:
		for iz: int in count_z:
			var thorn: MeshInstance3D = MeshInstance3D.new()
			thorn.mesh = cone
			var height: float = size.y * rng.randf_range(0.6, 1.0)
			var x: float = (ix + 0.5) / count_x * size.x - size.x * 0.5 + rng.randf_range(-0.12, 0.12)
			var z: float = (iz + 0.5) / count_z * size.z - size.z * 0.5 + rng.randf_range(-0.12, 0.12)
			thorn.position = Vector3(x, height * 0.5, z)
			thorn.scale = Vector3(1.0, height, 1.0)
			thorn.rotation = Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
			_visual.add_child(thorn)

	if _collision == null:
		_collision = CollisionShape3D.new()
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(size.x, size.y + 0.2, size.z)
	_collision.shape = box
	_collision.position.y = (size.y + 0.2) * 0.5
