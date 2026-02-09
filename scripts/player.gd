extends Node

@onready var speed = GameConfig.player["move_speed"]
@onready var jump_force = GameConfig.player["jump_force"]
@onready var gravity = GameConfig.player["gravity"]

func _physics_process(delta):
	velocity.y += gravity * delta
