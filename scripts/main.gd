extends Node3D

var generator: Node3D
var player: CharacterBody3D

func _ready() -> void:
	generator = preload("res://scripts/world_generator.gd").new()
	add_child(generator)
	create_player()
	create_environment()

func create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Scientist"
	player.position = Vector3(0, 4, 10)
	player.set_script(preload("res://scripts/player.gd"))
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player.add_child(collision)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	player.add_child(body)
	add_child(player)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 4, 8)
	camera.look_at_from_position(camera.position, player.position + Vector3(0, 1, 0))
	player.add_child(camera)
	camera.current = true

func create_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.42)
	env.ambient_light_energy = 0.7
	environment.environment = env
	add_child(environment)
