shader_type canvas_item;

uniform float intensidade : hint_range(0.0, 1.0) = 0.0;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centro = UV - vec2(0.5);
	float dist = length(centro);
	float angulo = atan(centro.y, centro.x);
	
	// Cria raios finos saindo do centro para as bordas
	float raio = floor(angulo * 40.0);
	float ruido = random(vec2(raio, floor(TIME * 25.0)));
	
	// Mostra apenas nas bordas da tela (dist > 0.32)
	float mascara_borda = smoothstep(0.32, 0.55, dist);
	float linha = step(0.82, ruido) * mascara_borda * intensidade;
	
	COLOR = vec4(1.0, 1.0, 1.0, linha * 0.45);
}