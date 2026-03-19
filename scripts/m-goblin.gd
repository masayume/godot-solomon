extends Monster
class_name Goblin

var direction := -1

var frames = []
var anim_speed = 0.1
var frame_index = 0
var time_accumulator = 0.0

func _ready():
	family = "goblin"
	super._ready()
	
	setup_animation()

func _process(delta):
	animate(delta)
	behave(delta)

func behave(delta):
	velocity.x = direction * GameConfig.monsterdata[family].speed

	sprite.flip_h = velocity.x < 0

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
	
func _physics_process(delta):

	# No gravity → flying enemy
	velocity.y = 0

	velocity.x = direction * GameConfig.monsterdata.ghost.speed

	move_and_slide()

	if is_on_wall():
		direction *= -1
