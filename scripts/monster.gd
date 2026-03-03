extends CharacterBody2D

var speed = 40

func _physics_process(delta):
	velocity.x = speed
	move_and_slide()
