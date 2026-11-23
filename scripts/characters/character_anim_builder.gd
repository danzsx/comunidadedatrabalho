class_name CharacterAnimBuilder
extends RefCounted
## Builds a 4-direction Idle + Walk SpriteFrames resource from a 4x4 grid sprite sheet.

const DIRECTIONS: Array[StringName] = [&"down", &"left", &"right", &"up"]


static func build_from_sheet(tex: Texture2D, frame_w: int = 24, frame_h: int = 32) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	if tex == null:
		return sf

	for row: int in range(DIRECTIONS.size()):
		var dir_name: String = String(DIRECTIONS[row])
		var idle_anim := StringName("idle_" + dir_name)
		var walk_anim := StringName("walk_" + dir_name)
		sf.add_animation(idle_anim)
		sf.set_animation_speed(idle_anim, 3.0)
		sf.set_animation_loop(idle_anim, true)

		sf.add_animation(walk_anim)
		sf.set_animation_speed(walk_anim, 7.5)
		sf.set_animation_loop(walk_anim, true)

		# Idle uses frame 0 and subtle breathing frame 1 (if sheet has 4 cols)
		var atlas0 := AtlasTexture.new()
		atlas0.atlas = tex
		atlas0.region = Rect2(0, row * frame_h, frame_w, frame_h)
		sf.add_frame(idle_anim, atlas0)

		for col: int in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
			sf.add_frame(walk_anim, atlas)

	return sf
