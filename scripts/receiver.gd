extends Node
class_name Receiver

var data: Dictionary = {}

func receive(action, source):
	print("Received action from: ", source.name)	
	match GameConfig.itemdata.get("action_type"):
		"collect":
			_handle_collection(source)
		"door":
			_handle_door(source)

func _handle_collection(player):
	var flag = GameConfig.itemdata.get("on_collect_flag")
	player.set_flag(flag, true) # Player now "owns" the key state
	print("Picked up: ", GameConfig.itemdata.get("name"))
	get_parent().queue_free()

func _handle_door(player):
	var requirement = GameConfig.itemdata.get("requires_flag")
	if player.has_flag(requirement):
		print("Level Complete!")
		# get_tree().change_scene_to_file(...)
	else:
		print("Door is locked. You need: ", requirement)
