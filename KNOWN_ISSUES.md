# Known issues and next steps

## Not verified by automation

The test suites cover logic, flow and placement: 278 checks across 8 suites, plus a windowed end-to-end run. They can't judge feel. These still need hands-on play:

- **Game feel**:
  - Jump and hover tuning.
  - Attack timing and hit-stop strength.
  - Camera smoothing and segment framing.
  - Boss difficulty: window lengths, spore speed, charge speed.
- **Gamepads**: testing was done with simulated input. Real Xbox and PlayStation pads haven't been tried, including the stick deadzone and rebinding by pressing a gamepad button.
- **Audio**: the sounds and music are generated and have only been checked programmatically (every file loads, the music loops, levels are normalised). Nobody has listened to them yet, and the mix may need balancing.
- **Display**: window mode, resolution and V-Sync changes are applied by the settings, but on headless runs they're skipped. Check them on your monitors.

## Limitations

- **Placeholder content**: primitive meshes, flat colours and generated chiptune audio. There are no animations beyond procedural squash and stretch, and no real character model.
- **One level**: the level is built by `tools/build_ruins_level.gd`. Re-running the generator overwrites hand edits to `level_ruins.tscn`. When the layout is final, stop using the generator and edit the scene directly.
- **Enemies stay defeated** after you die and respawn. Only collectibles roll back to the checkpoint. This is forgiving, but means a death-heavy section gets easier.
- **Fixed boss camera**: in the arena the player can occasionally be hidden behind a pillar. The pillars were lowered to 3.5 m to reduce this. A see-through silhouette for the player would fix it properly.
- **Ledge-avoiding enemies won't step down drops** deeper than 0.8 m, so enemies never follow you down a level.
- **Rail tracking**: the camera picks the closest point on the rail. A route that loops back close to itself could make the camera jump between the two passes. The current level doesn't do this.
- **No gizmos**: moving platforms show their travel only while running, and camera keys have no editor preview of their framing (use F3 in game).
- **Settings resolution** applies to the windowed mode only. Fullscreen uses the desktop resolution.
- **Headless-only warning**: test runs in `--headless` mode can print "2 ObjectDB instances were leaked at exit" (and "1 resources still in use"). That's Godot's dummy audio driver never finishing the last sound's playback. Windowed runs with a real audio driver are clean.
- **Coin persistence** is tracked by node path, so renaming or moving placed pickups breaks old saves' collected state. Saves made by an older build may show some items again.

## Suggested next steps

1. **Playtest and tune**: jump arc, hover length, boss windows, camera framing per segment. All of these are `@export` values.
2. **Art pass**:
   - Character model and animations (`AnimationTree` driven by the existing player states).
   - Modular ruin pieces to replace the boxes, foliage, and light shafts.
   - A player silhouette shader for occlusion.
3. **Audio pass**: real music and SFX dropped into `assets/audio/`, plus music crossfades.
4. **Respawn enemies at checkpoints** (optional), using the same snapshot idea as collectibles.
5. **Editor tooling**: gizmos for `MovingPlatform` travel and `RailCameraKey` framing. Optionally a dock to preview the camera at any rail offset.
6. **More levels**, with a level-select hub on the main menu (records are already stored per level).
7. **Accessibility**: hold-to-hover toggle, adjustable hit-stop, colour-blind-safe hazard markers (crimson vs. gold already differ in brightness), subtitles for audio cues.
8. **Save robustness**: give placed pickups stable IDs (exported) instead of node paths. Add a save version number for migrations.
