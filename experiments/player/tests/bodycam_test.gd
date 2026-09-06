extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	var overlay = scene.get_node("BodycamOverlay")
	# All permanent UI and effect nodes exist before _ready.
	assert(overlay.get_node("Effects") is ColorRect)
	assert(overlay.get_node("Watermark/AxonIcon").texture is AtlasTexture)
	assert(overlay.get_node("Clock") is Timer)
	assert(overlay.format_timestamp(0, 0) == "1970-01-01 00:00:00 +0000")
	assert(overlay.format_timestamp(0, -420) == "1969-12-31 17:00:00 -0700")
	assert(overlay.format_timestamp(0, 330) == "1970-01-01 05:30:00 +0530")
	root.add_child(scene)
	overlay.settings = overlay.settings.duplicate()
	var rig = scene.get_node("Player/LookRig")
	overlay.settings.first_person_only = true
	rig.set_first_person(false)
	await process_frame
	await process_frame
	assert(not overlay.effects.visible and not overlay.watermark.visible)
	rig.set_first_person(true)
	await process_frame
	await process_frame
	assert(overlay.effects.visible and overlay.watermark.visible)
	var previous_time: String = overlay.timestamp.text
	await create_timer(1.3).timeout
	assert(previous_time != overlay.timestamp.text)
	for node in overlay.find_children("*", "Control", true, false):
		assert(node.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/bodycam-preview.png")
	overlay.settings.effects_enabled = false
	await process_frame
	await process_frame
	assert(not overlay.effects.visible and overlay.watermark.visible)
	print("Bodycam: static scene, timezone rollover, live clock, view modes and input passthrough OK")
	quit()
