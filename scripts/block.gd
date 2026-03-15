extends StaticBody2D

@export var tile_size: int = 64
@export var variants: int = 6
@export var family: String = "earth"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider = $CollisionShape2D

func _ready():
	z_index = 0
	set_texture()
	set_random_variant()
	set_collidable()
	
func set_texture():
	var path = "res://sprites/blocks/%s.png" % family
	sprite.texture = load(path)

func set_random_variant():
	var tile_index = randi() % variants
	var x = tile_index * tile_size
	sprite.region_enabled = true
	sprite.region_rect = Rect2(x, 0, tile_size, tile_size)

func set_collidable():
	
	if !GameConfig.blockdata.has(family):
		print("ERROR: unknown block family: ", family)
		return
		
#	print("FAMILY:", family, " BLOCKDATA:", GameConfig.blockdata)
	
	var data = GameConfig.blockdata[family]	
	var collidable = data.get("collidable", true)
	
	# print(data)
	collider.disabled = !collidable
