extends Node3D

@export var grid_size := 9
@export var cell_size := 12.0
@export var seed := 0

var rng := RandomNumberGenerator.new()
var root: Node3D
var rock_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var crystal_mat: StandardMaterial3D
var gas_mat: StandardMaterial3D

func _ready() -> void:
	rng.seed = seed if seed != 0 else Time.get_unix_time_from_system()
	root = Node3D.new()
	root.name = "UndergroundWorld"
	add_child(root)
	make_materials()
	make_cave()
	make_crystals()
	make_gas()
	make_station()

func make_materials() -> void:
	rock_mat = mat(Color(0.045, 0.055, 0.06), 0.98)
	floor_mat = mat(Color(0.075, 0.085, 0.085), 0.9)
	crystal_mat = mat(Color(0.04, 0.65, 0.7), 0.28)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.02, 0.35, 0.4)
	crystal_mat.emission_energy_multiplier = 3.0
	gas_mat = mat(Color(0.12, 0.7, 0.35, 0.18), 0.4)
	gas_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gas_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func make_cave() -> void:
	for z in range(-4, 5):
		for x in range(-4, 5):
			var p := Vector3(x * cell_size, 0, z * cell_size)
			var floor_body := box(p + Vector3(0, -0.5, 0), Vector3(cell_size, 1, cell_size), floor_mat, true)
			floor_body.add_to_group("diggable")
			box(p + Vector3(0, 7, 0), Vector3(cell_size, 1, cell_size), rock_mat, true)
			if x == -4 or rng.randf() < 0.28:
				box(p + Vector3(-cell_size * 0.5, 2.5, 0), Vector3(0.6, 5, cell_size), rock_mat, true)
			if z == -4 or rng.randf() < 0.28:
				box(p + Vector3(0, 2.5, -cell_size * 0.5), Vector3(cell_size, 5, 0.6), rock_mat, true)

	for i in 85:
		var p := Vector3(rng.randf_range(-48, 48), 0, rng.randf_range(-48, 48))
		if p.length() < 10:
			continue
		var r := rng.randf_range(0.5, 1.8)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = r
		sphere.height = r * rng.randf_range(1.0, 1.8)
		mesh.mesh = sphere
		mesh.material_override = rock_mat
		mesh.position = p + Vector3(0, r * 0.5, 0)
		mesh.scale = Vector3(1.3, 1.0, 0.9)
		root.add_child(mesh)

func make_crystals() -> void:
	for i in 25:
		var p := Vector3(rng.randf_range(-48, 48), rng.randf_range(0.1, 1.5), rng.randf_range(-48, 48))
		if p.length() < 8:
			continue
		var mesh := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.5, rng.randf_range(1.0, 2.6), 0.5)
		mesh.mesh = prism
		mesh.material_override = crystal_mat
		mesh.position = p
		root.add_child(mesh)
		var light := OmniLight3D.new()
		light.position = p + Vector3(0, 1, 0)
		light.light_color = Color(0.05, 0.7, 0.75)
		light.light_energy = 0.65
		light.omni_range = 4
		root.add_child(light)

func make_gas() -> void:
	var center := Vector3(-36, 0, -36)
	var zone := Node3D.new()
	zone.name = "KAI_Gas_Zone"
	zone.position = center
	root.add_child(zone)
	for i in 16:
		var cloud := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r := rng.randf_range(2, 5)
		sphere.radius = r
		sphere.height = r * 1.2
		cloud.mesh = sphere
		cloud.material_override = gas_mat
		cloud.position = Vector3(rng.randf_range(-8, 8), rng.randf_range(0.2, 3), rng.randf_range(-8, 8))
		cloud.scale.y = 0.5
		zone.add_child(cloud)
	var light := OmniLight3D.new()
	light.light_color = Color(0.1, 0.8, 0.4)
	light.light_energy = 1.8
	light.omni_range = 18
	zone.add_child(light)

func make_station() -> void:
	var station := Node3D.new()
	station.name = "ResearchStation"
	root.add_child(station)
	box(Vector3(0, 2, 5), Vector3(8, 4, 0.5), rock_mat, true)
	box(Vector3(-4, 2, 1), Vector3(0.5, 4, 8), rock_mat, true)
	box(Vector3(4, 2, 1), Vector3(0.5, 4, 8), rock_mat, true)
	var label := Label3D.new()
	label.text = "KAI // DEEP RESEARCH"
	label.font_size = 64
	label.outline_size = 10
	label.position = Vector3(0, 4.5, 4.5)
	station.add_child(label)

func box(pos: Vector3, size: Vector3, material: Material, collision: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = material
	body.add_child(mesh)
	if collision:
		var c := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		c.shape = shape
		body.add_child(c)
	root.add_child(body)
	return body
