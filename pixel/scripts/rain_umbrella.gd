class_name RainUmbrella
extends Sprite2D

static var textures: Dictionary = {}

static func texture_for(index: int) -> Texture2D:
	index = posmod(index,4)
	if textures.has(index): return textures[index]
	var colors = [Color("5c88ac"),Color("96364c"),Color("79588d"),Color("54866d")]
	var color: Color = colors[index]
	var img = Image.create(33,26,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	# Discrete dome, scalloped hem, panel seams and a hooked shaft. No AA,
	# animated noise or fractional positioning.
	for y in range(18):
		for x in range(33):
			var dx = absf(x-16.0)
			var top = 2+floori(10*(1-sqrt(maxf(0,1-pow(dx/16,2)))))
			var bottom = 16-int(posmod(x,8) < 2)
			if y < top or y > bottom: continue
			var tone = color
			if x > 18 or y > 12: tone = color.darkened(.22)
			if y < top+3 and x < 17: tone = color.lightened(.18)
			if y == top or y == bottom or dx == 16: tone = Color("251f32")
			if absf(x-(16+(y-2)*.55)) < .65 or absf(x-(16-(y-2)*.55)) < .65: tone = color.darkened(.3)
			img.set_pixel(x,y,tone)
	img.fill_rect(Rect2i(16,16,1,8),Color("d7c7ad"))
	img.fill_rect(Rect2i(13,23,4,1),Color("413545"))
	img.set_pixel(12,22,Color("413545"))
	textures[index] = ImageTexture.create_from_image(img)
	return textures[index]

static func update_actor(sim, actor: Actor) -> void:
	var node = actor.get_node_or_null("RainUmbrella") as RainUmbrella
	var identity = str(actor.brain.get("profile_id",actor.kind+str(actor.item_id)))
	var enabled = sim.rain_strength > .1 and actor.visible and sim.model.room_at(actor.world).is_empty() and posmod(identity.hash(),5) != 0
	if not enabled:
		if node != null: node.visible = false
		return
	if node == null:
		node = RainUmbrella.new()
		node.name = "RainUmbrella"
		node.texture = texture_for(identity.hash())
		node.centered = false
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.z_index = 3
		actor.add_child(node)
	node.position = Vector2(-14 if actor.flip else -18,-58)
	node.visible = true
	if actor.bubble != null:
		actor.bubble.z_index = 4
		actor.bubble.position.y = -68
