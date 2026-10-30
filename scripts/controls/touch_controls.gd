extends Control
class_name TouchControls
## On-screen controls. The ONLY thing this script does to the game is press
## and release Input actions (move_left / move_right / jump / interact), so the
## game code never knows if input came from touch, keyboard or a gamepad.
##
## - Left side: floating horizontal stick (appears under the thumb).
## - Right side: big JUMP button; a contextual INTERACT button appears only
##   when something can be used; small PAUSE button in the top corner.
## - Each finger is tracked by its touch index: real multi-touch and holding.
## - Only reacts while the state is PLAYING. Touch-ups are always processed,
##   so no action can stay stuck when a menu opens mid-touch.

const BASE_STICK_RADIUS := 92.0
const BASE_BUTTON_RADIUS := 64.0
const DEADZONE := 0.18
const PAUSE_SIZE := 84.0

var _touches: Dictionary = {}     # touch index -> "stick" | "jump" | "interact" | "pause"
var _centers: Dictionary = {}     # button name -> Vector2
var _pressed := {"jump": false, "interact": false}
var _pause_rect := Rect2()
var _radius_btn := BASE_BUTTON_RADIUS
var _radius_stick := BASE_STICK_RADIUS
var _home_stick := Vector2.ZERO
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_active := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.settings_changed.connect(_relayout)
	GameState.state_changed.connect(_on_state)
	GameState.interact_changed.connect(func(_a: bool) -> void: queue_redraw())
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_on_state(GameState.state, GameState.state)


func _on_state(new_state: int, _old: int) -> void:
	if new_state != GameState.State.PLAYING:
		release_all()
	visible = new_state != GameState.State.MAIN_MENU \
		and new_state != GameState.State.LEVEL_COMPLETE \
		and not (new_state == GameState.State.SETTINGS and GameState.settings_return == GameState.State.MAIN_MENU)
	queue_redraw()


func release_all() -> void:
	_touches.clear()
	_stick_active = false
	_set_axis(0.0)
	_set_button("jump", false)
	_set_button("interact", false)
	_stick_origin = _home_stick
	_stick_pos = _home_stick
	queue_redraw()


func _relayout() -> void:
	var vp := get_viewport_rect().size
	var ins := PlatformService.get_safe_insets()
	var s: float = GameState.settings["control_scale"]
	var swap: bool = GameState.settings["swap_sides"]
	_radius_btn = BASE_BUTTON_RADIUS * s
	_radius_stick = BASE_STICK_RADIUS * s
	var margin := 40.0
	var bottom_y: float = vp.y - ins["bottom"] - margin

	var stick_x: float
	var jump_x: float
	var dir: float
	if not swap:
		stick_x = ins["left"] + margin + _radius_stick + 20.0
		jump_x = vp.x - ins["right"] - margin - _radius_btn
		dir = -1.0
	else:
		stick_x = vp.x - ins["right"] - margin - _radius_stick - 20.0
		jump_x = ins["left"] + margin + _radius_btn
		dir = 1.0
	_home_stick = Vector2(stick_x, bottom_y - _radius_stick)
	_centers["jump"] = Vector2(jump_x, bottom_y - _radius_btn)
	_centers["interact"] = Vector2(jump_x + dir * _radius_btn * 2.15, bottom_y - _radius_btn * 1.7)

	var px: float = vp.x - ins["right"] - 24.0 - PAUSE_SIZE
	if swap:
		px = ins["left"] + 24.0
	_pause_rect = Rect2(px, ins["top"] + 18.0, PAUSE_SIZE, PAUSE_SIZE)

	if not _stick_active:
		_stick_origin = _home_stick
		_stick_pos = _home_stick
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if GameState.state == GameState.State.PLAYING:
				_on_down(event.index, event.position)
		else:
			_on_up(event.index)
	elif event is InputEventScreenDrag:
		if GameState.state == GameState.State.PLAYING:
			_on_drag(event.index, event.position)


func _on_down(index: int, pos: Vector2) -> void:
	if _pause_rect.grow(14.0).has_point(pos):
		_touches[index] = "pause"
		GameState.change_state(GameState.State.PAUSED)
		return
	if pos.distance_to(_centers["jump"]) <= _radius_btn * 1.3:
		_touches[index] = "jump"
		_set_button("jump", true)
		return
	if GameState.can_interact and pos.distance_to(_centers["interact"]) <= _radius_btn * 1.1:
		_touches[index] = "interact"
		_set_button("interact", true)
		return
	var vp := get_viewport_rect().size
	var swap: bool = GameState.settings["swap_sides"]
	var in_stick_zone := (pos.x < vp.x * 0.5) != swap
	if in_stick_zone and not _stick_active and pos.y > vp.y * 0.2:
		_stick_active = true
		_touches[index] = "stick"
		_stick_origin = pos
		_stick_pos = pos
		_apply_stick()
		queue_redraw()


func _on_drag(index: int, pos: Vector2) -> void:
	if _touches.get(index, "") != "stick":
		return
	var dx := pos.x - _stick_origin.x
	if absf(dx) > _radius_stick:
		# the origin follows the thumb, so reversing direction is instant
		_stick_origin.x = pos.x - signf(dx) * _radius_stick
	_stick_pos = pos
	_apply_stick()
	queue_redraw()


func _on_up(index: int) -> void:
	var role: String = _touches.get(index, "")
	_touches.erase(index)
	if role == "stick":
		_stick_active = false
		_set_axis(0.0)
		_stick_origin = _home_stick
		_stick_pos = _home_stick
		queue_redraw()
	elif role == "jump" or role == "interact":
		_set_button(role, false)


func _apply_stick() -> void:
	var sens: float = GameState.settings["stick_sensitivity"]
	var v := clampf((_stick_pos.x - _stick_origin.x) / _radius_stick * sens, -1.0, 1.0)
	if absf(v) < DEADZONE:
		v = 0.0
	else:
		v = signf(v) * (absf(v) - DEADZONE) / (1.0 - DEADZONE)
	_set_axis(v)


func _set_axis(v: float) -> void:
	if v > 0.0:
		Input.action_press("move_right", v)
		Input.action_release("move_left")
	elif v < 0.0:
		Input.action_press("move_left", -v)
		Input.action_release("move_right")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func _set_button(b: String, down: bool) -> void:
	if _pressed[b] == down:
		return
	_pressed[b] = down
	if down:
		Input.action_press(b)
		PlatformService.vibrate(12)
	else:
		Input.action_release(b)
	queue_redraw()


func _draw() -> void:
	var a: float = GameState.settings["control_opacity"]
	var rim := Color(0.82, 0.86, 0.87, a * 0.85)

	# stick (floating): faint home hint when idle
	var idle_k := 0.5 if not _stick_active else 1.0
	draw_circle(_stick_origin, _radius_stick, Color(0.8, 0.85, 0.86, a * (0.30 if _stick_active else 0.12)))
	draw_arc(_stick_origin, _radius_stick, 0.0, TAU, 48, Color(rim.r, rim.g, rim.b, rim.a * idle_k), 2.5, true)
	var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(_radius_stick)
	draw_circle(knob, _radius_stick * 0.40, Color(0.85, 0.9, 0.9, a * (0.9 if _stick_active else 0.45)))

	# jump
	var jc: Vector2 = _centers["jump"]
	var jp: bool = _pressed["jump"]
	var jr := _radius_btn * (0.93 if jp else 1.0)
	draw_circle(jc, jr, Color(0.85, 0.9, 0.9, a * (0.55 if jp else 0.16)))
	draw_arc(jc, jr, 0.0, TAU, 48, rim, 4.0 if jp else 2.5, true)
	var r := jr * 0.34
	draw_polyline(PackedVector2Array([jc + Vector2(-r, r * 0.45), jc + Vector2(0, -r * 0.6), jc + Vector2(r, r * 0.45)]),
		Color(0.92, 0.95, 0.95, minf(a * 1.4, 1.0)), 5.0, true)

	# contextual interact (warm: the same colour as the lanterns)
	if GameState.can_interact:
		var ic: Vector2 = _centers["interact"]
		var ip: bool = _pressed["interact"]
		var ir := _radius_btn * 0.78 * (0.93 if ip else 1.0)
		var warm := Color(1.0, 0.78, 0.45)
		draw_circle(ic, ir, Color(warm.r, warm.g, warm.b, a * (0.6 if ip else 0.24)))
		draw_arc(ic, ir, 0.0, TAU, 40, Color(warm.r, warm.g, warm.b, minf(a * 1.3, 1.0)), 3.0, true)
		var hand := Vector2(0, ir * 0.1)
		draw_line(ic + hand + Vector2(-ir * 0.28, ir * 0.3), ic + hand + Vector2(ir * 0.28, -ir * 0.3),
			Color(1.0, 0.9, 0.7, minf(a * 1.4, 1.0)), 5.0, true)
		draw_circle(ic + hand + Vector2(ir * 0.28, -ir * 0.3), ir * 0.13, Color(1.0, 0.9, 0.7, minf(a * 1.4, 1.0)))

	# pause
	var pc := _pause_rect.get_center()
	draw_arc(pc, PAUSE_SIZE * 0.5, 0.0, TAU, 32, Color(rim.r, rim.g, rim.b, rim.a * 0.6), 2.0, true)
	var pw := PAUSE_SIZE * 0.07
	var ph := PAUSE_SIZE * 0.28
	draw_rect(Rect2(pc.x - pw * 2.2, pc.y - ph, pw * 1.6, ph * 2.0), Color(0.9, 0.93, 0.93, a * 0.9))
	draw_rect(Rect2(pc.x + pw * 0.6, pc.y - ph, pw * 1.6, ph * 2.0), Color(0.9, 0.93, 0.93, a * 0.9))
