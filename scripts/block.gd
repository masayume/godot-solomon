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

var is_spawning = true

func _ready():
	z_index = 10
	set_texture()
	set_random_variant()
	set_collidable()
	setup_animation()
	
	if family == "demonshield":
		_block_monster_spawner("demonhead")

func set_texture():
	var path = GameConfig.blockdata[family].get("sprite")
	sprite.texture = load(path)

func set_random_variant():
	# 1. Check if we have animation frames first
	# If we have frames, we skip the 'variant' region logic [cite: 19, 20]
	if frames.size() > 1:
		sprite.region_enabled = false
		return
	else:
	# 2. Otherwise, treat as a standard static block with variants 
		var tile_index
		if GameConfig.blockdata[family].get("variants") == 0:
			tile_index = variants
		else:
			tile_index = randi() % variants
		
		if family == "demonshield":
			print("demonshield tile_index: ", tile_index, " ", GameConfig.blockdata[family].get("variants"))
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

func _block_monster_spawner(monster):
	# 1. Get configuration from GameConfig (with safety fallback)
	var config = GameConfig.blockdata.get("demonshield", {})
	var spawn_rate = config.get("spawn_rate", 10.0)
	var monster_type = config.get("monster_type", monster)
	
	# 2. Get reference to level_loader
	var loader = get_tree().get_first_node_in_group("level_loader")
		
	# 3. Start the spawning loop
	while is_spawning and is_inside_tree():

		# Wait for the configured time
		await get_tree().create_timer(spawn_rate).timeout

		_spawn_monster_from_block(monster_type, loader)
		
		if not is_spawning or not is_inside_tree():
			break
		

func _spawn_monster_from_block(monster_type: String, loader):

	# 1. Get the monster scene (adapt this to match how your loader stores scenes)
	var monster_scene = null
	if loader and loader.scenes["demonhead"]:
		monster_scene = loader.scenes["demonhead"]

	if not monster_scene:
		push_error("Block: Could not find monster scene for '%s'" % monster_type)
		return

	# 2. Instantiate the monster
	var new_monster = monster_scene.instantiate()
	new_monster.add_to_group("monstergroup")
	
	# 3. CRITICAL: Set the family so monster.gd's _ready() applies stats correctly
	new_monster.family = monster_type
	
	# 4. Set position to the shield's position (slightly elevated so it doesn't clip the floor)
	new_monster.global_position = global_position + Vector2(0, -32)
	
	# 5. Add to the scene tree. 
	# We add it to the block's parent (the level container), NOT as a child of the block.
	# This keeps the scene hierarchy clean and prevents physics issues.
	get_parent().add_child.call_deferred(new_monster)
	
	print("Demonshield spawned a ", monster_type, " at ", new_monster.global_position)

# --- NEW: Cleanup ---
func _exit_tree():
	# This is automatically called when the block is queue_free()'d or the level changes.
	# It safely breaks the 'while' loop in _start_demonshield_spawner.
	is_spawning = false
