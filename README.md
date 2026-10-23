# SoundManager for Godot 4.4+

Features:
- Music with linear crossfades, looping, pause/resume
- One-shot SFX through a reusable voice pool (no node per sound)
- Positional SFX (2D/3D)
- Game SFX pause with the scene tree, UI SFX and music keep playing
- Voice limit with stealing and per-sound cooldown
- Random picks without immediate repeats, random pitch helper
- Bus volume / mute helpers with a perceptual slider curve
- Cached and background (threaded) audio loading
- Works with WAV, OGG, MP3 and other `AudioStream` types

Requires **Godot 4.4+** (typed dictionaries, `volume_linear`).

## 1) Setup

### As addon (recommended)
1. Put this folder to `res://addons/TAB_SoundManager`.
2. Go to **Project > Project Settings > Plugins** and enable `TAB_SoundManager`.
   This registers the `SoundManager` autoload and its project settings.

### Manual autoload
1. Go to **Project > Project Settings > Autoload**.
2. Add `SoundManager.gd` and name it `SoundManager`.

### Audio buses
Open the **Audio** panel (bottom dock), click **Add Bus** and name the new buses
`Music` and `SFX` (leave `Master` as-is). A warning is printed on startup if a bus
is missing — sounds then play on `Master`.

## 2) Settings

**Project Settings > Tab Plugins > Sound Manager** (`tab_plugins/sound_manager/*`):

| Setting | Default | Description |
|---|---|---|
| `music_bus` | `Music` | Bus for music |
| `sfx_bus` | `SFX` | Bus for all SFX |
| `master_bus` | `Master` | Exposed as `SoundManager.master_bus` for volume UI |
| `max_sfx_voices` | `32` | Max simultaneous SFX per pool (plain, 2D, 3D). The oldest sound is cut when the limit is reached |
| `sfx_cooldown_ms` | `30` | The same sound started again within this time is skipped. `0` disables it |

## 3) Music

Every `sound` argument accepts a path (`res://` or `uid://`) or an `AudioStream`.

```gdscript
# Crossfade to a track (default fade is 0.5 s)
SoundManager.music("res://assets/audio/title_theme.ogg")

# Swap to a variation of the track, keeping playback position
SoundManager.music("res://assets/audio/level_theme_intense.ogg", 0.5, true)

# Calling it again with the track that is already playing does nothing
SoundManager.music("res://assets/audio/title_theme.ogg")

SoundManager.music_pause()
SoundManager.music_resume()
SoundManager.music_stop(1.0)

SoundManager.is_music_playing()
SoundManager.get_music()  # current AudioStream or null

SoundManager.music_changed.connect(func(stream): print("now playing: ", stream))
```

Music always loops (OGG, MP3, WAV, `AudioStreamPlaylist`), regardless of import
settings. Streams without a loop setting (`AudioStreamRandomizer`,
`AudioStreamInteractive`, ...) play as they are. When such a track ends,
`music_changed` is emitted with `null`.

Music keeps playing while the scene tree is paused.

## 4) SFX

```gdscript
SoundManager.sfx("res://assets/audio/jump.wav")

# Pitch and volume (linear, 0..1)
SoundManager.sfx("res://assets/audio/coin.wav", 1.2, 0.8)

# Small random pitch variation (±10%)
SoundManager.sfx("res://assets/audio/step.wav", SoundManager.random_pitch(0.1))

# Preloaded streams work too
const HIT = preload("res://assets/audio/hit.wav")
SoundManager.sfx(HIT)

# Positional
SoundManager.sfx_2d("res://assets/audio/explosion.wav", enemy.global_position)
SoundManager.sfx_3d("res://assets/audio/explosion.wav", enemy.global_position)
```

SFX are always played once, even if the stream is imported with loop enabled.

Positional players live under the `SoundManager` node, so they use the main
viewport's world and listener. They won't be heard inside a separate `SubViewport` world.

## 5) Random picks

Never picks the same item twice in a row (when there is more than one).

```gdscript
var hits = [
	"res://assets/audio/hit_1.wav",
	"res://assets/audio/hit_2.wav",
	"res://assets/audio/hit_3.wav",
]
SoundManager.sfx_random(hits)
SoundManager.sfx_random(hits, SoundManager.random_pitch(0.05))

var songs = [
	"res://assets/audio/song_a.ogg",
	"res://assets/audio/song_b.ogg",
]
SoundManager.music_random(songs)
```

## 6) Pause

Game SFX (`sfx`, `sfx_2d`, `sfx_3d`) pause automatically with `get_tree().paused`.
Use `ui_sfx` for menus and buttons — it keeps playing while the game is paused.

```gdscript
SoundManager.ui_sfx("res://assets/audio/click.wav")
```

`sfx()` called while the tree is already paused still plays (engine behaviour),
but a sound started right before pausing would freeze, so prefer `ui_sfx` in pause menus.

Manual pause of all SFX without pausing the tree:

```gdscript
SoundManager.sfx_pause()
SoundManager.sfx_resume()
```

Don't mix it with tree pause: unpausing the tree also resumes SFX paused with `sfx_pause()`.

## 7) Fade out everything (music + SFX)

```gdscript
SoundManager.fade_out_all(1.5)
```

## 8) Volume

Slider values are `0..1` with a perceptual curve (`value²` as amplitude),
ready to bind to an `HSlider` with `max_value = 1`.

```gdscript
SoundManager.set_bus_volume(SoundManager.music_bus, 0.7)
SoundManager.get_bus_volume(SoundManager.sfx_bus)
SoundManager.set_bus_mute(SoundManager.master_bus, true)
SoundManager.is_bus_muted(SoundManager.master_bus)

# Raw conversion helpers
SoundManager.slider_to_db(0.5)  # -12 dB
SoundManager.db_to_slider(-12.0)  # 0.5
```

Saving the values between sessions is left to your save system.

## 9) Loading and cache

The first play of a path loads it on the main thread, which can hitch on large files.
Start loading in the background ahead of time, e.g. on level start:

```gdscript
SoundManager.preload_audio([
	"res://assets/audio/boss_theme.ogg",
	"res://assets/audio/explosion.wav",
])
```

Loaded streams stay in memory until `clear_cache()`. Missing paths are reported once.

```gdscript
SoundManager.get_audio("res://assets/audio/jump.wav")  # AudioStream or null
SoundManager.clear_cache()
```

## Migrating from 0.1

- Examples used `Sound.` — the autoload is `SoundManager`.
- `@export` bus names moved to Project Settings (see section 2).
- One default fade for everything: `0.5` s (was `0.3` for `music`/`music_stop`, `1.0` for `play_music`, `2.0` for `fade_out_all`).
- `current_music` was removed — use `is_music_playing()` / `get_music()` / `music_changed`.
- `sfx()` is no longer a coroutine; `sfx_random()` plays immediately (was deferred by a frame).
- Game SFX now pause with the scene tree; use `ui_sfx()` for sounds that must play in menus.
- `play_music(stream)` still works; `music()` now accepts streams as well.
