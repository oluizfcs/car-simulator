extends RigidBody3D

var transform_inicial: Transform3D

func _ready() -> void:
	transform_inicial = global_transform
	add_to_group("objetos_resetaveis")

func resetar_objeto() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = transform_inicial
	sleeping = true
