# Manus Integration Package - Theater of War
# Repo: https://github.com/melsofany/Theater-of-War-
# Goal: تركيب المدن المودرن بالأبراج الزجاجية + كل التضاريس بين المدن كجزء من الخريطة الأولى

## ما تم بنائه
- خريطة عالم 256x256 بكل التضاريس: صحراء، غابات، جبال، محيطات، هضاب، سهول، وديان، تلال، مستنقعات، شواطئ، أراضي محروقة
- 32 مدينة، كل مدينة لها interior مودرن: أبراج زجاجية 20-40 دور، واجهات Curtain Wall، شوارع واسعة 30م، محلات Ground Floor، مول، مستشفى مودرن، مسجد مودرن
- النظام متكامل: World Map هي الأساس، والمدن الداخلية تتحمل عند الاقتراب عبر ChunkManager

## الملفات الجاهزة للنسخ
ارفع هذه الملفات من هذه المحادثة إلى الريبو:

1. `integrated_world_city.html` -> أداة معاينة تفاعلية (للتوثيق)
2. `grand_map_interactive.html` -> معاينة تضاريس كاملة
3. `world_map_satellite.webp` -> Reference image للتضاريس
4. `downtown_city_aerial.webp` -> Reference للمدن الزجاجية
5. `top_down_city_map.webp` -> Reference للمدن الحضارية

## التنفيذ في Godot 4.3 - خطوات لـ Manus

### 1. إنشاء src/World/Maps/GrandStrategicMap.gd

```gdscript
extends Resource
class_name GrandStrategicMap

# كل التضاريس بين المدن - مطابقة لـ Phase 2 لكن موسعة
enum TerrainType {
  DEEP_SEA,        # محيط عميق - غير قابل للعبور
  SHALLOW_SEA,     # بحر ضحل - للسفن فقط
  BEACH,           # شاطئ - x1.2
  PLAINS,          # سهول - x1.0 أسرع
  HILLS,           # تلال - x1.4 + رؤية
  FOREST,          # غابات كثيفة - x2.2 + اختباء
  DESERT_DUNES,    # كثبان صحراء - x1.4 + استهلاك وقود
  DESERT_FLAT,     # صحراء مسطحة - x1.2
  SWAMP,           # مستنقع - x2.8 + استنزاف
  MOUNTAIN,        # جبال - غير قابل للعبور للمدرعات
  HIGH_MOUNTAIN,   # جبال شاهقة ثلجية - غير قابل للعبور نهائيا
  PLATEAU,         # هضبة - x1.3 + ميزة دفاعية
  VALLEY,          # وادي - x1.1 + ممر
  WASTELAND,       # أرض محروقة - x1.5
  RIVER,           # نهر - يحتاج جسر
  ROAD_ASPHALT,    # طريق أسفلت 30م - x0.7 أسرع
  ROAD_DIRT,       # طريق ترابي - x0.9
  CITY_MODERN      # مدينة مودرن زجاجية
}

const TERRAIN_STATS = {
  TerrainType.DEEP_SEA: { passable_land=false, passable_naval=true, cost=99.0, cover=0, name="محيط عميق" },
  TerrainType.SHALLOW_SEA: { passable_land=false, passable_naval=true, cost=1.0, cover=0, name="بحر ضحل" },
  TerrainType.BEACH: { passable_land=true, cost=1.2, cover=0.1, name="شاطئ" },
  TerrainType.PLAINS: { passable_land=true, cost=1.0, cover=0.2, name="سهول" },
  TerrainType.HILLS: { passable_land=true, cost=1.4, cover=0.4, name="تلال", elevation=30 },
  TerrainType.FOREST: { passable_land=true, cost=2.2, cover=0.8, name="غابات كثيفة" },
  TerrainType.DESERT_DUNES: { passable_land=true, cost=1.4, cover=0.2, fuel_mod=1.3, name="كثبان صحراوية" },
  TerrainType.DESERT_FLAT: { passable_land=true, cost=1.2, cover=0.1, fuel_mod=1.2, name="صحراء" },
  TerrainType.SWAMP: { passable_land=true, cost=2.8, cover=0.6, attrition=0.02, name="مستنقع" },
  TerrainType.MOUNTAIN: { passable_land=false, passable_infantry=true, cost=3.5, cover=0.9, elevation=80, name="جبال" },
  TerrainType.HIGH_MOUNTAIN: { passable_land=false, passable_infantry=false, cost=99.0, elevation=150, name="جبال شاهقة" },
  TerrainType.PLATEAU: { passable_land=true, cost=1.3, cover=0.5, elevation=40, name="هضبة", defense_bonus=1.2 },
  TerrainType.VALLEY: { passable_land=true, cost=1.1, cover=0.3, name="وادي" },
  TerrainType.WASTELAND: { passable_land=true, cost=1.5, cover=0.2, name="أرض محروقة" },
  TerrainType.RIVER: { passable_land=false, needs_bridge=true, cost=99.0, name="نهر" },
  TerrainType.ROAD_ASPHALT: { passable_land=true, cost=0.7, cover=0.1, name="طريق أسفلت 30م" },
  TerrainType.ROAD_DIRT: { passable_land=true, cost=0.9, cover=0.1, name="طريق ترابي" },
  TerrainType.CITY_MODERN: { passable_land=true, cost=1.0, cover=0.7, name="مدينة مودرن زجاجية" },
}

# خريطة 256x256 مع كل التضاريس
# تولد بـ Perlin noise + Voronoi للمدن
func generate_world(seed: int) -> Dictionary:
  # استخدم FastNoiseLite مع 4 octaves
  # وزع المدن على مسافات متباعدة
  # اربط المدن بطرق أسفلتية (A* مع تفضيل السهول والوديان)
  # أضف أنهار من الجبال للمحيطات
  pass
```

### 2. إنشاء src/World/Cities/ModernCity.gd

```gdscript
extends Resource
class_name ModernCity

enum ModernBuilding {
  GLASS_TOWER,      # برج زجاجي 20-40 دور - واجهة Curtain Wall + مهبط هليكوبتر
  MALL,             # مول تجاري - واجهة زجاجية كبيرة
  RES_HIGH,         # سكني فاخر - Pool على السطح
  SHOP_STRIP,       # محلات شارع - 6م رصيف + تندات
  HOSPITAL_MODERN,  # مستشفى مودرن - H على السطح
  MOSQUE_MODERN,    # مسجد مودرن بقبة زجاجية
  PARK_MODERN,      # حديقة مركزية
  POLICE_STATION,   # قسم شرطة
  POWER_SUBSTATION, # محطة كهرباء فرعية
  WATER_TOWER       # برج مياه
}

const BUILDING_STATS = {
  ModernBuilding.GLASS_TOWER: { floors="20-40", glass=true, helipad=true, shops=4, pop=400, npcs=8, income_mat=20, material="glass_reflective" },
  ModernBuilding.MALL: { floors=3, glass=true, shops=20, pop=0, npcs=15, income_mat=50, material="glass_storefront" },
  ModernBuilding.RES_HIGH: { floors=15, glass=true, pool=true, pop=800, npcs=10, income_manpower=30 },
  ModernBuilding.SHOP_STRIP: { floors=2, shops=6, pop=50, npcs=6, income_mat=15 },
  ModernBuilding.HOSPITAL_MODERN: { floors=6, helipad=true, beds=200, pop=0, npcs=12, heal_rate=0.05 },
  ModernBuilding.MOSQUE_MODERN: { floors=2, pop=0, morale_bonus=0.1 },
  ModernBuilding.PARK_MODERN: { floors=1, morale_bonus=0.05 },
  ModernBuilding.POLICE_STATION: { floors=3, intel_range=50, npcs=6 },
}

# شوارع واسعة
const STREET_WIDTHS = {
  "boulevard_main": 30,  # بوليفارد رئيسي 4 حارات + جزيرة نخل
  "avenue": 20,          # شارع جانبي 2 حارة + رصيف محلات 6م
  "side_street": 12,     # شارع فرعي
  "alley": 6             # زقاق
}

# توليد مدينة داخلية
func generate_interior(city_id: String, city_type: String) -> Array:
  # 12-18 مبنى حسب نوع المدينة
  # CAPITAL_GLASS: 18 مبنى (8 أبراج زجاجية + مولين + ...)
  # MODERN_COAST: 12 مبنى
  # Grid شوارع: كل 90م بوليفارد
  # طرق أسفلت مع خطوط صفراء ومعابر مشاة
  pass
```

### 3. تعديل src/World/World.gd

```gdscript
# في World.gd أضف:
var grand_map: GrandStrategicMap
var city_interiors: Dictionary = {} # city_id -> ModernCity interior

func _ready():
  grand_map = GrandStrategicMap.new()
  grand_map.generate_world(12345)
  # حمل interiors للمدن القريبة فقط عبر ChunkManager

func get_terrain_at(pos: Vector2i) -> TerrainType:
  # إذا داخل مدينة مودرن ومحملة، رجع CITY_MODERN
  # وإلا رجع تضاريس العالم الكبير
  if is_inside_city_interior(pos):
    return TerrainType.CITY_MODERN
  return grand_map.get_terrain(pos)

func should_stream_city(pos: Vector2i) -> bool:
  for city in cities:
    if pos.distance_to(city.world_pos) < 30:
      return true
  return false
```

### 4. تكامل مع Economy & Logistics (Phase 5-6)

- Glass Towers: تنتج Materials (مكاتب) + Manpower (سكان)
- Malls: تنتج Materials x2
- Hospitals: تعالج الوحدات (heal_rate في Logistics)
- Police: تزود intel_range في Intelligence
- Parks/Mosques: morale_bonus للوحدات القريبة

### 5. تكامل مع ChunkManager (Phase 10b)

- World Map 256x256 مقسمة Chunks 16x16
- كل مدينة interior هي Chunk خاص يتحمل عند الاقتراب
- استخدم existing ChunkManager.chunk math

## Prompt جاهز لـ Manus

انسخ هذا لـ Manus:

```
عندي ريبو Theater of War على Godot 4.3 - Phases 0-10c شغالة.
المطلوب:

1. ادمج الخريطة المتكاملة: عالم 256x256 بكل التضاريس (صحراء، غابات، جبال، محيطات، هضاب، سهول، وديان، تلال، مستنقعات، شواطئ، أراضي محروقة، أنهار) بين المدن.

2. المدن تكون جزء من الخريطة: 12 مدينة مودرن بأبراج زجاجية عالية Curtain Wall، شوارع واسعة 30م، محلات Ground Floor، مولات، مستشفيات مودرن بمهبط هليكوبتر.

3. المدن الداخلية تتحمل عند الاقتراب عبر ChunkManager (streaming) - استخدم SpatialGrid للتسجيل.

4. انشئ:
   - src/World/Maps/GrandStrategicMap.gd مع enum TerrainType الكامل + TERRAIN_STATS (cost, cover, passable)
   - src/World/Cities/ModernCity.gd مع ModernBuilding types
   - عدل src/World/World.gd ليدعم should_stream_city

5. التكامل:
   - Economy: الأبراج والمولات تنتج Materials
   - Logistics: المستشفيات تعالج
   - Intelligence: الشرطة تزود المدى

6. استخدم الصور المرجعية:
   - world_map_satellite.webp للتضاريس
   - downtown_city_aerial.webp للمدن الزجاجية

7. اعمل PR بعنوان "feat: integrate modern glass cities + full terrain diversity between cities"

الريبو: https://github.com/melsofany/Theater-of-War-
```

## ملفات للتحميل
- integrated_world_city.html (أداة المعاينة)
- GrandStrategicMap.gd code (في هذا الملف)
- Reference images (4 صور)

## تست
بعد التركيب:
```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
godot --headless --script tools/validate_project.gd
```

لازم 134/134 tests تعدي.
