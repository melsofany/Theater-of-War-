extends SceneTree

func _initialize() -> void:
	var map_data := TerrainGenerator.new(1337).generate()
	print("UNIFIED_MAP_CITIES=%d" % map_data.cities.size())
	print("UNIFIED_MAP_ZONES=%d" % map_data.zones.size())
	print("UNIFIED_MAP_ROADS=%d" % map_data.roads.size())
	if map_data.cities.size() != 13 or map_data.zones.size() != 6 or map_data.roads.size() != 14:
		print("UNIFIED_MAP_STATUS=FAIL")
		quit(1)
		return
	print("UNIFIED_MAP_STATUS=OK")
	quit(0)
