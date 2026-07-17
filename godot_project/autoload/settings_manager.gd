extends Node

## SettingsManager - 设置管理器
## 管理游戏设置：音视频、语言、难度偏好

var settings: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"voice_volume": 0.7,
	"resolution": "1920x1080",
	"fullscreen": false,
	"brightness": 0.5,
	"interface_language": "zh_CN",
	"subtitle_language": "zh_CN",
	"default_difficulty": DifficultyManager.Difficulty.NORMAL,
	"auto_save_enabled": true,
	"dialogue_speed": 1.0,
}

func _ready() -> void:
	_load_settings()

func get_setting(key: String):
	return settings.get(key, null)

## 返回全部设置字典（供存档同步等场景使用）
func get_all_settings() -> Dictionary:
	return settings

func set_setting(key: String, value) -> void:
	settings[key] = value
	_apply_setting(key, value)
	_save_settings()
	SystemEventBus.emit_signal("settings_changed", key, value)

func _apply_setting(key: String, value) -> void:
	match key:
		"master_volume": AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
		"music_volume": AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))
		"sfx_volume": AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))
		"voice_volume": AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(value))
		"fullscreen":
			if value: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _save_settings() -> void:
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(settings, "\t"))

func _load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	if json:
		for key in json:
			settings[key] = json[key]
