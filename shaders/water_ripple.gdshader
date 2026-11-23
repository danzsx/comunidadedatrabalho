shader_type canvas_item;

uniform float ripple_speed : hint_range(0.5, 6.0) = 2.2;
uniform float ripple_amount : hint_range(0.0, 0.02) = 0.004;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * 28.0 + TIME * ripple_speed) * ripple_amount;
	uv.y += cos(uv.x * 24.0 + TIME * ripple_speed * 0.85) * ripple_amount * 0.6;
	vec4 col = texture(TEXTURE, uv);
	float sparkle = smoothstep(0.92, 1.0, sin(uv.x * 36.0 + TIME * 2.6) * cos(uv.y * 30.0 - TIME * 1.9));
	col.rgb += vec3(0.28, 0.34, 0.4) * sparkle * col.a;
	COLOR = col;
}
