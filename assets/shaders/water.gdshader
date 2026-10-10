// Agua del lago: dos normales que se desplazan, más oscura hacia el centro (profundidad
// simulada por distancia al centro, sin leer el buffer de profundidad) y fresnel.
shader_type spatial;

uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 shallow_color : source_color = vec3(0.22, 0.36, 0.38);
uniform vec3 deep_color : source_color = vec3(0.05, 0.13, 0.19);
uniform vec2 center = vec2(0.0, -36.0);
uniform float radius = 18.5;
uniform float wave_speed = 0.025;
uniform float tile = 0.09;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * tile;
	vec3 n1 = texture(normal_tex, p + TIME * wave_speed * vec2(1.0, 0.35)).rgb;
	vec3 n2 = texture(normal_tex, p * 1.7 - TIME * wave_speed * vec2(0.4, 1.0)).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	float r = clamp(distance(world_pos.xz, center) / radius, 0.0, 1.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 base = mix(deep_color, shallow_color, smoothstep(0.55, 1.0, r));
	ALBEDO = mix(base, base * 1.6 + vec3(0.05), fres * 0.5);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
