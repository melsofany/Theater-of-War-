extends Node
class_name POWSystem
enum POWState { CAPTURED, IN_CAMP, EXCHANGED, RESCUED }
var pows: Array = []
func capture_unit(unit: Node, by: Node):
    var pow_data = {"unit_id": unit.name, "original_faction": unit.faction, "captured_by": by.faction, "pos": unit.global_position, "state": POWState.CAPTURED}
    pows.append(pow_data)
    var economy = get_node_or_null("/root/World/Economy")
    if economy:
        economy.add_materials(by.faction, 10)
    unit.queue_free()
func exchange_pows(a_pows: Array, b_pows: Array):
    for pow_data in a_pows + b_pows:
        pows.erase(pow_data)