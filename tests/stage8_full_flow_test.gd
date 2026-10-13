extends SmokeTestBase
## End-to-end check for Stage 8: main menu -> level -> boss -> results -> main menu, with music
## switching at each step, plus the generated audio files. Run it and also check the output for
## engine errors:  godot --headless --path . res://tests/stage8_full_flow_test.tscn

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"


func _init() -> void:
	level_scene = null


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var placeholder: Node = Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	GameState.start_new_run()
	_test_audio_files()

	# Main menu.
	SceneManager.change_scene(SceneManager.MAIN_MENU)
	await _wait_scene()
	var menu: MainMenu = get_tree().current_scene as MainMenu
	_check("game starts at the main menu", menu != null)
	_check("menu music plays", AudioManager.get_current_music() == &"menu")

	# Level.
	menu.start_button.pressed.emit()
	await _wait_scene()
	var level: Level = get_tree().current_scene as Level
	_check("Start -> level", level != null)
	_check("level music plays", AudioManager.get_current_music() == &"level")
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	_player = level.player
	_camera = level.camera
	_level = level
	var sounds_before: int = AudioManager.play_count
	await _press_jump()
	Input.action_release("jump")
	await _frames(40)
	_check("jumping plays sounds (jump/land)", AudioManager.play_count > sounds_before)

	# Boss.
	var arena: BossArena = level.get_node("BossArena") as BossArena
	var boss: KingMossback = arena.boss
	_teleport(Vector3(259.5, 10.05, -80))
	await _wait_until(func() -> bool: return arena.get_state() == BossArena.State.FIGHTING, 300)
	_check("entering the arena starts the boss fight", arena.get_state() == BossArena.State.FIGHTING)
	_check("boss music plays during the fight", AudioManager.get_current_music() == &"boss")
	boss.idle_time = 999.0
	boss.phase = 3
	boss.health = 1
	boss.force_vulnerable(5.0)
	boss.take_hit(1, boss.global_position + Vector3(0, 0, 3), 9.0)
	var opened: bool = await _wait_until(func() -> bool: return arena.exit_gate.is_open(), 600)
	_check("boss defeated, exit gate opens", opened)
	_check("victory stops the boss music", AudioManager.get_current_music() == &"")

	# Goal -> results -> main menu.
	await _frames(70)
	var goal: Node3D = level.find_child("LevelGoal", true, false) as Node3D
	_teleport(goal.global_position + Vector3(0, 0.1, 0))
	var shown: bool = await _wait_until(func() -> bool: return level.results_screen.is_open(), 200)
	_check("goal -> results screen", shown)
	level.results_screen.menu_button.pressed.emit()
	await _wait_scene()
	menu = get_tree().current_scene as MainMenu
	_check("results -> main menu", menu != null and not get_tree().paused)
	_check("menu music again", AudioManager.get_current_music() == &"menu")
	_check("the run is recorded", GameState.get_records(SceneManager.FIRST_LEVEL)["completed"])


func _test_audio_files() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for sound: StringName in SfxSynth.SOUND_NAMES:
		var path: String = SFX_DIR + String(sound) + ".wav"
		if not ResourceLoader.exists(path) or not (load(path) is AudioStream) or (load(path) as AudioStream).get_length() <= 0.0:
			missing.append(String(sound))
	_check("every sound effect has a generated WAV", missing.is_empty(), ", ".join(missing))
	var tracks_ok: bool = true
	for track: String in ["menu", "level", "boss"]:
		var stream: AudioStream = load(MUSIC_DIR + track + ".wav") as AudioStream
		tracks_ok = tracks_ok and stream != null and stream.get_length() > 8.0
	_check("menu, level and boss music loops exist (8+ s each)", tracks_ok)
	AudioManager.play_music(&"menu")
	var wav: AudioStreamWAV = AudioManager._music_player.stream as AudioStreamWAV
	_check("music is set to loop", wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_end > 0)
	AudioManager.stop_music()


func _wait_scene() -> void:
	await _frames(2)
	await _wait_until(func() -> bool: return not SceneManager.is_busy(), 240)
	await _frames(2)
