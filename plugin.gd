@tool
extends EditorPlugin

const AUTOLOAD_NAME = "SoundManager"
const SoundManagerScript = preload("SoundManager.gd")


func _enter_tree() -> void:
	_add_settings()


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, get_script().resource_path.get_base_dir().path_join("SoundManager.gd"))


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _add_settings() -> void:
	for key in SoundManagerScript.SETTINGS:
		var path: String = SoundManagerScript.SETTINGS_PREFIX + key
		var default_value: Variant = SoundManagerScript.SETTINGS[key]
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, default_value)
		ProjectSettings.set_initial_value(path, default_value)
		ProjectSettings.set_as_basic(path, true)
		ProjectSettings.add_property_info({"name": path, "type": typeof(default_value)})
