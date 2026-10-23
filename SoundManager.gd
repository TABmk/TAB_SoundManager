extends Node

signal music_changed(stream: AudioStream)

const SETTINGS_PREFIX := "tab_plugins/sound_manager/"
const SETTINGS: Dictionary[String, Variant] = {
	"music_bus": "Music",
	"sfx_bus": "SFX",
	"master_bus": "Master",
	"max_sfx_voices": 32,
	"sfx_cooldown_ms": 30,
}
const DEFAULT_FADE := 0.5
const MIN_DB := -80.0
const _FADE_META := &"_sound_manager_fade"

var music_bus: StringName
var sfx_bus: StringName
var master_bus: StringName
var sfx_cooldown_ms: int

var _music: AudioStreamPlayer
var _music_source: AudioStream
var _sfx: SfxPool
var _sfx_2d: SfxPool
var _sfx_3d: SfxPool
var _cache: Dictionary[String, AudioStream] = {}
var _missing: Dictionary[String, bool] = {}
var _loading: Dictionary[String, bool] = {}
var _oneshots: Dictionary[AudioStream, AudioStream] = {}
var _last_played: Dictionary[int, int] = {}
var _last_music_pick: Variant
var _last_sfx_pick: Variant


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_bus = _setting("music_bus")
	sfx_bus = _setting("sfx_bus")
	master_bus = _setting("master_bus")
	sfx_cooldown_ms = _setting("sfx_cooldown_ms")
	var max_voices: int = _setting("max_sfx_voices")
	_sfx = SfxPool.new(self, func(): return AudioStreamPlayer.new(), max_voices)
	_sfx_2d = SfxPool.new(self, func(): return AudioStreamPlayer2D.new(), max_voices)
	_sfx_3d = SfxPool.new(self, func(): return AudioStreamPlayer3D.new(), max_voices)


func _ready() -> void:
	for bus in [master_bus, music_bus, sfx_bus]:
		if AudioServer.get_bus_index(bus) == -1:
			push_warning("SoundManager: audio bus '%s' not found, sounds will play on Master. Check Project Settings > Tab Plugins > Sound Manager." % bus)


# --- Music ---

func music(sound: Variant, fade_time := DEFAULT_FADE, keep_position := false) -> void:
	var stream := _as_audio_stream(sound)
	if stream == null:
		return
	if stream == _music_source and _is_music_valid():
		music_resume()
		return
	var from_position := 0.0
	if _is_music_valid():
		from_position = _music.get_playback_position()
		_fade_out_music(fade_time)
	var length := stream.get_length()
	if keep_position and length > 0.0:
		from_position = fmod(from_position, length)
	_music = AudioStreamPlayer.new()
	_music_source = stream
	_music.stream = _with_loop(stream, true)
	_music.bus = music_bus
	_music.volume_linear = 0.0
	_music.finished.connect(_on_music_finished.bind(_music))
	add_child(_music)
	_music.play(from_position if keep_position else 0.0)
	_fade(_music, 1.0, fade_time)
	music_changed.emit(stream)


func play_music(stream: AudioStream, fade_time := DEFAULT_FADE, keep_position := false) -> void:
	music(stream, fade_time, keep_position)


func music_random(items: Array, fade_time := DEFAULT_FADE, keep_position := false) -> void:
	if items.is_empty():
		return
	_last_music_pick = _pick_random(items, _last_music_pick)
	music(_last_music_pick, fade_time, keep_position)


func music_stop(fade_time := DEFAULT_FADE) -> void:
	if _is_music_valid():
		_fade_out_music(fade_time)
		music_changed.emit(null)


func music_pause() -> void:
	if _is_music_valid():
		_music.stream_paused = true


func music_resume() -> void:
	if _is_music_valid():
		_music.stream_paused = false


func is_music_playing() -> bool:
	return _is_music_valid() and _music.playing


func get_music() -> AudioStream:
	return _music_source


# --- SFX ---

func sfx(sound: Variant, pitch := 1.0, volume := 1.0) -> void:
	var player = _take_sfx_player(_sfx, sound, pitch, volume, true)
	if player:
		player.play()


func ui_sfx(sound: Variant, pitch := 1.0, volume := 1.0) -> void:
	var player = _take_sfx_player(_sfx, sound, pitch, volume, false)
	if player:
		player.play()


func sfx_2d(sound: Variant, position: Vector2, pitch := 1.0, volume := 1.0) -> void:
	var player = _take_sfx_player(_sfx_2d, sound, pitch, volume, true)
	if player:
		player.global_position = position
		player.play()


func sfx_3d(sound: Variant, position: Vector3, pitch := 1.0, volume := 1.0) -> void:
	var player = _take_sfx_player(_sfx_3d, sound, pitch, volume, true)
	if player:
		player.global_position = position
		player.play()


func sfx_random(items: Array, pitch := 1.0, volume := 1.0) -> void:
	if items.is_empty():
		return
	_last_sfx_pick = _pick_random(items, _last_sfx_pick)
	sfx(_last_sfx_pick, pitch, volume)


func random_pitch(variation := 0.1) -> float:
	return randf_range(1.0 - variation, 1.0 + variation)


func sfx_pause() -> void:
	for player in _active_sfx():
		player.stream_paused = true


func sfx_resume() -> void:
	for player in _active_sfx():
		if player.can_process():
			player.stream_paused = false


func fade_out_all(fade_time := DEFAULT_FADE) -> void:
	music_stop(fade_time)
	for pool in [_sfx, _sfx_2d, _sfx_3d]:
		for player in pool.active():
			_fade(player, 0.0, fade_time, pool.release.bind(player))


# --- Loading ---

func get_audio(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if _missing.has(path):
		return null
	var res: Resource = null
	if _loading.has(path):
		_loading.erase(path)
		res = ResourceLoader.load_threaded_get(path)
	elif ResourceLoader.exists(path):
		res = ResourceLoader.load(path)
	if res is AudioStream:
		_cache[path] = res
		return res
	_missing[path] = true
	push_warning("SoundManager.get_audio: Invalid audio resource at '%s'." % path)
	return null


func preload_audio(paths: Array) -> void:
	for path in paths:
		if not (path is String) or _cache.has(path) or _loading.has(path):
			continue
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path, "AudioStream") == OK:
			_loading[path] = true


func clear_cache() -> void:
	_cache.clear()
	_missing.clear()
	_oneshots.clear()
	_last_played.clear()


# --- Buses ---

func set_bus_volume(bus: StringName, value: float) -> void:
	var index := _bus_index(bus)
	if index != -1:
		AudioServer.set_bus_volume_db(index, slider_to_db(value))


func get_bus_volume(bus: StringName) -> float:
	var index := _bus_index(bus)
	if index == -1:
		return 0.0
	return db_to_slider(AudioServer.get_bus_volume_db(index))


func set_bus_mute(bus: StringName, mute: bool) -> void:
	var index := _bus_index(bus)
	if index != -1:
		AudioServer.set_bus_mute(index, mute)


func is_bus_muted(bus: StringName) -> bool:
	var index := _bus_index(bus)
	return index != -1 and AudioServer.is_bus_mute(index)


func slider_to_db(value: float) -> float:
	if value <= 0.0:
		return MIN_DB
	return maxf(linear_to_db(value * value), MIN_DB)


func db_to_slider(db: float) -> float:
	if db <= MIN_DB:
		return 0.0
	return sqrt(db_to_linear(db))


# --- Internal ---

func _take_sfx_player(pool: SfxPool, sound: Variant, pitch: float, volume: float, pausable: bool) -> Variant:
	var stream := _as_audio_stream(sound)
	if stream == null or _on_cooldown(stream):
		return null
	var player = pool.acquire()
	_kill_fade(player)
	player.stream = _oneshot(stream)
	player.bus = sfx_bus
	player.pitch_scale = pitch
	player.volume_linear = volume
	player.process_mode = Node.PROCESS_MODE_PAUSABLE if pausable else Node.PROCESS_MODE_ALWAYS
	return player


func _on_cooldown(stream: AudioStream) -> bool:
	if sfx_cooldown_ms <= 0:
		return false
	var id := stream.get_instance_id()
	var now := Time.get_ticks_msec()
	if now - _last_played.get(id, -sfx_cooldown_ms) < sfx_cooldown_ms:
		return true
	_last_played[id] = now
	return false


func _oneshot(stream: AudioStream) -> AudioStream:
	if not _is_looping(stream):
		return stream
	if not _oneshots.has(stream):
		_oneshots[stream] = _with_loop(stream, false)
	return _oneshots[stream]


func _active_sfx() -> Array:
	return _sfx.active() + _sfx_2d.active() + _sfx_3d.active()


func _pick_random(items: Array, avoid: Variant) -> Variant:
	var i := randi() % items.size()
	if items.size() > 1 and is_same(items[i], avoid):
		i = (i + 1 + randi() % (items.size() - 1)) % items.size()
	return items[i]


func _as_audio_stream(value: Variant) -> AudioStream:
	if value is AudioStream:
		return value
	if value is String or value is StringName:
		return get_audio(value)
	push_warning("SoundManager: Expected AudioStream or path, got %s." % type_string(typeof(value)))
	return null


func _is_music_valid() -> bool:
	return is_instance_valid(_music)


func _fade_out_music(fade_time: float) -> void:
	_fade(_music, 0.0, fade_time, _music.queue_free)
	_music = null
	_music_source = null


func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player == _music:
		_music = null
		_music_source = null
		music_changed.emit(null)
	player.queue_free()


func _fade(player, to: float, time: float, on_done := Callable()) -> void:
	_kill_fade(player)
	if time <= 0.0:
		player.volume_linear = to
		if on_done.is_valid():
			on_done.call()
		return
	var tween: Tween = player.create_tween()
	tween.tween_property(player, "volume_linear", to, time)
	if on_done.is_valid():
		tween.tween_callback(on_done)
	player.set_meta(_FADE_META, tween)


func _kill_fade(player) -> void:
	if player.has_meta(_FADE_META):
		player.get_meta(_FADE_META).kill()
		player.remove_meta(_FADE_META)


func _bus_index(bus: StringName) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		push_warning("SoundManager: audio bus '%s' not found." % bus)
	return index


static func _setting(key: String) -> Variant:
	return ProjectSettings.get_setting(SETTINGS_PREFIX + key, SETTINGS[key])


static func _is_looping(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
	return "loop" in stream and stream.loop


# Returns a copy with looping switched, or the stream itself if it already matches
# or has no loop setting (AudioStreamRandomizer, AudioStreamInteractive, ...).
static func _with_loop(stream: AudioStream, loop: bool) -> AudioStream:
	var is_wav := stream is AudioStreamWAV
	if _is_looping(stream) == loop or not (is_wav or "loop" in stream):
		return stream
	var copy = stream.duplicate()
	if is_wav:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			# loop_end is in frames; the default 0 would make an empty loop.
			copy.loop_begin = 0
			copy.loop_end = int(copy.get_length() * copy.mix_rate)
	else:
		copy.loop = loop
	return copy


# Reuses players instead of creating a node per sound. When all voices are busy,
# the oldest sound is stopped and its player is reused.
class SfxPool:
	var _parent: Node
	var _create: Callable
	var _max_voices: int
	var _size := 0
	var _idle: Array = []
	var _active: Array = []

	func _init(parent: Node, create: Callable, max_voices: int) -> void:
		_parent = parent
		_create = create
		_max_voices = maxi(max_voices, 1)

	func acquire() -> Variant:
		var player
		if not _idle.is_empty():
			player = _idle.pop_back()
		elif _size < _max_voices:
			player = _create.call()
			player.finished.connect(release.bind(player))
			_parent.add_child(player)
			_size += 1
		else:
			player = _active.pop_front()
			player.stop()
		_active.append(player)
		return player

	func release(player) -> void:
		var i := _active.find(player)
		if i == -1:
			return
		_active.remove_at(i)
		player.stop()
		_idle.append(player)

	func active() -> Array:
		return _active.duplicate()
