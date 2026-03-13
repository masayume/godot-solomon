extends Node

#@export var x_off: float
#@export var y_off: float
#@export var tile_size: int = 64

static func world_to_grid(world_pos: Vector2, x_off: float, y_off: float, tile_size: int) -> Vector2i:

	var local_x = world_pos.x - x_off
	var local_y = world_pos.y + y_off

	var grid_x = floor((local_x - tile_size/2) / tile_size)
	var grid_y = -(floor(local_y / tile_size))

	return Vector2i(grid_x, grid_y)
