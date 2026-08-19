extends Node
class_name MaintenanceSystem
var vehicles: Dictionary = {}
func register_vehicle(vehicle: Node):
    vehicles[vehicle.get_instance_id()] = {"vehicle": vehicle, "level": 100.0}
func update_maintenance(delta: float):
    for id in vehicles:
        var data = vehicles[id]
        var v = data.vehicle
        if not is_instance_valid(v): continue
        if v.is_moving:
            data.level -= delta * 0.05
        if data.level < 30.0:
            v.speed *= 0.8
        if data.level <= 0.0:
            v.immobilized = true