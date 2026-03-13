# Project godot-solomon
[Solomon's Key](https://en.wikipedia.org/wiki/Solomon%27s_Key) (ソロモンの鍵) inspired platform puzzle game in Godot (GDScript). *WIP*

A tile-based puzzle platformer where the player can conjure and destroy blocks in front of them, similar to the 1986 TECMO arcade Solomon's Key.

# Game Structure
```
LevelRoot (Node2D)
 └ Level (Node2D) – script: level_loader.gd
   ├ Block instances
   ├ Block instances
   └ Player (CharacterBody2D)
```

# Grid System

The world is a 15 x 12 blocks tile grid. Tile size comes from configuration files (res://config/game.cfg).
Grid origin is bottom-left (positive Y goes upward in grid space instead of the Godot world space default (downward)).

There are two space coordinates core _conversion functions_ exist:

```
grid_to_local(tile_x, tile_y, tile_size, x_off, y_off)
world_to_grid(world_pos, x_off, y_off, tile_size)
```

# Configuration System

There are two configuration files.

res://config/game.cfg
General game settings like tile size, player attributes and screen values.

res://config/blocks.cfg
Defines properties of each block type: earth (default), stone, door, key, etc.

Example blocks.cfg:

```
[earth]
destructible=true
collidable=true
```

These values are loaded into _GameConfig.blockdata_ dictionary

Example structure:

```
blockdata = {
  "earth": {"destructible": true, "collidable": true},
  "stone": {"destructible": false, "collidable": true},
  "shield": {"destructible": false, "collidable": false}
}
```

# Block System

Blocks are instantiated from Block.tscn scene.


# Level System

Function _level_loader(n)_ is the level manager for each stage.

# Player

Player is a _CharacterBody2D_, instantiated from Player.tscn scene.

Player movement uses standard physics:

```
  velocity.x
  gravity
  jump_force
```

Player tracks facing direction.

Player sends its world _position_ and _direction_ as _signal_ to level_loader when pressing the fire key.












