extends Monster
class_name Demonhead

var direction := 1

var gravity = GameConfig.monsterdata.demonhead.gravity

#SIGNAL-demonhead-1 Define the signal with parameters able to destroy a block when hit
signal wall_impact(pos: Vector2, dir: int)

var hitbox: Area2D 

func _ready():
	family = "demonhead"
	add_to_group("monsters") 
	super._ready()
	

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()

	print("Demonhead layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	

func _physics_process(_delta):

	behave(_delta) # includes move_and_slide()

	if is_on_wall():
		#SIGNAL-demonhead-2 Emit the signal instead of calling a parent method directly
		wall_impact.emit(global_position, direction)				
		direction *= -1

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
	# If we hit the player's physical body
#	print("Ghost hit body:", body)
	if body.has_method("trigger_death_from_monster"):
		body.trigger_death_from_monster()

func behave(_delta):
	velocity.x = 2 * direction * GameConfig.monsterdata[family].speed

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
