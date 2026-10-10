extends Node
## VFX — global cinematic effects autoload.
## Screen shake, hit-stop, slow-mo, letterbox bars, screen flashes,
## shockwave rings, particle bursts, chidori aura, domain expansion dome.
## All effects are built in code; no textures or pre-made assets needed.

var _trauma := 0.0
var _bars_t := 0.0
var _bars_target := 0.0
var _ts_token := 0

var _bar_top: ColorRect
var _bar_bot: ColorRect
var _flash_rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_bar_top = ColorRect.new()
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bar_top)
	_bar_bot = ColorRect.new()
	_bar_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bar_bot)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	layer.add_child(_flash_rect)

func _process(delta: float) -> void:
	# Letterbox bars ease toward target.
	_bars_t = lerpf(_bars_t, _bars_target, clampf(10.0 * delta, 0.0, 1.0))
	var h := get_viewport().get_visible_rect().size.y
	var bh := h * 0.11 * _bars_t
	_bar_top.offset_bottom = bh
	_bar_bot.offset_top = -bh
	# Trauma-based screen shake.
	var cam := get_viewport().get_camera_3d()
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 1.7)
		if cam != null:
			var s := _trauma * _trauma * 1.4
			cam.h_offset = randf_range(-s, s)
			cam.v_offset = randf_range(-s, s)
	elif cam != null and (cam.h_offset != 0.0 or cam.v_offset != 0.0):
		cam.h_offset = 0.0
		cam.v_offset = 0.0

# ------------------------------------------------------------- time control --
func _set_time_scale(scale: float, dur: float) -> void:
	_ts_token += 1
	var mine := _ts_token
	Engine.time_scale = scale
	await get_tree().create_timer(dur, true, false, true).timeout
	if mine == _ts_token:
		Engine.time_scale = 1.0

## Brief freeze on hit — the core of game feel.
func hitstop(dur := 0.09) -> void:
	_set_time_scale(0.05, dur)

## Cinematic slow motion.
func slowmo(scale := 0.3, dur := 1.0) -> void:
	_set_time_scale(scale, dur)

# ------------------------------------------------------------------ camera --
func shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)

func letterbox(on: bool) -> void:
	_bars_target = 1.0 if on else 0.0

func flash(color: Color, strength := 0.7, dur := 0.3) -> void:
	var c := color
	c.a = strength
	_flash_rect.color = c
	var tw := _flash_rect.create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, dur)

# ------------------------------------------------------------------- spawns --
func _glow_mat(color: Color, alpha := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.5
	return m

func _particle_quad(color: Color, size := 0.35) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	q.material = m
	return q

## Expanding ground shockwave ring.
func shockwave(pos: Vector3, color: Color, max_radius := 7.0, dur := 0.45) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 12
	mi.mesh = tm
	var mat := _glow_mat(color)
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.3, 0)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * max_radius, dur)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)

## One-shot particle burst.
func burst(pos: Vector3, color: Color, count := 40, speed := 10.0) -> void:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.92
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -9, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.1
	pm.scale_max = 0.28
	pm.color = color
	p.process_material = pm
	p.draw_pass_1 = _particle_quad(color)
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.restart()
	p.finished.connect(p.queue_free)

## Crackling lightning aura that follows a node (the Chidori charge).
func chidori_aura(target: Node3D, dur: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 0.4
	p.preprocess = 0.4
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.9
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, 6, 0)
	pm.scale_min = 0.06
	pm.scale_max = 0.2
	pm.color = Color(0.55, 0.8, 1.0)
	p.process_material = pm
	p.draw_pass_1 = _particle_quad(Color(0.6, 0.85, 1.0), 0.3)
	target.add_child(p)
	p.position = Vector3(0, 1.0, 0)
	p.restart()
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.75, 1.0)
	light.light_energy = 4.0
	light.omni_range = 9.0
	target.add_child(light)
	light.position = Vector3(0, 1.2, 0)
	var flick := light.create_tween().set_loops()
	flick.tween_property(light, "light_energy", 1.5, 0.06)
	flick.tween_property(light, "light_energy", 5.0, 0.06)
	var tw := target.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(p.queue_free)
	tw.tween_callback(light.queue_free)

## DOMAIN EXPANSION — the cinematic ultimate.
func domain_expansion(center: Vector3, radius: float, tint: Color) -> void:
	letterbox(true)
	slowmo(0.22, 1.5)
	flash(Color(tint.r + 0.2, tint.g, tint.b + 0.05), 0.55, 0.6)
	shake(0.7)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 48
	sm.rings = 24
	dome.mesh = sm
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/domain.gdshader")
	sh.set_shader_parameter("tint", tint)
	dome.material_override = sh
	get_tree().current_scene.add_child(dome)
	dome.global_position = center + Vector3(0, 1.0, 0)
	dome.scale = Vector3.ONE * 0.5
	var tw := dome.create_tween()
	tw.tween_property(dome, "scale", Vector3.ONE * radius, 1.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(dome, "scale", Vector3.ONE * (radius * 1.12), 0.9)
	tw.parallel().tween_method(func(v: float) -> void: sh.set_shader_parameter("fade", v), 0.0, 1.0, 0.9)
	tw.tween_callback(dome.queue_free)
	await get_tree().create_timer(4.2, true, false, true).timeout
	letterbox(false)
