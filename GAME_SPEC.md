# Task: Build a 3D platformer prototype in Godot 4 (GDScript)

Build a complete, playable vertical-slice prototype of a 3D platformer, inspired by the feel of Kirby and the Forgotten Land: cute, chunky, readable and forgiving. There are NO copy abilities, NO inhaling/swallowing and NO clone/duplication mechanics. The player has movement, jump, a short float, and a melee attack. Use placeholder art (primitive meshes, flat colors, simple materials) and generated placeholder audio. Prioritize game feel, clean structure and a complete playable loop over visuals.

## How to work
- Target Godot 4.3+ (use whatever 4.x version is installed; check with `godot --version`). GDScript only, with static typing (`var x: float`, typed function signatures).
- Create the project in the current directory. Build everything in code and .tscn/.tres text files so it's reproducible without the editor where possible.
- Work in the numbered stages below. After each stage: run `godot --headless --check-only` / `godot --headless --quit` (or a headless scene load) to catch parse and load errors, fix them, then make a git commit with a clear message. Don't move on while there are script errors.
- If a feature can't be verified headlessly (feel, visuals), say so in the stage summary and list exactly what I should test by hand.
- Ask me before making any major decision not covered here. Otherwise choose sensible defaults and document them in the README.
- Expose every tuning value (speeds, gravity, jump force, damage, camera offsets, boss timings) as `@export` variables, grouped with `@export_group`.

## Project structure (suggested)
res://
  scenes/ (player, enemies, boss, level, ui, camera, pickups, main.tscn)
  scripts/ (player, camera, enemies, boss, ui, systems, util)
  autoload/ (GameState, SettingsManager, AudioManager, SceneManager)
  assets/ (placeholder meshes/materials, generated audio)
  README.md

Autoloads: GameState (health, coins, collectibles, checkpoint, level timer), SettingsManager (load/save/apply settings), AudioManager (buses, play SFX/music), SceneManager (scene changes with fade).

## Stage 1: Player controller
- CharacterBody3D with camera-relative movement (movement direction is derived from the current camera's basis, so controls stay intuitive when the rail curves).
- Walk/run with acceleration and deceleration; rotate the model smoothly toward the move direction.
- Jump: variable height (hold for higher), coyote time, jump buffering.
- Float: pressing jump again in the air triggers a limited-duration hover (slow fall, can't be repeated until landing), Kirby-style.
- Melee attack: short-range, cooldown, Area3D hitbox active only during the attack window, small hit-stop and knockback on hit. The attack can damage enemies and destroy breakable walls.
- Health: 5 hearts, brief invincibility with a blink after damage, knockback, death -> respawn at last checkpoint (reset coins collected since the checkpoint is not required).
- Animation: placeholder procedural squash/stretch plus a simple state machine (idle, run, jump, fall, hover, attack, hurt, dead). Use a clean state machine (enum + match, or node-based states).
- Input Map actions defined in project.godot: move_left/right/forward/back, jump, attack, pause, plus UI actions. Support keyboard+mouse AND gamepad (Xbox/PlayStation layouts) with proper deadzones.
- Test scene: a flat greybox with a few ledges for tuning the feel.

## Stage 2: Camera on rails
- A Path3D with a Curve3D defines the camera rail. A rail camera script keeps the camera on the path.
- Each frame, find the closest point on the curve to the player (`curve.get_closest_offset()` on the player's position in the path's local space). Smoothly move the camera along the path toward that offset (damped, with a max speed). Optionally limit how far the camera can lag behind or move backward.
- The camera looks at the player (or a point slightly ahead of them) with configurable offset (side/up/back), distance and FOV.
- Per-segment camera overrides: keyed points along the rail (resource or Node3D markers with an offset-along-path value) define settings like offset, FOV, look-ahead and pitch. Blend smoothly between neighboring keys as the player progresses. Examples: side-scroller segment, angled 3/4 segment, pulled-back segment, and a locked boss-arena segment.
- Basic collision avoidance so the camera doesn't clip into walls (spring-arm style raycast).
- Optional screen shake API (`camera.shake(strength, duration)`) that respects the screen-shake setting.
- Debug overlay toggled with F3 (or similar): draw the curve, the player's projected point, camera key points and current blend values.
- Verify with the greybox test scene having a curving path.

## Stage 3: Greybox level (one complete level)
Theme: overgrown ancient ruins (stone, moss, vines, soft sunlit forest light). Placeholder visuals only, but use a coherent color palette so it reads clearly (e.g. warm stone, green moss, one accent color for collectibles and a different one for hazards).
- Linear path, about 5-8 minutes of play, split into 4-5 distinct segments, each with its own camera setup, ending in the boss arena.
- Platforming: gaps, static + moving + crumbling platforms, ramps/slopes, spikes or thorn hazards, pits that respawn at the last checkpoint.
- Obstacles and breakable walls hiding secrets or shortcuts.
- Build the level from reusable scenes (platform, moving platform, breakable wall, hazard, checkpoint) so I can extend it.
- Add a start point, an end/boss gate, and a kill-plane.

## Stage 4: Enemies (simple state machines, all with telegraphed attacks)
1. Chaser ("Mossling"): idles/patrols until the player enters detection range, then chases. Contact damage. Dies in 1-2 hits, with knockback and a little death puff.
2. Shooter ("Sporeling"): keeps its distance, fires a slow, dodgeable projectile at the player on a timer with a visible wind-up, and retreats/strafes if the player gets too close (kiting). Projectiles despawn on hit or after a timeout.
3. Simple extra for variety: a stationary thorn plant or a bouncing enemy.
- Enemies drop coins or add score on defeat. Common enemy base class for health, hit reaction, knockback and death.
- Place several of each type throughout the level with sensible encounter design (e.g. introduce one type alone before mixing).

## Stage 5: Collectibles, breakables, checkpoints
- Coins (spin/bob, collect SFX and particle).
- 3 hidden special collectibles per level (e.g. "Lost Sprites"), placed in secret areas behind breakable walls or tricky platforming. They're tracked on the HUD and the results screen.
- Health pickup.
- Breakable walls with a break particle effect, debris, and a SFX.
- At least 3 checkpoints. They save the respawn position and collected state of items.
- HUD: hearts, coin count, special collectible count (e.g. 0/3), and a small boss health bar during the boss fight.

## Stage 6: Boss fight: "King Mossback" (king of the ruins)
- A large placeholder boss (stone/moss king figure built from primitives) in a circular or square arena with a locked camera segment and a boss intro (brief camera move, name card).
- Boss health bar on the HUD. 3 phases with clear telegraphs, a vulnerability window after each attack, and hit feedback (flash, shake, hit-stop):
  - Phase 1: Ground slam sending out a shockwave ring the player must jump over, plus a summon of a couple of Mosslings.
  - Phase 2: Spore/projectile barrage in patterns the player can weave through, plus a charge attack toward the player that leaves the boss stunned (vulnerable) if it hits a wall/pillar.
  - Phase 3: Faster combos of the earlier attacks. The arena changes (outer platforms crumble, falling rocks with ground markers).
- Player damage rules are clear: tell the player when the boss is vulnerable.
- Defeat sequence: slow-mo/impact, particles, boss collapses, the arena gate opens and leads to the level-complete screen.
- Player death in the boss fight respawns at the arena entrance with the boss reset.

## Stage 7: Menus, settings, save
- Main menu: Start, Continue (enabled only if a save exists), Settings, Quit.
- Pause menu (Esc / Start button): Resume, Settings, Restart from checkpoint, Return to main menu. Use `process_mode = PROCESS_MODE_WHEN_PAUSED` so the tree is paused while the menu works.
- Settings menu (shared between main and pause menu), saved to `user://settings.cfg` via ConfigFile and applied immediately:
  - Display: resolution (list of common 16:9/16:10 options), window mode (windowed/fullscreen/borderless), V-Sync, optional FPS cap
  - Audio: Master, Music, SFX volume sliders (mapped to AudioServer buses, linear -> dB)
  - Gameplay: camera smoothing, screen shake on/off
  - Graphics: quality preset (low/medium/high: MSAA, shadows quality, etc.)
  - Controls: basic rebinding for keyboard/mouse and gamepad, with a "reset to default" button
- Level-complete screen: time, coins, special collectibles found (x/3), buttons for Replay and Main Menu. Game over screen with Retry and Quit to Menu.
- Full keyboard and gamepad navigation in every menu (proper focus handling, with the first button focused on open).
- Save file at `user://save.cfg` (progress, best time, collectibles).
- Fade transitions between scenes via SceneManager.

## Stage 8: Audio and polish
- Generate placeholder audio via a script (simple tone/noise WAVs or AudioStreamGenerator): music loops for menu, level and boss, and SFX for jump, hover, attack, hit, enemy death, collect coin, special collect, wall break, checkpoint, boss attacks, UI click/hover. Keep it easy to swap in real files later.
- Audio buses: Master, Music, SFX (plus UI optional), with sliders wired up.
- Lightweight juice: GPUParticles3D/CPUParticles3D for breaking, collecting, hits and landing dust; squash and stretch; screen shake on big impacts; hit-stop.
- Final pass: remove debug prints, make sure the game starts from main menu -> level -> boss -> results -> main menu without errors.

## Deliverables
1. A complete, runnable Godot project (opens and runs with F5 into the main menu).
2. README.md with: how to run, controls (keyboard and gamepad), project structure, how to edit the camera rail and its key points, how to add enemies/segments/collectibles, and where tuning values live.
3. KNOWN_ISSUES.md listing limitations and suggested next steps.
4. A git history with one commit per stage.

Begin with Stage 1. Before writing code, briefly confirm your plan and flag any open questions.
