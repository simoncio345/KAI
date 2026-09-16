extends Node3D

@export var world_size := 80
@export var cell_size := 4.0
@export var seed := 0
@export var tree_count := 120

var rng := RandomNumberGenerator.new()
var world_root: Node3D

func _ready() -> void:
	world_root = Node3D.new()
	world_root.name = "ProceduralWorld"
	add_child(world_root)
	rng.seed = seed if seed != 0 else Time.get_unix_time_from_system()
	generate_world()

func generate_world() -> void:
	for x in range(-world_size / 2, world_size / 2):
		for z in range(-world_size / 2, world_size / 2):
			var height := noise_height(x, z)
			create_ground_cell(Vector3(x * cell_size, height - 1.0, z * cell_size))
	for i in tree_count:
		create_tree(Vector3(rng.randf_range(-world_size * 2.0, world_size * 2.0), 0, rng.randf_range(-world_size * 2.0, world_size * 2.0)))
	create_gas_zone(Vector3(0, 0, 0), 18.0)
	create_lab(Vector3(12, 0, 12))

func noise_height(x: int, z: int) -> float:
	return sin(float(x) * 0.17) * 1.5 + cos(float(z) * 0.13) * 1.2

func create_ground_cell(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(cell_size + 0.05, 2.0, cell_size + 0.05)
	mesh.mesh = box
	body.position = pos
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	body.add_child(collision)
	world_root.add_child(body)

func create_tree(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = 3.0
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.45
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.5
	root.add_child(trunk)
	var leaves := MeshInstance3D.new()
	var leaves_mesh := SphereMesh.new()
	leaves_mesh.radius = 1.7
	leaves_mesh.height = 3.4
	leaves.mesh = leaves_mesh
	leaves.position.y = 3.5
	root.add_child(leaves)
	world_root.add_child(root)

func create_gas_zone(pos: Vector3, radius: float) -> void:
	var gas := Area3D.new()
	gas.name = "ToxicGasZone"
	gas.position = pos
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	gas.add_child(collision)
	world_root.add_child(gas)

func create_lab(pos: Vector3) -> void:
	var lab := Node3D.new()
	lab.name = "ResearchLab"
	lab.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10, 5, 8)
	mesh.mesh = box
	mesh.position.y = 2.5
	lab.add_child(mesh)
	world_root.add_child(lab)
