extends Node
## Central game-state machine, settings, saved progress and app lifecycle.
## States: MAIN_MENU, PLAYING, PAUSED, SETTINGS, DEAD, LEVEL_COMPLETE.
## UI never changes scenes itself: it calls change_state() or send(command),
## and Main performs the transitions.

signal state_changed(new_state: int, old_state: int)
signal settings_changed
signal interact_changed(available: bool)
signal activity_changed
signal command(cmd: String)

enum State { MAIN_MENU, PLAYING, PAUSED, SETTINGS, DEAD, LEVEL_COMPLETE }

const DEFAULT_SETTINGS := {
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	"control_opacity": 0.5,
	"control_scale": 1.0,
	"stick_sensitivity": 1.0,
	"swap_sides": false,
	"haptics": true,
	"low_fx": false,
}

const DEFAULT_PROGRESS := {
	"in_run": false,
	"checkpoint": 0,
	"run_time": 0.0,
	"deaths": 0,
	"best_time": -1.0,
	"completions": 0,
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var progress: Dictionary = DEFAULT_PROGRESS.duplicate()

var state: int = State.MAIN_MENU
var settings_return: int = State.MAIN_MENU
var app_inactive := false
var can_interact := false

# current run
var checkpoint := 0
var run_time := 0.0
var deaths := 0

var _last_ui_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_load()


# ------------------------------------------------------------ state machine

func change_state(new_state: int) -> void:
	if new_state == state:
		return
	var old: int = state
	state = new_state
	_apply_pause()
	state_changed.emit(new_state, old)


func is_logic_paused() -> bool:
	return state == State.PAUSED \
		or (state == State.SETTINGS and settings_return == State.PAUSED) \
		or app_inactive


func _apply_pause() -> void:
	get_tree().paused = is_logic_paused()


func open_settings() -> void:
	settings_return = state
	change_state(State.SETTINGS)


func close_settings() -> void:
	save_all()
	change_state(settings_return)


func send(cmd: String) -> void:
	command.emit(cmd)


func set_interact(available: bool) -> void:
	if can_interact == available:
		return
	can_interact = available
	interact_changed.emit(available)


## Prevents one tap from triggering several menu actions (double events,
## transition still running, tap-through).
func ui_try() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_ui_ms < 350:
		return false
	_last_ui_ms = now
	return true


func handle_back() -> void:
	match state:
		State.PLAYING:
			change_state(State.PAUSED)
		State.PAUSED:
			change_state(State.PLAYING)
		State.SETTINGS:
			close_settings()
		State.LEVEL_COMPLETE:
			send("main_menu")
		State.MAIN_MENU:
			if PlatformService.platform_name() != "iOS":
				get_tree().quit()
		_:
			pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") \
			and (state == State.PLAYING or state == State.PAUSED or state == State.SETTINGS):
		handle_back()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if state == State.PLAYING:
				change_state(State.PAUSED)
			app_inactive = true
			_apply_pause()
			activity_changed.emit()
			save_all()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			app_inactive = false
			_apply_pause()
			activity_changed.emit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			handle_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_all()
			get_tree().quit()


# ------------------------------------------------------------------- saving

func _load() -> void:
	var data := SaveSystem.load_data()
	var s = data.get("settings", {})
	if typeof(s) == TYPE_DICTIONARY:
		for key in DEFAULT_SETTINGS:
			if s.has(key) and typeof(s[key]) == typeof(DEFAULT_SETTINGS[key]):
				settings[key] = s[key]
	settings["control_opacity"] = clampf(settings["control_opacity"], 0.1, 0.9)
	settings["control_scale"] = clampf(settings["control_scale"], 0.6, 1.6)
	settings["stick_sensitivity"] = clampf(settings["stick_sensitivity"], 0.5, 2.0)
	settings["music_volume"] = clampf(settings["music_volume"], 0.0, 1.0)
	settings["sfx_volume"] = clampf(settings["sfx_volume"], 0.0, 1.0)

	var p = data.get("progress", {})
	if typeof(p) == TYPE_DICTIONARY:
		if typeof(p.get("in_run")) == TYPE_BOOL:
			progress["in_run"] = p["in_run"]
		for key in ["checkpoint", "deaths", "completions"]:
			if typeof(p.get(key)) in [TYPE_FLOAT, TYPE_INT]:
				progress[key] = maxi(int(p[key]), 0)
		for key in ["run_time", "best_time"]:
			if typeof(p.get(key)) in [TYPE_FLOAT, TYPE_INT]:
				progress[key] = float(p[key])


func save_all() -> void:
	SaveSystem.save_data({"settings": settings, "progress": progress})


func has_continue() -> bool:
	return bool(progress["in_run"])


func start_new_run() -> void:
	checkpoint = 0
	run_time = 0.0
	deaths = 0
	progress["in_run"] = true
	progress["checkpoint"] = 0
	progress["run_time"] = 0.0
	progress["deaths"] = 0
	save_all()


func continue_run() -> void:
	checkpoint = int(progress["checkpoint"])
	run_time = float(progress["run_time"])
	deaths = int(progress["deaths"])


func save_checkpoint(index: int) -> void:
	checkpoint = index
	progress["in_run"] = true
	progress["checkpoint"] = index
	progress["run_time"] = run_time
	progress["deaths"] = deaths
	save_all()


func finish_run() -> void:
	progress["in_run"] = false
	progress["completions"] = int(progress["completions"]) + 1
	var best := float(progress["best_time"])
	if best < 0.0 or run_time < best:
		progress["best_time"] = run_time
	save_all()


func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
