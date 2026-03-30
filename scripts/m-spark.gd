extends Monster
class_name Spark

var direction := -1

var frames = []
var anim_speed = 0.1
var frame_index = 0
var time_accumulator = 0.0

var current_surface: String = "bottom"

var gravity = GameConfig.monsterdata.spark.gravity

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

func _process(delta):
	animate(delta)

func _physics_process(_delta):
	behave(_delta) # includes move_and_slide()


func behave(_delta):
	
	# 2. Update 'up_direction' so Godot knows what is 'floor' vs 'wall' 
	# for this specific surface
	up_direction = surface_normals.get(current_surface, Vector2.UP)

	# 1. Calculate direction based on current rotation
	# Vector2.RIGHT.rotated(rotation) gives us the 'Forward' vector
	var move_dir = Vector2.RIGHT.rotated(rotation) 
	velocity = move_dir * direction * GameConfig.monsterdata[family].speed
	
	move_and_slide()

	# 3. Handle Corner Turning
	if is_on_wall():
		# We hit a front wall -> Climb it
		rotation -= PI/2 
		_update_current_surface()
	elif not is_on_floor():
		# We ran out of floor -> Wrap around the corner
		rotation += PI/2
		_update_current_surface()

		# CRITICAL: After rotating outward, move the spark 1-2 pixels
		# forward so it doesn't immediately think it's 'on a wall' in the next frame
		global_position += velocity * _delta
		
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
	
