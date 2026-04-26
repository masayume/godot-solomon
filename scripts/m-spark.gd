extends Monster
class_name Spark

var direction := -1

var frames = []
var anim_speed = 0.1
var frame_index = 0
var time_accumulator = 0.0

var current_surface: String = "bottom"

var gravity = GameConfig.monsterdata.spark.gravity

var hitbox: Area2D 

# We'll use this to handle rotation based on surface
var surface_normals = {
	"bottom": Vector2.UP,
	"top": Vector2.DOWN,
	"left": Vector2.RIGHT,
	"right": Vector2.LEFT
}

func _ready():
	family = "spark"
	super._ready()
	z_index = 30
	# Initial rotation based on the starting surface
	rotation = surface_normals[current_surface].angle() + PI/2
		
	setup_animation()

	# Force visibility of collision for this specific instance
	# if you want to be 100% sure during debug
	if get_node_or_null("CollisionShape2D"):
		get_node("CollisionShape2D").visible = true

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()

	print("Spark layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	

func _process(delta):
	animate(delta)

func _physics_process(_delta):
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
	# 1. Update the 'Up' vector to match the wall we are currently hugging 
	up_direction = surface_normals.get(current_surface, Vector2.UP)

	# 2. Calculate movement 
	var move_dir = Vector2.RIGHT.rotated(rotation) 
	velocity = move_dir * direction * GameConfig.monsterdata[family].speed
	
	# STICKINESS: Apply a force towards the wall to keep is_on_floor() true
	velocity -= up_direction * 100.0 

	move_and_slide()

	# 3. Handle Corner Turning (Hitting a wall in front) # CONCAVE CORNER
	if is_on_wall():
		rotation += PI/2 # Swapped for direction -1
		_update_current_surface()
		# Slight adjustment to prevent getting stuck in the corner
		global_position -= move_dir * 2.0 
		
	elif not is_on_floor():
		# CONVEX CORNER: Rounding an outside edge (the 270° turn) 
		rotation -= PI/2 # Swapped for direction -1
		_update_current_surface()

		# SNAP: This is the critical fix for convex corners.
		# We must move the Spark "forward" and "down" into the new wall.
		var new_move_dir = Vector2.RIGHT.rotated(rotation)
		var snap_forward = new_move_dir * direction * 15.0
		var snap_down = -surface_normals[current_surface] * 10.0
		global_position += snap_forward + snap_down

		
func _update_current_surface():
	# Use the current rotation (snapped to 90 deg) to find the new surface
	var angle = int(round(rad_to_deg(rotation))) % 360
	if angle < 0: angle += 360

	match angle:
		0, 360: current_surface = "bottom"
		90:      current_surface = "left"
		180:     current_surface = "top"
		270:     current_surface = "right"

func animate(delta):
	time_accumulator += delta

	if time_accumulator >= anim_speed:
		time_accumulator -= anim_speed

		frame_index += 1
		if frame_index >= frames.size():
			frame_index = 0

		sprite.frame = frames[frame_index]
			
func setup_animation():
	frames = GameConfig.monsterdata[family].frames
	anim_speed = GameConfig.monsterdata[family].anim_speed

	frame_index = 0
	sprite.frame = frames[0]
	
