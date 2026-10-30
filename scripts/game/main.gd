extends Node
## Composition root and the only place that performs state transitions
## (start / continue / death / restart checkpoint / main menu / quit).
## UI screens only ask for things via GameState.change_state() / send().

var level: Level
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	add_child(Background.new())

	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 20
	touch_layer.add_child(TouchControls.new())
	add_child(touch_layer)

	add_child(MainMenu.new())
	add_child(PauseMenu.new())
	add_child(SettingsPanel.new())
	add_child(EndScreen.new())

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 60
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)

	GameState.command.connect(_on_command)
	GameState.change_state(GameState.State.MAIN_MENU)


func _on_command(cmd: String) -> void:
	match cmd:
		"new_game":
			_start_run(true)
		"continue":
			_start_run(false)
		"restart_checkpoint":
			_restart_checkpoint()
		"main_menu":
			_to_main_menu()
		"quit":
			GameState.save_all()
			get_tree().quit()


func _fade_to(alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # must run while the tree is paused
	tw.tween_property(_fade, "color:a", alpha, seconds)
	await tw.finished


func _pause_free_timer(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _unload_level() -> void:
	if level != null:
		level.queue_free()
		level = null
	GameState.set_interact(false)


func _start_run(is_new: bool) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, 0.35)
	_unload_level()
	if is_new:
		GameState.start_new_run()
	else:
		GameState.continue_run()
	level = Level.new()
	level.player_died.connect(_on_player_died)
	level.completed.connect(_on_completed)
	add_child(level)
	level.start_at(GameState.checkpoint)
	GameState.change_state(GameState.State.PLAYING)
	await _fade_to(0.0, 0.9)
	_busy = false


func _restart_checkpoint() -> void:
	if _busy or level == null:
		return
	_busy = true
	await _fade_to(1.0, 0.3)
	if level != null:
		level.respawn()
	GameState.change_state(GameState.State.PLAYING)
	await _fade_to(0.0, 0.6)
	_busy = false


func _to_main_menu() -> void:
	if _busy:
		return
	_busy = true
	GameState.save_all()
	await _fade_to(1.0, 0.35)
	_unload_level()
	GameState.change_state(GameState.State.MAIN_MENU)
	await _fade_to(0.0, 0.6)
	_busy = false


func _on_player_died() -> void:
	if GameState.state != GameState.State.PLAYING:
		return
	GameState.deaths += 1
	GameState.change_state(GameState.State.DEAD)
	AudioManager.play("death")
	PlatformService.vibrate(70)
	await _pause_free_timer(1.0)          # let the fall animation play out
	if level == null or GameState.state != GameState.State.DEAD:
		return
	await _fade_to(1.0, 0.45)
	if level == null or GameState.state != GameState.State.DEAD:
		return
	level.respawn()
	await _pause_free_timer(0.25)
	GameState.change_state(GameState.State.PLAYING)
	await _fade_to(0.0, 0.6)


func _on_completed() -> void:
	if GameState.state != GameState.State.PLAYING:
		return
	GameState.finish_run()
	AudioManager.play("end")
	GameState.change_state(GameState.State.LEVEL_COMPLETE)
