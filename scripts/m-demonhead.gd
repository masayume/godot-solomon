extends Monster
class_name Demonhead

var direction := 1

var frames = []
var anim_speed = 0.1
var frame_index = 0
var time_accumulator = 0.0

var gravity = GameConfig.monsterdata.demonhead.gravity

#SIGNAL-demonhead-1 Define the signal with parameters able to destroy a block when hit
signal wall_impact(pos: Vector2, dir: int)

func _ready():
	family = "demonhead"
	super._ready()
	
	setup_animation()

func _process(delta):
	animate(delta)

func _physics_process(_delta):

	behave(_delta) # includes move_and_slide()

	if is_on_wall():
		#SIGNAL-demonhead-2 Emit the signal instead of calling a parent method directly
		wall_impact.emit(global_position, direction)		
		
		direction *= -1


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
	
