extends Monster
class_name Ghost

var direction := -1

var frames = []
var anim_speed = 0.1
var frame_index = 0
var time_accumulator = 0.0

#SIGNAL-ghost-1 Define the signal with parameters able to destroy a block when hit
signal wall_impact(pos: Vector2, dir: int)

func _ready():
	family = "ghost"
	super._ready()
	
	setup_animation()

func _process(delta):
	animate(delta)

func _physics_process(_delta):

	# No gravity → flying enemy
	velocity.y = 0

	velocity.x = direction * GameConfig.monsterdata.ghost.speed

	behave(_delta) # includes move_and_slide()

	if is_on_wall():
		#SIGNAL-ghost-2 Emit the signal instead of calling a parent method directly
		wall_impact.emit(global_position, direction)
		print("Ghost hit wall at: [x,y]")

		direction *= -1
		
#		for i in get_slide_collision_count():
#			var collision = get_slide_collision(i)
#			var collider = collision.get_collider()
#
#			# Check if the collider is a Block (You can check its group or name)
#			if collider.is_in_group("debug_collision"): # Your loader adds blocks to this group [cite: 8]
#				notify_level_loader_of_impact(collider)




func behave(_delta):
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
	
