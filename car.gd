extends VehicleBody3D

var steer = 0.5
var power = 1200

func _physics_process(delta: float) -> void:
	steering = move_toward(steering, Input.get_axis("ui_right", "ui_left") * steer, delta * 5)
	var dir = Input.get_axis("ui_up", "ui_down")
	engine_force = dir * power
