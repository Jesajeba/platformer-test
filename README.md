# Platformer Test

A 3D platformer prototype in Godot 4 (GDScript), inspired by the feel of Kirby and the Forgotten Land. Built in stages from [GAME_SPEC.md](GAME_SPEC.md).

**Current status: Stage 4 (enemies).** F5 opens the Overgrown Ruins level (`scenes/levels/level_ruins.tscn`). The tuning test scene is `scenes/levels/test_greybox.tscn`. The main menu takes over in Stage 7.

## Running

- Open the folder in Godot 4.7+ and press **F5**, or from a terminal:
  ```
  godot --path .
  ```
- Automated smoke tests (headless; each exits with its failure count):
  ```
  godot --headless --path . res://tests/stage1_smoke_test.tscn
  godot --headless --path . res://tests/stage2_rail_camera_test.tscn
  godot --headless --path . res://tests/stage3_level_test.tscn
  godot --headless --path . res://tests/stage4_enemy_test.tscn
  ```
- Visual tours (windowed): `res://tests/camera_tour.tscn` visits every camera segment of the test greybox with the debug overlay on, `res://tests/level_tour.tscn` stops at each part of the ruins level, and `res://tests/enemy_showcase.tscn` shows the three enemies idle and attacking:
  ```
  godot --path . res://tests/level_tour.tscn
  ```

## Controls

| Action | Keyboard + mouse | Gamepad (Xbox / PlayStation) |
|---|---|---|
| Move | WASD or arrow keys | Left stick or D-pad |
| Jump (tap = short, hold = high) | Space | A / Cross |
| Hover (press jump again in the air, hold to keep floating) | Space | A / Cross |
| Attack | J or left mouse button | X / Square |
| Pause (used from Stage 7) | Esc | Start / Options |
| Rail camera debug overlay | F3 | - |

The stick deadzone is 0.2 on the movement actions, and analog input gives proportional speed. Godot maps gamepad buttons by position, so Xbox and PlayStation pads use the same bindings. Menus use Godot's built-in `ui_*` actions, which already cover keyboard, D-pad and left stick.

## Project structure

```
autoload/         Global singletons: GameState, SettingsManager (Audio/Scene managers come later)
assets/
  materials/      Greybox materials (prototype grid textures, 1 tile = 1 m)
  materials/ruins Ruins palette: stone, moss, grass, thorns, crumbling sandstone, teal runes...
  textures/       Prototype grid textures
scenes/
  player/         player.tscn
  enemies/        mossling, sporeling (+ spore_projectile), snapthorn
  level/          Reusable level pieces (see "Building levels")
  levels/         level_ruins.tscn (the level), test_greybox.tscn (tuning sandbox)
  test/           Test-only objects (training dummy)
scripts/
  player/  camera/  enemies/  level/  ui/  util/ (HitStop, Fx particles)
tools/            build_ruins_level.gd: generator for level_ruins.tscn
tests/            Headless smoke tests (shared SmokeTestBase) and visual tours
```

## Tuning

Every tuning value is an `@export` variable grouped with `@export_group`. Select the **Player** node in a scene to edit them in the Inspector:

- **Movement**: max speed, ground/air acceleration and deceleration, turn speed.
- **Jump**: jump height and time to peak (gravity is derived from these two), fall gravity multiplier, jump cut, coyote time, jump buffer.
- **Hover**: duration, fall speed, entry lift, speed multiplier.
- **Attack**: damage, windup/active/recovery timings, cooldown, knockback, lunge, hit-stop duration and strength.
- **Health**: max hearts, invincibility time, hurt knockback and stun, pit damage, respawn delay.
- **Visuals**: squash and stretch amounts, hover puff, run bob, foot swing.

Camera tuning is on the **RailCamera** node (rail following, smoothing, collision, shake) and on each **RailCameraKey** (framing per segment).

## Camera rail

The camera rides a rail (`Path3D`) that follows the player's route through the level.

- **How it moves**: Each physics frame, `RailCamera` finds the point on the rail closest to the player (`curve.get_closest_offset()` in the path's local space). It moves its own progress along the rail toward that point, damped, capped at `rail_max_speed`, and never more than `max_lag_distance` away. Turning off `allow_backward` stops the camera from moving back along the rail.
- **Camera keys**: `RailCameraKey` markers are children of the `Path3D`. Each key holds framing for one segment: offset, FOV, look height, look-ahead, pitch, and how closely the camera follows the player sideways and vertically. A key applies from where it sits on the rail. The camera blends into the next key over that key's `blend_in_distance`.
- **Offsets**: Offsets are relative to the rail's direction at the camera's point: `x` = right of the rail, `y` = up, `z` = back.
- **Locked keys**: Set `locked` and give the key a `lock_camera_point` and `lock_look_point`. The camera then holds still at that point, for example in a boss arena.
- **Look-ahead**: Look-ahead slides the camera and its aim point forward together. The camera never turns toward the player, so its angle comes only from the key. That keeps camera-relative controls steady: in a side-scrolling segment, "right" always runs along the path.
- **Collision**: A sphere cast from the player to the camera pulls the camera in front of walls, then lets it ease back out. It uses the `world` layer by default.
- **Shake**: `camera.shake(strength, duration)` with strength 0 to 1. It does nothing when `SettingsManager.screen_shake` is off. The camera also shakes when the player takes damage.
- **Smoothing**: `SettingsManager.camera_smoothing` (0 = snappy, 1 = floaty) chooses between the camera's `smoothing_rate_snappy` and `smoothing_rate_floaty`.
- **Debug overlay (F3)**: Draws the rail (cyan), the keys (orange, yellow when active, red when locked), the player's projected point (magenta) and the camera's rail position (green). It also lists progress, the active keys, the blend weight, FOV, collision and shake.

**Editing the rail**: Select `CameraRail` in the level and edit its curve with the Path3D tools. To add a segment, add a `Marker3D` child, attach `scripts/camera/rail_camera_key.gd`, and place it on the rail where the segment should begin. The test greybox has six example keys: Start (behind), Angled34, PulledBack, Curve34, SideScroller, and BossArena (locked).

## The level: Overgrown Ruins

The route is about 390 m long. It runs north (-Z) from the start, turns east (+X) at the colonnade, and ends at the boss arena. There are five segments, each with its own camera key:

| # | Segment | Camera | Contents |
|---|---|---|---|
| 1 | Courtyard | Behind, then angled 3/4 | Teaching steps, secret wall (Lost Sprite 1), ramp, 3 m gap, 7 m hover gap, checkpoint 1 |
| 2 | Colonnade | Side-scroller | Thorns, 3 m gap, moving platform over a 12 m pit, pillar stumps, crumbling bridge, wall blocking the path, checkpoint 2 |
| 3 | Stairway | Angled 3/4, climbing | Stairs with thorns, ramp, 4 m lift, secret wall (Lost Sprite 3), crumbling bridge, checkpoint 3 |
| 4 | Sunken Garden | Pulled back | Islands, moving platform, 8 m hover gap, thorn island, crumbling platforms, shortcut corridor behind a breakable wall, secret lift to a floating platform (Lost Sprite 2), checkpoint 4 |
| 5 | Throne Arena | Locked | Circular arena, entrance gate (open), 4 pillars, 4 outer platforms, throne, exit gate (closed until the boss is beaten), level goal |

**Colour language**:
- Crimson is a hazard.
- Gold is a collectible.
- Teal-topped stone moves.
- Orange cracked sandstone crumbles.
- Pale cracked stone breaks when attacked.

**Lost Sprite spots** are `Marker3D`s under `SpriteSpots`. Stage 5 places the collectibles there.

### Building levels

The reusable pieces are in `scenes/level/`. Each one exposes its size and timings in the Inspector:

| Scene | What it is |
|---|---|
| `platform.tscn` | Stone block with a moss cap (`GreyboxBlock`). It can be a box or a cylinder and builds its own mesh and collision from `size`. |
| `moving_platform.tscn` | Travels to `travel` and back, pausing at each end. The player rides it automatically. |
| `crumbling_platform.tscn` | Shakes when stood on, falls after `crumble_delay`, and returns after `respawn_time`. |
| `thorn_patch.tscn` | A thorn hazard covering `size`. It damages the player on touch, with knockback. |
| `breakable_wall.tscn` | Breaks after `hits_to_break` attacks. |
| `checkpoint.tscn` | Crystal pedestal. Touching it sets the respawn point to its `SpawnPoint` child, facing that child's -Z. |
| `gate.tscn` | Barred gateway with `open()` and `close()`. |
| `level_goal.tscn` | End trigger that emits `GameState.level_completed`. |
| `kill_plane.tscn` | Sends the player to the last checkpoint and costs 1 heart. |

A playable level's root uses `scripts/level/level.gd` (`Level`). Point its exports at the `Player`, a `StartPoint` marker and the `RailCamera`. On load it sends the player to the start, or to the active checkpoint when you restart the same level.

**The generator**: `level_ruins.tscn` is generated by `tools/build_ruins_level.gd`. Run it with:
```
godot --headless --path . res://tools/build_ruins_level.tscn
```
The output is an ordinary scene, so you can open it and edit it in the editor. Re-running the generator overwrites hand edits, so until the level is final, layout changes go in the generator. To add a segment there, write a `_build_*` function using the `_ground`, `_box`, `_ramp`, `_pillar` and `_instance` helpers, then add a camera key in `_build_camera_rail()`.

**Route check**: The Stage 3 test walks the camera rail and raycasts down every 0.5 m. Every gap must be 8.5 m or less, and every climb 2.3 m or less, unless a moving platform spans it. Jump plus a full hover covers about 10.6 m.

## Enemies

All enemies extend `EnemyBase` (`scripts/enemies/enemy_base.gd`), which handles:
- **Health and hits**: a hit makes the enemy flash white, knocks it back (`knockback_multiplier`), stuns it briefly, then gives it a short invulnerability window.
- **Contact damage**: touching an enemy hurts the player.
- **Death**: the enemy pops in a puff and awards `coin_reward` coins. Stage 5 turns these into coin pickups through `coin_scene`.
- **Movement**: gravity, and ledge avoidance so enemies don't walk off drops deeper than `edge_check_depth`.
- **Sleeping**: an enemy does nothing while the player is more than `active_distance` away.

Every attack has a wind-up: the enemy glows orange (`set_telegraph()`) before it strikes, and shows a yellow "!" when it first spots you.

| Enemy | Scene | Behaviour |
|---|---|---|
| **Mossling** (chaser) | `scenes/enemies/mossling.tscn` | Wanders near its spawn point. When you come within `detect_range` it shows "!" and chases you. In lunge range it crouches and glows for `windup_time`, then lunges. It gives up beyond `lose_range`. 2 HP. |
| **Sporeling** (shooter) | `scenes/enemies/sporeling.tscn` | Keeps between `retreat_distance` and `approach_distance` from you. It strafes, and backs off (sliding sideways at ledges) when you crowd it. Every `fire_interval` it swells and glows, then fires a slow spore at where you're standing. Spores pop on hit or after `projectile_lifetime`. 2 HP. |
| **Snapthorn** (stationary plant) | `scenes/enemies/snapthorn.tscn` | Rooted in place. When you come within `trigger_range` it rears back and glows, snaps forward (hitting anything in front of it), then rests. 2 HP. |

**Attack priority**: While you're attacking, enemies in front of you can't hurt you by touch, so your swing wins a trade. Their actual attacks (lunge, spores, snap) still hit.

**Placement**: Enemies are listed in `_build_enemies()` in `tools/build_ruins_level.gd`. The courtyard introduces the Mossling, the colonnade the Sporeling, and the stairway landing the Snapthorn, each on its own first. The garden and arena approach mix all three. To add an enemy by hand, instance its scene under `Enemies`. Its -Z is the direction it faces at start.

**Adding a new enemy type**: Extend `EnemyBase` and implement `_ai_process(delta)`, plus optionally `_on_hurt()` and `_update_visual(delta)`. The scene needs a `Visual` node holding the meshes and a `ContactArea` (an `Area3D` with mask = player). Put the body on the `enemy` layer with mask = `world`.

## Gameplay rules and defaults

- **Camera-relative movement**: "forward" is the active camera's forward vector flattened onto the ground, so controls follow the rail camera around curves.
- **Jump**: Holding jump gives a full jump (2.6 m by default). Releasing early cuts upward speed to 45%. Coyote time and the jump buffer are both 0.12 s.
- **Jump vs. hover**: A jump press in the air uses coyote time first, otherwise it starts the hover. Once the hover is used up, further presses are buffered and fire as a jump on landing.
- **Hover**: The hover starts with a small upward pop and then falls slowly (1.4 m/s). It lasts while jump is held, up to 1.2 s. Releasing jump or running out of time ends it, and it can't be used again until you land.
- **Attack**: The hitbox is only active during the swing's active window. Each swing hits each target once, with hit-stop on contact. You can attack on the ground (with a small forward lunge) or in the air (with a little hang time). Attacking cancels a hover.
- **Damage**: You have 5 hearts. Taking damage gives 1.2 s of blinking invincibility and knockback.
- **Pits**: Falling into a pit costs 1 heart and puts you back at the checkpoint. Losing the last heart counts as death.
- **Death**: After a short spin-out you respawn at the last checkpoint with full health. Before any checkpoint is reached, the checkpoint is the spawn point.
- **Physics interpolation** is enabled, so motion is smooth on high-refresh displays. Code that teleports a body should call `reset_physics_interpolation()`. The player emits `teleported` on respawns so the camera snaps instead of sweeping across the level.

## Physics layers

| # | Name | Used by |
|---|---|---|
| 1 | world | Level geometry, breakable walls, dummies |
| 2 | player | Player body |
| 3 | enemy | Enemies and dummies |
| 4 | player_attack | Player attack hitbox (detects enemy and breakable) |
| 5 | hazard | Damage areas (detect player) |
| 6 | breakable | Breakable walls |
| 7 | pickup | Collectibles (Stage 5) |

## Extending

- **Hittable objects**: implement `take_hit(damage: int, source_position: Vector3, knockback: float)` and put the body on the `enemy` or `breakable` layer.
- **Things that hurt the player**: call `player.take_damage(amount, source_position)`. The `DamageArea` script does this for any overlapping body.
- **Greybox geometry**: add a `StaticBody3D`, attach `scripts/level/greybox_block.gd`, and set `size` and `material`. It builds its own mesh and collision, including in the editor.
