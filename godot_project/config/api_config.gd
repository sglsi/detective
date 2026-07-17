## APIConfig — 网络层配置文件
## 集中管理后端地址、超时、重试等参数
## 支持通过 Godot 项目设置覆盖
##
## 注：本脚本由 project.godot 注册为 autoload 单例 "APIConfig"，
## 因此不声明 class_name（避免与 autoload 全局名冲突）。
## autoload 要求脚本继承 Node，故使用 extends Node（而非 RefCounted）。

extends Node

# ============ 后端地址 ============

## 开发环境 API 地址
const DEV_BASE_URL: String = "http://localhost:3000"

## 生产环境 API 地址（待定）
const PROD_BASE_URL: String = "https://api.sherlock-game.com"

## 从项目设置或环境变量获取后端地址
static func get_base_url() -> String:
	var url = ProjectSettings.get_setting("application/config/api_base_url", "")
	if url != "":
		return url
	
	# 开发/生产自动切换
	if OS.has_feature("editor") or OS.has_feature("debug"):
		return DEV_BASE_URL
	return PROD_BASE_URL

# ============ 请求参数 ============

## 请求超时（秒）
const REQUEST_TIMEOUT: float = 15.0

## 最大重试次数
const MAX_RETRIES: int = 2

## 重试间隔（秒）
const RETRY_DELAY: float = 1.0

## 最大并发请求数
const MAX_CONCURRENT_REQUESTS: int = 4

# ============ 离线队列 ============

## 离线队列最大长度
const MAX_PENDING_REQUESTS: int = 100

## 网络检测间隔（秒）
const CONNECTIVITY_CHECK_INTERVAL: float = 30.0

# ============ 端点定义 ============

## 所有 API 端点路径
const ENDPOINTS = {
	"health": "/api/health",
	"register": "/api/auth/register",
	"login": "/api/auth/login",
	"guest": "/api/auth/guest",
	"saves_list": "/api/saves",
	"saves_latest": "/api/saves/latest",
	"saves_upload": "/api/saves",
	"progress_list": "/api/progress",
	"progress_get": "/api/progress/{case_id}",
	"progress_update": "/api/progress/{case_id}",
}
