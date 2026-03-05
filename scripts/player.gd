extends CharacterBody2D

@onready var speed = GameConfig.gamedata.move_speed
@onready var jump_force = GameConfig.gamedata.jump_force
@onready var gravity = GameConfig.gamedata.gravity
@onready var off_xp = GameConfig.gamedata.off_xp

@export var block_scene: PackedScene
# var tile_size = 64
	
func _ready():
	print("Player ready:", self)
	print("PLAYER world:", global_position)
	print("SPRITE local:", $Sprite2D.position)
	
	# var ts = GameConfig.gamedata.TILE_SIZE
	# print("ts: " + str(ts))
	
func _physics_process(delta):
	velocity.x = 0
	if not is_on_floor():
		velocity.y += gravity * delta 
	move_and_slide()


func _input(event):
	if event.is_action_pressed("Fire"):
		print("is_action_pressed(Fire)")


func spawn_at(tile_x: int, tile_y: int, x_off: float, y_off: float):
	# Get tile size from config (single source of truth)
	var tile_size = GameConfig.gamedata.TILE_SIZE
	# Convert grid coordinates into pixel position
	
	print("spawn_at: " + str(x_off))
	print("parent:", get_parent())
	position = GameConfig.grid_to_local(
			tile_x, 
			tile_y, 
			tile_size, 
			x_off, 
			y_off
		)
	

	
