extends GutTest
## Tests for Unit combat: damage with armor, death, healing.

const UnitScenePath := "res://src/Units/Unit.tscn"

var _attacker: Unit
var _target: Unit
var _died_count: int = 0


func before_each():
	_died_count = 0
	_attacker = load(UnitScenePath).instantiate()
	_target = load(UnitScenePath).instantiate()
	add_child(_attacker)
	add_child(_target)
	_attacker.unit_type = UnitFactory.get_type("tank")
	_target.unit_type = UnitFactory.get_type("infantry")
	_apply(_attacker)
	_apply(_target)
	_target.died.connect(Callable(self, "_on_target_died"))


func _on_target_died(_u: Unit) -> void:
	_died_count += 1


func _apply(u: Unit) -> void:
	u.max_health = u.unit_type.max_health
	u.health = u.max_health
	u.armor = u.unit_type.armor
	u.max_speed = u.unit_type.max_speed
	u.radius = u.unit_type.radius


func after_each():
	if is_instance_valid(_attacker):
		_attacker.queue_free()
	if is_instance_valid(_target):
		_target.queue_free()


func test_take_damage_respects_armor():
	# Infantry armor = 1, tank damage = 35 -> 34 damage.
	var hp_before := _target.health
	_target.take_damage(35.0)
	assert_eq(_target.health, hp_before - 34.0)


func test_min_one_damage_always_applies():
	# Heavy armor vs tiny damage still does 1.
	_target.unit_type = UnitFactory.get_type("tank")
	_apply(_target)
	_target.take_damage(2.0)
	assert_eq(_target.health, _target.max_health - 1.0)


func test_unit_dies_at_zero_health():
	# Tank does 35, infantry has 80 hp / 1 armor -> 34 per hit.
	for i in 3:
		_target.take_damage(35.0)
	assert_false(_target.alive)
	assert_eq(_died_count, 1)


func test_dead_unit_takes_no_more_damage():
	# Kill it.
	for i in 10:
		_target.take_damage(35.0)
	var hp := _target.health
	_target.take_damage(100.0)
	assert_eq(_target.health, hp)


func test_heal_clamps_to_max():
	_target.take_damage(20.0)
	_target.heal(1000.0)
	assert_eq(_target.health, _target.max_health)


func test_attacker_acquires_target_in_range():
	_attacker.global_position = Vector3(0, 0, 0)
	_target.global_position = Vector3(10, 0, 0)
	# Tank range = 24.
	assert_true(_attacker._in_range(_target))
	_target.global_position = Vector3(100, 0, 0)
	assert_false(_attacker._in_range(_target))
