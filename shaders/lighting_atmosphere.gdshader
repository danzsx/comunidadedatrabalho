shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 0.8) = 0.24;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.55;
uniform vec4 tint_color : source_color = vec4(0.08, 0.05, 0.04, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float vig = smoothstep(vignette_softness, 0.88, dist) * vignette_strength;
	COLOR = vec4(tint_color.rgb, vig);
}
