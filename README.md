# SoundManager for Godot 4+

Features:
- Music playback with fades
- One-shot SFX playback
- Cached audio loading
- Random pick helpers for music and SFX
- Pause/resume all SFX
- Fade out everything at once
- Swap music keeping playback position
- Per-sound pitch

## 1) Setup (Autoload)

1. In Godot, go to **Project > Project Settings > Autoload**.
2. Add `SoundManager.gd` and name it `SoundManager`.
3. Create audio buses:
   - Open the **Audio** panel (bottom dock) and click **Add Bus**.
   - Rename the new buses to `Music` and `SFX` (leave `Master` as-is).
   - If you use different names, update the exported vars in `SoundManager.gd`.

## 1.1) As addon
1. Put this project to `addons` folder
2. Go to **Project > Project Settings > Plugins**.
3. Enable `TAB_SoundManager`

## 2) Play Music

```gdscript
# Play a track with a short fade
Sound.music("res://assets/audio/title_theme.ogg", 0.5)

# Swap tracks, keeping playback position
Sound.music("res://assets/audio/level_theme.ogg", 0.5, true)

# Stop music with a fade
Sound.music_stop()
```

## 3) Play SFX

```gdscript
# Play a one-shot sound effect
Sound.sfx("res://assets/audio/jump.wav")

# Pitch shift
Sound.sfx("res://assets/audio/coin.wav", 1.2)
```

## 4) Random Picks

```gdscript
var hits = [
	"res://assets/audio/hit_1.wav",
	"res://assets/audio/hit_2.wav",
	"res://assets/audio/hit_3.wav",
]
Sound.sfx_random(hits)

var songs = [
	"res://assets/audio/song_a.ogg",
	"res://assets/audio/song_b.ogg",
]
Sound.music_random(songs)
```

## 5) Pause/Resume SFX

```gdscript
Sound.sfx_pause()

Sound.sfx_resume()
```

## 6) Fade Out Everything (music + sfx)

```gdscript
Sound.fade_out_all(1.5)
```
