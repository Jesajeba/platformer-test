extends Node
## Writes every placeholder sound effect and music loop to WAV files:
##   res://assets/audio/sfx/<name>.wav and res://assets/audio/music/{menu,level,boss}.wav
## Run: godot --headless --path . res://tools/generate_audio.tscn
## AudioManager prefers these files over the in-memory recipes, so replacing a WAV (or adding an
## .ogg with the same name) swaps in real audio without code changes.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const MUSIC_TRACKS: Array[StringName] = [&"menu", &"level", &"boss"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MUSIC_DIR))
	var failures: int = 0
	for sound: StringName in SfxSynth.SOUND_NAMES:
		failures += _write(SfxSynth.build(sound), SFX_DIR + String(sound) + ".wav")
	for track: StringName in MUSIC_TRACKS:
		failures += _write(MusicSynth.build(track), MUSIC_DIR + String(track) + ".wav")
	print("generate_audio: %d files, %d failures" % [SfxSynth.SOUND_NAMES.size() + MUSIC_TRACKS.size(), failures])
	get_tree().quit(failures)


func _write(stream: AudioStreamWAV, path: String) -> int:
	if stream == null:
		push_error("generate_audio: nothing to write for " + path)
		return 1
	var error: Error = stream.save_to_wav(path)
	if error != OK:
		push_error("generate_audio: failed to write %s (%s)" % [path, error_string(error)])
		return 1
	print("  %s  %.2f s" % [path, stream.get_length()])
	return 0
