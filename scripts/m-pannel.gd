extends Monster
class_name Pannel

var direction := -1
var shoot_direction := Vector2.RIGHT # Fireball shooting direction

var gravity = GameConfig.monsterdata.pannel.gravity

var hitbox: Area2D 

# Fireball Logic
@export var fireball_scene: PackedScene
var shoot_timer: float = 0.0
var shoot_cooldown: float = 5.0 # Default, can be overridden by config or level data

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
		shoot_cooldown = GameConfig.monsterdata[family].cooldown

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
#	animate(delta)
	super._process(delta)

	# Handle Shooting Timer
	if shoot_timer > 0:
		shoot_timer -= delta
	else:
		_attempt_shoot()
		shoot_timer = shoot_cooldown
		
func _physics_process(_delta):
	# behave() now handles velocity, gravity, wall bouncing, and move_and_slide()
	behave(_delta) # includes move_and_slide()

	if is_on_wall():
		direction *= -1

func _attempt_shoot():
	
	print("Pannel attempt shoot to ", shoot_direction)
	if not fireball_scene:
		return

	change_state("pannel_shoot")
		
	var fb = fireball_scene.instantiate()

	# 1. Calculate a spawn offset based on the shooting direction
	# This pushes the fireball 24 pixels out of the monster's center, 
	# preventing it from spawning inside the monster and hitting itself.
	var spawn_offset = shoot_direction * 24.0 

	# Spawn at center of monster
	fb.global_position = global_position + spawn_offset
	
	# Set direction
	fb.direction = shoot_direction
	fb.rotation = shoot_direction.angle()
	
	# Add to parent (Level) so it doesn't move with the monster if the monster moves
	get_parent().add_child(fb)
	
	# Optional: Play a sound
	# audio_player.play() 
	
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
	
