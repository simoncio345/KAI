extends Node3D

@export var grid_size: int = 9
@export var cell_size: float = 12.0
@export var seed: int = 0

var rng := RandomNumberGenerator.new()
var root: Node3D
var rock_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var dug_mat: StandardMaterial3D
var crystal_mat: StandardMaterial3D
var gas_mat: StandardMaterial3D
var dug_count: int = 0
var gas_zone: Node3D
var gas_clouds: Array[MeshInstance3D] = []
var gas_age: float = 0.0
var gas_expansion: float = 1.0

signal sample_found(sample_number: int, position: Vector3)

func _ready() -> void:
	rng.seed = seed if seed != 0 else int(Time.get_unix_time_from_system())
	root = Node3D.new()
	root.name = "UndergroundWorld"
	add_child(root)
	make_materials()
	make_cave()
	make_crystals()
	make_gas()
	make_station()

func _process(delta: float) -> void:
	if not gas_zone:
		return
	gas_age += delta
	gas_expansion = minf(3.2, 1.0 + gas_age * 0.012)
	gas_zone.scale = Vector3.ONE * gas_expansion
	for i in gas_clouds.size():
		var cloud := gas_clouds[i]
		if is_instance_valid(cloud):
			cloud.rotation.y += delta * (0.08 + float(i % 4) * 0.02)
			cloud.position.y += sin(gas_age * 0.45 + float(i)) * delta * 0.08

func make_materials() -> void:
	rock_mat = mat(Color(0.045, 0.055, 0.06), 0.98)
	floor_mat = mat(Color(0.075, 0.085, 0.085), 0.9)
	dug_mat = mat(Color(0.16, 0.11, 0.07), 1.0)
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
			var p := Vector3(float(x) * cell_size, 0.0, float(z) * cell_size)
			create_diggable_floor(p)
			box(p + Vector3(0, 7, 0), Vector3(cell_size, 1, cell_size), rock_mat, true)
			if x == -4 or rng.randf() < 0.28:
				box(p + Vector3(-cell_size * 0.5, 2.5, 0), Vector3(0.6, 5, cell_size), rock_mat, true)
			if z == -4 or rng.randf() < 0.28:
				box(p + Vector3(0, 2.5, -cell_size * 0.5), Vector3(cell_size, 5, 0.6), rock_mat, true)

	for i in 85:
		var p := Vector3(rng.randf_range(-48.0, 48.0), 0.0, rng.randf_range(-48.0, 48.0))
		if p.length() < 10.0:
			continue
		var r: float = rng.randf_range(0.5, 1.8)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = r
		sphere.height = r * rng.randf_range(1.0, 1.8)
		mesh.mesh = sphere
		mesh.material_override = rock_mat
		mesh.position = p + Vector3(0, r * 0.5, 0)
		mesh.scale = Vector3(1.3, 1.0, 0.9)
		root.add_child(mesh)

func create_diggable_floor(p: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "DiggableGround_%d_%d" % [int(p.x), int(p.z)]
	body.position = p
	body.add_to_group("diggable")
	body.set_meta("dug", false)

	var mesh := MeshInstance3D.new()
	mesh.name = "GroundVisual"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(cell_size - 0.08, 1.0, cell_size - 0.08)
	mesh.mesh = box_mesh
	mesh.material_override = floor_mat
	body.add_child(mesh)

	var collision := CollisionShape3D.new()
	collision.name = "GroundCollision"
	var shape := BoxShape3D.new()
	shape.size = box_mesh.size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)

func dig_ground(body: StaticBody3D) -> bool:
	if not is_instance_valid(body) or not body.is_in_group("diggable"):
		return false
	if bool(body.get_meta("dug", false)):
		return false

	body.set_meta("dug", true)
	dug_count += 1

	var mesh := body.get_node_or_null("GroundVisual") as MeshInstance3D
	if mesh:
		mesh.material_override = dug_mat

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(body, "position:y", body.position.y - 2.5, 0.7)

	var sample := MeshInstance3D.new()
	sample.name = "ExcavatedSample_%d" % dug_count
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sample.mesh = sphere
	sample.material_override = crystal_mat
	sample.position = body.position + Vector3(0, -0.65, 0)
	root.add_child(sample)

	var light := OmniLight3D.new()
	light.light_color = Color(0.05, 0.7, 0.75)
	light.light_energy = 0.9
	light.omni_range = 3.5
	light.position = sample.position
	root.add_child(light)

	sample_found.emit(dug_count, body.global_position)
	return true

func make_crystals() -> void:
	for i in 25:
		var p := Vector3(rng.randf_range(-48.0, 48.0), rng.randf_range(0.1, 1.5), rng.randf_range(-48.0, 48.0))
		if p.length() < 8.0:
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
		light.omni_range = 4.0
		root.add_child(light)

func make_gas() -> void:
	gas_zone = Node3D.new()
	gas_zone.name = "KAI_Gas_Zone"
	gas_zone.position = Vector3(-36.0, 0.0, -36.0)
	root.add_child(gas_zone)

	for i in 22:
		var cloud := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r: float = rng.randf_range(2.0, 5.0)
		sphere.radius = r
		sphere.height = r * 1.2
		cloud.mesh = sphere
		cloud.material_override = gas_mat
		cloud.position = Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(0.2, 3.5), rng.randf_range(-9.0, 9.0))
		cloud.scale.y = 0.5
		gas_zone.add_child(cloud)
		gas_clouds.append(cloud)

	var light := OmniLight3D.new()
	light.light_color = Color(0.1, 0.8, 0.4)
	light.light_energy = 1.8
	light.omni_range = 18.0
	gas_zone.add_child(light)

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
