extends Node

## SystemEventBus — 系统事件总线
## 负责存档/设置/音频/网络状态等全局系统事件的发布与订阅

func _ready() -> void:
	pass

# ============ 认证事件 ============
signal user_registered
signal user_logged_in
signal user_logged_out
signal auth_error(error: String)

# ============ 存档事件 ============
signal game_saved(save_id: String, timestamp: int)
signal game_loaded
signal save_error(error: String)

# ============ 网络事件 ============
signal network_online
signal network_offline
signal api_error(endpoint: String, error: String)

# ============ 设置事件 ============
signal settings_changed(key: String, value)
signal language_changed(locale: String)

# ============ 游戏状态事件 ============
signal game_paused
signal game_resumed
signal game_over(reason: String)
signal case_completed(case_id: String, stars: Dictionary)
signal game_state_changed(new_state: int)
signal difficulty_changed(new_difficulty: int)
signal boot_complete
