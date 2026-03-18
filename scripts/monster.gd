extends CharacterBody2D
class_name Monster

@export var tile_size: int = 64
@export var variants: int = 6
@export var family: String = "ghost"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider = $CollisionShape2D

func _ready():
	z_index = 10
	set_texture()
	set_random_variant()
	set_collidable()

func _physics_process(delta: float):
	# Let children define behavior
	pass	
	
func set_texture():
	var path = "res://sprites/monsters/%s.png" % family
	sprite.texture = load(path)

func set_random_variant():
	var tile_index = randi() % variants
	var x = tile_index * tile_size
	sprite.region_enabled = true
	sprite.region_rect = Rect2(x, 0, tile_size, tile_size)

func set_collidable():
		
	if !GameConfig.monsterdata.has(family):
		print("ERROR: unknown monster family:", family)
		return
		
#	print("FAMILY:", family, " BLOCKDATA:", GameConfig.blockdata)
	
	var data = GameConfig.monsterdata[family]	
	var collidable = data.get("collidable", true)
	
	# print(data)
	collider.disabled = !collidable
