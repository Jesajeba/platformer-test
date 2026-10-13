@tool
class_name GreyboxBlock
extends StaticBody3D
## Solid box or cylinder for level building. Builds its own mesh and collision from
## `size`, with an optional cap (e.g. moss or grass) over the top surface.
## For cylinders, size.x is the diameter and size.y the height.

enum ShapeType { BOX, CYLINDER }

@export_group("Block")
@export var shape_type: ShapeType = ShapeType.BOX:
	set(value):
		shape_type = value
		_rebuild()
@export var size: Vector3 = Vector3(4.0, 1.0, 4.0):
	set(value):
		size = value.max(Vector3(0.05, 0.05, 0.05))
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()

@export_group("Top Cap")
## Optional material for a thin cap over the top face (moss, grass...). Leave empty for none.
@export var top_material: Material:
	set(value):
		top_material = value
		_rebuild()
@export var top_thickness: float = 0.15:
	set(value):
		top_thickness = maxf(value, 0.01)
		_rebuild()

var _visual: Node3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = build_visual(shape_type, size, material, top_material, top_thickness)
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	_collision.shape = build_shape(shape_type, size)


## Builds the visual for a block (body mesh plus optional top cap), centered on the origin.
static func build_visual(shape: ShapeType, block_size: Vector3, body_material: Material,
		cap_material: Material = null, cap_thickness: float = 0.15) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Visual"
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = _make_mesh(shape, block_size, body_material)
	root.add_child(body)
	if cap_material != null:
		var thickness: float = minf(cap_thickness, block_size.y)
		var overhang: float = 0.06
		var cap_size: Vector3 = Vector3(block_size.x + overhang, thickness, block_size.z + overhang)
		var cap: MeshInstance3D = MeshInstance3D.new()
		cap.mesh = _make_mesh(shape, cap_size, cap_material)
		cap.position.y = block_size.y * 0.5 - thickness * 0.5 + 0.01
		root.add_child(cap)
	return root


static func build_shape(shape: ShapeType, block_size: Vector3) -> Shape3D:
	if shape == ShapeType.CYLINDER:
		var cylinder: CylinderShape3D = CylinderShape3D.new()
		cylinder.radius = block_size.x * 0.5
		cylinder.height = block_size.y
		return cylinder
	var box: BoxShape3D = BoxShape3D.new()
	box.size = block_size
	return box


static func _make_mesh(shape: ShapeType, mesh_size: Vector3, mesh_material: Material) -> Mesh:
	if shape == ShapeType.CYLINDER:
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = mesh_size.x * 0.5
		cylinder.bottom_radius = mesh_size.x * 0.5
		cylinder.height = mesh_size.y
		cylinder.radial_segments = 24
		cylinder.rings = 1
		cylinder.material = mesh_material
		return cylinder
	var box: BoxMesh = BoxMesh.new()
	box.size = mesh_size
	box.material = mesh_material
	return box
