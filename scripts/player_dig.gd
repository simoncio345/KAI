extends CharacterBody3D

@export var speed := 5.5
@export var sprint_speed := 8.5
@export var gravity := 18.0
@export var mouse_sensitivity := 0.0025

var camera_pivot: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var objective_label: Label
var status_label: Label
var telemetry_label: Label
var exposure: float = 0.0
var samples: int = 0
var flashlight_on: bool = true
var dug_cells: Dictionary = {}

func _ready() -> void:
	camera_pivot = get_node("CameraPivot")
	camera = get_node("CameraPivot/Camera3D")
	flashlight = get_node("CameraPivot/Camera3D/Flashlight")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	create_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_F:
			flashlight_on = not flashlight_on
			flashlight.visible = flashlight_on
		elif event.keycode == KEY_E:
			dig_ground()
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
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

func dig_ground() -> void:
	if samples >= 5:
		status_label.text = "Ya tienes las 5 muestras. Llévalas a KAI // DEEP RESEARCH."
		return

	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z
	var end: Vector3 = origin + direction * 5.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		status_label.text = "Apunta al suelo para cavar."
		return

	var collider = result.get("collider")
	if collider == null or not collider.is_in_group("diggable"):
		status_label.text = "Aquí no puedes cavar. Apunta al suelo."
		return

	var cell_id: int = collider.get_instance_id()
	if dug_cells.has(cell_id):
		status_label.text = "Este lugar ya fue excavado. Busca otro punto del suelo."
		return

	dug_cells[cell_id] = true
	samples += 1
	create_dig_mark(result.get("position"))
	status_label.text = "MUESTRA OBTENIDA  |  Has extraído material del suelo."

func create_dig_mark(position: Vector3) -> void:
	var mark := MeshInstance3D.new()
	mark.name = "DigSite_%d" % samples
	var sphere := SphereMesh.new()
	sphere.radius = 0.72
	sphere.height = 0.10
	mark.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.018, 0.022, 0.022)
	material.roughness = 1.0
	mark.material_override = material
	mark.position = position + Vector3(0, 0.03, 0)
	get_parent().add_child(mark)

func update_gameplay(delta: float) -> void:
	var gas_center := Vector3(-36.0, 0.0, -36.0)
	var distance_to_gas: float = Vector2(global_position.x - gas_center.x, global_position.z - gas_center.z).length()
	var gas_level: float = clampf(100.0 - distance_to_gas * 3.2, 0.0, 100.0)

	if gas_level > 35.0:
		exposure = minf(100.0, exposure + delta * gas_level * 0.055)
	else:
		exposure = maxf(0.0, exposure - delta * 2.0)

	telemetry_label.text = "PROFUNDIDAD  %04dm\nGAS KAI       %03d%%\nEXPOSICIÓN    %03d%%" % [int(abs(global_position.y - 7.0) + 120.0), int(gas_level), int(exposure)]
	objective_label.text = "MUESTRAS  %d/5   |   Cava el suelo para obtener muestras" % samples

	if samples >= 5 and global_position.distance_to(Vector3(0, 0, 5)) < 12.0:
		status_label.text = "INVESTIGACIÓN COMPLETA  |  Muestras entregadas en la estación"
	elif samples >= 5:
		status_label.text = "Todas las muestras reunidas. Regresa a KAI // DEEP RESEARCH."
	elif gas_level > 65.0:
		status_label.text = "ALERTA AMBIENTAL  |  Concentración elevada."
	elif gas_level > 35.0:
		status_label.text = "Detector KAI: presencia de gas detectada."
	else:
		status_label.text = "WASD mover   SHIFT correr   F linterna   E cavar   ESC mouse"

	if exposure >= 100.0:
		status_label.text = "EXPOSICIÓN CRÍTICA  |  Regresa a una zona segura."
		global_position = Vector3(0, 0.2, 0)
		exposure = 0.0

func create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(650, 112)
	panel.color = Color(0.008, 0.018, 0.022, 0.86)
	canvas.add_child(panel)

	var title := Label.new()
	title.position = Vector2(18, 10)
	title.text = "KAI // DEEP RESEARCH"
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)

	objective_label = Label.new()
	objective_label.position = Vector2(18, 46)
	objective_label.text = "MUESTRAS  0/5   |   Cava el suelo para obtener muestras"
	objective_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(18, 150)
	status_label.text = "WASD mover   SHIFT correr   F linterna   E cavar   ESC mouse"
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.86))
	canvas.add_child(status_label)

	telemetry_label = Label.new()
	telemetry_label.position = Vector2(1050, 22)
	telemetry_label.text = "PROFUNDIDAD 0120m\nGAS KAI       000%\nEXPOSICIÓN    000%"
	telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	telemetry_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(telemetry_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(0.7, 1.0, 0.9, 0.9))
	canvas.add_child(crosshair)
