extends Monster
class_name Goblin

var direction := 1
@export var gravity := 900

func _physics_process(delta):

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	velocity.x = direction * GameConfig.monsterdata.goblin.speed

	move_and_slide()

	if is_on_wall():
		direction *= -1
