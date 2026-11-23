class_name TimeDial
extends Control
## Ornate Graveyard Keeper 2-inspired circular Day & Period medallion drawn crisply on HUD.

var current_day: int = 1
var current_period: int = 0

const SKY_COLORS: Array[Color] = [
	Color("6ec6e8"), # Manha
	Color("e89b5a"), # Tarde
	Color("273968"), # Noite
	Color("181e3b"), # Madrugada
]


func set_time(day: int, period: int) -> void:
	current_day = day
	current_period = clampi(period, 0, 3)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var outer_r: float = minf(size.x, size.y) * 0.48
	var inner_r: float = outer_r * 0.66

	# Cast shadow
	draw_circle(center + Vector2(1.5, 2.0), outer_r, Color(0.05, 0.04, 0.03, 0.55))
	# Outer weathered iron-stone bezel
	draw_circle(center, outer_r, Color("3c3f4a"))
	draw_arc(center, outer_r, 0.0, TAU, 48, Color("202229"), 2.0, true)
	draw_arc(center, outer_r - 2.0, 0.0, TAU, 48, Color("767b8a"), 1.0, true)

	# 7 weekday pips around the bezel ring
	var active_weekday: int = posmod(current_day - 1, 7)
	var pip_r: float = (outer_r + inner_r) * 0.5
	for i: int in range(7):
		var angle: float = -PI * 0.5 + (TAU * float(i) / 7.0)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * pip_r
		var is_today: bool = (i == active_weekday)
		draw_circle(pos, 4.0 if is_today else 3.0, Color("22242c"))
		draw_circle(pos, 2.8 if is_today else 1.8, Color("f4c454") if is_today else Color("8c8274"))

	# Inner sky dome
	draw_circle(center, inner_r + 1.5, Color("24201c"))
	draw_circle(center, inner_r, SKY_COLORS[current_period])

	# Sun or Moon orb inside sky
	if current_period <= 1:
		var sun_pos: Vector2 = center + (Vector2(-5.0, -7.0) if current_period == 0 else Vector2(6.0, -4.0))
		draw_circle(sun_pos, 5.2, Color(1.0, 0.94, 0.62, 0.45))
		draw_circle(sun_pos, 3.4, Color("fff09a"))
	else:
		var moon_pos: Vector2 = center + Vector2(-4.0, -6.0)
		draw_circle(moon_pos, 3.6, Color("eaf2ff"))
		draw_circle(moon_pos + Vector2(1.6, -0.8), 3.0, SKY_COLORS[current_period])
		draw_circle(center + Vector2(5.0, -8.0), 0.9, Color("fff6c4"))
		draw_circle(center + Vector2(8.0, -2.0), 0.8, Color("dceeff"))

	# Small Brazilian village hill & church/UBS roof silhouette at bottom of sky circle
	var hill_y: float = center.y + inner_r * 0.42
	var hill_col: Color = Color("5a944a") if current_period <= 1 else Color("284238")
	draw_circle(Vector2(center.x, hill_y + 10.0), inner_r * 0.72, hill_col)
	# Tiny house silhouette
	draw_rect(Rect2(center.x - 4.0, hill_y - 4.0, 8.0, 6.0), Color("e6d8be") if current_period <= 1 else Color("7c889e"))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(center.x - 5.5, hill_y - 4.0),
			Vector2(center.x, hill_y - 9.0),
			Vector2(center.x + 5.5, hill_y - 4.0),
		]),
		Color("b8563c") if current_period <= 1 else Color("5c3430")
	)
	# Warm glowing window pixel at night
	if current_period >= 2:
		draw_rect(Rect2(center.x - 1.0, hill_y - 2.0, 2.0, 2.0), Color("ffd470"))

	# Crisp inner gold rim
	draw_arc(center, inner_r, 0.0, TAU, 36, Color("c49b56"), 1.3, true)
