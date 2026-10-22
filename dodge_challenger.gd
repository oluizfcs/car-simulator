extends VehicleBody3D

const FORCE = 500

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	steering = move_toward(
		steering,
		Input.get_axis("ui_right", "ui_left"),
		delta * 1.1 # aumentar esse valor faz o carro virar mais rápido
	)
	
	engine_force = Input.get_axis("ui_down", "ui_up") * FORCE
