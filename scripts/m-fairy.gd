extends Monster
class_name Fairy

# var direction := -1

var gravity = GameConfig.monsterdata.fairy.gravity

var hitbox: Area2D 


func _ready():
	family = "fairy"
	add_to_group("monsters") 
	super._ready()

	# Force visibility of collision for this specific instance
	# if you want to be 100% sure during debug
	if get_node_or_null("CollisionShape2D"):
		get_node("CollisionShape2D").visible = true

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()
	
#	print("Fairy layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	
		

func _physics_process(_delta):

	behave(_delta) # includes move_and_slide()

	if is_on_wall():
		direction *= -1

func _setup_hitbox():
	if not hitbox: return
	
	# the hitbox is configured as an item layer so the Player's CollectionZone finds it
	hitbox.collision_layer = 4 # Or whichever layer your items use (e.g. Layer 3 or 4)
	hitbox.collision_mask = 0  # It doesn't need to monitor anything; the player monitors it




func behave(_delta):
	velocity.x = direction * GameConfig.monsterdata[family].speed
		
	sprite.flip_h = velocity.x < 0

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0

	# Check if the fairy just hit the floor
	if is_on_floor():
		# Define how high you want the bounce to be. 
		# Negative values move UP in Godot's 2D coordinate system.
		# You can also use a variable like GameConfig.monsterdata[family].bounce_force
		var bounce_force = GameConfig.monsterdata[family].bounce_force 
		velocity.y = bounce_force
				
	# simple back-and-forth
#	if is_on_wall():
#		direction *= -1
		
	move_and_slide()
