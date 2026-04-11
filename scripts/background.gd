extends Sprite2D

func _ready():
	self.scale=Vector2(4, 4)

	var loader = get_tree().get_first_node_in_group("level_loader")
	if loader and "current_level" in loader:
		var level_id = loader.current_level
		var section = "level_" + str(level_id)	
		if GameConfig.gamedata.has(section):
			var sprite_path = GameConfig.gamedata[section].get("sprite", "res://sprites/backgrounds/back_001.png")
			
			# 4. Load the texture dynamically
			var new_tex = load(sprite_path)
			if new_tex:
				self.texture = new_tex 
			else:
				push_error("Background Error: Could not load texture at " + sprite_path)

func refresh_background():
	var loader = get_tree().get_first_node_in_group("level_loader")
	if loader:
		var section = "level_" + str(loader.current_level)
		if GameConfig.gamedata.has(section):
			var sprite_path = GameConfig.gamedata[section].get("sprite", "res://sprites/backgrounds/back_001.png")
			self.texture = load(sprite_path)
			self.scale = Vector2(4, 4)
