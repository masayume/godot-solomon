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

There are some configuration files that manage __game entities behavior__.

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

```
res://config/fx.cfg
```
General fx like "block poof/foop", "swirls", "lights" etc.


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

# FX System

Function _setup_fx(...)_ defines the fx attributes: sprite, hframes, frames[], velocity
Function _on_timer_timeout()_ may wait for the fx to finish to play what happens after the fx.

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

# Interaction System

The interaction system is designed to be data-driven and consistent. This means that it's possible to scale it up to handle new items, monsters, projectiles more easily.

Instead of: collect items, open gate, monster kills player there are interaction types that are reused anywhere is possible:

- COLLECT
- DAMAGE
- TRIGGER

This is implemented via an "active role" for Player (Interactor) and a "passive role" for Items etc.

The Collision Matrix Check

Check exact Inspector settings for both nodes: "**LAYER**" is "**who I am**", "**Mask**" is "**who I am looking for**".    

||      Node      ||       Script        ||       Layer      ||    Mask          ||
| Player (Area2D) | interaction_detector | 2 (Player)        | 3 (Interactables) |
| Key (Area2D)    | Child of Item        | 3 (Interactables) | 2 (Player)        |


```
  2^(1−1)=1 (Layer 1)
  2^(2−1)=2 (Layer 2)
```



The Player (The Active Agent)

```
  player.gd: Stores the flags array (e.g., ["has_key", "speed_up"]).

  interactor.gd: The bridge. It has one job: find a node named "Receiver" on the target and call its function.

  function _on_interaction_detector_area_entered(..) will trigger when the player overlaps it. You can check for a flag here to determine the result of this interaction.
```

The Item (The Passive Agent)

```
CharacterBody2D (item.gd) — Root node
 ├── CollisionShape2D - The "Physical" shape (used for blocking)
 ├── Receiver (Added via script) 
 ├── Sprite2D 
 └── Area2D - The "Sensor" shape (used for overlapping) 
       └── CollisionShape2D

  item.gd: The physical body. It handles the Sprite and Collision. It doesn't know "what" it is.

  receiver.gd: The brain. It holds the data injected during spawning. It contains the match statement that executes the actual game logic.
```

It's possible to distinguish between "_collectible_" items (like keys) and "_trigger_" items (like doors).

- Keys: Call item_node.queue_free() and spawn_fx("poof", ...) immediately upon collection.
- Doors: Do not call queue_free() on the door; instead, let the load_next_level() function handle clearing the whole scene.


The Loader (The Creator)

```
  level_loader.gd: The factory. It instantiates the item.tscn, asks ItemDatabase for the config, and sticks a new Receiver onto the item.
```

Example. The "Key to Door" Logic Loop

- Spawn: level_loader creates a Key with on_collect_flag: "gold_key".
- Overlap: Player touches Key. player.gd calls interactor.interact(key).
- Collect: Key’s receiver.gd sees it is a collectible. It calls player.add_flag("gold_key") and then queue_free().
- Open: Player touches Door. interactor.interact(door).
- Win: Door’s receiver.gd sees it is a door. It checks player.has_flag("gold_key"). If true, it triggers win_level().










