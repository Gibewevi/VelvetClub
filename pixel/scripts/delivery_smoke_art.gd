class_name DeliverySmokeArt
extends RefCounted

# Hand-pixelled lobes, assembled into six distinct drawings: pop, billow,
# full cloud, separate lobes, small wisps, final flecks. No scaling or alpha
# noise is involved; the road remains visible between the cloud fragments.
const INK = {
	"h": Color("fff0dc"),
	"m": Color("e4c9bd"),
	"s": Color("bca7b7"),
	"d": Color("998ba6"),
}
const LOBES = [
	["hh", "ms"],
	[".hh.", "hhhm", "hmms", ".ss."],
	["..hh..", ".hhhh.", "hhhhhm", "hhhhmm", ".mmmss", "..sss."],
	["..hhhh..", ".hhhhhh.", "hhhhhhhm", "hhhhhhmm", "hhhhmmmm", ".hmmmmss", ".mmmsss.", "..sssd.."],
	["...hhhh...", ".hhhhhhhh.", ".hhhhhhhhm", "hhhhhhhhhm", "hhhhhhhhmm", "hhhhhmmmmm", ".hhhmmmmss", ".mmmmssss.", "..mmssss..", "...sssd..."],
]

# A lobe is [drawing index, x, y]. Their order gives readable overlap and
# preserves scalloped bottoms instead of making one smooth elliptical blob.
const CLOUD_STEPS = [
	[
		[[1, 12, 14], [2, 8, 12]],
		[[2, 13, 11], [3, 7, 8], [2, 5, 12], [2, 10, 12]],
		[[3, 13, 7], [4, 6, 3], [3, 3, 9], [4, 8, 8]],
		[[3, 4, 2], [2, 15, 5], [3, 11, 10], [2, 2, 11], [0, 21, 2]],
		[[1, 3, 5], [2, 12, 8], [1, 19, 14], [1, 5, 15], [0, 21, 2]],
		[[0, 3, 4], [1, 12, 7], [0, 20, 15]],
	],
	[
		[[1, 8, 14], [2, 11, 12]],
		[[2, 5, 12], [3, 10, 8], [2, 14, 12], [2, 8, 12]],
		[[3, 4, 7], [4, 10, 3], [3, 13, 10], [4, 5, 8]],
		[[2, 3, 4], [3, 13, 2], [3, 4, 10], [2, 16, 11], [0, 1, 1]],
		[[1, 17, 4], [2, 5, 8], [1, 2, 14], [1, 15, 15], [0, 1, 1]],
		[[0, 18, 3], [1, 7, 7], [0, 2, 15]],
	],
	[
		[[1, 9, 14], [2, 11, 12]],
		[[3, 9, 7], [2, 14, 11], [2, 6, 11], [2, 10, 12]],
		[[3, 11, 4], [3, 4, 6], [3, 13, 9], [4, 6, 8]],
		[[3, 8, 1], [2, 17, 7], [3, 3, 10], [2, 12, 12], [0, 1, 5]],
		[[1, 11, 2], [1, 19, 9], [2, 4, 9], [1, 13, 15], [0, 1, 4]],
		[[0, 12, 1], [1, 4, 8], [0, 18, 13]],
	],
]
const FLECK_STEPS = [
	["........", "........", "...h....", "..hhm...", "...s....", "........", "........", "........"],
	["........", "...h....", "..hhhm..", ".hhhmm..", "..mms...", "...s....", "........", "........"],
	["........", "....hh..", "...hhm..", "..hmm...", "..ss....", "........", "........", "........"],
	["........", ".....h..", "....hm..", "....s...", "........", "........", "........", "........"],
]

static var _cloud_cache: Array = []
static var _fleck_cache: Array[Texture2D] = []

static func clouds() -> Array:
	if _cloud_cache.is_empty():
		for steps in CLOUD_STEPS:
			var frames: Array[Texture2D] = []
			for lobes in steps:
				var img = Image.create(24, 20, false, Image.FORMAT_RGBA8)
				img.fill(Color.TRANSPARENT)
				for lobe in lobes:
					_stamp(img, LOBES[lobe[0]], Vector2i(lobe[1], lobe[2]))
				frames.append(ImageTexture.create_from_image(img))
			_cloud_cache.append(frames)
	return _cloud_cache

static func flecks() -> Array[Texture2D]:
	if _fleck_cache.is_empty():
		for drawing in FLECK_STEPS:
			var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
			img.fill(Color.TRANSPARENT)
			_stamp(img, drawing, Vector2i.ZERO)
			_fleck_cache.append(ImageTexture.create_from_image(img))
	return _fleck_cache

static func _stamp(img: Image, drawing: Array, origin: Vector2i) -> void:
	for y in range(drawing.size()):
		var row: String = drawing[y]
		for x in range(row.length()):
			var key = row[x]
			if INK.has(key):
				img.set_pixel(origin.x + x, origin.y + y, INK[key])
