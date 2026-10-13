# Overgrown Ruins: platformer prototype

A 3D platformer vertical slice in Godot 4 (GDScript), inspired by the feel of Kirby and the Forgotten Land: cute, chunky, readable and forgiving. You move, jump, hover and attack through one level of overgrown ruins, then fight the boss, King Mossback. Everything uses placeholder art (primitive meshes, flat colours) and generated placeholder audio. It was built in stages from [GAME_SPEC.md](GAME_SPEC.md). Limitations and next steps are in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## Running

- Open the folder in **Godot 4.7+** and press **F5**. The game starts at the main menu. From a terminal:
  ```
  godot --path .
  ```
- The tuning sandbox is `scenes/levels/test_greybox.tscn`. Open it and press **F6**.
- **Automated tests**: each one runs headless and exits with its failure count.
  ```
  godot --headless --path . res://tests/stage1_smoke_test.tscn
  godot --headless --path . res://tests/stage2_rail_camera_test.tscn
  godot --headless --path . res://tests/stage3_level_test.tscn
  godot --headless --path . res://tests/stage4_enemy_test.tscn
  godot --headless --path . res://tests/stage5_collectibles_test.tscn
  godot --headless --path . res://tests/stage6_boss_test.tscn
  godot --headless --path . res://tests/stage7_menus_test.tscn
  godot --headless --path . res://tests/stage8_full_flow_test.tscn
  ```
  The tests use `user://test_save.cfg` and `user://test_settings.cfg`, so they never touch your real save or settings.
- **Visual tours**: run these windowed to watch, optionally with `--write-movie out.png` to capture frames.
  - `tests/camera_tour.tscn`: every camera segment of the greybox, with the debug overlay on.
  - `tests/level_tour.tscn`: each part of the ruins level.
  - `tests/enemy_showcase.tscn`: the three enemies, idle and attacking.
  - `tests/boss_showcase.tscn`: the boss's attacks.
  - `tests/menu_tour.tscn`: every menu.
- **Generators**: re-run these after changing their scripts.
  ```
  godot --headless --path . res://tools/build_ruins_level.tscn
  godot --headless --path . res://tools/generate_audio.tscn
  ```

## Controls

| Action | Keyboard + mouse | Gamepad (Xbox / PlayStation) |
|---|---|---|
| Move | WASD or arrow keys | Left stick or D-pad |
| Jump (tap = short, hold = high) | Space | A / Cross |
| Hover (press jump again in the air, hold to keep floating) | Space | A / Cross |
| Attack | J or left mouse button | X / Square |
| Pause | Esc | Start / Options |
| Menus: move, confirm, back | Arrow keys, Enter/Space, Esc | D-pad or stick, A / Cross, B / Circle |
| Rail camera debug overlay | F3 | - |

- The stick deadzone is 0.2 on the movement actions, and analog input gives proportional speed.
- Godot maps gamepad buttons by position, so Xbox and PlayStation pads use the same bindings.
- Every binding can be changed in **Settings → Controls**, with a reset to defaults.

## Project structure

```
autoload/            GameState (run state + save file), SettingsManager, AudioManager, SceneManager
assets/
  audio/sfx/         Generated sound effects (WAV), replace with real files any time
  audio/music/       Generated music loops: menu, level, boss
  materials/         Greybox materials (prototype grid textures, 1 tile = 1 m)
  materials/ruins/   Ruins palette: stone, moss, grass, thorns, crumbling sandstone, teal runes...
  textures/          Prototype grid textures
  ui/theme.tres      Project-wide UI theme
scenes/
  player/            player.tscn
  enemies/           mossling, sporeling (+ spore_projectile), snapthorn
  boss/              king_mossback, shockwave, falling_rock
  pickups/           coin, lost_sprite, health_pickup
  level/             Reusable level pieces (see "Building levels")
  levels/            level_ruins.tscn (the level), test_greybox.tscn (tuning sandbox)
  ui/                hud, main_menu, settings_menu, pause_menu, game_over_screen, results_screen
  test/              Test-only objects (training dummy)
scripts/
  player/  camera/  enemies/  boss/  pickups/  level/  ui/
  audio/             SfxSynth (sound recipes), MusicSynth (music loops)
  util/              HitStop, Fx (one-shot particles)
tools/               build_ruins_level.gd (level generator), generate_audio.gd (WAV generator)
tests/               Smoke tests (shared SmokeTestBase) and visual tours
```

## Where tuning values live

Every tuning value is an `@export` variable grouped with `@export_group`. Select the node and edit it in the Inspector:

| Node | Groups |
|---|---|
| **Player** (`scenes/player/player.tscn`) | Movement, Jump (height and time-to-peak; gravity is derived from them), Hover, Attack (timings, knockback, hit-stop), Health (hearts, invincibility, pit damage, respawn), Visuals (squash and stretch), Juice (dust, sparks, landing shake) |
| **RailCamera** (in each level) | Rail Following (damping, max speed, max lag, backtracking), Smoothing, Collision, Shake |
| **RailCameraKey** (children of `CameraRail`) | Framing (offset, FOV, look height, look-ahead, pitch), Follow, Blend, Lock |
| **Enemies** (`scenes/enemies/*.tscn`) | Health, Contact, Movement, Rewards, Activation, plus per-type Detection, Patrol, Chase, Lunge Attack, Spacing, Shooting, Snap Attack |
| **KingMossback** (`scenes/boss/king_mossback.tscn`) | Phases, Movement, Vulnerability, Ground Slam, Summon, Spore Barrage, Charge, Phase 3, Defeat |
| **BossArena** (in the level) | Arena, Intro, Falling Rocks, Victory |
| **Level pieces** | size, travel, cycle and pause times, crumble delay and respawn time, damage, hits to break... |
| **SettingsManager** (`autoload/settings_manager.gd`) | Defaults for the player-facing settings |

## Gameplay rules and defaults

- **Camera-relative movement**: "forward" is the camera's forward vector flattened onto the ground, so controls follow the rail camera around curves.
- **Jump**: holding jump gives a full jump (2.6 m). Releasing early cuts upward speed to 45%. Coyote time and the jump buffer are both 0.12 s.
- **Hover**: pressing jump in the air uses coyote time first, otherwise it starts the hover. The hover starts with a small pop, then falls slowly (1.4 m/s) while jump is held, for up to 1.2 s. It can't be used again until you land. Once it's used, a further press is buffered and becomes a jump on landing.
- **Attack**: the hitbox is only live during the active part of the swing. Each swing hits each target once, with hit-stop and a spark. It works on the ground (with a small lunge) and in the air (with a little hang time), and cancels a hover. **Attack priority**: while you're attacking, enemies in front of you can't hurt you by touch, so your swing wins the trade.
- **Damage**: 5 hearts. A hit gives 1.2 s of blinking invincibility, knockback and a camera shake.
- **Pits**: falling in costs 1 heart and returns you to the last checkpoint, keeping what you collected.
- **Defeat**: a short spin-out, then the **Game Over** screen offers Retry (back to the last checkpoint with full health, items rolled back to it) or Quit to Menu. This follows Kirby and the Forgotten Land: there are no lives. The tuning greybox respawns you automatically instead.
- **Physics interpolation** is on, so motion is smooth on high-refresh displays. Code that teleports a body should call `reset_physics_interpolation()`.

## Camera rail

The camera rides a rail (`Path3D`) that follows the player's route through the level.

- **Following the player**: each physics frame, `RailCamera` finds the point on the rail closest to the player (`curve.get_closest_offset()` in the path's local space). It moves its own progress toward that point, damped, capped at `rail_max_speed`, and never more than `max_lag_distance` away. With `allow_backward` off, it never moves back along the rail.
- **Camera keys**: `RailCameraKey` markers are children of the `Path3D`. Each key sets the framing for one segment: offset, FOV, look height, look-ahead, pitch, and how much the camera follows the player sideways and vertically.
  - A key takes effect from where it sits on the rail.
  - The camera blends into the next key over that key's `blend_in_distance`.
  - Offsets are relative to the rail's direction: `x` = right, `y` = up, `z` = back.
- **Look-ahead**: slides the camera and its aim point forward together rather than turning the camera. The camera's angle therefore comes only from the key, which keeps camera-relative controls steady: in a side-scroller, "right" always runs along the path.
- **Locked keys** (`locked`, `lock_camera_point`, `lock_look_point`): the camera holds a fixed shot, as in the boss arena.
- **Collision**: a sphere cast from the player to the camera pulls the camera in front of walls, then lets it ease back out. It uses the `world` layer. Fixed shots (locked keys and cutscene overrides) skip collision.
- **API**:
  - `shake(strength, duration)`: strength 0 to 1. It respects the Screen Shake setting.
  - `set_override(position, look, fov)` / `clear_override()`: cutscene shots.
  - `snap_to_target()`: jump straight to the player. The camera does this automatically on respawns.
- **Debug overlay (F3)**: draws the rail (cyan), the keys (orange; yellow when active; red when locked), the player's projected point (magenta) and the camera's rail position (green). It also lists progress, the active keys, the blend weight, FOV, collision and shake.

**Editing the rail and its key points**:
- Select `CameraRail` in the level and edit its curve with the Path3D tools.
- To add a segment, add a `Marker3D` child, attach `scripts/camera/rail_camera_key.gd`, and place it on the rail where the segment should start. Then set its framing.
- In the ruins level these are generated in `_build_camera_rail()` (see "The level generator" below).
- The greybox has six example keys: behind, angled 3/4, pulled back, curve, side-scroller and locked arena.

## The level: Overgrown Ruins

The route is about 390 m long. It runs north from the start, turns east at the colonnade, and ends in the throne arena. There are five segments, each with its own camera key:

| # | Segment | Camera | Contents |
|---|---|---|---|
| 1 | Courtyard | Behind, then angled 3/4 | Teaching steps, cracked wall hiding Lost Sprite 1, ramp, 3 m gap, 7 m hover gap, Mosslings introduced alone, checkpoint 1 |
| 2 | Colonnade | Side-scroller | Thorns, 3 m gap, moving platform over a 12 m pit, pillar stumps, crumbling bridge, a cracked wall blocking the path, Sporelings introduced, checkpoint 2 |
| 3 | Stairway | Angled 3/4, climbing | Stairs with thorns, ramp, 4 m lift, cracked wall hiding Lost Sprite 3, crumbling bridge, Snapthorns introduced, checkpoint 3 |
| 4 | Sunken Garden | Pulled back | Islands, moving platform, 8 m hover gap, thorn island, crumbling platforms, shortcut corridor behind a cracked wall, hidden lift to Lost Sprite 2, mixed enemies, checkpoint 4 |
| 5 | Throne Arena | Locked | King Mossback: entrance gate, 4 pillars, 4 outer platforms, throne, exit gate and goal |

**Colour language**:
- Crimson means a hazard.
- Gold means a collectible.
- Teal-topped stone moves.
- Orange cracked sandstone crumbles.
- Pale cracked stone breaks when attacked.

### Building levels

The reusable pieces are in `scenes/level/`:

| Scene | What it is |
|---|---|
| `platform.tscn` | Stone block with a moss cap (`GreyboxBlock`). It can be a box or a cylinder and builds its own mesh and collision from `size`. |
| `moving_platform.tscn` | Travels to `travel` and back, pausing at each end. The player rides it automatically. |
| `crumbling_platform.tscn` | Shakes when stood on, falls after `crumble_delay`, and comes back after `respawn_time`. |
| `thorn_patch.tscn` | A thorn hazard covering `size`. It damages the player on touch, with knockback. |
| `breakable_wall.tscn` | Breaks after `hits_to_break` attacks, with debris, dust, sound and a camera shake. |
| `checkpoint.tscn` | Crystal pedestal. Touching it sets the respawn point to its `SpawnPoint` child (facing its -Z) and autosaves. |
| `gate.tscn` | Barred gateway with `open()` and `close()`. |
| `level_goal.tscn` | End trigger. It completes the level and opens the results screen. |
| `kill_plane.tscn` | Pit trigger: costs 1 heart and returns you to the checkpoint. |

A playable level's root uses `scripts/level/level.gd` (`Level`). Point its exports at the `Player`, a `StartPoint` marker and the `RailCamera`. It handles the rest:
- Placing the player at the start, or at the checkpoint when continuing or restarting.
- The level timer and autosaving.
- The music.
- The pause menu, Game Over screen and results screen.
- The HUD (`scenes/ui/hud.tscn`), which should be instanced in the level.

**The level generator** (`tools/build_ruins_level.gd`) produces `level_ruins.tscn` from code. The output is an ordinary scene you can open and edit in the editor. Re-running the generator overwrites hand edits, so while the layout is still changing, make changes in the generator.
- **Adding a segment**: write a `_build_*` function using the `_ground`, `_box`, `_ramp`, `_pillar` and `_instance` helpers. Add a camera key in `_build_camera_rail()` and extend the rail's curve points.
- **Route check**: the Stage 3 test walks the camera rail and raycasts down every 0.5 m. Every gap must be 8.5 m or less, and every climb 2.3 m or less, unless a moving platform spans it. For reference, jump plus a full hover carries about 10.6 m.

## Enemies

All enemies extend `EnemyBase` (`scripts/enemies/enemy_base.gd`), which handles:
- **Hits**: health, a white hit flash, knockback, a short stun and brief invulnerability.
- **Contact damage**.
- **Death**: a puff, a sound, and dropped coin pickups.
- **Movement**: gravity, and ledge avoidance (enemies won't walk off drops deeper than `edge_check_depth`).
- **Sleeping** while the player is further than `active_distance`.

Every attack is telegraphed: the enemy glows orange (`set_telegraph()`) before it strikes, and a yellow "!" pops up when it first spots you.

| Enemy | Behaviour |
|---|---|
| **Mossling** (chaser) | Wanders near its spawn point. Within `detect_range` it shows "!" and chases. In lunge range it crouches and glows for `windup_time`, then lunges. It gives up beyond `lose_range`. 2 HP. |
| **Sporeling** (shooter) | Keeps between `retreat_distance` and `approach_distance` from you, strafing. When crowded it backs off, sliding sideways at ledges. Every `fire_interval` it swells and glows, then fires a slow spore at where you're standing. Spores pop on a hit or after `projectile_lifetime`. 2 HP. |
| **Snapthorn** (rooted plant) | Within `trigger_range` it rears back and glows, snaps forward (hitting anything in front of it), then rests. Knockback doesn't move it. 2 HP. |

- **Adding enemies to the level**: instance the scene under `Enemies` (its -Z is the direction it faces at start), or list it in `_build_enemies()` in the generator. Each type is introduced alone before being mixed with others.
- **New enemy types**: extend `EnemyBase` and implement `_ai_process(delta)`, plus optionally `_on_hurt()` and `_update_visual(delta)`. The scene needs a `Visual` node holding the meshes and a `ContactArea` (an `Area3D` with mask = player). Put the body on the `enemy` layer with mask = `world`.

## Collectibles, checkpoints and HUD

- **Coins**: about 120. They trace the route, and arcs of coins show where to jump over gaps. The hidden shortcut corridor is lined with them. Enemies drop coins that pop out, land, and blink away after 10 s.
- **Lost Sprites** (3, gold and glowing):
  - Sprite 1 is behind the courtyard's cracked wall.
  - Sprite 2 is on the floating platform reached by the hidden lift beside garden island B.
  - Sprite 3 is behind the cracked wall on the stairway's upper ledge.
- **Hearts**: restore 2 hearts. A heart is only picked up when you're hurt. There are three: after the colonnade's crumbling bridge, on the stairway's upper ledge, and before the boss gate.
- **Checkpoints** (4, plus the arena entrance during the boss fight) save the respawn point and a snapshot of what you've collected. Dying rolls coins, Lost Sprites and pickups back to that snapshot. Pits don't roll anything back.
- **HUD**: hearts, coin count and Lost Sprites (x/3) in the top-left, plus the boss health bar at the bottom during the fight. The icons are drawn in code (`HudIcon`), and everything runs on `GameState` signals.
- **Adding a pickup**: instance its scene anywhere in the level. Placed pickups are tracked by node path, so they persist through checkpoints. For a new kind of pickup, extend `Pickup` and override `_on_collected(player)` (and `can_collect(player)` if it needs a condition).

## Boss: King Mossback

The `BossArena` node in the level (`scripts/boss/boss_arena.gd`) runs the fight. The boss itself is `scenes/boss/king_mossback.tscn` (`KingMossback`, which extends `EnemyBase`).

- **Intro**: walking in closes the gate behind you, and the arena entrance becomes the respawn point. Your controls lock, the camera cuts to a close shot of the king, a name card plays, the boss bar appears and the boss music starts.
- **Hitting him**: he only takes damage in the **vulnerable window** after each attack. You can tell it's open by the dizzy stars, the pulsing gold glow and the floating "Attack!" label ("Dizzy! Attack!" after a pillar crash). Each window allows up to 3 hits. Hits outside a window clank off. A hit that lands flashes him, shakes the camera and adds hit-stop.
- **12 HP, three phases** (changing at 8 and 4 HP, each with a roar):
  1. **Ground slam**: a shockwave ring you jump over. **Summon**: Mosslings on the far side of the arena (at most 3 alive).
  2. **Spore barrage**: 3 rings of slow spores, each with a gap. **Charge**: if he hits a pillar or the throne he's stunned for a long window. If he misses, he stops at the edge with only a short opening.
  3. **Faster combos** (slam+charge, barrage+slam, charge+barrage). The outer platforms crumble away, and **rocks fall** onto red ground markers, about half of them aimed at you.
- **Defeat**: slow motion, debris, he topples and sinks, coins burst out and a victory jingle plays. The exit gate then opens to the goal.
- **Dying in the fight** resets him and the arena, and you respawn at the arena entrance for a quick restart. Continuing or restarting from that checkpoint also restarts the fight.
- **Tuning and testing**: `start_attack()` and `force_vulnerable()` are available for testing and tuning. The pillars and throne are in the `boss_pillar` group (the things his charge crashes into). He's on his own `boss` physics layer, so he's solid to the player but doesn't pull the camera in.

## Menus, settings and saving

- **Main menu**:
  - **Start** begins a new run.
  - **Continue** is enabled only when a run is in progress. It resumes at the saved checkpoint with the items you'd collected by then.
  - **Settings** and **Quit**.
  - Your best time, Lost Sprites and coins show below the buttons once you've finished the level.
- **Pause menu** (Esc / Start): Resume, Settings, Restart from Checkpoint and Main Menu. The game is paused underneath (`get_tree().paused`), and the menus use `PROCESS_MODE_ALWAYS`.
- **Results screen**: time, coins, Lost Sprites (x/3) and best time ("New best time!" when you beat it). It offers Replay and Main Menu.
- **Settings** (shared by both menus): every change is applied immediately and saved to `user://settings.cfg`.
  - Display: resolution (common 16:9 and 16:10 sizes), window mode (Windowed, Fullscreen, Borderless), V-Sync, FPS cap.
  - Audio: Master, Music and SFX volume (linear slider converted to dB on the buses).
  - Gameplay: camera smoothing, screen shake.
  - Graphics quality:

    | Preset | MSAA | Render scale | Shadows | SSAO and glow |
    |---|---|---|---|---|
    | Low | None | 75% | 1K, hard | Off |
    | Medium | 2x | 100% | 2K, soft | On |
    | High | 4x | 100% | 4K, softer | On |

  - Controls: keyboard/mouse and gamepad rebinding for every action, plus Reset Controls.
- **Save file** (`user://save.cfg`): progress is autosaved at the level start and at each checkpoint (level, checkpoint, the items you had at that checkpoint, and time). Finishing the level records best time, Lost Sprites and coins.
- **Fades**: scene changes fade through `SceneManager.change_scene()`.
- **Navigation**: every menu works with keyboard or gamepad. The first button is focused when a menu opens, disabled buttons are skipped, and `ui_cancel` backs out. Menus play UI sounds.

## Audio

- **Buses**: Master, Music, SFX and UI (`default_bus_layout.tres`).
- **Sound effects**: `AudioManager.play_sfx(&"name")` plays a sound, and `play_ui()` uses the UI bus.
- **Music**: `play_music(&"menu" | &"level" | &"boss")` loops a track, and `stop_music()` stops it.
- **Placeholder audio**: all audio is generated:
  - `scripts/audio/sfx_synth.gd` holds the sound recipes (tone sweeps, note sequences, filtered noise).
  - `scripts/audio/music_synth.gd` holds the music: chiptune loops with lead, bass and drums, written as note lists. The menu track is calm (C major, 92 BPM), the level track bouncy (F major, 128 BPM), and the boss track driving (D minor, 150 BPM).
  - `tools/generate_audio.gd` writes everything to `assets/audio/sfx/*.wav` and `assets/audio/music/*.wav`.
- **Swapping in real audio**: replace a WAV, or add an `.ogg` with the same name. AudioManager prefers files, falls back to the recipes, and loops music automatically.
- **Sounds**: coin, sprite, heal, checkpoint, wall_break, stone_hit, jump, hover, attack, hit, hurt, land, enemy_death, spore_fire, boss_roar, boss_slam, boss_charge, victory, ui_move, ui_select, ui_back.

## Physics layers

| # | Name | Used by |
|---|---|---|
| 1 | world | Level geometry, breakable walls, dummies (also the camera's collision layer) |
| 2 | player | Player body |
| 3 | enemy | Enemies and the boss (hit by the player's attack) |
| 4 | player_attack | Player attack hitbox |
| 5 | hazard | Damage areas, thorns, spores |
| 6 | breakable | Breakable walls |
| 7 | pickup | Collectibles |
| 8 | boss | King Mossback (solid to the player, ignored by the camera) |

## Extending

- **Hittable things**: implement `take_hit(damage: int, source_position: Vector3, knockback: float)` and put the body on the `enemy` or `breakable` layer.
- **Things that hurt the player**: call `player.take_damage(amount, source_position)`. `DamageArea` (and `ThornPatch`) do this for any overlapping body.
- **Greybox geometry**: add a `StaticBody3D`, attach `scripts/level/greybox_block.gd`, and set `size`, `material` and optionally a `top_material` cap.
- **Effects**: `Fx.puff()` and `Fx.chunks()` spawn one-shot particles. `HitStop.apply()` briefly slows time.
