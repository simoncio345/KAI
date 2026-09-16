extends Node3D

@export var world_size := 44
@export var cell_size := 5.0
@export var seed := 0
@export var tree_count := 95

var rng := RandomNumberGenerator.new()
var world_root: Node3D
var ground_material: StandardMaterial3D
var grass_material: StandardMaterial3D
var trunk_material: StandardMaterial3D
var rock_material: StandardMaterial3D
var lab_material: StandardMaterial3D
var sample_material: StandardMaterial3D
var gas_material: StandardMaterial3D

func _ready() -> void:
	world_root = Node3D.new()
	world_root.name = "ProceduralWorld"
	add_child(world_root)
	rng.seed = seed if seed != 0 else Time.get_unix_time_from_system()
	create_materials()
	generate_world()

func create_materials() -> void:
	ground_material = create_noise_material(Color(0.16, 0.20, 0.14), Color(0.28, 0.31, 0.20), 3.0)
	grass_material = create_noise_material(Color(0.10, 0.22, 0.10), Color(0.22, 0.38, 0.12), 5.0)
	trunk_material = create_material(Color(0.20, 0.12, 0.07), 0.95)
	rock_material = create_material(Color(0.25, 0.28, 0.28), 0.92)
	lab_material = create_material(Color(0.32, 0.38, 0.42), 0.72, 0.15)
	sample_material = create_material(Color(0.20, 0.90, 0.95), 0.25, 0.45)
	gas_material = create_material(Color(0.35, 0.95, 0.65, 0.28), 0.35)
	gas_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gas_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func create_material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func create_noise_material(base_color: Color, detail_color: Color, scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.roughness = 0.92
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04 * scale
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([base_color, detail_color])
	texture.color_ramp = gradient
	material.albedo_texture = texture
	return material

func generate_world() -> void:
	for x in range(-world_size / 2, world_size / 2):
		for z in range(-world_size / 2, world_size / 2):
			var height := noise_height(x, z)
			create_ground_cell(Vector3(x * cell_size, height - 1.0, z * cell_size))

	for i in tree_count:
		var p := Vector3(rng.randf_range(-100.0, 100.0), 0.0, rng.randf_range(-100.0, 100.0))
		if p.distance_to(Vector3(-25, 0, -25)) > 24.0 and p.distance_to(Vector3(22, 0, 22)) > 13.0:
			create_tree(p)

	create_rocks()
	create_gas_zone(Vector3(-25, 0.0, -25), 18.0)
	create_lab(Vector3(22, 0.0, 22))
	create_samples()

func noise_height(x: int, z: int) -> float:
	return sin(float(x) * 0.17) * 1.5 + cos(float(z) * 0.13) * 1.2

func create_ground_cell(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(cell_size + 0.08, 2.0, cell_size + 0.08)
	mesh.mesh = box
	mesh.material_override = ground_material
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
	root.name = "Tree"

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = 3.5
	trunk_mesh.top_radius = 0.28
	trunk_mesh.bottom_radius = 0.48
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_material
	trunk.position.y = 1.75
	root.add_child(trunk)

	var leaves := MeshInstance3D.new()
	var leaves_mesh := SphereMesh.new()
	leaves_mesh.radius = 2.0
	leaves_mesh.height = 3.7
	leaves.mesh = leaves_mesh
	leaves.material_override = grass_material
	leaves.position.y = 4.0
	root.add_child(leaves)

	world_root.add_child(root)

func create_rocks() -> void:
	for i in 55:
		var root := Node3D.new()
		root.name = "Rock"
		root.position = Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
		var mesh := MeshInstance3D.new()
		var rock := SphereMesh.new()
		rock.radius = rng.randf_range(0.4, 1.3)
		rock.height = rock.radius * 1.3
		mesh.mesh = rock
		mesh.material_override = rock_material
		mesh.scale = Vector3(1.2, 0.65, 0.9)
		mesh.position.y = rock.radius * 0.45
		root.add_child(mesh)
		world_root.add_child(root)

func create_gas_zone(pos: Vector3, radius: float) -> void:
	var gas := Node3D.new()
	gas.name = "ToxicGasZone"
	gas.position = pos

	var volume := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.2
	volume.mesh = sphere
	volume.material_override = gas_material
	volume.scale = Vector3(1.0, 0.55, 1.0)
	volume.position.y = 4.0
	gas.add_child(volume)

	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 4.0
	core_mesh.bottom_radius = 7.0
	core_mesh.height = 0.7
	core.mesh = core_mesh
	core.material_override = gas_material
	core.position.y = 0.25
	gas.add_child(core)

	world_root.add_child(gas)

func create_lab(pos: Vector3) -> void:
	var lab := Node3D.new()
	lab.name = "ResearchLab"
	lab.position = pos

	var building := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(12, 5, 9)
	building.mesh = box
	building.material_override = lab_material
	building.position.y = 2.5
	lab.add_child(building)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(13, 0.5, 10)
	roof.mesh = roof_mesh
	roof.material_override = rock_material
	roof.position.y = 5.25
	lab.add_child(roof)

	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(2.2, 3.0, 0.3)
	door.mesh = door_mesh
	door.material_override = sample_material
	door.position = Vector3(0, 1.5, -4.65)
	lab.add_child(door)

	var sign := Label3D.new()
	sign.text = "KAI RESEARCH LAB"
	sign.font_size = 64
	sign.outline_size = 12
	sign.position = Vector3(0, 6.5, -4.8)
	lab.add_child(sign)

	world_root.add_child(lab)

func create_samples() -> void:
	var positions := [
		Vector3(-5, 1, -8),
		Vector3(18, 1, -8),
		Vector3(-40, 1, -10),
		Vector3(-15, 1, 28),
		Vector3(45, 1, -30)
	]
	for i in positions.size():
		var area := Area3D.new()
		area.name = "Sample_%d" % (i + 1)
		area.position = positions[i]
		area.add_to_group("sample")

		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.1
		mesh.mesh = capsule
		mesh.material_override = sample_material
		mesh.rotation_degrees = Vector3(0, 0, 90)
		area.add_child(mesh)

		var glow := OmniLight3D.new()
		glow.light_color = Color(0.2, 0.9, 1.0)
		glow.light_energy = 1.2
		glow.omni_range = 5.0
		area.add_child(glow)

		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 1.5
		collision.shape = shape
		area.add_child(collision)
		world_root.add_child(area)
