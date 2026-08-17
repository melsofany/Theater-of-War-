extends Resource
class_name GrandStrategicMap

# Theater of War - Grand Strategic Map with Full Terrain Diversity
# Between Cities: Desert, Forests, Mountains, Oceans, Plateaus, Plains, Valleys, Hills, Swamps, Beaches, Wasteland, Rivers

enum TerrainType {
	DEEP_SEA,
	SHALLOW_SEA,
	BEACH,
	PLAINS,
	HILLS,
	FOREST_DENSE,
	DESERT_DUNES,
	DESERT_FLAT,
	SWAMP,
	MOUNTAIN,
	HIGH_MOUNTAIN,
	PLATEAU,
	VALLEY,
	WASTELAND,
	RIVER,
	ROAD_ASPHALT,
	ROAD_DIRT,
	CITY_MODERN,
	CITY_CLASSIC,
	BRIDGE
}

const TERRAIN_STATS = {
	TerrainType.DEEP_SEA: {"ar": "محيط عميق", "en": "Deep Ocean", "pass_land": false, "pass_naval": true, "cost": 99.0, "cover": 0.0, "color": Color("#0a2e5a")},
	TerrainType.SHALLOW_SEA: {"ar": "بحر ضحل", "en": "Shallow Sea", "pass_land": false, "pass_naval": true, "cost": 1.0, "cover": 0.0, "color": Color("#1e6fa6")},
	TerrainType.BEACH: {"ar": "شاطئ", "en": "Beach", "pass_land": true, "cost": 1.2, "cover": 0.1, "color": Color("#e6d5a7")},
	TerrainType.PLAINS: {"ar": "سهول", "en": "Plains", "pass_land": true, "cost": 1.0, "cover": 0.2, "color": Color("#8ab66a")},
	TerrainType.HILLS: {"ar": "تلال", "en": "Hills", "pass_land": true, "cost": 1.4, "cover": 0.4, "elev": 30, "color": Color("#a8c686")},
	TerrainType.FOREST_DENSE: {"ar": "غابات كثيفة", "en": "Dense Forest", "pass_land": true, "cost": 2.2, "cover": 0.8, "color": Color("#2a6a2a")},
	TerrainType.DESERT_DUNES: {"ar": "كثبان صحراوية", "en": "Desert Dunes", "pass_land": true, "cost": 1.4, "cover": 0.2, "fuel_mod": 1.3, "color": Color("#d9b56a")},
	TerrainType.DESERT_FLAT: {"ar": "صحراء مسطحة", "en": "Desert Flat", "pass_land": true, "cost": 1.2, "cover": 0.1, "fuel_mod": 1.2, "color": Color("#e6c88a")},
	TerrainType.SWAMP: {"ar": "مستنقع", "en": "Swamp", "pass_land": true, "cost": 2.8, "cover": 0.6, "attrition": 0.02, "color": Color("#3a5a3a")},
	TerrainType.MOUNTAIN: {"ar": "جبال", "en": "Mountains", "pass_land": false, "pass_inf": true, "cost": 3.5, "cover": 0.9, "elev": 80, "color": Color("#7a7a7a")},
	TerrainType.HIGH_MOUNTAIN: {"ar": "جبال شاهقة", "en": "High Mountains", "pass_land": false, "cost": 99.0, "elev": 150, "color": Color("#e0e0e0")},
	TerrainType.PLATEAU: {"ar": "هضبة", "en": "Plateau", "pass_land": true, "cost": 1.3, "cover": 0.5, "elev": 40, "def_bonus": 1.2, "color": Color("#c4a77d")},
	TerrainType.VALLEY: {"ar": "وادي", "en": "Valley", "pass_land": true, "cost": 1.1, "cover": 0.3, "color": Color("#9aba7a")},
	TerrainType.WASTELAND: {"ar": "أرض محروقة", "en": "Wasteland", "pass_land": true, "cost": 1.5, "cover": 0.2, "color": Color("#8a7a6a")},
	TerrainType.RIVER: {"ar": "نهر", "en": "River", "pass_land": false, "needs_bridge": true, "cost": 99.0, "color": Color("#2a7abf")},
	TerrainType.ROAD_ASPHALT: {"ar": "طريق أسفلت 30م", "en": "Asphalt Highway 30m", "pass_land": true, "cost": 0.7, "cover": 0.1, "color": Color("#3a3a3a")},
	TerrainType.ROAD_DIRT: {"ar": "طريق ترابي", "en": "Dirt Road", "pass_land": true, "cost": 0.9, "cover": 0.1, "color": Color("#8a6a4a")},
	TerrainType.CITY_MODERN: {"ar": "مدينة مودرن زجاجية", "en": "Modern Glass City", "pass_land": true, "cost": 1.0, "cover": 0.7, "color": Color("#60a5fa")},
	TerrainType.CITY_CLASSIC: {"ar": "مدينة كلاسيكية", "en": "Classic City", "pass_land": true, "cost": 1.0, "cover": 0.7, "color": Color("#fbbf24")},
	TerrainType.BRIDGE: {"ar": "جسر", "en": "Bridge", "pass_land": true, "cost": 0.8, "color": Color("#5a5a5a")},
}

# Cities embedded in world - 32 cities with modern interiors
const WORLD_CITIES = [
	{"id": "city_cairo_admin", "name": "القاهرة الجديدة - العاصمة الإدارية", "name_en": "New Cairo Admin Capital", "pos": Vector2i(128, 142), "type": "CAPITAL_GLASS", "pop": 18000, "is_modern": true, "towers": 12, "buildings": 22},
	{"id": "city_alamein", "name": "العلمين - أبراج زجاجية", "name_en": "Alamein Glass Towers", "pos": Vector2i(45, 78), "type": "MODERN_COAST", "pop": 12000, "is_modern": true, "towers": 8, "buildings": 16},
	{"id": "city_mansoura_new", "name": "المنصورة الجديدة", "name_en": "New Mansoura", "pos": Vector2i(142, 85), "type": "MODERN_NEW", "pop": 9000, "is_modern": true, "towers": 4, "buildings": 12},
	{"id": "city_aswan_new", "name": "أسوان الجديدة", "name_en": "New Aswan", "pos": Vector2i(135, 210), "type": "MODERN_NEW", "pop": 7000, "is_modern": true, "towers": 3, "buildings": 10},
]

# Generate world with all terrains
func generate(seed_val: int = 12345) -> void:
	# Use FastNoiseLite for heightmap
	# 0.0-0.2 = deep sea, 0.2-0.3 = shallow, 0.3-0.35 = beach, 0.35-0.6 = plains/hills/forest, 0.6-0.75 = mountains, 0.75+ = high mountains
	# Desert in south-east, swamp in south-west, forest in east, plateau in center
	# Roads via A* preferring plains/valleys
	# Rivers from high mountains to seas
	pass

func get_move_cost(terrain: TerrainType, unit_type: String) -> float:
	var stats = TERRAIN_STATS[terrain]
	if unit_type == "naval" and not stats.get("pass_naval", false):
		return 99.0
	if unit_type != "naval" and not stats.get("pass_land", true):
		if unit_type == "infantry" and stats.get("pass_inf", false):
			return stats.cost * 1.5
		return 99.0
	return stats.cost

func should_stream_city(world_pos: Vector2i, city_pos: Vector2i) -> bool:
	return world_pos.distance_to(city_pos) < 30
