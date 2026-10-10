extends Control
## Domain meter HUD. Always visible (desktop and touch).

@export var player_path: NodePath

var _player: Node = null
var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player_path != NodePath(""):
		_player = get_node_or_null(player_path)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if _player == null:
		return
	var mval: float = _player.get("meter")
	var frac: float = clampf(mval / 100.0, 0.0, 1.0)
	var vp := get_viewport_rect().size
	var w := 440.0
	var h := 24.0
	var pos := Vector2((vp.x - w) * 0.5, vp.y - h - 30.0)
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.55))
	var fill := Color(1.0, 0.35, 0.15)
	if frac >= 1.0:
		var pulse := 0.75 + 0.25 * sin(_t * 8.0)
		fill = Color(1.0, 0.1 + 0.25 * pulse, 0.2)
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2((w - 4) * frac, h - 4)), fill)
	draw_rect(Rect2(pos, Vector2(w, h)), Color(1, 1, 1, 0.6), false, 2.0)
	var font := ThemeDB.fallback_font
	var label := "DOMAIN EXPANSION READY" if frac >= 1.0 else "DOMAIN METER"
	var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	var alpha := 0.65 + 0.35 * absf(sin(_t * 6.0)) if frac >= 1.0 else 0.85
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, pos.y - 10.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, alpha))
