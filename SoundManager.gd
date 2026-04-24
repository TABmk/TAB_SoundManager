extends Node

@export var music_bus := "Music"
@export var sfx_bus := "SFX"
@export var master_bus := "Master"

var current_music: AudioStreamPlayer
var _cache: Dictionary[String, AudioStream] = {}
var _last_music_position := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func music(path: String, fade_time := 0.3, keep_position := false) -> void:
	var stream := get_audio(path)
	if stream == null:
		return
	play_music(stream, fade_time, keep_position)


func music_random(streams: Array, fade_time := 0.3, keep_position := false) -> void:
	var choice = _pick_random(streams)
	if choice == null:
		return
	if typeof(choice) == TYPE_STRING:
		music(choice, fade_time, keep_position)
	elif choice is AudioStream:
		play_music(choice, fade_time, keep_position)
	else:
		_warn_invalid_audio(choice)


func play_music(stream: AudioStream, fade_time := 1.0, keep_position := false) -> void:
	if stream == null:
		return
	if _is_music_valid() and current_music.playing:
		_last_music_position = current_music.get_playback_position()
		var old_music := current_music
		_fade_out(old_music, fade_time)
	else:
		_last_music_position = 0.0
	current_music = AudioStreamPlayer.new()
	current_music.stream = _create_music_stream(stream)
	current_music.bus = music_bus
	add_child(current_music)
	if keep_position:
		current_music.play(_last_music_position)
	else:
		current_music.play()
	_fade_in(current_music, fade_time)


func music_stop() -> void:
	if _is_music_valid() and current_music.playing:
		_fade_out(current_music, 0.3)


func sfx(path: String, pitch: float = 1.0) -> void:
	var stream := get_audio(path)
	if stream == null:
		return
	var s := _create_sfx_player(stream, pitch)
	s.play()
	await s.finished
	s.queue_free()


func sfx_random(streams: Array) -> void:
	var choice = _pick_random(streams)
	if choice == null:
		return
	if typeof(choice) == TYPE_STRING:
		sfx.call_deferred(choice)
		return
	var stream := _as_audio_stream(choice)
	if stream == null:
		return
	var s := _create_sfx_player(stream, 1.0)
	s.play()
	s.finished.connect(s.queue_free)


func fade_out_all(fade_time := 2.0) -> void:
	if _is_music_valid() and current_music.playing:
		_fade_out(current_music, fade_time)
	for child in get_children():
		if child is AudioStreamPlayer and child != current_music:
			_fade_out(child, fade_time)


func sfx_pause() -> void:
	for child in get_children():
		if child is AudioStreamPlayer and child.bus == sfx_bus and child.playing:
			child.stream_paused = true


func sfx_resume() -> void:
	for child in get_children():
		if child is AudioStreamPlayer and child.bus == sfx_bus and child.stream_paused:
			child.stream_paused = false


func get_audio(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var res := ResourceLoader.load(path)
	if res is AudioStream:
		_cache[path] = res
		return res
	push_warning("SoundManager.get_audio: Invalid audio resource at '%s'." % path)
	return null


func slider_to_db(value: float) -> float:
	if value <= 0.0:
		return -80.0
	var curved := pow(value, 2.0)
	return 20.0 * log(curved) / log(10.0)


func db_to_slider(db: float) -> float:
	if db <= -80.0:
		return 0.0
	var linear := pow(10.0, db / 20.0)
	return pow(linear, 1.0 / 2.0)


func _pick_random(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


func _as_audio_stream(value: Variant) -> AudioStream:
	if typeof(value) == TYPE_STRING:
		return get_audio(value)
	if value is AudioStream:
		return value
	_warn_invalid_audio(value)
	return null


func _warn_invalid_audio(value) -> void:
	push_warning("SoundManager: Expected AudioStream or path, got %s." % typeof(value))


func _create_music_stream(stream: AudioStream) -> AudioStream:
	var music_stream := stream.duplicate()
	if music_stream is AudioStream:
		music_stream.loop = true
	return music_stream


func _create_sfx_player(stream: AudioStream, pitch: float) -> AudioStreamPlayer:
	var s := AudioStreamPlayer.new()
	s.stream = _create_sfx_stream(stream)
	s.bus = sfx_bus
	s.pitch_scale = pitch
	add_child(s)
	return s


func _create_sfx_stream(stream: AudioStream) -> AudioStream:
	var sfx_stream := stream.duplicate()
	if sfx_stream is AudioStream:
		sfx_stream.loop = false
	return sfx_stream


func _fade_in(player: AudioStreamPlayer, time: float) -> void:
	player.volume_db = -80
	var tween := create_tween()
	tween.tween_property(player, "volume_db", 0, time)


func _fade_out(player: AudioStreamPlayer, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -80, time)
	tween.tween_callback(Callable(player, "queue_free"))


func _is_music_valid() -> bool:
	return current_music != null and is_instance_valid(current_music)
