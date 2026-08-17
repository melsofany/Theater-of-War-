extends Node
class_name BuildingComponent
@export var floors:int=10
@export var enterable:bool=true
@export var cover:float=0.5
var health:float=100.0
func take_damage(a:float): health-=a
func can_unit_enter(t:String)->bool: return t=="infantry"
