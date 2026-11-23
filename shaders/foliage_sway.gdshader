shader_type canvas_item;

uniform float sway_speed : hint_range(0.2, 5.0) = 1.6;
uniform float sway_strength : hint_range(0.0, 8.0) = 2.2;
uniform float phase_offset : hint_range(0.0, 6.28) = 0.0;

void vertex() {
	float weight = clamp(1.0 - UV.y, 0.0, 1.0);
	weight = weight * weight;
	VERTEX.x += sin(TIME * sway_speed + phase_offset + UV.y * 2.5) * sway_strength * weight;
}
