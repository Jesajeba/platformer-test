@tool
class_name GreyboxBlock
extends StaticBody3D
## Solid box for greyboxing. Builds its own mesh and collision from `size`,
## so a level can be laid out with one node per block.

@export_group("Block")
@export var size: Vector3 = Vector3(4.0, 1.0, 4.0):
	set(value):
		size = value.max(Vector3(0.05, 0.05, 0.05))
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	_mesh_instance.mesh = mesh

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
