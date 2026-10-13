extends Node
## Plays sound effects (and, from Stage 8, music) on the Music / SFX / UI buses.
##
## Sounds are looked up by name: a file at res://assets/audio/sfx/<name>.wav (or .ogg) wins,
## otherwise the placeholder recipe in SfxSynth is used. Drop real files in to replace them.

const SFX_DIR: String = "res://assets/audio/sfx/"
const POOL_SIZE: int = 16

## Name of the most recently played sound (handy for tests and debugging).
var last_played: StringName = &""
var play_count: int = 0

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)


## Plays a one-shot sound effect. `pitch_jitter` randomizes pitch by up to +/- that fraction.
func play_sfx(sound_name: StringName, pitch_jitter: float = 0.05, volume_db: float = 0.0, bus: StringName = &"SFX") -> void:
	var stream: AudioStream = get_stream(sound_name)
	if stream == null:
		push_warning("AudioManager: no sound named '%s'" % sound_name)
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()
	last_played = sound_name
	play_count += 1


func play_ui(sound_name: StringName) -> void:
	play_sfx(sound_name, 0.0, 0.0, &"UI")


func get_stream(sound_name: StringName) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var stream: AudioStream = null
	for extension: String in [".wav", ".ogg"]:
		var path: String = SFX_DIR + String(sound_name) + extension
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		stream = SfxSynth.build(sound_name)
	_cache[sound_name] = stream
	return stream
