extends CharacterBody2D

@onready var speed = GameConfig.gamedata.move_speed
@onready var jump_force = GameConfig.gamedata.jump_force
@onready var gravity = GameConfig.gamedata.gravity
	
func _ready():
	var ts = GameConfig.gamedata.TILE_SIZE
	var level = get_parent().get_node("LevelRoot/Level")

	var tile_x = 6
	var tile_y = 4

	global_position = level.position + Vector2(tile_x, tile_y) * ts + Vector2(ts/2, ts/2)


func _physics_process(delta):
	velocity.y += gravity * delta
	move_and_slide()

@export var block_scene: PackedScene
var tile_size = 64

func _input(event):
	if event.is_action_pressed("Fire"):
		create_block()

func create_block():
	var dir = Vector2.RIGHT  # later: use facing
	var grid_pos = (position / tile_size).floor()
	var target = grid_pos + dir

	var block = block_scene.instantiate()
	block.position = target * tile_size
	get_parent().add_child(block)
