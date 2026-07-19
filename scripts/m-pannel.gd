extends Monster
class_name Pannel

# var direction := -1

var shoot_direction := Vector2.RIGHT # Fireball shooting direction

var gravity = GameConfig.monsterdata.pannel.gravity

# -- Fire breath state machine -------------------
enum BreathState { PATROL, CHARGING, BREATHING }
var breath_state: BreathState = BreathState.PATROL

var charge_timer: float = 0.0
var cooldown_timer: float = 0.0

var hitbox: Area2D 


# Fireball Logic
@export var fireball_scene: PackedScene
@export var charge_time: float = 0.8        # seconds spent winding up before breathing fire
@export var breath_cooldown: float = 0.5    # seconds before it can charge again after breathing

var level_started := false  # Monster holds fire
var shoot_timer = 2.0

func _ready():
	family = "pannel"
	add_to_group("monsters") 
	super._ready() # This triggers Monster._ready() which calls change_state(family)

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()
	
	# Pannel HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	

	# Initialize Shoot Direction based on Level Data or Config
	_init_shoot_direction()
	
	# Get Cooldown from Config if available
	if GameConfig.monsterdata.has(family) and GameConfig.monsterdata[family].has("cooldown"):
		breath_cooldown = GameConfig.monsterdata[family].cooldown

	# Waits for level_started before shooting
#	var loader = get_tree().get_first_node_in_group("loader") # or however you reference it
	# AFTER - walk up to the level root which owns the signal
	var loader = get_parent()  # fireballs are added to get_parent(), so it's the level node
	if loader and loader.has_signal("level_started"):
		loader.level_started.connect(func():
			level_started = true
			cooldown_timer = breath_cooldown  # start a fresh cooldown from level start
		)

	state_animation_finished.connect(_on_state_animation_finished)
			
func _init_shoot_direction():
	# Check if the specific instance has a 'shoot_dir' property set by the LevelLoader
	# If not, default to RIGHT or based on initial movement direction
	if has_meta("shoot_direction"):
		if get_meta("shoot_direction") == "up":
			shoot_direction = Vector2.UP
		elif get_meta("shoot_direction") == "down":	
			shoot_direction = Vector2.DOWN
		elif get_meta("shoot_direction") == "left":	
			shoot_direction = Vector2.LEFT
		else:
			shoot_direction = Vector2.RIGHT			
	else:
		# Default behavior: if moving left, shoot left? Or always right? 
		# Let's default to RIGHT unless specified otherwise in level JSON as "direction"
		shoot_direction = Vector2.RIGHT
		
func _process(delta):

	# IMPORTANT: Calls Monster._process() to run animate(delta)
	super._process(delta)

	if not level_started:  # Guards to hold fire
		return
		
	# Handle Shooting Timer
#	if shoot_timer > 0:
#		shoot_timer -= delta
#	else:
#		_attempt_shoot()
#		shoot_timer = breath_cooldown
		
func _physics_process(_delta):
	# behave() now handles velocity, gravity, wall bouncing, and move_and_slide()
	# behave(_delta) # includes move_and_slide()

	if is_on_wall():
		direction *= -1

	match breath_state:
		BreathState.PATROL:
			_process_patrol(_delta)
		BreathState.CHARGING:
			_process_charging(_delta)
		BreathState.BREATHING:
			_process_breathing(_delta)

func _process_patrol(_delta):
	if cooldown_timer > 0:
		cooldown_timer -= _delta

	behave(_delta) # includes move_and_slide()

#		var probe_pos = global_position + Vector2(direction * tile_size * 0.5, 0)
#		wall_impact.emit(probe_pos, direction)
#		direction *= -1

	# Look for a block or the Player straight ahead; wind up a fire breath
#	if cooldown_timer <= 0 and _target_ahead():
#		_start_charge()

	if level_started and cooldown_timer <= 0:
		_start_charge()

func _process_charging(_delta):
	velocity.x = 0
#	_apply_gravity(_delta)
#	move_and_slide()
 
#	charge_timer -= _delta
#	if charge_timer <= 0:
#		_breathe_fire()
	_breathe_fire()
  

func _process_breathing(_delta):
	velocity.x = 0
	_apply_gravity(_delta)
	move_and_slide()
	# Returns to PATROL automatically once the "pannel_breath" animation
	# finishes - see _on_state_animation_finished() below.

func _apply_gravity(_delta):
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0

func _attempt_shoot2DEL():
	
#	print("Pannel attempt shoot to ", shoot_direction)
	if not fireball_scene:
		return

	change_state("pannel_breath")
		
	var fb = fireball_scene.instantiate()
	
	# disable raycast to fly straight
	fb.is_monster_projectile = true

	# Find the loader and pass it to the fireball before adding to scene
	var loader = get_tree().get_first_node_in_group("level_loader")
	fb.loader = loader
#	get_parent().add_child(fb)

	
	# ==========================================
	# 🔍 DEBUG VISUALIZATION
	# ==========================================
#	var debug_marker = ColorRect.new()
#	debug_marker.color = Color.RED
#	debug_marker.size = Vector2(12, 12)
#	debug_marker.position = Vector2(-6, -6) # Centers the 12x12 square on the exact point
#	get_parent().add_child(debug_marker)
	

	# 1. Define a consistent margin distance (e.g., 24 pixels)
	var spawn_distance = 32.0
	
	# Fine-tune per direction if sprite pivot isn't centered
	const SPAWN_OFFSETS := {
		Vector2.RIGHT: Vector2(-60, 10),
		Vector2.LEFT:  Vector2(-70, 10),
		Vector2.UP:    Vector2(-52, 0),   # tweak Y if still off
		Vector2.DOWN:  Vector2(-62, 0),   # tweak Y if still off
	}

	# 2. Calculate the offset. 
	# Since shoot_direction is a normalized Vector2 (length of 1), 
	# multiplying it by the distance gives the exact world-space offset.
	# Example: Vector2.LEFT * 24.0 = Vector2(-24, 0)
	var spawn_offset = shoot_direction * spawn_distance
	# 3. Apply the offset to the monster's global position
	# fb.global_position = sprite.global_position + spawn_offset
	fb.global_position = sprite.global_position + spawn_offset + SPAWN_OFFSETS[shoot_direction]

	# Move the debug marker to the EXACT same spot
#	debug_marker.global_position = fb.global_position

	
	# 4. Set direction and rotation
	fb.direction = shoot_direction
	fb.rotation = shoot_direction.angle()

	# 5. DEBUG: Print the exact math to the console
#	print("🔍 DEBUG MATH:")
#	print("   Monster global_position: ", global_position)
#	print("   Shoot direction:         ", shoot_direction)
#	print("   Calculated offset:       ", spawn_offset)
#	print("   Fireball global_position:", fb.global_position)
		
	# Add to parent (Level) so it doesn't move with the monster if the monster moves
	get_parent().add_child(fb)
	
	# Optional: Play a sound
	# audio_player.play() 

func _start_charge():
	breath_state = BreathState.CHARGING
	charge_timer = charge_time
	change_state("pannel_charge")  # add this state to monster.cfg (see notes)
 
func _breathe_fire():
	breath_state = BreathState.BREATHING
	change_state("pannel_breath")  # add this state to monster.cfg, loop = false

	var spawn_distance = 32.0  # tweak to match the Pannel's mouth/sprite pivot
 
	const BREATH_SPAWN_OFFSETS := {
		Vector2.RIGHT: Vector2(-60, 10),
		Vector2.LEFT:  Vector2(-70, 10),
		Vector2.UP:    Vector2(-52, 0),   # tweak Y if still off
		Vector2.DOWN:  Vector2(-64, 32),   # tweak Y if still off
	}
	
	if not fireball_scene:
		push_warning("Pannel '%s' has no fireball_scene assigned - can't breathe fire!" % name)
		return

	var fb = fireball_scene.instantiate()
	fb.family = "fireball"  # picks stats/sprite from projectiles.cfg

	# 2. Calculate the offset. 
	# Since shoot_direction is a normalized Vector2 (length of 1), 
	# multiplying it by the distance gives the exact world-space offset.
	# Example: Vector2.LEFT * 24.0 = Vector2(-24, 0)
	var spawn_offset = shoot_direction * spawn_distance
	
	# 3. Apply the offset to the monster's global position
	# fb.global_position = sprite.global_position + spawn_offset
	fb.global_position = sprite.global_position + spawn_offset + BREATH_SPAWN_OFFSETS[shoot_direction] 

	# 4. Set direction and rotation
	fb.direction = shoot_direction
	fb.rotation = shoot_direction.angle()

###DEBUG directional projectile debug
	# 5. DEBUG: Print the exact math to the console
#	print("🔍 DEBUG MATH:")
#	print("   Monster global_position: ", global_position)
#	print("   Shoot direction:         ", shoot_direction)
#	print("   Calculated offset:       ", spawn_offset)
#	print("   Fireball global_position:", fb.global_position)
	
	# Fly straight, ignore the player-fireball crawl/surface logic
	fb.is_monster_projectile = true
	fb.loader = get_tree().get_first_node_in_group("level_loader")
 
	# Same idea as Pannel's SPAWN_OFFSETS: the sprite pivot isn't symmetric,
	# so LEFT needs its own tuned constant - it's not just a mirror/negation
	# of RIGHT's value. RIGHT below is confirmed correct; nudge LEFT's
	# Vector2 until the fireball lines up with the mouth when facing left.
#	const BREATH_SPAWN_OFFSETS := {
#		Vector2.RIGHT: Vector2(-0, 0),
#		Vector2.LEFT:  Vector2(-120, 0),  # TODO: tweak until it lines up
#	}

	# Move the debug marker to the EXACT same spot
#	debug_marker.global_position = fb.global_position
	
#	var shoot_dir = Vector2(direction, 0)
#	var shoot_dir = shoot_direction
	
	# Spawn offset uses -direction (not +direction). The math for "front"
	# was inverted relative to the Pannel's sprite/pivot, which is why the
	# fireball was appearing on the tail side instead of the mouth side.
	# Travel direction (shoot_dir/rotation below) is untouched - that part
	# was already correct.
 
	# Add to the level (not to the Pannel) so it doesn't move with it
	get_parent().add_child(fb)



func _setup_hitbox():
	if not hitbox: return
	
	# Ensure Hitbox is set to detect the Player (Layer 2)
	hitbox.collision_layer = 4 # Hitbox needs to be found by fireballs...
	hitbox.collision_mask = 2  # Monitor the Player's Layer
	
#	if not hitbox.area_entered.is_connected(_on_hitbox_entered):
#		hitbox.area_entered.connect(_on_hitbox_entered)
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _on_hitbox_body_entered(body):

	if body.has_method("trigger_death_from_monster"):
		body.trigger_death_from_monster()

func behave(_delta):
	# Use state-specific speed if defined in config, otherwise fallback to default family speed
	var current_speed = GameConfig.monsterdata[current_state].get("speed", stats.get("speed", 0))
	velocity.x = direction * current_speed
#	velocity.x = direction * GameConfig.monsterdata[family].speed

	sprite.flip_h = velocity.x < 0

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0
		
	# simple back-and-forth
#	if is_on_wall():
#		direction *= -1

	move_and_slide()
	
func _on_state_animation_finished(state_name: String):
	if state_name == "pannel_breath":
		print("shot; back to patrol")
		breath_state = BreathState.PATROL
		cooldown_timer = breath_cooldown
		change_state("pannel")
		
