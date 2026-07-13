###DEBUG debug grid overlay
## ENABLE/DISABLE adding/removing the debug_script_overlay.gd in Script
##
## Scene tree:
##   LevelRoot
##   └── Level  (LevelLoader)
##       └── DebugOverlay  ← add this script here
##
## Node2D, child of Level (LevelLoader), z_index = 1000, Process Mode = Inherit
## Position = (0, 0) - do not set any position offset on this node.

extends Node2D

const C_GRID   := Color(0.25, 0.45, 1.00, 0.40)
const C_FILL   := Color(0.25, 0.45, 1.00, 0.05)
const C_PLAYER := Color(0.10, 1.00, 0.40, 0.60)
const C_TARGET := Color(1.00, 0.90, 0.10, 0.70)
const C_LABEL  := Color(1.00, 1.00, 1.00, 0.55)
const LWIDTH   := 1.5
const FSIZE    := 9

var _loader : Node = null
var _player : Node = null
var _font   : Font = null

var _ts   : int   = 0
var _xoff : float = 0.0
var _yoff : float = 0.0
var _cols : int   = 0
var _rows : int   = 0

var _player_cell := Vector2i(-1, -1)
var _target_cell := Vector2i(-1, -1)

func _ready() -> void:
	_font   = ThemeDB.fallback_font
	_loader = get_parent()   # direct parent = LevelLoader
	# No position fix - _cell_rect handles coordinate spaces via to_global/to_local

func _process(_dt: float) -> void:
	if _loader == null:
		return

	var ts = _loader.get("tile_size")
	if ts == null or float(ts) < 2.0:
		return
	_ts   = int(float(ts))
#	_xoff = float(_loader.get("x_off") or 0.0)
#	_yoff = float(_loader.get("y_off") or 0.0)
	var raw_xoff = _loader.get("x_off")
	_xoff = float(raw_xoff) if raw_xoff != null else 0.0

	var raw_yoff = _loader.get("y_off")
	_yoff = float(raw_yoff) if raw_yoff != null else 0.0

###DEBUG overlay alignment
#	print("[OVERLAY RAW] _ts=", _ts, " _xoff=", _xoff, " _yoff=", _yoff,
#	  " | loader.tile_size=", _loader.get("tile_size"),
#	  " loader.x_off=", _loader.get("x_off"),
#	  " loader.y_off=", _loader.get("y_off"))
	
	var ld = _loader.get("current_level_data")
	if ld is Dictionary:
		_cols = int(ld.get("block_width",  0))
		_rows = int(ld.get("block_height", 0))

	if _cols == 0 or _rows == 0:
		return

	if _player == null or not is_instance_valid(_player):
		_player = _loader.get("player")

	if _player and is_instance_valid(_player):
		# Convert player world pos → LevelLoader local space
		# so x_off/y_off apply in the same coordinate frame
		var lp : Vector2 = _loader.to_local(_player.global_position)

		# Same snap as player.gd spell emit
		var sx : float = floor((lp.x - _ts) / _ts) * _ts
		var sy : float = round(lp.y / _ts) * _ts

		# Grid conversion in loader-local space
		var half := _ts / 2.0
		var gx := int(floor((sx - _xoff - half) / _ts)) + 1
		var gy := int(-floor((sy + _yoff + half) / _ts)) + 1
		_player_cell = Vector2i(gx, gy)

		var dir : int  = int(_player.get("facing")    or 1)
		var crc : bool = bool(_player.get("crouching") or false)
		_target_cell = Vector2i(_player_cell.x + dir, _player_cell.y)
		if crc:
			_target_cell.y -= 1
	else:
		_player_cell = Vector2i(-1, -1)
		_target_cell = Vector2i(-1, -1)

	queue_redraw()

func _draw() -> void:
	if _ts < 2 or _cols == 0 or _rows == 0:
		return

	# Expanded ranges to draw overlays for elements mapped outside block bounds (0 and max rows)
	for c in range(0, _cols + 1):
		for r in range(0, _rows + 2):
			var rect := _cell_rect(c, r)
			draw_rect(rect, C_FILL,  true)
			draw_rect(rect, C_GRID,  false, LWIDTH)
			draw_string(_font, rect.position + Vector2(2, FSIZE + 1),
						"%d,%d" % [c, r],
						HORIZONTAL_ALIGNMENT_LEFT, -1, FSIZE, C_LABEL)

func _drawOLD() -> void:
	if _ts < 2 or _cols == 0 or _rows == 0:
		return

	for c in range(1, _cols + 1):
		for r in range(1, _rows + 1):
			var rect := _cell_rect(c, r)
			draw_rect(rect, C_FILL,  true)
			draw_rect(rect, C_GRID,  false, LWIDTH)
			draw_string(_font, rect.position + Vector2(2, FSIZE + 1),
						"%d,%d" % [c, r],
						HORIZONTAL_ALIGNMENT_LEFT, -1, FSIZE, C_LABEL)

	_highlight(_player_cell, C_PLAYER)
	_highlight(_target_cell, C_TARGET)


func _highlight(cell: Vector2i, col: Color) -> void:
	if cell.x < 0:
		return
	var rect := _cell_rect(cell.x, cell.y)
	draw_rect(rect, Color(col.r, col.g, col.b, 0.28), true)
	draw_rect(rect, col, false, 2.5)
	draw_string(_font,
		rect.position + Vector2(2, rect.size.y * 0.55),
		"%d,%d" % [cell.x, cell.y],
		HORIZONTAL_ALIGNMENT_LEFT, -1, FSIZE + 2, col)

func _cell_rect(col: int, row: int) -> Rect2:
	var half := _ts * 0.5

	# 1. Bypass manual math and let GameConfig calculate the exact local coordinate 
	#    the same way level_loader.gd does for blocks and items!
	var local_pos: Vector2 = GameConfig.grid_to_local(col, row, _ts, _xoff, _yoff)
		
	# 2. Convert from loader local space to absolute global screen space
	var global_pos : Vector2 = _loader.to_global(local_pos)
			
	# 3. Convert absolute screen space to this overlay canvas drawing layer
	var local_draw_pos : Vector2 = to_local(global_pos)

###DEBUG cell alignment position check
#	if col == 8 and row == 11:
#		print("[OVERLAY CHECK] local_pos=", local_pos,
#			" loader.global=", _loader.global_position,
#			" overlay.global=", global_position,
#			" global_pos(door)=", global_pos,
#			" local_draw_pos=", local_draw_pos)

	# Rect2 draws from top-left, so offset by half the tile size to frame the block
	return Rect2(local_draw_pos.x - half, local_draw_pos.y - half, _ts, _ts)

func _cell_rectOLD(col: int, row: int) -> Rect2:
	var half := _ts * 0.5

	# Use the exact GameConfig positioning used to place blocks inside your loader
	var cx : float = (col - 1) * _ts + _xoff + half
	var cy : float = -(row - 1) * _ts - _yoff - half
		
	# 1. Match the exact grid_to_local mapping used by your level loader
	# If GameConfig is globally accessible, you can use:
#	var local_pos = GameConfig.grid_to_local(col, row, _ts, _xoff, _yoff)

	# Convert from loader local space to absolute global screen space
	var global_pos : Vector2 = _loader.to_global(Vector2(cx, cy))
			
	# Compute cell center in LevelLoader local space (mirrors grid_to_local exactly)
#	var cx : float = (col - 1) * _ts + _xoff + half
#	var cy : float = -(row - 1) * _ts - _yoff - half

	# Convert absolute screen space to this overlay canvas drawing layer
	var local_draw_pos : Vector2 = to_local(global_pos)
	
	# 2. Convert from the loader's local coordinate space directly to the overlay's space
	var world : Vector2 = _loader.to_global(Vector2(cx, cy))
	var local : Vector2 = to_local(world)
	
#	return Rect2(local.x - half, local.y - half, _ts, _ts)
	return Rect2(local_draw_pos.x - half, local_draw_pos.y - half, _ts, _ts)
	
