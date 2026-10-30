extends CanvasLayer
class_name SettingsPanel
## Settings. Opened from the main menu or the pause menu; every control
## changes GameState.settings live and is saved when the panel is closed.

var _box: VBoxContainer


func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	UIKit.full_rect(root)
	root.theme = UIKit.get_theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	UIKit.full_rect(dim)
	root.add_child(dim)

	var center := CenterContainer.new()
	UIKit.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	panel.add_child(_box)

	GameState.state_changed.connect(_on_state)
	_on_state(GameState.state, GameState.state)


func _on_state(new_state: int, _old: int) -> void:
	visible = new_state == GameState.State.SETTINGS
	if visible:
		_rebuild()


func _rebuild() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var title := UIKit.title("პარამეტრები", 40)
	title.custom_minimum_size = Vector2(0, 64)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_box.add_child(title)

	_add_slider("მუსიკა", "music_volume", 0.0, 1.0, false)
	_add_slider("ხმოვანი ეფექტები", "sfx_volume", 0.0, 1.0, true)
	_add_slider("ღილაკების გამჭვირვალობა", "control_opacity", 0.15, 0.9, false)
	_add_slider("ღილაკების ზომა", "control_scale", 0.6, 1.6, false)
	_add_slider("მართვის მგრძნობელობა", "stick_sensitivity", 0.5, 2.0, false)
	_add_toggle("მართვის მხარეების შებრუნება", "swap_sides")
	_add_toggle("ვიბრაცია", "haptics")
	_add_toggle("დაბალი ეფექტები (უკეთესი FPS)", "low_fx")

	var back := UIKit.button("უკან", func() -> void: GameState.close_settings())
	back.custom_minimum_size = Vector2(0, 58)
	_box.add_child(back)


func _add_slider(text: String, key: String, lo: float, hi: float, test_sfx: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_box.add_child(row)
	var l := UIKit.label(text, 21)
	l.custom_minimum_size = Vector2(300, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var v := UIKit.label("%d%%" % roundi(float(GameState.settings[key]) * 100.0), 19, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	v.custom_minimum_size = Vector2(64, 0)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(GameState.settings[key])
	s.custom_minimum_size = Vector2(280, 46)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(val: float) -> void:
		GameState.settings[key] = val
		v.text = "%d%%" % roundi(val * 100.0)
		GameState.settings_changed.emit())
	if test_sfx:
		s.drag_ended.connect(func(_changed: bool) -> void: AudioManager.play("land"))
	row.add_child(s)
	row.add_child(v)


func _add_toggle(text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_box.add_child(row)
	var l := UIKit.label(text, 21)
	l.custom_minimum_size = Vector2(300, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(190, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.button_pressed = bool(GameState.settings[key])
	b.text = _on_off(b.button_pressed)
	b.toggled.connect(func(on: bool) -> void:
		GameState.settings[key] = on
		b.text = _on_off(on)
		GameState.settings_changed.emit())
	row.add_child(b)


func _on_off(on: bool) -> String:
	return "ჩართულია" if on else "გამორთულია"
