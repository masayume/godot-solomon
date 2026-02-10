extends CharacterBody2D

@onready var speed = GameConfig.player["move_speed"]
@onready var jump_force = GameConfig.player["jump_force"]
@onready var gravity = GameConfig.player["gravity"]

func _physics_process(delta):
	velocity.y += gravity * delta
	move_and_slide()

@export var block_scene: PackedScene
var tile_size = 32

func _input(event):
	if event.is_action_pressed("fire"):
		create_block()

func create_block():
	var dir = Vector2.RIGHT  # later: use facing
	var grid_pos = (position / tile_size).floor()
	var target = grid_pos + dir

	var block = block_scene.instantiate()
	block.position = target * tile_size
	get_parent().add_child(block)
