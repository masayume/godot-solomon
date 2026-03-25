extends StaticBody2D

@export var tile_size: int = 64
@export var variants: int = 6
@export var family: String = "earth"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider = $CollisionShape2D

var frames = []
var anim_speed = 0.1
var frame_index = 0
var time_accumulator = 0.0

func _ready():
	z_index = 0
	set_texture()
	set_random_variant()
	set_collidable()
	setup_animation()
	
func set_texture():
	var path = "res://sprites/blocks/%s.png" % family
	sprite.texture = load(path)

func set_random_variant():
	# 1. Check if we have animation frames first
	# If we have frames, we skip the 'variant' region logic [cite: 19, 20]
	if frames.size() > 1:
		sprite.region_enabled = false
		return

	# 2. Otherwise, treat as a standard static block with variants 
	var tile_index = randi() % variants
	var x = tile_index * tile_size
	sprite.region_enabled = true
	sprite.region_rect = Rect2(x, 0, tile_size, tile_size)
		
func set_random_variant_old():
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
	
func _process(delta):
	if frames.size() > 1:
		animate(delta)
			
func setup_animation():
	if GameConfig.blockdata.has(family):
		var data = GameConfig.blockdata[family]
		if data.has("frames"):
			frames = data.frames
			anim_speed = data.get("anim_speed", 0.1)
			
			# 3. CRITICAL: Set sprite properties for runtime sheets
			sprite.region_enabled = false  # Disable region to use frames 
			sprite.hframes = frames.size() # Tell Godot there are 8 columns 
			sprite.vframes = 1             # Ensure it's a single row
			
			frame_index = 0
			sprite.frame = frames[0]

func animate(delta):
	time_accumulator += delta

	if time_accumulator >= anim_speed:
		time_accumulator -= anim_speed

		frame_index += 1
		if frame_index >= frames.size():
			frame_index = 0

		sprite.frame = frames[frame_index]	
