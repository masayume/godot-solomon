extends Node2D

var shapes := []

func _ready():
	collect_shapes()

func collect_shapes():
	shapes.clear()

	for node in get_tree().get_nodes_in_group("debug_collision"):
		var shape = node.get_node_or_null("CollisionShape2D")
		if shape:
			shapes.append(shape)

#func _draw():
#	for s in shapes:
#		var pos = s.global_position
#		draw_circle(to_local(pos), 4.0, Color.RED)

func _draw():
	for s in shapes:
		if s.shape is RectangleShape2D:
			var ext = s.shape.extents
			var rect = Rect2(s.global_position - ext, ext * 2)
			draw_rect(Rect2(to_local(rect.position), rect.size), Color.RED, false)


func _process(_delta):
	queue_redraw()
