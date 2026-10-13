# Platformer Test

A 3D platformer prototype in Godot 4 (GDScript), inspired by the feel of Kirby and the Forgotten Land. Built in stages from [GAME_SPEC.md](GAME_SPEC.md).

**Current status: Stage 1 (player controller).** F5 opens the greybox test scene. The main menu takes over in Stage 7.

## Running

- Open the folder in Godot 4.7+ and press **F5**, or from a terminal:
  ```
  godot --path .
  ```
- Automated Stage 1 smoke test (headless; exits with the failure count):
  ```
  godot --headless --path . res://tests/stage1_smoke_test.tscn
  ```

## Controls

| Action | Keyboard + mouse | Gamepad (Xbox / PlayStation) |
|---|---|---|
| Move | WASD or arrow keys | Left stick or D-pad |
| Jump (tap = short, hold = high) | Space | A / Cross |
| Hover (press jump again in the air, hold to keep floating) | Space | A / Cross |
| Attack | J or left mouse button | X / Square |
| Pause (used from Stage 7) | Esc | Start / Options |

The stick deadzone is 0.2 on the movement actions, and analog input gives proportional speed. Godot maps gamepad buttons by position, so Xbox and PlayStation pads use the same bindings. Menus use Godot's built-in `ui_*` actions, which already cover keyboard, D-pad and left stick.

## Project structure

```
autoload/         Global singletons (GameState; Settings/Audio/Scene managers come later)
assets/
  materials/      Greybox materials (world-triplanar prototype grid textures, 1 tile = 1 m)
  textures/       Prototype grid textures
scenes/
  player/         player.tscn
  level/          Reusable level pieces: breakable wall, hazard block, kill plane
  levels/         Playable scenes (test_greybox.tscn)
  test/           Test-only objects (training dummy)
scripts/
  player/  camera/  level/  ui/  util/
tests/            Headless smoke tests
```

## Tuning

Every tuning value is an `@export` variable grouped with `@export_group`. Select the **Player** node in a scene to edit them in the Inspector:

- **Movement**: max speed, ground/air acceleration and deceleration, turn speed.
- **Jump**: jump height and time to peak (gravity is derived from these two), fall gravity multiplier, jump cut, coyote time, jump buffer.
- **Hover**: duration, fall speed, entry lift, speed multiplier.
- **Attack**: damage, windup/active/recovery timings, cooldown, knockback, lunge, hit-stop duration and strength.
- **Health**: max hearts, invincibility time, hurt knockback and stun, pit damage, respawn delay.
- **Visuals**: squash and stretch amounts, hover puff, run bob, foot swing.

## Gameplay rules and defaults

- **Camera-relative movement**: "forward" is the active camera's forward vector flattened onto the ground. This keeps working when the rail camera (Stage 2) curves.
- **Jump**: Holding jump gives a full jump (2.6 m by default). Releasing early cuts upward speed to 45%. Coyote time and the jump buffer are both 0.12 s.
- **Jump vs. hover**: A jump press in the air uses coyote time first, otherwise it starts the hover. Once the hover is used up, further presses are buffered and fire as a jump on landing.
- **Hover**: The hover starts with a small upward pop and then falls slowly (1.4 m/s). It lasts while jump is held, up to 1.2 s. Releasing jump or running out of time ends it, and it can't be used again until you land.
- **Attack**: The hitbox is only active during the swing's active window. Each swing hits each target once, with hit-stop on contact. You can attack on the ground (with a small forward lunge) or in the air (with a little hang time). Attacking cancels a hover.
- **Damage**: You have 5 hearts. Taking damage gives 1.2 s of blinking invincibility and knockback.
- **Pits**: Falling into a pit costs 1 heart and puts you back at the checkpoint. Losing the last heart counts as death.
- **Death**: After a short spin-out you respawn at the last checkpoint with full health. Before any checkpoint is reached, the checkpoint is the spawn point.
- **Physics interpolation** is enabled, so motion is smooth on high-refresh displays. Code that teleports a body should call `reset_physics_interpolation()`.

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
