class_name SfxSynth
extends RefCounted
## Tiny procedural synth for placeholder sound effects. Builds mono 16-bit AudioStreamWAVs
## from tone sweeps, note sequences and filtered noise. Recipes live in `build()`.

const MIX_RATE: int = 22050
## Every sound with a recipe (tools/generate_audio.gd writes these to assets/audio/sfx/).
const SOUND_NAMES: Array[StringName] = [&"coin", &"sprite", &"heal", &"checkpoint", &"wall_break", &"stone_hit",
	&"jump", &"hover", &"attack", &"hit", &"hurt", &"enemy_death", &"spore_fire", &"land", &"boss_roar",
	&"boss_slam", &"boss_charge", &"victory", &"ui_move", &"ui_select", &"ui_back"]

enum Wave { SINE, SQUARE, TRIANGLE, SAW, NOISE }


## Returns a generated stream for a named sound, or null if there's no recipe.
static func build(sound_name: StringName) -> AudioStreamWAV:
	var samples: PackedFloat32Array
	match sound_name:
		&"coin":
			samples = sequence([[988.0, 0.06], [1319.0, 0.2]], Wave.SQUARE, 0.28)
		&"sprite":
			samples = mix(sequence([[1047.0, 0.08], [1319.0, 0.08], [1568.0, 0.08], [2093.0, 0.35]], Wave.TRIANGLE, 0.45),
				tone(4000.0, 6000.0, 0.6, Wave.SINE, 0.08, 0.01, 0.5, 30.0))
		&"heal":
			samples = mix(tone(400.0, 900.0, 0.25, Wave.TRIANGLE, 0.4), delay(sequence([[1175.0, 0.2]], Wave.SINE, 0.3), 0.18))
		&"checkpoint":
			samples = sequence([[784.0, 0.09], [988.0, 0.09], [1175.0, 0.09], [1568.0, 0.3]], Wave.TRIANGLE, 0.4)
		&"wall_break":
			samples = mix(noise(0.45, 0.6, 0.25, 0.002, 0.35), tone(140.0, 45.0, 0.3, Wave.SQUARE, 0.35, 0.002, 0.2))
		&"stone_hit":
			samples = mix(noise(0.12, 0.45, 0.3, 0.001, 0.1), tone(180.0, 90.0, 0.1, Wave.SQUARE, 0.25, 0.001, 0.08))
		&"jump":
			samples = tone(320.0, 620.0, 0.13, Wave.SQUARE, 0.22, 0.002, 0.06)
		&"hover":
			samples = tone(520.0, 700.0, 0.3, Wave.TRIANGLE, 0.3, 0.01, 0.15, 9.0)
		&"attack":
			samples = mix(noise(0.14, 0.35, 0.7, 0.005, 0.1), tone(900.0, 300.0, 0.1, Wave.SAW, 0.12))
		&"hit":
			samples = mix(noise(0.08, 0.55, 0.45, 0.001, 0.06), tone(240.0, 80.0, 0.12, Wave.SQUARE, 0.35, 0.001, 0.08))
		&"hurt":
			samples = tone(420.0, 140.0, 0.3, Wave.SQUARE, 0.3, 0.002, 0.15, 14.0)
		&"enemy_death":
			samples = mix(tone(700.0, 90.0, 0.3, Wave.SQUARE, 0.25), noise(0.25, 0.3, 0.35, 0.01, 0.2))
		&"spore_fire":
			samples = tone(330.0, 180.0, 0.18, Wave.SINE, 0.5, 0.005, 0.1, 20.0)
		&"land":
			samples = noise(0.08, 0.25, 0.15, 0.001, 0.07)
		&"boss_roar":
			samples = mix(tone(120.0, 70.0, 0.9, Wave.SAW, 0.4, 0.05, 0.4, 7.0), noise(0.9, 0.25, 0.15, 0.05, 0.5))
		&"boss_slam":
			samples = mix(noise(0.6, 0.7, 0.18, 0.001, 0.5), tone(95.0, 32.0, 0.5, Wave.SQUARE, 0.45, 0.001, 0.3))
		&"boss_charge":
			samples = mix(tone(180.0, 460.0, 0.4, Wave.SAW, 0.3, 0.01, 0.15), noise(0.4, 0.2, 0.5, 0.05, 0.2))
		&"victory":
			samples = sequence([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.22], [784.0, 0.1], [1047.0, 0.5]], Wave.TRIANGLE, 0.45)
		&"ui_move":
			samples = tone(1200.0, 1200.0, 0.035, Wave.SQUARE, 0.15, 0.001, 0.02)
		&"ui_select":
			samples = sequence([[880.0, 0.04], [1320.0, 0.09]], Wave.SQUARE, 0.2)
		&"ui_back":
			samples = sequence([[660.0, 0.04], [440.0, 0.09]], Wave.SQUARE, 0.2)
		_:
			return null
	return to_stream(samples)


#region Generators

## A single tone sweeping from `freq_start` to `freq_end` with a linear attack/release envelope.
static func tone(freq_start: float, freq_end: float, duration: float, wave: Wave = Wave.SQUARE, volume: float = 0.5,
		attack: float = 0.005, release: float = 0.08, vibrato_hz: float = 0.0) -> PackedFloat32Array:
	var count: int = int(duration * MIX_RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	var hold: float = 0.0
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var progress: float = t / duration
		var freq: float = lerpf(freq_start, freq_end, progress)
		if vibrato_hz > 0.0:
			freq *= 1.0 + 0.04 * sin(TAU * vibrato_hz * t)
		var previous: float = phase
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		if wave == Wave.NOISE and phase < previous:
			hold = randf_range(-1.0, 1.0)
		out[i] = _wave_value(wave, phase, hold) * volume * _envelope(t, duration, attack, release)
	return out


## Notes played back to back: [[frequency, duration], ...].
static func sequence(notes: Array, wave: Wave = Wave.SQUARE, volume: float = 0.4) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for note: Array in notes:
		out.append_array(tone(note[0], note[0], note[1], wave, volume, 0.003, minf(0.05, note[1] * 0.5)))
	return out


## White noise through a one-pole low-pass (`brightness` 0..1, higher = brighter).
static func noise(duration: float, volume: float = 0.5, brightness: float = 0.5, attack: float = 0.002,
		release: float = 0.1) -> PackedFloat32Array:
	var count: int = int(duration * MIX_RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var filtered: float = 0.0
	var alpha: float = clampf(brightness, 0.01, 1.0)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		filtered += alpha * (randf_range(-1.0, 1.0) - filtered)
		out[i] = filtered * volume * _envelope(t, duration, attack, release) * (1.5 if alpha < 0.5 else 1.0)
	return out


## Sums two sample buffers (the result is as long as the longer one).
static func mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other: PackedFloat32Array = b if a.size() >= b.size() else a
	for i: int in other.size():
		out[i] = clampf(out[i] + other[i], -1.0, 1.0)
	return out


## Prepends `seconds` of silence.
static func delay(samples: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(seconds * MIX_RATE))
	out.append_array(samples)
	return out


static func to_stream(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream

#endregion


static func _wave_value(wave: Wave, phase: float, hold: float) -> float:
	match wave:
		Wave.SINE:
			return sin(TAU * phase)
		Wave.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		Wave.TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		Wave.SAW:
			return 2.0 * phase - 1.0
		_:
			return hold


static func _envelope(t: float, duration: float, attack: float, release: float) -> float:
	var a: float = clampf(t / maxf(attack, 0.0001), 0.0, 1.0)
	var r: float = clampf((duration - t) / maxf(release, 0.0001), 0.0, 1.0)
	return a * r
