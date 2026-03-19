extends CharacterBody2D
class_name Monster

@export var tile_size: int = 64
@export var variants: int = 6
# @export var family: String = "ghost"
@export var family: String

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider = $CollisionShape2D

var stats = {}

func _ready():
	z_index = 20
	set_texture()
	set_random_variant()
	set_collidable()

	if not GameConfig.monsterdata.has(family):
		print("Unknown monster family:", family)
		return

	stats = GameConfig.monsterdata[family]

	apply_stats()

func apply_stats():

	# --- common Sprite setup ---
	if stats.has("sprite"):
		$Sprite2D.texture = load(stats["sprite"])
		print(stats)

	sprite.hframes = GameConfig.monsterdata[family].hframes
	sprite.vframes = 1

	set_texture()

		
func _physics_process(delta: float):
	# Let children define behavior
	pass	
	
func set_texture():
	var path = "res://sprites/monsters/%s.png" % family
	sprite.texture = load(path)
	# 🔥 FORCE RESET EVERYTHING RELATED TO REGION/SLICING
	sprite.region_enabled = false
	sprite.region_rect = Rect2(0, 0, 0, 0)
	
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
