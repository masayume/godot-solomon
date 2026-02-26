extends CharacterBody2D

@onready var speed = GameConfig.gamedata.move_speed
@onready var jump_force = GameConfig.gamedata.jump_force
@onready var gravity = GameConfig.gamedata.gravity

@export var block_scene: PackedScene
var tile_size = 64
	
func _ready():
	var ts = GameConfig.gamedata.TILE_SIZE
	print("ts: " + str(ts))

func _physics_process(delta):
	# velocity.y += gravity * delta
	move_and_slide()

func _input(event):
	if event.is_action_pressed("Fire"):
		print("create_block()")

func spawn_at(tile_x: int, tile_y: int, x_off: float, y_off: float):
	# Get tile size from config (single source of truth)
	var tile_size = GameConfig.gamedata.TILE_SIZE
	# Convert grid coordinates into pixel position

	global_position = GameConfig.grid_to_local(

		tile_x,        # player grid X
		tile_y,        # player grid Y
		tile_size,
		x_off,
		y_off
	)


	
