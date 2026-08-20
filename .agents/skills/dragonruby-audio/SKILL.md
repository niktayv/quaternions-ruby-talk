---
name: dragonruby-audio
description: Advanced audio in DragonRuby GTK — spatial audio, procedural synthesis, beat synchronisation, crossfading, audio queues. Use when the user asks about DragonRuby music, sound effects beyond basic playback, rhythm games, or generated audio.
---

This skill covers advanced DragonRuby audio patterns. For basic sound playback see the main `dragonruby` skill.

The `args.audio` / `args.outputs.sounds` API surface lives in the main
`dragonruby` skill's Audio section — one home per topic. This skill starts
where that API ends.

## Spatial Audio

Map screen coordinates to the normalised -1..1 range the engine expects:

```ruby
def screen_to_audio_x(screen_x, screen_w = 1280)
  (screen_x / screen_w.to_f * 2.0) - 1.0
end

def screen_to_audio_y(screen_y, screen_h = 720)
  (screen_y / screen_h.to_f * 2.0) - 1.0
end

# Attach audio position to a moving entity:
args.audio[:explosion] = {
  input: 'sounds/boom.wav',
  x: screen_to_audio_x(entity.x),
  y: screen_to_audio_y(entity.y),
  z: 0.0,
  gain: 1.0
}

# Update position each tick for a moving source:
if args.audio[:engine]
  args.audio[:engine].x = screen_to_audio_x(ship.x)
  args.audio[:engine].y = screen_to_audio_y(ship.y)
end
```

You can hang arbitrary metadata on the audio hash for convenience — extra keys are ignored by the engine:
```ruby
args.audio[:sfx] = {
  input: 'sounds/laser.wav',
  gain: 1.0,
  # custom metadata:
  source_entity_id: enemy.entity_id,
  started_at: Kernel.tick_count
}
```

## Crossfading Between Tracks

Smoothly transition between two loops without clicks:

```ruby
def tick_music(args)
  args.state.main_track  ||= :track_a
  args.state.other_track ||= :track_b

  args.audio[:track_a] ||= { input: 'sounds/music_a.ogg', looping: true, gain: 1.0 }
  args.audio[:track_b] ||= { input: 'sounds/music_b.ogg', looping: true, gain: 0.0 }

  # Trigger crossfade every 600 ticks (10 seconds):
  if Kernel.tick_count.zmod?(600)
    args.state.main_track, args.state.other_track =
      args.state.other_track, args.state.main_track
  end

  # Fade toward targets:
  target_a = args.state.main_track == :track_a ? 1.0 : 0.0
  target_b = args.state.main_track == :track_b ? 1.0 : 0.0
  args.audio[:track_a].gain = args.audio[:track_a].gain.lerp(target_a, 0.02)
  args.audio[:track_b].gain = args.audio[:track_b].gain.lerp(target_b, 0.02)
end
```

## Audio Queue with Timed Playback

Decouple scheduling from playback — queue audio for future ticks:

```ruby
args.state.audio_queue ||= []

# Schedule a sound:
args.state.audio_queue << {
  id:       :"sfx_#{Kernel.tick_count}",
  input:    'sounds/beep.wav',
  gain:     0.8,
  queue_at: Kernel.tick_count + 30   # play in 0.5 seconds
}

# Process queue each tick:
def process_audio_queue(args)
  ready, pending = args.state.audio_queue.partition { |e| e[:queue_at] <= Kernel.tick_count }
  args.state.audio_queue = pending
  ready.each { |e| args.audio[e[:id]] = e }
end
```

## Gain Decay (Natural Fade-out)

Apply a per-tick decay rate instead of manual envelope tracking:

```ruby
args.audio.each do |id, track|
  next unless track.is_a?(Hash) && track[:decay_rate]
  track[:gain] -= track[:decay_rate]
  args.audio.delete(id) if track[:gain] <= 0
end

# Create a decaying sound:
duration_ticks = 120
args.audio[:boom] = {
  input: 'sounds/explosion.wav',
  gain: 1.0,
  decay_rate: 1.0 / duration_ticks
}
```

## Procedural Synthesis

Generate audio from code using mathematical wave functions.

### Sine wave
```ruby
def sine_wave(frequency: 440, duration_ticks: 60, gain: 0.5)
  sample_rate = 44100
  num_samples = (sample_rate * duration_ticks / 60.0).ceil
  samples = num_samples.map do |i|
    gain * Math.sin(2.0 * Math::PI * frequency * i / sample_rate)
  end
  [2, sample_rate, samples]   # [channels, sample_rate, data]
end

args.audio[:beep] = { input: sine_wave(frequency: 880, duration_ticks: 30) }
```

### Caching by frequency
```ruby
args.state.wave_cache ||= {}
args.state.wave_cache[440] ||= sine_wave(frequency: 440, duration_ticks: 60)
args.audio[:note_a] = { input: args.state.wave_cache[440] }
```

### Harmonic decomposition (bell-like timbres)
```ruby
def bell_sound(fundamental: 440)
  harmonics = [
    { ratio: 0.5, gain: 1.0, duration: 120 },
    { ratio: 1.0, gain: 0.8, duration: 90 },
    { ratio: 2.0, gain: 0.5, duration: 60 },
    { ratio: 3.0, gain: 0.3, duration: 40 }
  ]
  harmonics.map.with_index do |h, i|
    id = :"bell_harmonic_#{Kernel.tick_count}_#{i}"
    args.audio[id] = {
      input: sine_wave(frequency: fundamental * h[:ratio],
                       duration_ticks: h[:duration],
                       gain: h[:gain]),
      decay_rate: h[:gain] / h[:duration]
    }
  end
end
```

### Interactive slider for real-time pitch/gain control
```ruby
slider_rect = { x: 100, y: 300, w: 400, h: 20 }

if args.inputs.mouse.held && args.inputs.mouse.inside_rect?(slider_rect)
  t = (args.inputs.mouse.x - slider_rect[:x]).to_f / (slider_rect[:w] - 1)
  args.audio[:synth].pitch = 0.5 + t * 1.5   # 0.5x to 2.0x pitch
end
```

## Beat Synchronisation

Accumulate fractional beats per tick to avoid rhythmic drift:

```ruby
BPM = 120.0
args.state.beat_accumulator ||= 0.0
args.state.beats_per_tick   ||= BPM / (60.0 * 60)   # beats per tick at 60fps

args.state.beat_accumulator += args.state.beats_per_tick
current_beat = args.state.beat_accumulator.to_i

if current_beat != args.state.last_beat
  args.state.last_beat = current_beat
  # Fire on each beat:
  args.outputs.sounds << 'sounds/kick.wav' if (current_beat % 4) == 0
  args.outputs.sounds << 'sounds/snare.wav' if (current_beat % 4) == 2
end
```

### Latency calibration
```ruby
# Allow player to tap to calibrate audio latency
if args.inputs.keyboard.key_down.space
  expected_beat_tick = args.state.quarter_beat_occurred_at
  actual_tick        = Kernel.tick_count
  args.state.calibration_ticks += (actual_tick - expected_beat_tick) / 2
end
```

## Note Mapping (Musical Scale)

```ruby
A4 = 440.0

NOTE_OFFSETS = {
  c: -9, d: -7, e: -5, f: -4, g: -2, a: 0, b: 2
}

def note_frequency(note, octave = 4)
  semitones = NOTE_OFFSETS[note] + (octave - 4) * 12
  A4 * (2.0 ** (semitones / 12.0))
end

# Usage:
freq = note_frequency(:c, 4)   # => ~261.6 Hz (Middle C)
```

## Waveform Visualisation

Render a waveform for debugging/aesthetics:

```ruby
def render_waveform(args, samples, rect)
  x_scale = rect[:w].to_f / samples.length
  y_scale = rect[:h] / 2.0
  cy = rect[:y] + rect[:h] / 2

  args.outputs.static_lines << samples.map.with_index do |amp, i|
    { x: rect[:x] + i * x_scale,       y: cy + amp * y_scale,
      x2: rect[:x] + (i+1) * x_scale,  y2: cy + (samples[i+1] || amp) * y_scale,
      r: 0, g: 200, b: 255 }
  end
end
```

## Defaults Pattern for Audio Options

```ruby
AUDIO_DEFAULTS = { gain: 1.0, pitch: 1.0, looping: false, fade_out: false }

def play_sound(args, id:, input:, **opts)
  args.audio[id] = AUDIO_DEFAULTS.merge(opts).merge(input: input)
end

play_sound(args, id: :laser, input: 'sounds/laser.wav', gain: 0.6)
```
