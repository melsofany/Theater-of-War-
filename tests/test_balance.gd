extends GutTest
## Balance regression tests (10c+).
##
## Deterministic duel harness: two units in range with full supply/fuel/health
## trade fire with cooldowns advanced manually (no nav/physics/randomness), so
## the outcome depends only on UnitType stats + Balance scaling. These guard
## against accidental balance drift — e.g. a tank should still beat an infantry
## 1v1, and a mirror match should be close, not lopsided.

const UnitScenePath := "res://src/Units/Unit.tscn"


func _make_duel_unit(type_key: String, pos: Vector3) -> Unit:
	var u: Unit = load(UnitScenePath).instantiate()
	u.unit_type = UnitFactory.get_type(type_key)
	u.global_position = pos
	add_child(u)
	# Apply type-derived stats the way the scene's _ready would, then top off
	# resources so readiness is ~1.0 and supply never blocks firing.
	u.max_health = u.unit_type.max_health
	u.health = u.max_health
	u.armor = u.unit_type.armor
	u.max_speed = u.unit_type.max_speed
	u.radius = u.unit_type.radius
	u.fuel = u.max_fuel
	u.supply = u.max_supply
	# Give effectively-unlimited ammo so the duel isolates stat balance from
	# supply depletion (a mirror infantry fight would otherwise run dry).
	u.max_supply = 100000.0
	u.supply = 100000.0
	u.max_fuel = 100000.0
	u.fuel = 100000.0
	return u


## Run a mutual-fire duel until one side dies or a round cap is hit. Cooldowns
## are advanced by the slower unit's cooldown each round so both get to fire.
## Returns { "winner": Unit, "loser": Unit, "rounds": int }.
func _run_duel(a: Unit, b: Unit, max_rounds: int = 200) -> Dictionary:
	# Place them in range of each other (use the larger range).
	a.global_position = Vector3(0, 0, 0)
	b.global_position = Vector3(minf(a.unit_type.range, b.unit_type.range) * 0.5, 0, 0)
	var rounds := 0
	while a.alive and b.alive and rounds < max_rounds:
		if a._cooldown <= 0.0 and a.alive:
			a._fire(b)
			a._cooldown = a.unit_type.attack_cooldown
		if b.alive and b._cooldown <= 0.0:
			b._fire(a)
			b._cooldown = b.unit_type.attack_cooldown
		# Advance time by the smaller cooldown so the faster unit fires again sooner.
		var step: float = minf(a.unit_type.attack_cooldown, b.unit_type.attack_cooldown)
		a._cooldown = maxf(a._cooldown - step, 0.0)
		b._cooldown = maxf(b._cooldown - step, 0.0)
		rounds += 1
	var winner: Unit = a if a.alive else b
	var loser: Unit = b if a.alive else a
	return {"winner": winner, "loser": loser, "rounds": rounds}


func after_each():
	for c in get_children():
		c.queue_free()


func test_tank_beats_infantry_one_on_one():
	var tank := _make_duel_unit("tank", Vector3(0, 0, 0))
	var inf := _make_duel_unit("infantry", Vector3(10, 0, 0))
	var r := _run_duel(tank, inf)
	assert_eq(r["winner"], tank)
	assert_eq(r["loser"], inf)
	# Tank (300hp/12armor vs inf 8dmg) should win comfortably but not instantly.
	assert_true(r["rounds"] >= 2)
	assert_true(r["rounds"] <= 40)


func test_mirror_match_is_close_not_lopsided():
	# Two identical infantry trade fire in lockstep. A symmetric duel may end
	# with both dead (honest) — the balance property we guard is that it is NOT
	# lopsided: it takes several exchanges (not a one-shot) and any survivor is
	# badly damaged, not at full health.
	var a := _make_duel_unit("infantry", Vector3(0, 0, 0))
	var b := _make_duel_unit("infantry", Vector3(10, 0, 0))
	var r := _run_duel(a, b)
	# Several exchanges, not a single one-shot kill.
	assert_true(r["rounds"] >= 3)
	# Not lopsided: at most one survives, and if one survives it is damaged.
	var survivors: int = int(a.alive) + int(b.alive)
	assert_true(survivors <= 1)
	if a.alive:
		assert_true(a.health < a.max_health * 0.5)
	if b.alive:
		assert_true(b.health < b.max_health * 0.5)


func test_artillery_outranges_and_beats_infantry():
	var art := _make_duel_unit("artillery", Vector3(0, 0, 0))
	var inf := _make_duel_unit("infantry", Vector3(10, 0, 0))
	# Artillery range (55) > infantry range (18); the duel places them at the
	# shared in-range distance, so artillery's higher damage should win.
	var r := _run_duel(art, inf)
	assert_eq(r["winner"], art)
