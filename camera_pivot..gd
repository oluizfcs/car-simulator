extends Node3D

@export var carro_alvo: Node3D
@export var spring_arm: SpringArm3D
@export var cam_terceira_pessoa: Camera3D
@export var cam_primeira_pessoa: Camera3D

var primeira_pessoa := false

func _ready() -> void:
	# Começa já na posição e direção do carro
	global_position = carro_alvo.global_position
	var frente = carro_alvo.global_transform.basis.z
	rotation.y = atan2(-frente.x, -frente.z)

	spring_arm.rotation.x = deg_to_rad(-15)
	spring_arm.add_excluded_object((carro_alvo as CollisionObject3D).get_rid())
	_atualizar_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		primeira_pessoa = not primeira_pessoa
		_atualizar_camera()

func _atualizar_camera() -> void:
	cam_primeira_pessoa.current = primeira_pessoa
	cam_terceira_pessoa.current = not primeira_pessoa

func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(
		carro_alvo.global_position, 1.0 - exp(-8.0 * delta))
	var frente = carro_alvo.global_transform.basis.z
	rotation.y = lerp_angle(rotation.y, atan2(-frente.x, -frente.z), 1.0 - exp(-3.0 * delta))
