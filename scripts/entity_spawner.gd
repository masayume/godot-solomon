extends Node2D
class_name EntitySpawner

@export var item_scene: PackedScene

var scenes = {
	"fairy": preload("res://scenes/m-Fairy.tscn"),
	"blueflame": preload("res://scenes/m-Blueflame.tscn"),
	"orangeflame": preload("res://scenes/m-Orangeflame.tscn"),
	"chimera": preload("res://scenes/m-Chimera.tscn"),
	"demonhead": preload("res://scenes/m-Demonhead.tscn"),
	"dragon": preload("res://scenes/m-Dragon.tscn"),
	"earthmage": preload("res://scenes/m-Earthmage.tscn"),
	"gargoyle": preload("res://scenes/m-Gargoyle.tscn"),
	"ghost": preload("res://scenes/m-Ghost.tscn"),
	"goblin": preload("res://scenes/m-Goblin.tscn"),
	"nuel": preload("res://scenes/m-Nuel.tscn"),
	"pannel": preload("res://scenes/m-Pannel.tscn"),
	"salamander": preload("res://scenes/m-Salamander.tscn"),
	"serpent": preload("res://scenes/m-Serpent.tscn"),
	"spark": preload("res://scenes/m-Spark.tscn"),
}

var monsters := {}    ## Vector2i -> Monster node
var item_nodes := {}  ## Vector2i -> Item node

@onready var loader = get_parent()

func clear():
	monsters.clear()
	item_nodes.clear()

func add_item(ix: int, iy: int, type: String, showing: bool = false, is_hidden: bool = false) -> Node2D:
	var item = item_scene.instantiate()
	item.family = type
	item.name = "IT_" + str(item.family)
	item.set_meta("is_hidden_item", is_hidden)
	item.add_to_group("itemgroup")

	if type == "door":
		loader.doorx = ix
		loader.doory = iy
		item.add_to_group("doorgroup")

	if type == "key":
		item.add_to_group("keygroup")

	# Interaction Sensor Setup
	var area = item.get_node("Area2D")
	area.collision_layer = 0
	area.collision_mask = 0
	
	if is_hidden:
		area.set_collision_layer_value(3, false)
		area.set_collision_mask_value(2, false)
	else:
		area.set_collision_layer_value(3, true)
		area.set_collision_mask_value(2, true)

	# Receiver Component
	var receiver = Receiver.new()
	receiver.name = "Receiver"
	receiver.data = GameConfig.itemdata[type]
	item.add_child(receiver)

	item.visible = showing
	loader.add_child(item)

	var cell = Vector2i(ix, iy)
	item_nodes[cell] = item
	
	item.position = GameConfig.grid_to_local(
		ix, iy, loader.tile_size, loader.x_off, loader.y_off
	)
	return item

func add_monster(monster_data: Dictionary) -> Node2D:
	var family = monster_data["family"]
	var instance = scenes[family].instantiate()
	instance.family = family

	if family == "spark":
		var start_surface = monster_data["attached"]
		instance.current_surface = start_surface 
		var spawn_pos = GameConfig.grid_to_local(monster_data["pos"][0], monster_data["pos"][1], loader.tile_size, loader.x_off, loader.y_off)

		match start_surface:
			"bottom": spawn_pos.y += (loader.tile_size / 2) - 1 
			"top":    spawn_pos.y -= (loader.tile_size / 2) - 1
			"left":   spawn_pos.x -= (loader.tile_size / 2) - 1
			"right":  spawn_pos.x += (loader.tile_size / 2) - 1

		instance.position = spawn_pos

	if monster_data.has("shoot_direction"):
		var dir = monster_data["shoot_direction"]
		instance.set_meta("shoot_direction", dir)
		if dir == "up": instance.rotation_degrees = -90
		elif dir == "down": instance.rotation_degrees = 90
		elif dir == "left": instance.scale.x = -1

	instance.name = "MO_" + str(instance.family)
	instance.add_to_group("debug_collision")
	instance.add_to_group("monstergroup")

	if family in ["ghost", "spark", "dragon"]:
		loader.debug_monster(instance)

	var area = Area2D.new()
	area.name = "HitBox"
	instance.collision_mask = 0
	area.collision_layer = 0
	area.collision_mask = 3

	area.set_deferred("monitoring", true)
	area.set_deferred("monitorable", true)
	area.set_collision_layer_value(4, true)
	area.set_collision_mask_value(2, true)

	instance.collision_layer = 4
	instance.collision_mask = 3

	if not instance.has_node("Receiver"):
		var receiver = Receiver.new()
		receiver.name = "Receiver"
		receiver.data = GameConfig.monsterdata[family]
		instance.add_child(receiver)

	var hitbox = instance.get_node_or_null("HitBox")
	if hitbox:
		hitbox.collision_layer = 4
		hitbox.collision_mask = 0

	loader.add_child(instance)
	instance.add_child(area)
						
	if family != "spark":
		instance.position = GameConfig.grid_to_local(
			monster_data["pos"][0], monster_data["pos"][1],
			loader.tile_size, loader.x_off, loader.y_off
		)

	if family == "demonhead":
		loader.spawn_fx("boom", instance.global_position, Vector2i(-1,-1), false)

	if GameConfig.gamedata.game.collider_debug:
		loader._debug_node_shapes(instance, Color(1, 0, 0, 0.7))
				
	return instance

func spawn_all_monsters(data: Dictionary):
	if data.has("monsters"):
		for m in data["monsters"]:
			var instance = add_monster(m)
			instance.visible = false
			instance.set_physics_process(false)

func spawn_fairy():
	var instance = scenes["fairy"].instantiate()	
	instance.family = "fairy"
	instance.name = "MO_fairy"

	instance.add_to_group("debug_collision")
	instance.add_to_group("monstergroup")

	var area = Area2D.new()
	area.name = "HitBox"

	var collision_shape = CollisionShape2D.new()
	var box_shape = RectangleShape2D.new()
	box_shape.size = Vector2(32, 32) 
	collision_shape.shape = box_shape
	area.add_child(collision_shape)

	instance.collision_mask = 0
	area.collision_layer = 0
	area.collision_mask = 3

	area.set_deferred("monitoring", true)
	area.set_deferred("monitorable", true)
	area.set_collision_layer_value(4, true)
	area.set_collision_mask_value(2, true)

	instance.collision_layer = 4
	instance.collision_mask = 3

	if not instance.has_node("Receiver"):
		var receiver = Receiver.new()
		receiver.name = "Receiver"
		receiver.data = GameConfig.monsterdata[instance.family]
		instance.add_child(receiver)

	var hitbox = instance.get_node_or_null("HitBox")
	if hitbox:
		hitbox.collision_layer = 4
		hitbox.collision_mask = 0

	instance.position = GameConfig.grid_to_local(
		loader.doorx, loader.doory, loader.tile_size, loader.x_off, loader.y_off
	)

	loader.call_deferred("add_child", instance)
	instance.add_child(area)
