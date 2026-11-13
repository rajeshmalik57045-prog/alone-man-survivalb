extends Node3D
## Entry point. Builds the world, player, camera rig, HUD, game state, menus and touch controls,
## then wires them together with signals.

const InputSetup := preload("res://scripts/input_setup.gd")
const WorldScript := preload("res://scripts/world.gd")
const PlayerScript := preload("res://scripts/player.gd")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const HudScript := preload("res://scripts/hud.gd")
const ControlsScript := preload("res://scripts/mobile_controls.gd")
const StateScript := preload("res://scripts/game_state.gd")
const MenusScript := preload("res://scripts/menus.gd")

var _hud
var _menus


func _ready() -> void:
	InputSetup.register_actions()

	var world = WorldScript.new()
	world.name = "World"
	add_child(world)

	var player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0.0, world.height_at(0.0, 0.0) + 1.5, 0.0)
	add_child(player)

	var rig = CameraRigScript.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.set_target(player)
	player.cam_rig = rig

	_hud = HudScript.new()
	_hud.name = "Hud"
	add_child(_hud)
	_hud.bind(player, rig)

	var controls_layer := CanvasLayer.new()
	controls_layer.name = "ControlsLayer"
	controls_layer.layer = 10
	add_child(controls_layer)

	var controls = ControlsScript.new()
	controls.name = "MobileControls"
	controls_layer.add_child(controls)

	var state = StateScript.new()
	state.name = "GameState"
	state.player = player
	state.world = world
	add_child(state)
	player.world = world
	player.state = state

	_menus = MenusScript.new()
	_menus.name = "Menus"
	add_child(_menus)
	_menus.setup(state, controls)

	controls.move_changed.connect(player.on_move_changed)
	controls.look_delta.connect(rig.add_look)
	controls.jump_pressed.connect(player.request_jump)
	controls.use_pressed.connect(player.use_action)
	controls.crouch_toggled.connect(player.set_crouch)
	controls.menu_pressed.connect(_on_menu_pressed)
	player.notified.connect(_hud.show_message)
	state.message.connect(_hud.show_message)

	_hud.show_message("ALONE MAN - Phase 3: gather, craft, survive")


func _on_menu_pressed(id: String) -> void:
	if id == "inventory" or id == "crafting":
		_menus.open(id)
	else:
		_hud.on_menu_pressed(id)
