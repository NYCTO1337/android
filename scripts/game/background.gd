extends Node
class_name Background
## Layered parallax world behind (and in front of) the gameplay:
##   far trees (glowing mist) -> mid trees + ruined bridge -> drifting fog
##   -> [gameplay] -> huge near trunks + fog -> vignette.
## All textures are 1024x512 and wrap horizontally. Layout is recomputed from
## the viewport size so any aspect ratio is covered.

const TEX_W := 1024.0
const TEX_H := 512.0
const MID_BASE := 490.0   # y (in texture) of the tree roots in bg_mid
const GROUND_BELOW_CENTER := 132.0  # screen distance: camera centre -> ground

var _back: ParallaxBackground
var _front: ParallaxBackground
var _far: ParallaxLayer
var _mid: ParallaxLayer
var _fog_back: ParallaxLayer
var _near: ParallaxLayer
var _fog_front: ParallaxLayer


func _ready() -> void:
	_back = ParallaxBackground.new()
	_back.layer = -10
	add_child(_back)
	_far = _add_layer(_back, "bg_far", Vector2(0.10, 0.04))
	_mid = _add_layer(_back, "bg_mid", Vector2(0.35, 0.08))
	_fog_back = _add_layer(_back, "fog", Vector2(0.6, 0.1))
	_fog_back.modulate = Color(1, 1, 1, 0.55)

	_front = ParallaxBackground.new()
	_front.layer = 3
	add_child(_front)
	_near = _add_layer(_front, "fg_near", Vector2(1.35, 0.0))
	_fog_front = _add_layer(_front, "fog", Vector2(1.15, 0.1))
	_fog_front.modulate = Color(1, 1, 1, 0.28)

	var vig_layer := CanvasLayer.new()
	vig_layer.layer = 4
	add_child(vig_layer)
	var vig := TextureRect.new()
	vig.texture = load("res://assets/art/vignette.png")
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig_layer.add_child(vig)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_fog_back.motion_offset.x -= 10.0 * delta
	_fog_front.motion_offset.x -= 22.0 * delta


func _add_layer(parent: Node, tex_name: String, motion: Vector2) -> ParallaxLayer:
	var l := ParallaxLayer.new()
	l.motion_scale = motion
	var s := Sprite2D.new()
	s.texture = load("res://assets/art/%s.png" % tex_name)
	s.centered = false
	l.add_child(s)
	parent.add_child(l)
	return l


func _place(layer: ParallaxLayer, scale_f: float, y: float) -> void:
	var s := layer.get_child(0) as Sprite2D
	s.scale = Vector2(scale_f, scale_f)
	s.position = Vector2(0.0, y)
	layer.motion_mirroring = Vector2(TEX_W * scale_f, 0.0)


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var gy := vp.y * 0.5 + GROUND_BELOW_CENTER   # where the ground is on screen

	var sf := maxf(vp.y * 1.25 / TEX_H, 1.0)
	_place(_far, sf, (vp.y - TEX_H * sf) * 0.5)

	var sm := maxf(vp.y * 0.95 / TEX_H, 1.3)
	_place(_mid, sm, gy - MID_BASE * sm)

	var sfog := 1.6
	_place(_fog_back, sfog, gy - 40.0 - 0.62 * TEX_H * sfog)

	var sn := maxf(vp.y * 1.05 / TEX_H, 1.0)
	_place(_near, sn, vp.y - TEX_H * sn)

	var sfog2 := 2.2
	_place(_fog_front, sfog2, gy + 20.0 - 0.62 * TEX_H * sfog2)
