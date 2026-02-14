extends StaticBody2D

@export var tile_size: int = 32
@export var variants: int = 6   # number of block images

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	randomize()
	var tile_index = randi() % variants

	var x = tile_index * tile_size
	sprite.region_enabled = true
	sprite.region_rect = Rect2(x, 0, tile_size, tile_size)
