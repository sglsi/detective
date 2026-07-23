extends Node

## GameStateMachine -- 游戏全局状态机 (E-25 S5.2.1)
## BOOT -> MENU -> LOADING_CASE -> IN_CASE -> CASE_COMPLETE -> MENU

enum State { BOOT, MENU, LOADING_CASE, IN_CASE, PAUSE, CASE_COMPLETE, CREDITS }

var current := State.BOOT
var previous := State.BOOT

signal state_changed(from_state: int, to_state: int)
signal entered_menu
signal entered_case(case_id: String)
signal case_completed(case_id: String)

func _ready() -> void:
	_transition(State.MENU)

func _transition(to: int) -> void:
	previous = current
	current = to
	state_changed.emit(previous, to)
	match to:
		State.MENU: entered_menu.emit()
		State.IN_CASE:
			var cid = GameManager.current_case_id if GameManager else ""
			entered_case.emit(cid)
		State.CASE_COMPLETE:
			var cid = GameManager.current_case_id if GameManager else ""
			case_completed.emit(cid)

func go_menu() -> void: _transition(State.MENU)
func go_loading() -> void: _transition(State.LOADING_CASE)
func go_in_case() -> void: _transition(State.IN_CASE)
func go_pause() -> void: _transition(State.PAUSE)
func go_complete() -> void: _transition(State.CASE_COMPLETE)
func go_credits() -> void: _transition(State.CREDITS)
