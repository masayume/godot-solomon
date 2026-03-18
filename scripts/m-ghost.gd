extends Monster
class_name Ghost

var direction := -1

func _physics_process(delta):

	# No gravity → flying enemy
	velocity.y = 0

	velocity.x = direction * GameConfig.monsterdata.ghost.speed

	move_and_slide()

	if is_on_wall():
		direction *= -1
