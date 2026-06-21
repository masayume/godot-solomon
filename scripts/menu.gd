extends Control

# Path to whatever scene currently starts the game
const GAME_SCENE := "res://scenes/Main.tscn"

@onready var bg_sprite: Sprite2D = $BackgroundSprite
@onready var press_enter: Label = $PressEnterLabel
@onready var press_s: Label = $PressSKey
@onready var press_x: Label = $PressXKey

func _ready() -> void:

	### LOAD background
	var tex = bg_sprite.texture
	var screen_size = get_viewport_rect().size
	var tex_size = tex.get_size()

	var scale_factor = max(screen_size.x / tex_size.x, screen_size.y / tex_size.y) - 0.3
	bg_sprite.scale = Vector2(scale_factor, scale_factor)

	# Anchor crop to the right: position so the right edge of the image
	# aligns with the right edge of the screen
	var scaled_width = tex_size.x * scale_factor
	bg_sprite.position.x = screen_size.x - scaled_width / 2.0
	bg_sprite.position.y = screen_size.y / 2.0

	### Press Enter Text
	press_enter.text = "Press Enter to start"
	_blink_label()

	press_x.text = "Press X to create/destroy blocks"
	press_s.text = "Press S so shoot a fireball"


	$StartButton.pressed.connect(_on_start_pressed)
	set_process_unhandled_input(true)
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_start_pressed()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _blink_label() -> void:
	var t := create_tween()
	t.set_loops()
	t.tween_property(press_enter, "modulate:a", 0.0, 0.8)
	t.tween_property(press_enter, "modulate:a", 1.0, 0.8)
	
