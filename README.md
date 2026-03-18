# Project godot-solomon **WIP**
[Solomon's Key](https://en.wikipedia.org/wiki/Solomon%27s_Key) (ソロモンの鍵) inspired platform puzzle game in Godot (GDScript).

A tile-based puzzle platformer where the player can conjure and destroy blocks in front of them, similar to the 1986 TECMO arcade Solomon's Key.

# Game Structure
```
LevelRoot (Node2D)
 └ Level (Node2D) – script: level_loader.gd
   ├ Block instances
   ├ Block instances
   └ Player (CharacterBody2D)
```

# Viewport Coordinates and Logic Grid System

The world is a 15 x 12 blocks large tile grid. Tile size and other attributes comes from __configuration files__ (res://config/game.cfg).
Grid origin is bottom-left (positive Y goes upward in grid space instead of the Godot world space default (downward)).

There are two space coordinates _core conversion functions_ exist:

```
grid_to_local(tile_x, tile_y, tile_size, x_off, y_off)
world_to_grid(world_pos, x_off, y_off, tile_size)
```

# Configuration System

There are some configuration files that manage game entities behavior.

```
res://config/game.cfg
```
General __game settings__ like tile size, player attributes and screen values.

```
res://config/blocks.cfg
```
Defines properties of each block type: earth (default), stone, door, key, etc. See below.

```
res://config/items.cfg
```
Defines item attributes

```
res://config/monsters.cfg
```
Defines monster attributes

# Block System

[Solomon's Key Item Reference](https://strategywiki.org/wiki/Solomon%27s_Key/Items)

Blocks are instantiated at runtime from Block.tscn scene.

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

# Monster System

[Solomon's Key Monster Reference](https://strategywiki.org/wiki/Solomon%27s_Key/Enemies)

Monsters are instantiated at runtime from Monster.tscn scene via monster.gd script.
Monster sprites are in res://sprites/monsters/

The resource file res://config/monsters.cfg defines properties for each monster type: ghost (default), goblin, chimera, spark, etc.

Each monster has a specific class (i.e. ghost, goblin etc.) that inherits from Monster class and manages look, physics, behavior, interactions etc.

Example monsters.cfg:

```
[ghost]
destructible=true
collidable=true
```

These values are loaded into _GameConfig.monsterdata_ dictionary

Example structure:

```
monsterdata = {
  "ghost": {"destructible": true, "collidable": true},
  "goblin": {"destructible": false, "collidable": true},
  "spark": {"destructible": false, "collidable": false}
}
```

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












