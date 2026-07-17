extends Monster
class_name Blueflame

var gravity = GameConfig.monsterdata.blueflame.gravity

var hitbox: Area2D 


func _ready():
	family = "blueflame"
	add_to_group("monsters") 
	super._ready()
	
	# Force visibility of collision for this specific instance
	# if you want to be 100% sure during debug
	if get_node_or_null("CollisionShape2D"):
		get_node("CollisionShape2D").visible = true

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()
	
	print("Blueflame layer:", collision_layer, " mask: ", collision_mask)

	#  HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	

func _physics_process(_delta):
	# behave() now handles velocity, gravity, wall bouncing, and move_and_slide()    
	behave(_delta) # includes move_and_slide()


func _setup_hitbox():
	if not hitbox: return
	
	# Ensure Hitbox is set to detect the Player (Layer 2)
	hitbox.collision_layer = 0 # Hitbox doesn't need to be found
	hitbox.collision_mask = 2  # Monitor the Player's Layer
	
#	if not hitbox.area_entered.is_connected(_on_hitbox_entered):
#		hitbox.area_entered.connect(_on_hitbox_entered)
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _on_hitbox_body_entered(body):
	# If we hit the player's physical body
#	print("Ghost hit body:", body)
	if body.has_method("trigger_death_from_monster"):
		body.trigger_death_from_monster()



func behave(_delta):
	# Use state-specific speed if defined in config, otherwise fallback to default family speed
	var state_data = GameConfig.monsterdata.get(current_state, stats)
	var current_speed = state_data.get("speed", stats.get("speed", 0))
		
	velocity.x = direction * current_speed
	sprite.flip_h = velocity.x < 0

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0
		
	# simple back-and-forth
	if is_on_wall():
		direction *= -1
		
	move_and_slide()

	
