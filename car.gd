extends VehicleBody3D

var steer = 0.5
var power = 1200

@onready var origem_camera = $OrigemCamera
@export var sensibilidade = 0.2

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventMouseMotion:
		origem_camera.rotate_y(deg_to_rad(-event.relative.x * sensibilidade))
		origem_camera.rotate_x(deg_to_rad(-event.relative.y * sensibilidade))
		origem_camera.rotation.y = clamp(origem_camera.rotation.y, deg_to_rad(-90), deg_to_rad(45))
		origem_camera.rotation.x = clamp(origem_camera.rotation.x, deg_to_rad(-90), deg_to_rad(45))

func _physics_process(delta: float) -> void:
	steering = move_toward(steering, Input.get_axis("right", "left") * steer, delta * 5)
	var dir = Input.get_axis("up", "down")
	engine_force = dir * power
	
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
