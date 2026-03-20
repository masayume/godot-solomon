extends Node
class_name Receiver

func receive(action, source):

	var entity = get_parent()

	match action:

		"damage":
			if entity.has_method("take_damage"):
				entity.take_damage(1)

		"collect":
			if entity.has_method("on_collect"):
				entity.on_collect(source)

		"trigger":
			if entity.has_method("on_trigger"):
				entity.on_trigger(source)
