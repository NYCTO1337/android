extends RefCounted
class_name UIKit
## Shared look for all menus: thin type, hairline borders, no bright colours.

const COL_TEXT := Color(0.80, 0.82, 0.82)
const COL_DIM := Color(0.52, 0.54, 0.54)
const COL_HI := Color(0.96, 0.97, 0.97)

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/DejaVuSans.ttf")
	f.spacing_glyph = 1
	t.default_font = f
	t.default_font_size = 26

	t.set_color("font_color", "Label", COL_TEXT)

	t.set_stylebox("normal", "Button", _line_box(Color(0, 0, 0, 0), Color(0.42, 0.44, 0.44, 0.7)))
	t.set_stylebox("hover", "Button", _line_box(Color(1, 1, 1, 0.05), Color(0.7, 0.72, 0.72, 0.9)))
	t.set_stylebox("pressed", "Button", _line_box(Color(1, 1, 1, 0.14), Color(0.95, 0.96, 0.96, 1.0)))
	t.set_stylebox("disabled", "Button", _line_box(Color(0, 0, 0, 0), Color(0.3, 0.3, 0.3, 0.4)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", COL_HI)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	t.set_font_size("font_size", "Button", 27)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.02, 0.025, 0.03, 0.9)
	panel.border_color = Color(0.35, 0.37, 0.37, 0.8)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(2)
	panel.set_content_margin_all(30)
	t.set_stylebox("panel", "PanelContainer", panel)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.16)
	track.set_content_margin_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.77, 0.77, 0.75)
	fill.set_content_margin_all(2)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob: Texture2D = load("res://assets/art/knob.png")
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	t.set_icon("grabber_disabled", "HSlider", knob)

	_theme = t
	return t


static func _line_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_bottom = 2
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


static func title_font() -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/DejaVuSans-ExtraLight.ttf")
	f.spacing_glyph = 10
	return f


static func label(text: String, size: int = 26, color: Color = COL_TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size: int) -> Label:
	var l := label(text, size, COL_HI, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", title_font())
	return l


## Every menu button goes through GameState.ui_try(), so a tap can only fire
## one action even if the platform delivers duplicate events.
static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(400, 62)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		if GameState.ui_try():
			AudioManager.play("step")
			cb.call())
	return b


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
