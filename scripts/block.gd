extends StaticBody2D

@export var tile_size: int = 64
@export var variants: int = 6
@export var family: String = "earth"

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	set_texture()
	set_random_variant()

func set_texture():
	var path = "res://sprites/blocks/%s.png" % family
	sprite.texture = load(path)

func set_random_variant():
	var tile_index = randi() % variants
	var x = tile_index * tile_size
	sprite.region_enabled = true
	sprite.region_rect = Rect2(x, 0, tile_size, tile_size)
