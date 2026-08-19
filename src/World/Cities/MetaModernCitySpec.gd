extends Resource
class_name MetaModernCitySpec

# Modern Glass Cities - Interior scenes for world cities
# Optional city specification supplied with the Meta AI package.

enum ModernBuilding {
	GLASS_TOWER,       # برج زجاجي 20-40 دور - Curtain Wall عاكس + مهبط هليكوبتر H
	MALL,              # مول تجاري Grand Mall - واجهة زجاجية كاملة + باركنج
	RES_HIGH,          # سكني فاخر - Pool على السطح + حدائق
	SHOP_STRIP,        # محلات شارع - 6م رصيف + تندات + كافيهات
	HOSPITAL_MODERN,   # مستشفى مودرن - H على السطح + Helipad
	MOSQUE_MODERN,     # مسجد مودرن بقبة زجاجية تركواز
	PARK_MODERN,       # حديقة مركزية - نخل + نوافير
	POLICE_STATION,    # قسم شرطة - intel range
	POWER_SUBSTATION,  # محطة كهرباء فرعية
	WATER_TOWER,       # برج مياه
	FUEL_STATION,      # محطة وقود
	COMMS_TOWER        # برج اتصالات
}

const BUILDING_STATS = {
	ModernBuilding.GLASS_TOWER: {
		"ar": "برج زجاجي", "en": "Glass Tower",
		"floors": "20-40", "glass": true, "helipad": true, "shops": 4,
		"pop": 400, "npcs": 8, "income_mat": 20, "income_fuel": 0,
		"material": "res://assets/materials/glass_reflective.tres",
		"icon": "🏢", "color": Color("#60a5fa"), "height": 120
	},
	ModernBuilding.MALL: {
		"ar": "مول تجاري", "en": "Shopping Mall",
		"floors": 3, "glass": true, "shops": 20, "pop": 0, "npcs": 15,
		"income_mat": 50, "material": "res://assets/materials/glass_storefront.tres",
		"icon": "🛍️", "color": Color("#fbbf24"), "height": 15
	},
	ModernBuilding.RES_HIGH: {
		"ar": "سكني فاخر", "en": "Luxury Residential",
		"floors": 15, "glass": true, "pool": true, "pop": 800, "npcs": 10,
		"income_manpower": 30, "icon": "🏠", "color": Color("#a78bfa"), "height": 60
	},
	ModernBuilding.SHOP_STRIP: {
		"ar": "محلات شارع", "en": "Shop Strip",
		"floors": 2, "shops": 6, "pop": 50, "npcs": 6,
		"income_mat": 15, "icon": "🏪", "color": Color("#fb923c"), "height": 8
	},
	ModernBuilding.HOSPITAL_MODERN: {
		"ar": "مستشفى مودرن", "en": "Modern Hospital",
		"floors": 6, "helipad": true, "beds": 200, "pop": 0, "npcs": 12,
		"heal_rate": 0.05, "icon": "🏥", "color": Color("#f87171"), "height": 24
	},
	ModernBuilding.MOSQUE_MODERN: {
		"ar": "مسجد مودرن", "en": "Modern Mosque",
		"floors": 2, "pop": 0, "morale_bonus": 0.1,
		"icon": "🕌", "color": Color("#4ade80"), "height": 20
	},
	ModernBuilding.PARK_MODERN: {
		"ar": "حديقة", "en": "Park", "floors": 1,
		"morale_bonus": 0.05, "icon": "🌳", "color": Color("#34d399"), "height": 2
	},
	ModernBuilding.POLICE_STATION: {
		"ar": "قسم شرطة", "en": "Police Station",
		"floors": 3, "intel_range": 50, "npcs": 6,
		"icon": "🚔", "color": Color("#38bdf8"), "height": 12
	},
	ModernBuilding.POWER_SUBSTATION: {
		"ar": "محطة كهرباء", "en": "Power Substation",
		"floors": 1, "powers_city": true, "icon": "⚡", "color": Color("#fbbf24"), "height": 6
	},
	ModernBuilding.WATER_TOWER: {
		"ar": "برج مياه", "en": "Water Tower",
		"floors": 1, "icon": "💧", "color": Color("#22d3ee"), "height": 25
	},
	ModernBuilding.FUEL_STATION: {
		"ar": "محطة وقود", "en": "Fuel Station",
		"floors": 1, "fuel_supply": 100, "icon": "⛽", "color": Color("#fb7185"), "height": 4
	},
	ModernBuilding.COMMS_TOWER: {
		"ar": "برج اتصالات", "en": "Comms Tower",
		"floors": 1, "intel_range": 80, "icon": "📡", "color": Color("#22d3ee"), "height": 50
	},
}

const STREET_WIDTHS = {
	"boulevard_main": 30,  # بوليفارد رئيسي 4 حارات + جزيرة نخل في النص
	"avenue": 20,          # شارع 2 حارة + رصيف محلات 6م
	"side_street": 12,     # فرعي
	"alley": 6
}

# توليد مدينة داخلية
func generate_interior(city_id: String, city_type: String, seed_val: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(city_id + str(seed_val))
	var count = 12
	if city_type == "CAPITAL_GLASS":
		count = 18
	elif city_type == "MODERN_COAST":
		count = 14
	
	var buildings = []
	for i in count:
		var b_type = ModernBuilding.values()[rng.randi() % ModernBuilding.size()]
		buildings.append({
			"type": b_type,
			"pos": Vector2(rng.randf_range(-180, 180), rng.randf_range(-180, 180)),
			"floors": rng.randi_range(3, 35),
			"rotation": rng.randf_range(0, 360)
		})
	
	return {"city_id": city_id, "buildings": buildings, "roads": generate_roads()}

func generate_roads() -> Array:
	# Grid شوارع كل 90م - بوليفارد رئيسي + شوارع جانبية
	# أسفلت مع خطوط صفراء ومعابر مشاة
	var roads = []
	for i in range(-3, 4):
		roads.append({"type": "boulevard_main", "x": i * 90, "vertical": true, "width": 30})
		roads.append({"type": "boulevard_main", "y": i * 90, "vertical": false, "width": 30})
	return roads
