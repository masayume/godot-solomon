## debug_grid_overlay.gd
## Node2D, child of Level (LevelLoader), z_index = 1000
##
## Scene tree:
##   LevelRoot
##   └── Level  (LevelLoader)
##       └── DebugGridOverlay   ← this script

extends Node2D

# ── colours ───────────────────────────────────────────────────────────────────
const C_GRID   := Color(0.25, 0.45, 1.00, 0.40)   # blue cell borders
const C_FILL   := Color(0.25, 0.45, 1.00, 0.05)   # very faint blue fill
const C_PLAYER := Color(0.10, 1.00, 0.40, 0.60)   # green  = player cell
const C_TARGET := Color(1.00, 0.90, 0.10, 0.70)   # yellow = cast target
const C_LABEL  := Color(1.00, 1.00, 1.00, 0.60)   # white  coord labels
const LWIDTH   := 1.5
const FSIZE    := 9

# ── runtime refs ──────────────────────────────────────────────────────────────
var _loader : Node   = null
var _player : Node   = null
var _font   : Font   = null

# ── grid params (read from loader every frame) ────────────────────────────────
var _ts    : int   = 64     # tile_size
var _xoff  : float = 0.0   # x_off
var _yoff  : float = 0.0   # y_off
var _cols  : int   = 20
var _rows  : int   = 11

# ── highlighted cells ─────────────────────────────────────────────────────────
var _player_cell := Vector2i(-1, -1)
var _target_cell := Vector2i(-1, -1)

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_font = ThemeDB.fallback_font
	_loader = get_parent()   # parent IS the LevelLoader (Level node)
	if not _loader:
		push_error("DebugGridOverlay: parent is not LevelLoader")


	var n := get_parent()
	while n:
		print("[DBG] node: ", n.name, " | script: ", n.get_script())
		n = n.get_parent()


func _process(_dt: float) -> void:
	# ── sync grid params from loader ──────────────────────────────────────
	if _loader:
		_ts   = int(_loader.get("tile_size") or 64)
		_xoff = float(_loader.get("x_off")   or 0.0)
		_yoff = float(_loader.get("y_off")   or 0.0)
		var ld = _loader.get("current_level_data")
		if ld is Dictionary:
			_cols = ld.get("block_width",  20)
			_rows = ld.get("block_height", 11)

	# ── resolve player lazily ────────────────────────────────────────────
	if _player == null or not is_instance_valid(_player):
		_player = _loader.get("player") if _loader else null

	# ── update highlighted cells ─────────────────────────────────────────
	if _player and is_instance_valid(_player):
		# Use the same snapping the player uses when emitting spell_pressed
		var gp   : Vector2 = _player.global_position
		var half : float   = _ts / 2.0
		var sx   : float   = floor((gp.x - _ts) / _ts) * _ts   # matches player snap
		var sy   : float   = round(gp.y / _ts) * _ts
		var snapped := Vector2(sx, sy)

		_player_cell = _w2g(snapped)

		# facing is the variable name in player.gd  (not facing_dir)
		var dir : int  = int(_player.get("facing") or 1)
		var crc : bool = bool(_player.get("crouching") or false)
		_target_cell  = Vector2i(_player_cell.x + dir, _player_cell.y)
		if crc:
			_target_cell.y -= 1
	else:
		_player_cell = Vector2i(-1, -1)
		_target_cell = Vector2i(-1, -1)

#DEBUG
	# ── debug print once per second ──────────────────────────────────────
	# (comment this out once the overlay is visible)
#	if Engine.get_frames_drawn() % 60 == 0:
#		print("[DBG overlay] ts=%d x_off=%.1f y_off=%.1f cols=%d rows=%d | player=%s target=%s" \
#			% [_ts, _xoff, _yoff, _cols, _rows, _player_cell, _target_cell])

	queue_redraw()


func _draw() -> void:
	if _ts == 0 or _cols == 0 or _rows == 0:
		return

	# ── 1. full grid ─────────────────────────────────────────────────────
	for c in range(1, _cols + 1):
		for r in range(1, _rows + 1):
			var rect := _cell_rect(c, r)
			draw_rect(rect, C_FILL,  true)
			draw_rect(rect, C_GRID,  false, LWIDTH)
			# tiny coord label at top-left of cell
			draw_string(_font, rect.position + Vector2(2, FSIZE + 1),
						"%d,%d" % [c, r],
						HORIZONTAL_ALIGNMENT_LEFT, -1, FSIZE, C_LABEL)

	# ── 2. player cell ────────────────────────────────────────────────────
	_hi(_player_cell, C_PLAYER)

	# ── 3. cast-target cell ───────────────────────────────────────────────
	_hi(_target_cell, C_TARGET)


func _hi(cell: Vector2i, col: Color) -> void:
	if cell.x < 0:
		return
	var rect  := _cell_rect(cell.x, cell.y)
	var fill  := Color(col.r, col.g, col.b, 0.28)
	draw_rect(rect, fill, true)
	draw_rect(rect, col,  false, 2.5)
	draw_string(_font,
		rect.position + Vector2(2, rect.size.y * 0.55),
		"%d,%d" % [cell.x, cell.y],
		HORIZONTAL_ALIGNMENT_LEFT, -1, FSIZE + 2, col)


# ── helpers ───────────────────────────────────────────────────────────────────

## Returns the Rect2 (in this node's local space = Level's local space)
## for the grid cell (col, row).  Mirrors GameConfig.grid_to_local exactly.
func _cell_rect(col: int, row: int) -> Rect2:
	var half := _ts * 0.5
	# grid_to_local gives the CENTER of the cell
	var cx := (col - 1) * _ts + _xoff + half
	var cy := -(row - 1) * _ts - _yoff - half
	return Rect2(cx - half, cy - half, _ts, _ts)


## Same formula as GameConfig.world_to_grid — floor-based.
func _w2g(world_pos: Vector2) -> Vector2i:
	var half := _ts / 2.0
	var gx   := int(floor((world_pos.x - _xoff - half) / _ts)) + 1
	var gy   := int(-floor((world_pos.y + _yoff + half) / _ts)) + 1
	return Vector2i(gx, gy)
