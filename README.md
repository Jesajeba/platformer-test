# Platformer Test

A 3D platformer prototype in Godot 4 (GDScript), inspired by the feel of Kirby and the Forgotten Land. Built in stages from [GAME_SPEC.md](GAME_SPEC.md).

**Current status: Stage 6 (boss fight).** F5 opens the Overgrown Ruins level (`scenes/levels/level_ruins.tscn`). The tuning test scene is `scenes/levels/test_greybox.tscn`. The main menu takes over in Stage 7.

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
  godot --headless --path . res://tests/stage5_collectibles_test.tscn
  godot --headless --path . res://tests/stage6_boss_test.tscn
  ```
- Visual tours (windowed): `res://tests/camera_tour.tscn` visits every camera segment of the test greybox with the debug overlay on, `res://tests/level_tour.tscn` stops at each part of the ruins level, `res://tests/enemy_showcase.tscn` shows the three enemies idle and attacking, and `res://tests/boss_showcase.tscn` runs through the boss's attacks:
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
autoload/         Global singletons: GameState, SettingsManager, AudioManager (SceneManager comes in Stage 7)
assets/
  materials/      Greybox materials (prototype grid textures, 1 tile = 1 m)
  materials/ruins Ruins palette: stone, moss, grass, thorns, crumbling sandstone, teal runes...
  audio/sfx/      Optional sound files that replace the generated placeholders (see Audio)
  textures/       Prototype grid textures
scenes/
  player/         player.tscn
  enemies/        mossling, sporeling (+ spore_projectile), snapthorn
  pickups/        coin, lost_sprite, health_pickup
  boss/           king_mossback, shockwave, falling_rock
  ui/             hud.tscn
  level/          Reusable level pieces (see "Building levels")
  levels/         level_ruins.tscn (the level), test_greybox.tscn (tuning sandbox)
  test/           Test-only objects (training dummy)
scripts/
  player/  camera/  enemies/  boss/  pickups/  level/  ui/  audio/ (SfxSynth)  util/ (HitStop, Fx particles)
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

## Collectibles, checkpoints and HUD

- **Coins** (scenes/pickups/coin.tscn): there are about 120 in the level. They trace the route, and arcs of coins show where to jump over a gap. The shortcut corridor is lined with them as a reward. Enemies drop their coin_reward as coins that pop out, land, and blink away after 10 s.
- **Lost Sprites** (lost_sprite.tscn, sprite_id 1-3): three per level. Sprite 1 is behind the courtyard's cracked wall. Sprite 3 is behind the cracked wall on the stairway's upper ledge. Sprite 2 is on the floating platform reached by the hidden lift beside garden island B.
- **Hearts** (health_pickup.tscn): restore heal_amount (2). A heart is only picked up when you're hurt, otherwise it stays put. There are three: after the colonnade's crumbling bridge, on the stairway's upper ledge, and before the boss gate.
- **Checkpoints** save the respawn point and a snapshot of what you've collected:
  - **Dying** puts you back at the checkpoint with coins, Lost Sprites and pickups rolled back to that snapshot. Anything you collected since then reappears.
  - **Pits** cost a heart and return you to the checkpoint, but keep everything you collected.
  - Placed pickups are tracked by node path (Pickup.persistent). Dropped coins aren't tracked.
- **Breakable walls** throw debris chunks and dust, play a stone sound and shake the camera when they break. A hit that doesn't break the wall gives a small chip.
- **HUD** (scenes/ui/hud.tscn): hearts, coin count and Lost Sprites (x/3) in the top-left, plus a boss health bar at the bottom. The boss bar appears on GameState.start_boss(). The icons are drawn in code (HudIcon), so no textures are needed. The HUD runs entirely on GameState signals.
- **Level timer**: GameState.level_time counts while the level is running. Stage 7's results screen will show it.

To add a pickup, instance its scene anywhere in the level. Placed pickups are persistent by default. For a new kind of pickup, extend Pickup and override _on_collected(player) (and can_collect(player) if it needs a condition).

## Boss: King Mossback

The fight is run by the BossArena node in the level (scripts/boss/boss_arena.gd), and the boss is scenes/boss/king_mossback.tscn (KingMossback, which extends EnemyBase).

- **Intro**: Walking through the entrance trigger closes the gate behind you. The arena entrance becomes the respawn point, your controls lock, the camera cuts to a close shot of the king, and a name card plays ("King Mossback, King of the Ruins"). The boss bar appears and the fight starts after intro_duration.
- **Hitting him**: He only takes damage in the **vulnerable window** after each attack. You can tell it's open by the dizzy stars over his head, the pulsing gold glow and the floating "Attack!" label ("Dizzy! Attack!" after a pillar crash). Each window allows up to max_hits_per_window (3) hits. Hits outside a window clank off with a stone sound and sparks. A hit that lands flashes him and shakes the camera.
- **12 HP**, with phases at 8 and 4 HP. Each phase change starts with a roar (phase_transition_time). Every attack has an orange wind-up glow first.
  - **Phase 1**: The **ground slam** raises his fists, then slams, sending out a shockwave ring. Jump over it, since it only hurts you on the ground. The **summon** calls Mosslings at the far side of the arena (at most 3 alive). The pattern is slam, summon, slam.
  - **Phase 2**: The **spore barrage** fires 3 rings of slow spores, each with a 3-spore gap to slip through or jump over. The **charge** lowers his head, locks aim just before going, and rushes you. If he hits a pillar or the throne he's **stunned** for a long window. If he misses, he stops at the arena edge with only a short opening. The pattern is barrage, charge, slam, charge.
  - **Phase 3**: Wind-ups are 35% faster, and attacks come in **combos** (slam+charge, barrage+slam, charge+barrage) with the window after the last one. The **arena changes**: the four outer platforms shake and fall away, and **rocks fall** with red ground markers. About half of them target your position.
- **Defeat**: slow motion, debris bursts, and he topples and sinks. 10 coins burst out, the boss bar fades, and after exit_open_delay the exit gate opens to the level goal.
- **Dying in the fight** resets him (full health, phase 1, back by the throne), restores the arena, and clears summons and hazards. You respawn at the arena entrance and the fight restarts after a short intro. Falling into a pit just costs a heart and returns you to the entrance.

All timings, speeds, counts and thresholds are exported on the KingMossback and BossArena nodes. start_attack() and orce_vulnerable() are there for testing and tuning. The pillars and throne are in the oss_pillar group (things his charge crashes into). He's on his own physics layer (oss), so he's solid to the player but doesn't pull the camera in. Locked camera keys and the intro shot skip camera collision entirely.

## Audio

AudioManager.play_sfx(&"name") plays a sound on the SFX bus, and play_ui() uses the UI bus. The buses (Master, Music, SFX, UI) are defined in default_bus_layout.tres. Every sound is generated in code by scripts/audio/sfx_synth.gd (tone sweeps, note sequences, filtered noise). To use a real recording instead, put <name>.wav or <name>.ogg in es://assets/audio/sfx/ and it's picked up automatically. Sounds: coin, sprite, heal, checkpoint, wall_break, stone_hit, jump, hover, attack, hit, hurt, enemy_death, spore_fire, land, ui_move, ui_select, ui_back. Stage 8 adds music and wires up the remaining gameplay sounds.

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
