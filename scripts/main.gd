extends Node3D

var generator: Node3D
var player: CharacterBody3D
var menu_layer: CanvasLayer
var started: bool = false

func _ready() -> void:
	create_underground_environment()
	create_menu()

func create_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MainMenu"
	add_child(menu_layer)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.003, 0.007, 0.01, 1.0)
	menu_layer.add_child(background)

	var title := Label.new()
	title.text = "KAI"
	title.position = Vector2(0, 75)
	title.size = Vector2(1280, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 78)
	background.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "DEEP RESEARCH // PROTOCOLO KAI-01"
	subtitle.position = Vector2(0, 160)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	background.add_child(subtitle)

	var line := ColorRect.new()
	line.position = Vector2(440, 215)
	line.size = Vector2(400, 2)
	line.color = Color(0.2, 0.75, 0.72, 0.8)
	background.add_child(line)

	var story := Label.new()
	story.text = "AÑO 2047\n\nUna red de sensores subterráneos ha detectado un gas desconocido que está aumentando rápidamente.\nLa señal procede de una antigua zona de investigación abandonada.\n\nLa misión KAI-01 es descubrir qué está liberando el gas antes de que la zona quede completamente cubierta.\n\nTú eres la científica enviada para investigar. La respuesta está bajo tus pies."
	story.position = Vector2(190, 245)
	story.size = Vector2(900, 230)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 18)
	background.add_child(story)

	var start := Button.new()
	start.text = "INICIAR EXPEDICIÓN"
	start.position = Vector2(455, 505)
	start.size = Vector2(370, 64)
	start.add_theme_font_size_override("font_size", 21)
	start.pressed.connect(start_game)
	background.add_child(start)

	var controls := Label.new()
	controls.text = "WASD MOVER   |   SHIFT CORRER   |   F LINTERNA   |   E EXCAVAR   |   ESC PAUSA"
	controls.position = Vector2(0, 610)
	controls.size = Vector2(1280, 40)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 14)
	background.add_child(controls)

func start_game() -> void:
	if started:
		return
	started = true
	menu_layer.queue_free()

	generator = preload("res://scripts/world_generator.gd").new()
	generator.name = "WorldGenerator"
	add_child(generator)
	create_player()

func create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Scientist"
	player.position = Vector3(0, 1.4, 0)
	player.set_script(preload("res://scripts/player_kai.gd"))

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
	body.visible = false
	player.add_child(body)

	var camera_pivot := Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 1.55, 0)
	player.add_child(camera_pivot)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 78.0
	camera.near = 0.05
	camera.far = 180.0
	camera_pivot.add_child(camera)

	var flashlight := SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(0.78, 0.9, 1.0)
	flashlight.light_energy = 5.5
	flashlight.spot_range = 32.0
	flashlight.spot_angle = 30.0
	flashlight.spot_attenuation = 1.15
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)

	add_child(player)

func create_underground_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "UndergroundEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.006, 0.009)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.055, 0.075, 0.085)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.035, 0.065, 0.07)
	env.fog_light_energy = 0.55
	env.fog_density = 0.018
	env.fog_height = 1.0
	env.fog_height_density = 0.035
	environment.environment = env
	add_child(environment)

	var weak_light := OmniLight3D.new()
	weak_light.name = "EmergencyLight"
	weak_light.position = Vector3(0, 3.8, 0)
	weak_light.light_color = Color(0.08, 0.35, 0.4)
	weak_light.light_energy = 1.0
	weak_light.omni_range = 10.0
	add_child(weak_light)
