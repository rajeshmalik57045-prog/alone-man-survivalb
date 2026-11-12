extends Node3D
## Phase 1 entry point. Builds the test world, player, camera rig, HUD and touch controls,
## then wires them together with signals.

const InputSetup := preload("res://scripts/input_setup.gd")
const WorldScript := preload("res://scripts/test_world.gd")
const PlayerScript := preload("res://scripts/player.gd")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const HudScript := preload("res://scripts/hud.gd")
const ControlsScript := preload("res://scripts/mobile_controls.gd")


func _ready() -> void:
	InputSetup.register_actions()

	var world = WorldScript.new()
	world.name = "TestWorld"
	add_child(world)

	var player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child(player)

	var rig = CameraRigScript.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.set_target(player)
	player.cam_rig = rig

	var hud = HudScript.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind(player, rig)

	var controls_layer := CanvasLayer.new()
	controls_layer.name = "ControlsLayer"
	controls_layer.layer = 10
	add_child(controls_layer)

	var controls = ControlsScript.new()
	controls.name = "MobileControls"
	controls_layer.add_child(controls)

	controls.move_changed.connect(player.on_move_changed)
	controls.look_delta.connect(rig.add_look)
	controls.jump_pressed.connect(player.request_jump)
	controls.use_pressed.connect(player.use_action)
	controls.crouch_toggled.connect(player.set_crouch)
	controls.menu_pressed.connect(hud.on_menu_pressed)
	player.notified.connect(hud.show_message)

	hud.show_message("ALONE MAN - Phase 1 test world")
