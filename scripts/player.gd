extends CharacterBody3D
## Player controller (Phase 1): camera-relative movement, sprint, jump, crouch, USE action.
##
## VISUAL: the first model found in MODEL_CANDIDATES is used (the Mixamo "Idle.fbx" with skin).
## Animations are loaded from the other FBX files listed in ANIM_FILES (Mixamo "Without Skin").
## If no model is found, a clearly-marked PLACEHOLDER capsule is shown.

signal notified(text: String)

const MODEL_CANDIDATES := [
	"res://assets/characters/survivor.glb",
	"res://assets/characters/survivor.fbx",
	"res://assets/characters/Idle.fbx",
]
const ANIM_DIR := "res://assets/characters/"
## animation name -> file that contains it. "idle" comes from the model file itself.
const ANIM_FILES := {
	"walk": "Walking.fbx",
	"run": "Running.fbx",
	"jump": "Jump.fbx",
	"crouch_idle": "Crouch Idle.fbx",
	"crouch_walk": "Crouch Walk Back.fbx",
}
const LOOPING := ["idle", "walk", "run", "crouch_idle", "crouch_walk"]
const ANIM_LIB := "game"
const FBX_FACING_YAW := PI  # Mixamo models face +Z, the game moves toward -Z

const SHOW_DEBUG := true  # yellow debug text (top-left); set to false when animations work

const GRAVITY := 18.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2
const USE_RANGE := 2.6

@export var run_speed := 5.0
@export var sprint_speed := 7.5
@export var crouch_speed := 1.8
@export var jump_velocity := 6.0
@export var acceleration := 28.0

var cam_rig  # camera rig node; provides `yaw`

var health := 100.0
var hunger := 100.0
var thirst := 100.0
var stamina := 100.0

var touch_move := Vector2.ZERO
var touch_sprint := false
var crouching := false

var _jump_requested := false
var _visual: Node3D
var _is_placeholder := true
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _anim: AnimationPlayer
var _debug_label: Label
var _debug_info := "model: placeholder (no Idle.fbx found)"


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1

	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = STAND_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT * 0.5
	add_child(_shape)

	_visual = _build_visual()
	add_child(_visual)
	if _anim:
		_setup_animations()
	if SHOW_DEBUG:
		_make_debug_label()


# ---------- input from controls ----------

func on_move_changed(vector: Vector2, sprint: bool) -> void:
	touch_move = vector
	touch_sprint = sprint


func request_jump() -> void:
	_jump_requested = true


func set_crouch(on: bool) -> void:
	crouching = on
	var h := CROUCH_HEIGHT if on else STAND_HEIGHT
	_capsule.height = h
	_shape.position.y = h * 0.5
	if _is_placeholder:
		_visual.scale.y = h / STAND_HEIGHT


func use_action() -> void:
	var best: Node3D = null
	var best_dist := USE_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node3D
		if node == null:
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	if best:
		var item := str(best.get_meta("item", "Item"))
		best.remove_from_group("interactable")
		best.queue_free()
		notified.emit("%s collected" % item)
	else:
		notified.emit("Nothing to use here")


# ---------- physics ----------

func _physics_process(delta: float) -> void:
	var move := touch_move
	var sprint_wanted := touch_sprint
	if move.length() < 0.05:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprint_wanted = Input.is_action_pressed("sprint")

	var yaw := 0.0
	if cam_rig:
		yaw = cam_rig.yaw
	var dir := Basis(Vector3.UP, yaw) * Vector3(move.x, 0.0, move.y)

	var moving := move.length() > 0.1
	var sprinting := sprint_wanted and moving and not crouching and stamina > 5.0 and is_on_floor()

	var speed := run_speed
	if crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed

	var target_h := dir * speed
	velocity.x = move_toward(velocity.x, target_h.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_h.z, acceleration * delta)

	if is_on_floor():
		if _jump_requested and not crouching:
			velocity.y = jump_velocity
	else:
		velocity.y -= GRAVITY * delta
	_jump_requested = false

	if sprinting:
		stamina = maxf(0.0, stamina - 18.0 * delta)
	else:
		stamina = minf(100.0, stamina + 12.0 * delta)

	if moving:
		var target_yaw := atan2(-dir.x, -dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))

	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	if _debug_label:
		var playing := ""
		if _anim:
			playing = "\nplaying: %s" % str(_anim.current_animation)
		_debug_label.text = _debug_info + playing
	if _anim == null:
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var key := "idle"
	var anim_speed := 1.0
	if not is_on_floor():
		key = "jump"
	elif crouching:
		key = "crouch_walk" if hspeed > 0.3 else "crouch_idle"
	elif hspeed > 3.2:
		key = "run"
		anim_speed = clampf(hspeed / 4.6, 0.8, 1.6)
	elif hspeed > 0.3:
		key = "walk"
		anim_speed = clampf(hspeed / 1.4, 0.6, 2.0)

	var full := "%s/%s" % [ANIM_LIB, key]
	if not _anim.has_animation(full):
		full = "%s/idle" % ANIM_LIB
		if not _anim.has_animation(full):
			return
	_anim.speed_scale = anim_speed
	if _anim.current_animation != full:
		_anim.play(full, 0.2)


# ---------- visuals ----------

func _build_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"

	for path in MODEL_CANDIDATES:
		if not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var model := scene.instantiate() as Node3D
		if model == null:
			continue
		if str(path).ends_with(".fbx"):
			model.rotation.y = FBX_FACING_YAW
		root.add_child(model)
		var found := model.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			_anim = found[0] as AnimationPlayer
		else:
			_debug_info = "model loaded but NO AnimationPlayer inside Idle.fbx"
		_is_placeholder = false
		return root

	# PLACEHOLDER (orange capsule with a "nose" box so the facing direction is visible).
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = STAND_HEIGHT
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.45, 0.15)
	capsule.material = body_mat
	body.mesh = capsule
	body.position.y = STAND_HEIGHT * 0.5
	root.add_child(body)

	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 0.3)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.95, 0.9, 0.8)
	box.material = nose_mat
	nose.mesh = box
	nose.position = Vector3(0.0, 1.5, -0.38)
	root.add_child(nose)

	return root


func _make_debug_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_debug_label = Label.new()
	_debug_label.position = Vector2(24.0, 215.0)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	_debug_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_debug_label.add_theme_constant_override("outline_size", 4)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_debug_label)


func _setup_animations() -> void:
	var lib := AnimationLibrary.new()
	var report: PackedStringArray = []

	# Work out where the skeleton is, relative to the AnimationPlayer's root node.
	var skel_path := ""
	var anim_root := _anim.get_node_or_null(_anim.root_node)
	if anim_root:
		var skel := _find_skeleton(anim_root)
		if skel:
			skel_path = str(anim_root.get_path_to(skel))
	report.append("skeleton: %s" % (skel_path if skel_path != "" else "NOT FOUND"))

	var own := _best_animation(_anim)
	if own:
		lib.add_animation("idle", _prepare_animation(own, "idle", ""))
		report.append("idle OK %.1fs" % own.length)
	else:
		report.append("idle: NO ANIMATION in Idle.fbx")

	for key in ANIM_FILES:
		var file_name := String(ANIM_FILES[key])
		var path: String = ANIM_DIR + file_name
		if not ResourceLoader.exists(path):
			report.append("%s: file missing" % str(key))
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			report.append("%s: cannot load" % str(key))
			continue
		var inst := packed.instantiate()
		var players := inst.find_children("*", "AnimationPlayer", true, false)
		var added := false
		if not players.is_empty():
			var src := _best_animation(players[0] as AnimationPlayer)
			if src:
				lib.add_animation(str(key), _prepare_animation(src, str(key), skel_path))
				report.append("%s OK %.1fs" % [str(key), src.length])
				added = true
		if not added:
			report.append("%s: no animation" % str(key))
		inst.free()

	_anim.add_animation_library(ANIM_LIB, lib)
	_debug_info = "\n".join(report)


func _find_skeleton(node: Node) -> Skeleton3D:
	var found := node.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return null
	return found[0] as Skeleton3D


## Mixamo files contain an empty "Take 001" plus the real animation, so pick the longest one.
func _best_animation(player: AnimationPlayer) -> Animation:
	var best: Animation = null
	for anim_name in player.get_animation_list():
		if str(anim_name) == "RESET":
			continue
		var a := player.get_animation(anim_name)
		if a == null:
			continue
		if best == null or a.length > best.length:
			best = a
	if best != null and best.length < 0.05:
		return null
	return best


func _prepare_animation(src: Animation, key: String, skel_path: String) -> Animation:
	var anim := src.duplicate() as Animation
	anim.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(key) else Animation.LOOP_NONE

	for t in anim.get_track_count():
		var track_type := anim.track_get_type(t)
		var is_bone_track := (
			track_type == Animation.TYPE_POSITION_3D
			or track_type == Animation.TYPE_ROTATION_3D
			or track_type == Animation.TYPE_SCALE_3D
		)
		var bone := anim.track_get_path(t).get_concatenated_subnames()

		# Point bone tracks of other files at THIS model's skeleton.
		if is_bone_track and bone != "" and skel_path != "":
			anim.track_set_path(t, NodePath("%s:%s" % [skel_path, bone]))

		# Keep the hip bone from travelling forward/sideways, so the animation plays "in place".
		if track_type == Animation.TYPE_POSITION_3D and bone.ends_with("Hips"):
			var count := anim.track_get_key_count(t)
			if count > 0:
				var first: Vector3 = anim.track_get_key_value(t, 0)
				for k in count:
					var v: Vector3 = anim.track_get_key_value(t, k)
					anim.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))
	return anim
