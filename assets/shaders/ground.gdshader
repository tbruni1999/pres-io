// Suelo: mezcla tierra y pasto con una máscara de baja frecuencia en coordenadas de mundo,
// y una segunda escala de variación para que no se note la repetición. 4 lecturas de textura.
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_enable;
uniform float tile = 0.2;
uniform float mask_tile = 0.012;
uniform float grass_amount = 0.55;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float m = texture(mask_tex, p * mask_tile).r;
	float g = smoothstep(grass_amount - 0.12, grass_amount + 0.12, m);
	vec3 dirt = texture(dirt_tex, p * tile).rgb;
	vec3 grass = texture(grass_tex, p * tile * 0.8 + vec2(0.37, 0.11)).rgb;
	vec3 c = mix(dirt, grass, g);
	c *= mix(0.88, 1.08, texture(mask_tex, p * 0.07).r);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
