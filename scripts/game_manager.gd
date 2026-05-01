extends Node

# State variables
var current_lives: int = 0
var max_lives: int = 6

# Signal to notify UI when things change
signal lives_changed(new_count)

var is_player_active: bool = false:
	set(value):
		is_player_active = value
		# Notify the HUD to redraw whenever this state changes
		lives_changed.emit(current_lives) # Trigger the HUD redraw
		print("is_player_active set to ", value)

var _hud_ref = null

func register_hud_lives(node):
	_hud_ref = node

func set_player_in_game(active: bool):
	is_player_active = active
	print("set player active: 1 life on stage")
	
func _ready():
	# Initialize from parsed GameConfig data 
	current_lives = GameConfig.gamedata.get("start_lives", 3)
	max_lives = GameConfig.gamedata.get("max_lives", 6)

func add_life():
	if current_lives < max_lives:
		current_lives += 1
		lives_changed.emit(current_lives) # emit signal to UI

func remove_life():
	current_lives -= 1
	lives_changed.emit(current_lives) # emit signal to UI
	if current_lives <= 0:
		handle_game_over()

func handle_game_over():
	
	# level_loader.gd adds itself to the group_ add_to_group("level_loader")

	# 1. Get reference to the level loader
	var loader = get_tree().get_first_node_in_group("level_loader")	

	if loader:
	# 2. Call the function to wipe the current level content
	# This clears blocks, monsters, and dictionaries
		loader.clear_current_level()

	# 3. Show the Game Over text using the existing UI label reference[cite: 1]
		if loader.level_label:
			loader.level_label.text = "GAME OVER"
			loader.level_label.visible = true

	# 4. Play the game over sound
	play_game_over_sound()

func play_game_over_sound():
	var sfx_path = "res://sounds/orig-game-over.wav"
	var sfx = load(sfx_path)
	
	if sfx:
		# Create a temporary audio player if one doesn't exist in game_manager
		var audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		audio_player.stream = sfx
		audio_player.play()		
