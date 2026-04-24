@tool
extends EditorPlugin

const AUTOLOAD_NAME = "SoundManager"


func _enable_plugin():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/TAB_SoundManager/SoundManager.gd")


func _disable_plugin():
	remove_autoload_singleton(AUTOLOAD_NAME)
