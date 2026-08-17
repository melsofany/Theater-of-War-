extends Control
## Minimap
##
## Top-down strategic overlay. Draws a bordered rectangle representing the world
## bounds and a colored dot for each unit (blue = player, red = enemy), plus a
## camera frustum indicator. Reads world + camera references set by Main.

class_name Minimap

@export var world: World
@export var camera: Camera3D
@export var bg_color: Color = Color(0.05, 0.07, 0.1, 0.85)
@export var border_color: Color = Color(0.4, 0.5, 0.6, 0.9)
@export var player_color: Color = Color(0.3, 0.6, 1.0)
@export var enemy_color: Color = Color(1.0, 0.3, 0.3)
@export var camera_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var world_bounds: Rect2 = Rect2(-100, -100, 200, 200)
@export var dot_radius: float = 2.5
var map_texture: Texture2D
@export var map_texture_opacity: float = 0.78
const META_TACTICAL_MAP_PATH := "res://assets/maps/meta_package/theater_of_war_tactical_map.webp"


func _ready() -> void:
	var image := Image.load_from_file(META_TACTICAL_MAP_PATH)
	if image and not image.is_empty():
		map_texture = ImageTexture.create_from_image(image)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, bg_color, true)
	if map_texture:
		draw_texture_rect(map_texture, r, false, Color(1.0, 1.0, 1.0, map_texture_opacity))
	draw_rect(r, border_color, false, 1.5)
	if not world:
		return
	# World bounds -> minimap mapping. World x maps to minimap x, world z to minimap y.
	var s := Vector2(size.x / world_bounds.size.x, size.y / world_bounds.size.y)
	for u in world.get_units():
		if not is_instance_valid(u) or u.faction == null:
			continue
		var wp := Vector2(u.global_position.x, u.global_position.z)
		var mp := Vector2(
			(wp.x - world_bounds.position.x) * s.x,
			(wp.y - world_bounds.position.y) * s.y
		)
		var c := enemy_color if not u.faction.is_player else player_color
		draw_circle(mp, dot_radius, c)
	# Camera indicator: project a few world points back to the minimap.
	if camera:
		var cy := camera.global_position
		var corners := PackedVector2Array()
		for off in [Vector2(-15, -10), Vector2(15, -10), Vector2(15, 10), Vector2(-15, 10)]:
			var wp := Vector2(cy.x + off.x, cy.z + off.y)
			corners.append(Vector2(
				(wp.x - world_bounds.position.x) * s.x,
				(wp.y - world_bounds.position.y) * s.y
			))
		if corners.size() >= 2:
			draw_polyline(corners + PackedVector2Array([corners[0]]), camera_color, 1.0, true)


func _process(_delta: float) -> void:
	queue_redraw()
