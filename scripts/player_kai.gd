extends CharacterBody3D

@export var speed: float = 5.5
@export var sprint_speed: float = 8.5
@export var gravity: float = 18.0
@export var mouse_sensitivity: float = 0.0025

var camera_pivot: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var objective_label: Label
var status_label: Label
var telemetry_label: Label
var interaction_label: Label
var generator: Node
var exposure: float = 0.0
var samples: int = 0
var flashlight_on: bool = true
var game_finished: bool = false

func _ready() -> void:
	camera_pivot = get_node("CameraPivot")
	camera = get_node("CameraPivot/Camera3D")
	flashlight = get_node("CameraPivot/Camera3D/Flashlight")
	generator = get_parent().get_node_or_null("WorldGenerator")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	create_hud()
	if generator and generator.has_signal("sample_found"):
		generator.sample_found.connect(_on_sample_found)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not game_finished:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_F and not game_finished:
			flashlight_on = not flashlight_on
			flashlight.visible = flashlight_on
		elif event.keycode == KEY_E and not game_finished:
			dig_forward()
	elif event is InputEventMouseButton and event.pressed and not game_finished:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if game_finished:
		velocity = Vector3.ZERO
		return

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_direction := Vector3(input.x, 0.0, input.y)
	var direction := (transform.basis * local_direction).normalized()
	var current_speed: float = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else speed
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	update_gameplay(delta)
	update_interaction()

func update_gameplay(delta: float) -> void:
	var gas_center := Vector3(-36.0, 0.0, -36.0)
	var distance_to_gas: float = Vector2(global_position.x - gas_center.x, global_position.z - gas_center.z).length()
	var gas_level: float = clampf(100.0 - distance_to_gas * 3.2, 0.0, 100.0)

	if gas_level > 35.0:
		exposure = minf(100.0, exposure + delta * gas_level * 0.055)
	else:
		exposure = maxf(0.0, exposure - delta * 2.0)

	telemetry_label.text = "PROFUNDIDAD  %04dm\nGAS KAI       %03d%%\nEXPOSICIÓN    %03d%%" % [int(abs(global_position.y - 7.0) + 120.0), int(gas_level), int(exposure)]
	objective_label.text = "MUESTRAS  %d/5\nCava el suelo para encontrar evidencia." % samples

	if gas_level > 65.0:
		status_label.text = "ALERTA AMBIENTAL | Concentración elevada."
	elif gas_level > 35.0:
		status_label.text = "Detector KAI: presencia de gas detectada."
	else:
		status_label.text = "WASD mover | SHIFT correr | F linterna | E cavar"

	if exposure >= 100.0:
		status_label.text = "EXPOSICIÓN CRÍTICA | Regresando a la estación."
		global_position = Vector3(0, 0.2, 0)
		exposure = 0.0

func update_interaction() -> void:
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 4.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		interaction_label.text = ""
		return
	var collider = hit.get("collider")
	if collider is StaticBody3D and collider.is_in_group("diggable") and not bool(collider.get_meta("dug", false)):
		interaction_label.text = "E  |  EXCAVAR SUELO"
	else:
		interaction_label.text = ""

func dig_forward() -> void:
	if not generator:
		return
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 4.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider is StaticBody3D and collider.is_in_group("diggable"):
		generator.dig_ground(collider)

func _on_sample_found(sample_number: int, position: Vector3) -> void:
	samples = sample_number
	status_label.text = "MUESTRA %d/5 RECUPERADA | El suelo revela una anomalía." % samples
	if samples >= 5:
		show_ending()

func show_ending() -> void:
	game_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var overlay := ColorRect.new()
	overlay.name = "EndingOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.01, 0.014, 0.96)
	get_node("HUD").add_child(overlay)

	var title := Label.new()
	title.text = "KAI // INFORME FINAL"
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.position += Vector2(-280, -190)
	title.add_theme_font_size_override("font_size", 36)
	overlay.add_child(title)

	var story := Label.new()
	story.text = "Las cinco excavaciones contienen el mismo compuesto desconocido.\n\nLas muestras demuestran que el gas no llegó desde la superficie.\nSu origen está mucho más abajo, bajo la caverna.\n\nEl último análisis registra una enorme cavidad bajo el laboratorio.\nLa investigación KAI-01 acaba de descubrir su primera pista.\n\nINVESTIGACIÓN COMPLETA\nORIGEN DEL GAS: LOCALIZADO"
	story.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	story.position += Vector2(-400, -75)
	story.add_theme_font_size_override("font_size", 20)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay.add_child(story)

	var close := Label.new()
	close.text = "ESC para liberar el mouse"
	close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	close.position += Vector2(-120, -50)
	close.add_theme_font_size_override("font_size", 16)
	overlay.add_child(close)

func create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(650, 118)
	panel.color = Color(0.008, 0.018, 0.022, 0.88)
	canvas.add_child(panel)

	var title := Label.new()
	title.position = Vector2(18, 10)
	title.text = "KAI // DEEP RESEARCH"
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)

	objective_label = Label.new()
	objective_label.position = Vector2(18, 48)
	objective_label.text = "MUESTRAS  0/5\nCava el suelo para encontrar evidencia."
	objective_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(18, 154)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.86))
	canvas.add_child(status_label)

	telemetry_label = Label.new()
	telemetry_label.position = Vector2(1030, 22)
	telemetry_label.text = "PROFUNDIDAD 0120m\nGAS KAI       000%\nEXPOSICIÓN    000%"
	telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	telemetry_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(telemetry_label)

	interaction_label = Label.new()
	interaction_label.position = Vector2(520, 620)
	interaction_label.add_theme_font_size_override("font_size", 20)
	interaction_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.9, 1.0))
	canvas.add_child(interaction_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(0.7, 1.0, 0.9, 0.9))
	canvas.add_child(crosshair)
