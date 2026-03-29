extends Monster
class_name Spark

var direction := -1

var frames = []
var anim_speed = 0.1
var frame_index = 0
var time_accumulator = 0.0

var current_surface: String = "bottom"

var gravity = GameConfig.monsterdata.spark.gravity

func _ready():
	family = "spark"
	super._ready()
	
	setup_animation()

func _process(delta):
	animate(delta)

func _physics_process(_delta):

	velocity.x = direction * GameConfig.monsterdata.spark.speed

	behave(_delta) # includes move_and_slide()

	if is_on_wall():
		direction *= -1


func behave(_delta):
	velocity.x = direction * GameConfig.monsterdata[family].speed

	sprite.flip_h = velocity.x < 0

	# Move along the current surface normal (wall-crawler)
	var move_dir = Vector2.RIGHT.rotated(rotation) 
	velocity = move_dir * GameConfig.monsterdata.spark.speed

	move_and_slide()

	if is_on_wall():
		# Rotate 90 degrees to climb the wall
		rotation -= PI/2 
	elif not is_on_floor():
		# Rotate 90 degrees to wrap around the corner
		rotation += PI/2


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
	
