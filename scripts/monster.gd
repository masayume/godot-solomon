extends CharacterBody2D
class_name Monster

@export var tile_size: int = 64
@export var variants: int = 6
# @export var family: String = "ghost"
@export var family: String

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider = $CollisionShape2D

var stats = {}

# ==========================================
# --- ANIMATION STATE MACHINE VARIABLES ---
# ==========================================
var current_state: String = ""
var frames: Array = []
var anim_speed: float = 0.1
var frame_index: int = 0
var time_accumulator: float = 0.0
signal state_animation_finished(state_name)

func _ready():
	z_index = 20
	add_to_group("monstergroup")
	
	set_collision_layer_value(4, true)  # Monster Layer (Box 4)
	set_collision_mask_value(1, true)   # Only see Walls (Box 1)

	set_collidable()

	if not GameConfig.monsterdata.has(family):
		push_error("CONFIG ERROR: Monster family '%s' not found in GameConfig!" % family)
		return

	stats = GameConfig.monsterdata[family]

	change_state(family)

	_ensure_receiver_setup()
	_force_hitbox_setup()

	# --- NEW: Start the lifetime countdown in the background ---
	_manage_lifetime()

func _process(delta):
	# The parent class now handles animation ticking for ALL monsters
	animate(delta)

# ==========================================
# --- ANIMATION STATE MACHINE LOGIC ---
# ==========================================
func change_state(new_state: String):
	if current_state == new_state:
		return
		
	if not GameConfig.monsterdata.has(new_state):
		push_error("CONFIG ERROR: State '%s' not found in GameConfig.monsterdata!" % new_state)
		return
		
	current_state = new_state
	var data = GameConfig.monsterdata[current_state] 
	
	# 1. Load Texture safely and check for failures
	if data.has("sprite"):
		var new_texture = load(data.sprite)
		if new_texture == null:
			push_error("FAILED TO LOAD SPRITE: '%s' for monster '%s'. Check the path and capitalization in monster.cfg!" % [data.sprite, family])
		else:
			sprite.texture = new_texture

	# 2. Setup Frames
	if data.has("hframes"):
		sprite.hframes = data.hframes
	else:
		sprite.hframes = 1

	# FORCE disable region to prevent old slicing code from hiding the sprite
	sprite.region_enabled = false
	sprite.region_rect = Rect2(0, 0, 0, 0)

	# Ensure frames is actually an Array (ConfigFile can sometimes be tricky)
	# Safely pull frames and speed, providing fallbacks if missing in config
	var raw_frames = data.get("frames", [0])
	if typeof(raw_frames) != TYPE_ARRAY:
		push_error("CONFIG ERROR: 'frames' must be an Array (e.g., [0,1,2]) in state '%s'" % new_state)
		frames = [0]
	else:
		frames = raw_frames

	anim_speed = data.get("anim_speed", 0.1) 

	# Reset animation tracking
	frame_index = 0
	time_accumulator = 0.0

	if frames.size() > 0:
		sprite.frame = frames[0]
	else:
		push_error("CONFIG ERROR: 'frames' array is empty in state '%s'!" % new_state)
		sprite.frame = 0

#DEBUG
	# Success message to confirm it worked
#	print("✅ DEBUG: Successfully changed %s to state '%s'. Texture: %s" % [family, current_state, sprite.texture.resource_path if sprite.texture else "NULL"])
			
func animate(delta):
	# If there's only one frame, just ensure it's set and exit
	if frames.size() <= 1:
		if frames.size() == 1:
			sprite.frame = frames[0]
		return	

	time_accumulator += delta

	if time_accumulator >= anim_speed:
		time_accumulator -= anim_speed

		# Check if we are at the last frame
		if frame_index >= frames.size() - 1:
			# Emit signal for any state finishing its last frame
			state_animation_finished.emit(current_state)
			
			var data = GameConfig.monsterdata[current_state]
			
			# Manage loop=false animations
			if data.get("loop", true) == false:
				# If it's a temporary state (like shooting), automatically return to the default state (family)
				if current_state != family:
					change_state(family)
				return
				
			frame_index = 0
		else:
			frame_index += 1
		
		sprite.frame = frames[frame_index]


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
	print("monster:BOOM must spawn an item.")

	var loader = get_parent()

	if loader:
		# 1. pick the random treasure
		var item_type: String = "bag200"
		var treasures_list = stats.get("treasures", [])
		if treasures_list is Array and treasures_list.size() > 0:
			item_type = treasures_list.pick_random()

		# 2. instantiate the item
		if loader.get("item_scene"):
			var dropped_item = loader.item_scene.instantiate()
			dropped_item.family = item_type
			dropped_item.global_position = global_position
			
			# 3. Trigger the physical pop!
			dropped_item.pop()
			
			# 4. Add safely to the level
			loader.add_child.call_deferred(dropped_item)

		# 5. Boom
		if loader.has_method("spawn_fx"):
			loader.spawn_fx("boom", global_position, Vector2i(-1, -1), false)

	# 6. Destroy monster
	queue_free.call_deferred()


func _physics_process(_delta: float):
	# Let children define behavior
	pass	
	

func _manage_lifetime():
	# 1. Check if this monster has a lifetime defined in GameConfig
	if not stats.has("lifetime"):
		return

	var lifetime = stats.lifetime
	# Use .get() with a fallback of 3.0 seconds in case fade_duration is missing from config
	var fade_duration = stats.get("fade_duration", 3.0)
				
	# Wait for the monster's full lifetime
	await get_tree().create_timer(lifetime).timeout
	
	# Safety check: ensure the monster hasn't already been destroyed (e.g., by a fireball)
	if not is_inside_tree():
		return

	# 2. Immediately disable the hitbox so the player can no longer be hurt by it
	print("demonhead disabled hitbox")
	var hb = get_node_or_null("HitBox")
	if hb:
		hb.monitoring = false
		hb.monitorable = false
		hb.set_collision_layer_value(4, false) # Remove from Monster layer
		hb.set_collision_mask_value(2, false)  # Stop looking for Player

	# 3. Start the disappearance tween (fade out over 3 seconds)
	var tween = create_tween()
	
	# 3a. Main Node Fade: Slowly reduce alpha to 0 over fade_duration seconds
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_IN_OUT)	

	# 3b. Blink Effect: Create a separate tween for the color pulse
	var blink_tween = create_tween()
	blink_tween.set_loops(6) # Repeat the blink 6 times
	
	# Blink to "invisible" (black/transparent)
	blink_tween.tween_property(self, "modulate:r", 0.0, 0.1)
	blink_tween.tween_property(self, "modulate:g", 0.0, 0.1)
	blink_tween.tween_property(self, "modulate:b", 0.0, 0.1)
	
	# Blink back to White
	blink_tween.tween_property(self, "modulate:r", 1.0, 0.1)
	blink_tween.tween_property(self, "modulate:g", 1.0, 0.1)
	blink_tween.tween_property(self, "modulate:b", 1.0, 0.1)

	# Clean up: Stop the blink when the main fade finishes
	tween.tween_callback(func(): blink_tween.kill())
		
	# Explicitly fade the sprite as well to ensure it works perfectly
	if has_node("Sprite2D"):
		tween.parallel().tween_property($Sprite2D, "modulate:a", 0.0, fade_duration)

	# 4. Wait for the fade to finish, then flush (destroy) the monster
	await tween.finished
	queue_free()


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
