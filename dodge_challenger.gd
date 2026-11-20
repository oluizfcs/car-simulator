extends VehicleBody3D

const FORCE = 200
const STEER_MAX = 0.45 # ~25 graus (muito mais natural que 1.0 radiano)
const STEER_SPEED = 2.5 # Velocidade com que o volante gira

func _physics_process(delta: float) -> void:
	var velocidade_kmh = linear_velocity.length() * 3.6
	var input_direcao = Input.get_axis("right", "left")
	
	# 1. Quanto mais rápido o carro está, menos o volante vira (evita rodar em alta velocidade)
	# A 0 km/h vira 100% do STEER_MAX; a 120 km/h vira cerca de 35%
	var fator_velocidade = clamp(1.0 - (velocidade_kmh / 180.0), 0.35, 1.0)
	var angulo_alvo = input_direcao * STEER_MAX * fator_velocidade
	
	# 2. Volante retorna ao centro mais rápido do que vira (sensação de direção real)
	var velocidade_volante = STEER_SPEED if input_direcao != 0 else STEER_SPEED * 1.8
	steering = move_toward(steering, angulo_alvo, delta * velocidade_volante)
	
	# Aceleração
	var acel = Input.get_axis("down", "up")
	engine_force = acel * FORCE
	
	var label = find_child("velocimetro", true, false)
	if label:
		label.text = "%d km/h" % round(velocidade_kmh)
