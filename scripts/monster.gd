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
	add_to_group("monstergroup")
	
	set_collision_layer_value(4, true)  # Monster Layer (Box 4)
	set_collision_mask_value(1, true)   # Only see Walls (Box 1)
		
	set_texture()
	set_random_variant()
	set_collidable()

	if not GameConfig.monsterdata.has(family):
		push_error("CONFIG ERROR: Monster family '%s' not found in GameConfig!" % family)
		return

	stats = GameConfig.monsterdata[family]

	_ensure_receiver_setup()
	_force_hitbox_setup()
	apply_stats()


func _force_hitbox_setup():
	# If HitBox is missing from the .tscn (common in inherited scenes), CREATE IT
	var hb = get_node_or_null("HitBox")
	if not hb:
		print("[DEBUG] HitBox missing in scene tree for ", name, ". Creating one programmatically.")
		hb = Area2D.new()
		hb.name = "HitBox"
		add_child(hb)
		
		# We need a shape for the new Area2D
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 20.0 # Default hazard size
		shape.shape = circle
		hb.add_child(shape)

	# Setup detection layers
	hb.collision_layer = 0
	hb.collision_mask = 0
	hb.set_collision_layer_value(4, true) # Is a Monster
	hb.set_collision_mask_value(2, true)  # LOOKS FOR PLAYER (Layer 2)
	
	hb.set_deferred("monitoring", true)
	hb.set_deferred("monitorable", true)
	
	# Connect signal
	if not hb.body_entered.is_connected(_on_hitbox_entered):
		hb.body_entered.connect(_on_hitbox_entered)
		print("[SUCCESS] Hitbox connected for ", name)

func _ensure_receiver_setup():
	var receiver = get_node_or_null("Receiver")
	if not receiver:
		receiver = Receiver.new()
		receiver.name = "Receiver"
		add_child(receiver)
		print("[DEBUG] Created missing Receiver node for ", name)
	
	receiver.data = {
		"action_type": "hazard",
		"family": family
	}


func _setup_hitbox():
	# The HitBox is the Area2D node defined in Monster.tscn
	var hb = get_node_or_null("HitBox")
	if not hb:
		push_warning("NODE ERROR: Monster '%s' is missing a 'HitBox' Area2D!" % name)
		return
		
	hb.collision_layer = 0
	hb.collision_mask = 0
		
	# Hitbox is a 'Monster' (Layer 4)
	hb.set_collision_layer_value(4, true)
	# Hitbox MUST look for 'Player' (Layer 2)
	hb.set_collision_mask_value(2, true)

	hb.set_deferred("monitoring", true)
	hb.set_deferred("monitorable", true)
		
	# Connect to body_entered because the Player is a CharacterBody2D
	if not hb.body_entered.is_connected(_on_hitbox_entered):
		hb.body_entered.connect(_on_hitbox_entered)

# this looks for a body (the Player) - Can't see a fireball
func _on_hitbox_entered(body: Node2D):
	# If the thing entering the Area is the Player
	if body.has_method("trigger_death_from_monster"):
		var receiver = get_node_or_null("Receiver")
		if receiver:
			# Pass the interaction to the receiver
			receiver.receive("monster_hit", body)
		else:
			# Fallback if receiver failed
			body.trigger_death_from_monster()

# this is called by fireball.gd _on_area_entered(area)
func take_damage():
	# Trigger any death animations or sounds here
	print("Monster hit by fireball!")
	
	# If you have a global FX system like for items:
	# GameConfig.spawn_fx("explosion", global_position)
	
	var loader = get_parent()
	if not loader or not loader.has_method("add_item"):
		queue_free.call_deferred()
		return
			
	print("monster:BOOM must spawn an item.")

	# 1. FETCH RANDOM TREASURE TYPE
	# Default to "bag200" if the 'treasures' attribute doesn't exist or is empty
	var item_type: String = "bag200"
	var treasures_list = stats.get("treasures", [])
	if treasures_list is Array and treasures_list.size() > 0:
		item_type = treasures_list.pick_random()

	# 2. Fetch layout calibration data directly from your level loader parameters
	# 	 Capture positions and variables BEFORE the monster node is freed
	var death_pos = global_position	# (Adjust variable names if your level_loader uses different terms like offset_x or map_offset)
	var x_off = loader.get("x_off") if loader.get("x_off") != null else 0.0
	var y_off = loader.get("y_off") if loader.get("y_off") != null else 0.0
	var current_tile_size = loader.get("tile_size") if loader.get("tile_size") != null else 64
	var grid_pos: Vector2i = loader.Grid.world_to_grid(global_position, x_off, y_off, current_tile_size)

	# 3. Spawn item securely outside the physics thread
	loader.add_item.call_deferred(grid_pos.x, grid_pos.y, item_type, true, false)

	# 4. FIX: Create a Tween controller on the LOADER node so it survives the monster's death
	var controller_tween = loader.create_tween()		

	# Wait exactly 1 frame (a tiny interval) for call_deferred to finish spawning the item
	controller_tween.tween_interval(0.01)
	
	# Run the search and physics calculations safely on the loader's life-thread
	controller_tween.tween_callback(func():
		var spawned_item: Node2D = null
		# Look through loader children for our newly added item [cite: 1]
		for child in loader.get_children():
			if child.is_in_group("itemgroup") and child.visible:
				# Track the item matching our immediate explosion area
				if child.global_position.distance_to(death_pos) < 96.0:
					spawned_item = child
					break
					
		if spawned_item and is_instance_valid(spawned_item):
			# 🔥 OVERRIDE USUAL BEHAVIOR: Shut down any default grid-lock or tracking scripts
			spawned_item.set_process(false)
			spawned_item.set_physics_process(false)
			
			# Force start the treasure item exactly at the center of the fireball impact
			spawned_item.global_position = death_pos
			
			# Setup classic arcade trajectory parameters
			var velocity = Vector2(
				randf_range(-150.0, 150.0), # Left/Right explosion blast scattering
				randf_range(-400.0, -500.0) # Upward vertical thrust force
			)
			var gravity: float = 1300.0
			
			# Calculate the exact ground baseline target (the native layout destination grid line)
			var ground_y: float = GameConfig.grid_to_local(grid_pos.x, grid_pos.y, current_tile_size, x_off, y_off).y
			
			# Launch a frame-by-frame processing tween to manually translate coordinates
			var physics_tween = loader.create_tween()
			physics_tween.tween_method(func(elapsed):
				if is_instance_valid(spawned_item):
					var dt = 0.016 # Approximated delta time step
					
					# Standard physics calculation equations
					velocity.y += gravity * dt
					spawned_item.global_position += velocity * dt
					
					# Land check: stop calculating once it touches or falls past floor height
					if velocity.y > 0 and spawned_item.global_position.y >= ground_y:
						spawned_item.global_position.y = ground_y
						
						# RESTORE USUAL BEHAVIOR: turn tracking and detection mechanics back on
						spawned_item.set_process(true)
						spawned_item.set_physics_process(true)
						physics_tween.kill() # Terminate processing loop safely
			, 0.0, 1.0, 2.0)
	)

	# 5. Play death graphic
#	if loader and loader.has_method("spawn_fx"):
#		loader.spawn_fx("poof", global_position, Vector2i(-1, -1), false)

	# 6. Destroy monster
	queue_free.call_deferred()



func _apply_pop_physics(grid_pos: Vector2i, item_type: String):
	var loader = get_parent()
	if not loader: return
	
	# 1. Wait 1 frame so call_deferred has finished adding the item to the tree
	await get_tree().process_frame
	
	# 2. Look for the newly spawned item
	var spawned_item: Node2D = null
	for child in loader.get_children():
		# Match visible items close to the monster's death global coordinates
		if child.is_in_group("items") and child.visible:
			if child.global_position.distance_to(global_position) < 96.0:
				spawned_item = child
				break
				
	if spawned_item == null:
		return # Item wasn't found or already handled

	# 3. Arcade Physics Parameters
	# Start with an explosive push: up and slightly randomized left/right
	var velocity = Vector2(
		randf_range(-150.0, 150.0), 
		randf_range(-300.0, -420.0) 
	)
	var gravity: float = 1200.0
	
	# Capture the starting altitude so it knows exactly where the ground layer floor is
	var ground_y: float = spawned_item.global_position.y

	# 4. Use a frame processing loop to manually update position safely over time
	# This bypasses any engine level lockouts on standard properties
	var tween = create_tween()
	tween.tween_method(
		func(elapsed_time: float):
			# Ensure the item hasn't been collected or deleted during the animation arc
			if is_instance_valid(spawned_item):
				# Fetch delta approximation per call iteration
				var frame_delta = 0.016 
				
				# Physics integration step
				velocity.y += gravity * frame_delta
				spawned_item.global_position += velocity * frame_delta
				
				# Land check: Stop falling once it lands back at floor height
				if velocity.y > 0 and spawned_item.global_position.y >= ground_y:
					spawned_item.global_position.y = ground_y
					tween.kill() # Terminate physical calculations immediately upon landing
	, 
	0.0, 1.0, 1.5 # Run safely for up to 1.5 seconds maximum if it somehow misses the floor
	)

func apply_stats():

	# --- common Sprite setup ---
	if stats.has("sprite"):
		$Sprite2D.texture = load(stats["sprite"])
#		print(stats)

	sprite.hframes = stats.get("hframes", 1)
	sprite.vframes = 1
	sprite.region_enabled = false
	
#	sprite.hframes = GameConfig.monsterdata[family].hframes
#	sprite.vframes = 1

	set_texture()


		
func _physics_process(_delta: float):
	# Let children define behavior
	pass	
	
func set_texture():
#	var path = "res://sprites/monsters/%s.png" % family
	var path = GameConfig.monsterdata[family].sprite
	sprite.texture = load(path)
	# 🔥 FORCE RESET EVERYTHING RELATED TO REGION/SLICING
	sprite.region_enabled = false
	sprite.region_rect = Rect2(0, 0, 0, 0)
	
func set_random_variant():
	var tile_index = randi() % variants
	var x = tile_index * tile_size
	sprite.region_enabled = true
	sprite.region_rect = Rect2(x, 0, tile_size, tile_size)

func _on_body_entered(body):
	# We use the Interactor node already attached to the Player
	# instead of creating a new one with .new() every time.
	if $Interactor: 
		$Interactor.interact(body)
		
func set_collidable():
		
	if !GameConfig.monsterdata.has(family):
		print("ERROR: unknown monster family:", family)
		return
		
#	print("FAMILY:", family, " BLOCKDATA:", GameConfig.blockdata)
	
	var data = GameConfig.monsterdata[family]	
	var collidable = data.get("collidable", true)
	
	# print(data)
	collider.disabled = !collidable
