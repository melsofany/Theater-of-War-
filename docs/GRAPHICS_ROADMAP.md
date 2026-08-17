# خطة تطوير جرافيكس وميكانيكس Theater of War - المراحل المتقدمة
# Godot 4.3 - من RTS بسيط لمسرح حرب حقيقي

## نظرة عامة
اللعبة حاليا Phases 0-10c شغالة. الخطة دي تضيف طبقة الواقعية التكتيكية:
غبار، قذائف، تلف مدرعات، إصابات، إخلاء، حراسة، تأمين، جر معدات، أسر وتبادل.

---

## Phase 11: VFX Battlefield - الغبار والقذائف والحفر

### 1. غبار المعركة Dust System
**التنفيذ في Godot:**
```gdscript
# src/Combat/VFX/DustSystem.gd
extends GPUParticles3D
# عند حركة دبابة/مدرعة: يولد dust trail
# عند انفجار: dust cloud كبير يتمدد
# Shader: alpha fade + wind influence

func emit_dust(pos: Vector3, intensity: float, type: String):
  # type: "movement", "explosion", "landing"
  # intensity حسب وزن المركبة وسرعتها
  # يأثر على الرؤية: يقلل intel_range بنسبة 20% داخل السحابة
```
**الجرافيكس:**
- حركة الدبابات: غبار خلفي خفيف يختفي بعد 2 ثانية
- قذيفة مدفعية: سحابة غبار قطر 15م ترتفع 8م
- هبوط هليكوبتر: غبار دائري ينتشر

### 2. سقوط القذائف وتأثيرها Shell Impact
```gdscript
# src/Combat/VFX/ShellImpact.gd
enum ImpactType { HE, AP, SMOKE, ILLUM }

func on_impact(pos: Vector3, type: ImpactType, caliber: int):
  match type:
    HE:
      create_crater(pos, caliber) # حفرة مكان القذيفة
      spawn_fragments(pos, 360) # شظايا
      screen_shake(intensity=caliber/100.0)
    AP:
      if hit_armor: spawn_spark + ricochet
      else: penetration + internal explosion
    SMOKE:
      spawn_smoke_wall(pos, duration=30s) # للتغطية على الانسحاب
```

### 3. حفرة مكان القذيفة Crater System
```gdscript
# src/World/Maps/CraterManager.gd
# يستخدم Decal + تعديل heightmap

func create_crater(pos: Vector3, caliber: int):
  var radius = caliber / 50.0 # 155mm = 3.1م قطر
  var depth = caliber / 100.0
  # 1. Decal أسود محروق
  # 2. تعديل terrain heightmap - حفرة
  # 3. الحفرة توفر cover للجنود (cover=0.6)
  # 4. تبقى طول المعركة، تختفي بعد 10 دقائق
  # 5. لو قذيفة كبيرة، تدمر طريق أسفلت
```

### 4. ارتداد المدفع/الدبابة Recoil
```gdscript
# src/Units/Components/RecoilComponent.gd
extends Node3D

@export var recoil_distance: float = 0.5 # متر للخلف
@export var recoil_time: float = 0.15

func fire():
  var tween = create_tween()
  tween.tween_property(barrel, "position:z", -recoil_distance, recoil_time/2).set_trans(Tween.TRANS_QUAD)
  tween.tween_property(barrel, "position:z", 0, recoil_time/2).set_ease(Tween.EASE_OUT)
  # اهتزاز كامل الدبابة
  chassis.position.z -= recoil_distance * 0.3
  # غبار من الفوهة + وميض
  muzzle_flash.emitting = true
  dust_from_barrel.emitting = true
```

### 5. قنابل دخان للتغطية على الانسحاب Smoke Screen
```gdscript
# src/Combat/VFX/SmokeGrenade.gd
# الجندي يلقي قنبلة دخان لتغطية الانسحاب

func throw_smoke(from: Vector3, to: Vector3):
  # مسار مقذوف
  # عند السقوط: سحابة دخان تتمدد 20م عرض، 8م ارتفاع
  # تمنع الرؤية تماما (fog_of_war = true داخلها)
  # مدة 45 ثانية، الرياح تحركها
  # AI: عند أمر Retreat، الجنود يلقون دخان تلقائيا
```

---

## Phase 12: تلف المدرعات وإصابات الجنود

### 1. تلف في المدرعات - Armor Damage Visualization
```gdscript
# src/Units/Components/ArmorDamage.gd

enum DamageZone { FRONT, SIDE, REAR, TRACKS, TURRET, ENGINE }

var damage_zones: Dictionary = {
  FRONT: 0.0, SIDE: 0.0, REAR: 0.0, TRACKS: 0.0, TURRET: 0.0
}

func take_hit(zone: DamageZone, penetration: float):
  damage_zones[zone] += penetration
  match zone:
    TRACKS:
      if damage > 0.7: immobilized = true # تحتاج جر
      show_broken_track_mesh()
      spawn_track_debris()
    ENGINE:
      if damage > 0.8: engine_dead = true, smoke_black
    TURRET:
      if damage > 0.6: turret_jammed = true, لا يستطيع الدوران
  # تغيير ماتيريال: حرق، ثقوب، دخان
  update_material_damage()
```

**الجرافيكس:**
- جنزير مقطوع: يظهر على الأرض + دخان
- برج معطل: مائل + شرارات
- محرك محترق: دخان أسود كثيف + لهب

### 2. إصابات الجنود وإخلاء
```gdscript
# src/Units/SoldierInjury.gd

enum InjuryState { HEALTHY, WOUNDED_LIGHT, WOUNDED_HEAVY, INCAPACITATED, KIA }

func on_hit(damage: float):
  if damage < 30: state = WOUNDED_LIGHT (يمشي ببطء -30%)
  elif damage < 70: state = WOUNDED_HEAVY (لا يستطيع القتال، يحتاج حمل)
  elif damage < 90: state = INCAPACITATED (على الأرض، ينزف)
  
  # طلب إخلاء
  if state >= WOUNDED_HEAVY:
    request_medevac()

func request_medevac():
  # أقرب جندي سليم يتحول لـ Carrier
  # Animation: يحمل صاحبه على الكتف
  # سرعة -50%، لا يقاتل
  # ينقله لنقطة إخلاء أو إسعاف
```

### 3. الجندي الذي يحمل صاحبه - Buddy Carry
```gdscript
# src/Units/States/CarryState.gd
extends UnitState

# AnimationTree:
# - carrier: يحمل بيدين، يمشي ببطء
# - wounded: على كتف carrier

func enter():
  carrier.speed *= 0.5
  carrier.can_shoot = false
  # يبحث عن Ambulance أو Helicopter Landing Zone

func update():
  if reached_ambulance:
    transfer_wounded_to_ambulance()
    carrier.speed = normal
```

---

## Phase 13: دوريات الغفرة والحراسة - تأمين المنشآت

### الفكرة: السيطرة تعني التأمين والحماية
مش كفاية تحتل مبنى، لازم تحرسه.

```gdscript
# src/AI/GuardDuty/PatrolSystem.gd

enum GuardType {
  PATROL,       # دورية تلف حول المنشأة
  STATIC_GUARD, # حراسة ثابتة على مدخل
  QRF,          # قوة تدخل سريع قريبة
}

class GuardPost:
  var position: Vector3
  var radius: float # نطاق الحراسة 50م
  var guard_type: GuardType
  var units: Array # 2-4 جنود أو مدرعة
  var is_secured: bool = false

func secure_location(building_id: String, units: Array):
  # لما تسيطر على مكان:
  # 1. المبنى يتحول للون فصيلك
  # 2. يظهر دائرة خضراء (نطاق التأمين)
  # 3. لازم تترك وحدة حراسة، لو مشيت، المبنى يصبح محايد بعد 2 دقيقة
  # 4. الحراسة تمنع تسلل العدو (Intelligence يكشف أي حركة داخل الدائرة)

func create_patrol_route(center: Vector3, radius: float) -> Array[Vector3]:
  # 4-6 نقاط حول المنشأة
  # الدورية تلف كل 3 دقائق
  # لو شافت عدو، تبلغ وتهاجم أو تطلب QRF
```

**التنفيذ:**
- المبنى المؤمن: أيقونة درع خضراء فوقه + دائرة خضراء شفافة
- المبنى غير المؤمن: أيقونة درع رمادي + يبدأ يرمش بعد دقيقة
- دورية الغفرة: جنود يمشون في مسار، مع كشاف ليلي ليلا
- لو العدو دخل نطاق الحراسة، إنذار + كل الوحدات القريبة تتوجه

---

## Phase 14: الإخلاء والإنقاذ - سيارات إسعاف وهليكوبتر

### 1. سيارات الإسعاف Ambulance
```gdscript
# src/Units/Vehicles/Ambulance.gd
extends Vehicle

# تجمع الجرحى من الميدان
# سعة 4 جرحى
# سرعة عالية على الطرق، بطيئة في الصحراء
# علامة صليب أحمر - لا يهاجمها AI (قانون حرب) إلا لو أمر مباشر
# تنقل الجرحى للمستشفى الميداني

func pickup_wounded(wounded: Array):
  # Animation: باب خلفي يفتح، نقالة
  # تنقل للمستشفى: الجرحى يشفون بعد 5 دقائق ويعودون كـ Manpower

### 2. الإخلاء بالهليكوبتر Helicopter Medevac
```gdscript
# src/Units/Air/HelicopterMedevac.gd

func medevac_request(pos: Vector3, count: int):
  # هليكوبتر تطير من القاعدة
  # تهبط (غبار كثيف) في LZ آمنة
  # تحمل 6 جرحى
  # تطير للمستشفى الرئيسي
  # مدة الرحلة حسب المسافة + خطر (قد تضرب)
```

### 3. صيانة المعدات والمستشفى للأفراد
```gdscript
# src/Logistics/MaintenanceSystem.gd

# كل مركبة لها maintenance_level 0-100
# يقل مع الحركة والقتال
# عند 30%: سرعة -20%، احتمال تعطل 10%
# عند 0%: معطلة تماما، تحتاج ورشة

# ورشة ميدانية: تصلح 10% كل دقيقة لو ثابتة
# مستشفى ميداني: يعالج WOUNDED_LIGHT في 2 دقيقة، HEAVY في 5 دقائق

# src/Economy/Hospital.gd
func treat_soldier(soldier):
  if soldier.state == WOUNDED_LIGHT:
    await 120s -> HEALTHY
  elif WOUNDED_HEAVY:
    await 300s -> WOUNDED_LIGHT -> 120s -> HEALTHY
  elif INCAPACITATED:
    await 600s -> WOUNDED_HEAVY
```

---

## Phase 15: الانسحاب - جر المعدات المعطوبة أو تفجيرها

### 1. جر المعدات - Towing
```gdscript
# src/Logistics/TowingSystem.gd

func tow_vehicle(tower: Vehicle, towed: Vehicle):
  # الشروط:
  # - tower وزنها >= towed وزنها * 0.7
  # - towed معطلة (immobilized)
  # - المسافة < 10م
  # - وصلة جر (كابل يظهر جرافيكس)
  
  # النتيجة:
  # - سرعة tower -60%
  # - لا تستطيع القتال أثناء الجر
  # - تستهلك وقود x2
  # - تجرها للورشة أو خارج الخريطة (انسحاب ناجح)

  # Animation: كابل بين المركبتين، تراب يتحرك

func can_tow(tower, towed) -> bool:
  return tower.mass >= towed.mass * 0.7 and towed.immobilized and tower.operational
```

### 2. تفجير المعدات حتى لا تقع في الأسر - Scuttling
```gdscript
# src/Combat/ScuttleSystem.gd

func scuttle_vehicle(vehicle: Vehicle, by: Unit):
  # عندما لا يمكن جرها والعدو قريب (<100م)
  # الجندي يضع عبوة ناسفة
  # عد تنازلي 10 ثواني
  # انفجار يدمر المركبة تماما + حفرة كبيرة
  # لا يمكن للعدو الاستيلاء عليها
  
  # الشروط الأخلاقية: لو فيها جرحى، لا يمكن تفجيرها (لازم إخلاء أولا)

func on_enemy_approaching(damaged_vehicle):
  # AI يقرر تلقائيا:
  # if can_tow -> جر
  # elif enemy < 50m and tow impossible -> تفجير
  # elif enemy < 100m -> طلب QRF لحماية الجر
```

### 3. الوقوع في الأسر وتبادل الأسرى - POW System
```gdscript
# src/Economy/POWSystem.gd

enum POWState { FREE, CAPTURED, IN_CAMP, EXCHANGED }

class POW:
  var original_faction: int
  var captured_by: int
  var rank: String
  var capture_pos: Vector3
  var equipment_lost: Array # كل معداته تؤخذ
  var state: POWState

func capture_unit(unit: Unit, by: Unit):
  # يحدث عندما:
  # - وحدة محاصرة (لا إمداد 5 دقائق + عدو حولها)
  # - وحدة مصابة INCAPACITATED والعدو وصل لها قبل الإخلاء
  # - طاقم دبابة يهرب من دبابة معطوبة والعدو قريب
  
  # النتيجة:
  # - الوحدة تتحول لـ POW، لا تقاتل
  # - معداتها تؤخذ (تذهب لـ Economy للعدو كـ Materials)
  # - تنقل لمعسكر أسرى خلف خطوط العدو
  # - تظهر في قائمة POWs

func exchange_pows(faction_a_pows: Array, faction_b_pows: Array):
  # تبادل أسرى:
  # - كل أسير يعود لفصيله
  # - يعود بلا معدات (يحتاج إعادة تسليح من المخزن)
  # - معنويات +10 للفصيل عند عودة أسراه
  # - يحتاج 2 دقيقة في المستشفى قبل القتال

func rescue_pows(rescue_team: Array, camp_pos: Vector3):
  # عملية إنقاذ:
  # - قوة خاصة تهاجم معسكر الأسرى
  # - لو نجحت، الأسرى يتحررون ويعودون فورا
```

---

## خطة التنفيذ التقني لـ Manus / OpenHands

### الترتيب المقترح (6 أسابيع):

**الأسبوع 1: VFX Core**
- GPUParticles3D للغبار والدخان
- Decal للكراتر
- RecoilComponent + MuzzleFlash
- ScreenShake

**الأسبوع 2: Damage & Injury**
- ArmorDamageComponent (5 zones)
- SoldierInjury + CarryState
- تحديث ماتيريال للتلف

**الأسبوع 3: Guard & Patrol**
- GuardPost + PatrolSystem
- SecuredZone (دائرة خضراء)
- QRF Behavior Tree

**الأسبوع 4: Medevac & Maintenance**
- Ambulance + HelicopterMedevac
- MaintenanceSystem + Hospital
- Dust عند هبوط هليكوبتر

**الأسبوع 5: Towing & Scuttling**
- TowingSystem (كابل جر)
- ScuttleSystem (تفجير)
- تحديث Economy لفقدان معدات

**الأسبوع 6: POW System**
- POW capture logic
- POW Camp building
- Exchange + Rescue missions

### ملفات جديدة:
```
src/Combat/VFX/
  DustSystem.gd, ShellImpact.gd, CraterManager.gd, SmokeGrenade.gd, RecoilComponent.gd
src/Units/Components/
  ArmorDamage.gd, SoldierInjury.gd
src/Units/States/
  CarryState.gd, GuardState.gd, PatrolState.gd
src/AI/GuardDuty/
  PatrolSystem.gd, GuardPost.gd, SecuredZone.gd
src/Logistics/
  MaintenanceSystem.gd, TowingSystem.gd, MedevacSystem.gd
src/Economy/
  Hospital.gd, POWSystem.gd, POWCamp.gd
src/Combat/
  ScuttleSystem.gd
```

### Prompt لـ Manus:

```
نفذ Phase 11-15 للجرافيكس الواقعي في Theater of War:

1. VFX: غبار حركة، حفر قذائف، ارتداد مدفع، دخان انسحاب
2. Damage: تلف مدرعات (جنزير، محرك، برج)، إصابات جنود، حمل جريح
3. Guard: دوريات حراسة حول المنشآت، تأمين = حراسة مستمرة، QRF
4. Medevac: إسعاف + هليكوبتر إخلاء + مستشفى ميداني + صيانة
5. Towing: جر معطوب بدبابة أخرى أو تفجيره، نظام أسر وتبادل

استخدم:
- GPUParticles3D للغبار/الدخان
- Decal للكراتر
- AnimationTree للحمل والجر
- Tween للارتداد

الريبو: https://github.com/melsofany/Theater-of-War-
حافظ على 134 tests + أضف tests جديدة لكل phase.
```

---

## الخلاصة
الخطة دي تحول اللعبة من RTS تقليدي لمحاكاة مسرح حرب حقيقي:
- كل قذيفة لها أثر (حفرة + غبار + دخان)
- كل جندي له قيمة (إصابة، إخلاء، أسر، تبادل)
- كل معدات لها مصير (صيانة، جر، تفجير، غنيمة)
- كل مكان له تأمين (حراسة، دورية، QRF)

ده اللي يخلي السيطرة على المكان تعني تأمينه وحمايته فعلا.
