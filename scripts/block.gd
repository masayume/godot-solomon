extends StaticBody2D

@export var tile_size: int = 64
@export var variants: int = 6

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	var tile_index = randi() % variants

	var atlas := AtlasTexture.new()
	atlas.atlas = sprite.texture
	atlas.region = Rect2(
		tile_index * tile_size,
		0,
		tile_size,
		tile_size
	)

	sprite.texture = atlas
