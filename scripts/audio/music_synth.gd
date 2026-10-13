class_name MusicSynth
extends RefCounted
## Renders the placeholder chiptune music loops (menu, level, boss): a lead melody, a bass
## line and drums, written as note lists on a 16th-note grid. Each track loops seamlessly.

const RATE: int = SfxSynth.MIX_RATE

## Note names to MIDI numbers (octave 4 = middle C).
const NOTES: Dictionary = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
	"G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


static func render(track: StringName) -> PackedFloat32Array:
	match track:
		&"menu":
			return _render_menu()
		&"level":
			return _render_level()
		&"boss":
			return _render_boss()
	return PackedFloat32Array()


static func build(track: StringName) -> AudioStreamWAV:
	var samples: PackedFloat32Array = render(track)
	return null if samples.is_empty() else SfxSynth.to_stream(samples, true)


#region Tracks

## Calm and warm: C - Am - F - G, 92 BPM.
static func _render_menu() -> PackedFloat32Array:
	var song: Dictionary = _song(92.0, 8)
	_melody(song, "E5 4 G5 4 C6 8 | B5 4 A5 4 G5 8 | A5 4 C6 4 E6 8 | D6 4 C6 4 A5 8 | F5 4 A5 4 C6 8 | A5 4 G5 4 F5 8 | G5 4 B5 4 D6 4 B5 4 | G5 8 D5 6 - 2",
		SfxSynth.Wave.TRIANGLE, 0.2)
	_melody(song, "C3 8 G3 8 | C3 8 G3 8 | A2 8 E3 8 | A2 8 E3 8 | F2 8 C3 8 | F2 8 C3 8 | G2 8 D3 8 | G2 8 D3 8",
		SfxSynth.Wave.SINE, 0.28)
	_drums(song, "....h.......h...", 0.0, 0.0, 0.05)
	return _finish(song)


## Bouncy: F - Dm - Bb - C, 128 BPM.
static func _render_level() -> PackedFloat32Array:
	var song: Dictionary = _song(128.0, 8)
	_melody(song, "C5 2 F5 2 A5 2 C6 2 A5 2 F5 2 A5 4 | G5 2 A5 2 Bb5 2 A5 2 G5 4 F5 4 | D5 2 F5 2 A5 2 D6 2 C6 2 A5 2 F5 4 | E5 2 F5 2 G5 2 A5 2 F5 8 | D5 2 F5 2 Bb5 2 D6 2 C6 2 Bb5 2 A5 4 | G5 2 A5 2 Bb5 2 C6 2 D6 8 | E5 2 G5 2 C6 2 E6 2 D6 2 C6 2 Bb5 4 | A5 2 G5 2 E5 2 G5 2 C6 6 - 2",
		SfxSynth.Wave.SQUARE, 0.11)
	_melody(song, _octave_bass(["F2", "F2", "D2", "D2", "Bb1", "Bb1", "C2", "C2"]), SfxSynth.Wave.TRIANGLE, 0.32)
	_drums(song, "k...s...k.k.s...", 0.45, 0.22, 0.06, "h.h.h.h.h.h.h.h.")
	return _finish(song)


## Driving and tense: Dm - Bb - C - A, 150 BPM.
static func _render_boss() -> PackedFloat32Array:
	var song: Dictionary = _song(150.0, 8)
	_melody(song, "D5 2 D5 2 F5 2 D5 2 A5 2 D5 2 G5 2 F5 2 | E5 2 D5 2 C5 2 D5 2 F5 2 E5 2 D5 2 A4 2 | D5 2 D5 2 F5 2 D5 2 Bb5 2 D5 2 A5 2 F5 2 | G5 2 F5 2 E5 2 F5 2 D5 2 E5 2 F5 2 G5 2 | E5 2 E5 2 G5 2 E5 2 C6 2 E5 2 Bb5 2 G5 2 | A5 2 G5 2 F5 2 G5 2 E5 2 F5 2 G5 2 E5 2 | E5 2 E5 2 A5 2 E5 2 C#6 2 E5 2 B5 2 A5 2 | A5 2 G5 2 F5 2 E5 2 C#5 2 D5 2 E5 2 C#5 2",
		SfxSynth.Wave.SAW, 0.09)
	var bass: PackedStringArray = PackedStringArray()
	for root: String in ["D2", "D2", "Bb1", "Bb1", "C2", "C2", "A1", "A1"]:
		bass.append(" ".join(_repeat(root + " 2", 8)))  # Driving 8th notes on the root.
	_melody(song, " | ".join(bass), SfxSynth.Wave.SQUARE, 0.13)
	_drums(song, "k.k.s.k.k.k.s.ks", 0.5, 0.26, 0.05, "hhhhhhhhhhhhhhhh")
	return _finish(song)

#endregion


#region Rendering

static func _song(bpm: float, bars: int) -> Dictionary:
	var step: float = 60.0 / bpm / 4.0
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(int(round(step * 16.0 * bars * RATE)))
	return {"step": step, "bars": bars, "buffer": buffer}


## Adds a part written as "NOTE STEPS NOTE STEPS ... | ..." ("-" = rest, bars separated by "|").
static func _melody(song: Dictionary, part: String, wave: SfxSynth.Wave, volume: float) -> void:
	var tokens: PackedStringArray = part.replace("|", " ").split(" ", false)
	var position: int = 0
	var i: int = 0
	while i + 1 < tokens.size():
		var note: String = tokens[i]
		var steps: int = int(tokens[i + 1])
		if note != "-":
			_add_note(song, position, steps, _frequency(note), wave, volume)
		position += steps
		i += 2


## Root/octave bounce in 8th notes, one chord root per bar.
static func _octave_bass(roots: Array) -> String:
	var bars: PackedStringArray = PackedStringArray()
	for root: String in roots:
		var high: String = root.left(root.length() - 1) + str(int(root.right(1)) + 1)
		bars.append(" ".join(PackedStringArray([root + " 2", high + " 2", root + " 2", high + " 2", root + " 2", high + " 2", root + " 2", high + " 2"])))
	return " | ".join(bars)


static func _repeat(token: String, count: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for i: int in count:
		out.append(token)
	return out


## Drum pattern per bar (16 steps): k = kick, s = snare, h = hi-hat. `hats` overrides the hat line.
static func _drums(song: Dictionary, pattern: String, kick_volume: float, snare_volume: float, hat_volume: float, hats: String = "") -> void:
	var step: float = song["step"]
	for bar: int in song["bars"]:
		for s: int in 16:
			var start: int = int(round((bar * 16 + s) * step * RATE))
			var hit: String = pattern[s]
			if hit == "k" and kick_volume > 0.0:
				_mix_at(song, start, SfxSynth.tone(150.0, 45.0, 0.16, SfxSynth.Wave.SINE, kick_volume, 0.001, 0.08))
			elif hit == "s" and snare_volume > 0.0:
				_mix_at(song, start, SfxSynth.noise(0.12, snare_volume, 0.6, 0.001, 0.1))
			if hat_volume > 0.0 and ((hats != "" and hats[s] == "h") or (hats == "" and hit == "h")):
				_mix_at(song, start, SfxSynth.noise(0.035, hat_volume, 1.0, 0.0005, 0.03))


static func _add_note(song: Dictionary, position: int, steps: int, frequency: float, wave: SfxSynth.Wave, volume: float) -> void:
	var step: float = song["step"]
	var duration: float = steps * step * 0.92
	var start: int = int(round(position * step * RATE))
	_mix_at(song, start, SfxSynth.tone(frequency, frequency, duration, wave, volume, 0.006, minf(0.06, duration * 0.4)))


## Adds samples into the song buffer, wrapping past the end so the loop stays seamless.
static func _mix_at(song: Dictionary, start: int, samples: PackedFloat32Array) -> void:
	var buffer: PackedFloat32Array = song["buffer"]
	var length: int = buffer.size()
	for i: int in samples.size():
		var index: int = (start + i) % length
		buffer[index] += samples[i]
	song["buffer"] = buffer


static func _finish(song: Dictionary) -> PackedFloat32Array:
	var buffer: PackedFloat32Array = song["buffer"]
	var peak: float = 0.001
	for v: float in buffer:
		peak = maxf(peak, absf(v))
	var gain: float = 0.85 / peak
	for i: int in buffer.size():
		buffer[i] *= gain
	return buffer


static func _frequency(note: String) -> float:
	var octave: int = int(note.right(1))
	var name: String = note.left(note.length() - 1)
	var midi: int = 12 * (octave + 1) + NOTES[name]
	return 440.0 * pow(2.0, (midi - 69) / 12.0)

#endregion
