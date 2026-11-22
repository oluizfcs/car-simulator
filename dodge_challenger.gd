extends VehicleBody3D

const FORCE = 800
const STEER_MAX = 0.45
const STEER_SPEED = 2.5

@onready var label = find_child("velocimetro", true, false)

func _physics_process(delta: float) -> void:
	var velocidade_kmh = linear_velocity.length() * 3.6
	var input_direcao = Input.get_axis("right", "left")

	var fator_velocidade = clamp(1.0 - (velocidade_kmh / 180.0), 0.35, 1.0)
	var angulo_alvo = input_direcao * STEER_MAX * fator_velocidade
	var velocidade_volante = STEER_SPEED if input_direcao != 0 else STEER_SPEED * 1.8
	steering = move_toward(steering, angulo_alvo, delta * velocidade_volante)

	engine_force = Input.get_axis("down", "up") * FORCE

	if label:
		label.text = "%d km/h" % round(velocidade_kmh)
