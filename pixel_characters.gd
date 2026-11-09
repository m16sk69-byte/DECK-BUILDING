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
	"임프": [
		"................",
		"....K......K....",
		"....KK....KK....",
		".....KSSSSK.....",
		"....KSSSSSSK....",
		"....KS.ES.ESK...",
		"....KSSSSSSK....",
		".....KSSSSK.....",
		"...KKKBBBBKKK...",
		"..K..KBBBBK..K..",
		".....KBBBBK.....",
		".....KBBBBK.....",
		"......KBBK......",
		".....KK..KK.....",
		"....KK....KK....",
		"................",
	],
	"슬라임": [
		"................",
		"................",
		"................",
		"................",
		"......KKKK......",
		"....KKGGGGKK....",
		"...KGGGGGGGGK...",
		"..KGGGEGG.EGGK..",
		"..KGGGGGGGGGGK..",
		".KGGGGYYYYGGGGK.",
		".KGGGGGGGGGGGGK.",
		".KGGGGGGGGGGGGK.",
		"..KGGGGGGGGGGK..",
		"...KKKKKKKKKK...",
		"................",
		"................",
	],
	"용": [
		"................",
		"..KK.......KK...",
		"..KGK.....KGK...",
		"..KGGK...KGGK...",
		"...KGGKKKGGK....",
		"....KGGGGGK.....",
		"....KGEGG.GK....",
		".....KGGGGK.....",
		"...KKKGGGGKKK...",
		"..KGGKGGGGKGGK..",
		".KGG.KGGGGK.GGK.",
		".....KGGGGK.....",
		"....KGGGGGGK....",
		"...KKGGKKGGKK...",
		"..KK..K..K..KK..",
		"................",
	],
	"하피": [
		"................",
		".....KKKKKK.....",
		"....KSSSSSSK....",
		"....KSESS.ESK...",
		".....KSSSSK.....",
		"..KKKGGGGGGKKK..",
		".KGGKGGGGGGKGGK.",
		"KGGG.KGGGGK.GGGK",
		"KGG..KGGGGK..GGK",
		".....KGGGGK.....",
		".....KGGGGK.....",
		"......KGGK......",
		".....KY..YK.....",
		"....KY....YK....",
		"...KK......KK...",
		"................",
	],
	"거미": [
		"................",
		"................",
		".....KKKKKK.....",
		"....KSSSSSSK....",
		"....KSESS.ESK...",
		".....KSSSSK.....",
		"..K..KPPPPK..K..",
		"...KKPPPPPPKK...",
		"..K.KPPPPPPK.K..",
		".K..KPPPPPPK..K.",
		"K...KPPPPPPK...K",
		"...KPPPPPPPPK...",
		"..K..KKKKKK..K..",
		".K............K.",
		"K..............K",
		"................",
	],
}

static func _base_kind(kind: String) -> String:
	if kind == "고블린": return "검사"
	if kind == "고블린 궁수": return "궁수"
	if kind == "오크" or kind == "언데드 골렘": return "검사"
	if kind == "녹티스" or kind == "회복술사" or kind == "사령술사": return "마법사"
	if kind == "드래곤" or kind == "가고일": return "용"
	if kind == "아라크네": return "거미"
	if kind == "저격수": return "궁수"
	if kind == "도적" or kind == "기사" or kind == "동국의 검사" or kind == "방패병" or kind == "검투사" or kind == "보스" or kind == "검신 알론드": return "검사"
	return kind if PATTERNS.has(kind) else "검사"

static func make_image(kind: String, enemy := false) -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var palette := {
		"K":Color("263044"), "M":Color("c3dbdc"), "S":Color("ffd7af"),
		"E":Color("263044"), "B":Color("58b9d0"), "G":Color("80c894"),
		"P":Color("b69bed"), "Y":Color("f9d779"),
	}
	if kind == "고블린" or kind == "고블린 궁수":
		palette["S"] = Color("9ed271")
	if kind == "오크": palette["S"] = Color("70a86d")
	if kind == "언데드 골렘": palette["S"] = Color("91aaa0")
	if kind == "녹티스": palette["S"] = Color("e1d0dc")
	if kind == "임프": palette["S"] = Color("e38c96")
	if kind == "슬라임": palette["G"] = Color("80d8d0")
	if kind == "가고일": palette["G"] = Color("8e9da9")
	if kind == "드래곤": palette["G"] = Color("78ba80")
	if kind == "하피": palette["G"] = Color("e5b871")
	if kind == "아라크네": palette["P"] = Color("866ca5")
	if kind == "사령술사": palette["P"] = Color("685f88")
	if enemy:
		palette["B"] = Color("e67e70")
		palette["G"] = Color("d9976f")
		palette["P"] = Color("d187bd")
		palette["M"] = Color("c59f9c")
	if kind == "보스" or kind == "동국의 검사" or kind == "검신 알론드":
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
