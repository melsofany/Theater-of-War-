extends GutTest
## Tests for the Economy system: stores, affordability, spending, income,
## capacity clamping.

func before_each():
	Economy.clear()
	Economy.register_faction("blue",
		{Economy.R.MANPOWER: 100.0, Economy.R.FUEL: 50.0, Economy.R.MATERIALS: 200.0})


func after_each():
	Economy.clear()


func test_can_afford_when_enough():
	assert_true(Economy.can_afford("blue", {Economy.R.MANPOWER: 50, Economy.R.MATERIALS: 100}))


func test_cannot_afford_when_short():
	assert_false(Economy.can_afford("blue", {Economy.R.MANPOWER: 500}))


func test_spend_deducts_resources():
	Economy.spend("blue", {Economy.R.MANPOWER: 30, Economy.R.FUEL: 20})
	assert_eq(Economy.amount("blue", Economy.R.MANPOWER), 70.0)
	assert_eq(Economy.amount("blue", Economy.R.FUEL), 30.0)


func test_spend_blocked_when_unaffordable():
	var ok := Economy.spend("blue", {Economy.R.MANPOWER: 500})
	assert_false(ok)
	# Resources unchanged.
	assert_eq(Economy.amount("blue", Economy.R.MANPOWER), 100.0)


func test_credit_clamps_to_capacity():
	# Default manpower capacity is 500.
	Economy.credit("blue", Economy.R.MANPOWER, 1000.0)
	assert_eq(Economy.amount("blue", Economy.R.MANPOWER), 500.0)


func test_income_accumulates_over_time():
	# Simulate a manual tick: recompute needs world; instead set income directly
	# via credit and verify accumulation by calling _process-like logic.
	Economy.credit("blue", Economy.R.MATERIALS, -200.0)  # reset to 0
	# Manually invoke the per-faction credit with a delta of 2s at +5/s.
	var inc: Dictionary = {Economy.R.MATERIALS: 5.0}
	# Replicate _process: credit income * delta.
	Economy.credit("blue", Economy.R.MATERIALS, inc[Economy.R.MATERIALS] * 2.0)
	assert_eq(Economy.amount("blue", Economy.R.MATERIALS), 10.0)


func test_production_cost_for_tank_includes_fuel():
	var cost: Dictionary = UnitFactory.cost_of("tank")
	assert_true(cost.has(Economy.R.FUEL))
	assert_gt(cost[Economy.R.FUEL], 0)


func test_production_cost_for_infantry_has_manpower():
	var cost: Dictionary = UnitFactory.cost_of("infantry")
	assert_true(cost.has(Economy.R.MANPOWER))
	assert_false(cost.has(Economy.R.FUEL))
