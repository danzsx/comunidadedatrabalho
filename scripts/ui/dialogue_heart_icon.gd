class_name DialogueHeartIcon
extends Control
## Crisp pixel-art relationship heart icon rendered inside the DialogueUI nameplate.

var heart_color: Color = Color(0.46, 0.24, 0.62, 1.0)
var highlight_color: Color = Color(0.84, 0.72, 0.96, 1.0)


func set_bond_from_axes(axes: Dictionary) -> void:
	var trust: int = int(axes.get(&"trust", 0))
	var affinity: int = int(axes.get(&"affinity", 0))
	var familiarity: int = int(axes.get(&"familiarity", 0))
	var cooperation: int = int(axes.get(&"cooperation", 0))

	if trust <= -2:
		heart_color = Color(0.36, 0.35, 0.42, 1.0)
		highlight_color = Color(0.58, 0.56, 0.64, 1.0)
	elif trust >= 3 and cooperation >= 2:
		heart_color = Color(0.95, 0.68, 0.22, 1.0)
		highlight_color = Color(1.0, 0.92, 0.66, 1.0)
	elif trust >= 2 or affinity >= 2:
		heart_color = Color(0.88, 0.30, 0.46, 1.0)
		highlight_color = Color(1.0, 0.72, 0.78, 1.0)
	elif familiarity >= 1 or trust >= 1:
		heart_color = Color(0.28, 0.54, 0.86, 1.0)
		highlight_color = Color(0.72, 0.88, 1.0, 1.0)
	else:
		heart_color = Color(0.46, 0.24, 0.62, 1.0)
		highlight_color = Color(0.84, 0.72, 0.96, 1.0)
	queue_redraw()


func _draw() -> void:
	var outline: Color = Color(0.14, 0.11, 0.16, 1.0)
	# 11x10 crisp pixel-art heart centered in 14x14 control
	var ox: float = 1.0
	var oy: float = 2.0
	var rows: Array[String] = [
		"..OO...OO..",
		".OHHO.OXXO.",
		"OHXXOOXXXXO",
		"OHXXXXXXXXO",
		"OXXXXXXXXXO",
		".OXXXXXXXO.",
		"..OXXXXXO..",
		"...OXXXO...",
		"....OXO....",
		".....O.....",
	]
	for y: int in range(rows.size()):
		var row: String = rows[y]
		for x: int in range(row.length()):
			var ch: String = row[x]
			if ch == ".":
				continue
			var col: Color = outline
			if ch == "X":
				col = heart_color
			elif ch == "H":
				col = highlight_color
			draw_rect(Rect2(ox + float(x), oy + float(y), 1.0, 1.0), col)
