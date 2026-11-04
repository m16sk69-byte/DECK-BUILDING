extends RefCounted

# Original 16x16 placeholder pixel characters, shared by cards and the map.
const PATTERNS = {
	"검사": [
		"................",
		".....KKKKKK.....",
		"....KMMMMMMK....",
		"...KMMMMMMMMK...",
		"...KMMKMMKMMK...",
		"...KKSSSSSSKK...",
		"....KSESSESK....",
		"....KSSSSSSK....",
		".....KSSSSK.....",
		"....KBBBBBBK..Y.",
		"...KBBBBBBBBK.Y.",
		"...KBBBBBBBBKYY.",
		"...KBBYBBYBBK.Y.",
		"....KBBBBBBK..Y.",
		"....KBBKKBBK....",
		"....KKK..KKK....",
	],
	"궁수": [
		"................",
		".....KKKKKK.....",
		"....KGGGGGGK....",
		"...KGGGGGGGGK...",
		"...KGGGGGGGGK...",
		"...KKSSSSSSKK...",
		"....KSESSESK....",
		"....KSSSSSSK....",
		".....KSSSSK..Y..",
		"....KGGGGGGK.YY.",
		"...KGGGGGGGGK.Y.",
		"...KGGYGGYGGK.Y.",
		"...KGGGGGGGGK.Y.",
		"....KGGGGGGK.YY.",
		"....KGK..KGK.Y..",
		"....KKK..KKK....",
	],
	"마법사": [
		".......K........",
		"......KPK.......",
		".....KPPPK......",
		"....KPPPPPK.....",
		"...KPPPPPPPK....",
		"..KKKPPPPPKKK...",
		"....KSESSESK....",
		"....KSSSSSSK.Y..",
		".....KSSSSK.YYY.",
		"....KPPPPPPK.Y..",
		"...KPPPPPPPPK.Y.",
		"...KPPYPPYPPK.Y.",
		"..KPPPPPPPPPPKY.",
		"..KPPPPPPPPPPKY.",
		"...KPPKKPPK...Y.",
		"...KKK..KKK.....",
	],
}

static func _base_kind(kind: String) -> String:
	if kind == "고블린": return "검사"
	if kind == "고블린 궁병": return "궁수"
	if kind == "방패병" or kind == "검투사" or kind == "보스": return "검사"
	return kind if PATTERNS.has(kind) else "검사"

static func make_image(kind: String, enemy := false) -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var palette := {
		"K":Color("263044"), "M":Color("c3dbdc"), "S":Color("ffd7af"),
		"E":Color("263044"), "B":Color("58b9d0"), "G":Color("80c894"),
		"P":Color("b69bed"), "Y":Color("f9d779"),
	}
	if kind == "고블린" or kind == "고블린 궁병":
		palette["S"] = Color("9ed271")
	if enemy:
		palette["B"] = Color("e67e70")
		palette["G"] = Color("d9976f")
		palette["P"] = Color("d187bd")
		palette["M"] = Color("c59f9c")
	if kind == "보스":
		palette["M"] = Color("f3c65e")
		palette["B"] = Color("a25c92")
	for y in range(16):
		var row: String = PATTERNS[_base_kind(kind)][y]
		for x in range(mini(16, row.length())):
			var symbol := row.substr(x, 1)
			if palette.has(symbol): image.set_pixel(x, y, palette[symbol])
	return image

static func make_sprite(kind: String, enemy := false) -> ImageTexture:
	return ImageTexture.create_from_image(make_image(kind, enemy))

static func make_card(kind: String) -> ImageTexture:
	var tile := make_image(kind)
	tile.resize(64, 64, Image.INTERPOLATE_NEAREST)
	var card := Image.create(100, 70, false, Image.FORMAT_RGBA8)
	card.fill(Color("1a303a"))
	card.blend_rect(tile, Rect2i(0, 0, 64, 64), Vector2i(18, 3))
	return ImageTexture.create_from_image(card)
