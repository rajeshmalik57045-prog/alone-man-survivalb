extends Node3D
## TEMPORARY test arena for Phase 1 (movement, camera, jump, USE button).
## Phase 2 replaces this with a real terrain, forest, rocks and river built from real assets.


func _ready() -> void:
	_build_environment()
	_build_ground_and_obstacles()
	_build_pickups()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


func _build_ground_and_obstacles() -> void:
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(240.0, 1.0, 240.0), Color(0.27, 0.38, 0.2))

	# Scattered blocks give a sense of movement and something for the camera to collide with.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 40:
		var x := rng.randf_range(-40.0, 40.0)
		var z := rng.randf_range(-40.0, 40.0)
		if absf(x) < 5.0 and absf(z) < 5.0:
			continue
		var h := rng.randf_range(1.0, 4.0)
		var w := rng.randf_range(1.0, 3.0)
		var g := rng.randf_range(0.35, 0.6)
		_add_box(Vector3(x, h * 0.5, z), Vector3(w, h, w), Color(g, g, g))

	# Steps to test jumping (a jump reaches about 1 m).
	for i in 4:
		var step_h := 0.4 * float(i + 1)
		_add_box(Vector3(8.0 + float(i) * 1.5, step_h * 0.5, -8.0), Vector3(1.5, step_h, 4.0), Color(0.55, 0.45, 0.35))


func _build_pickups() -> void:
	_add_pickup(Vector3(3.0, 0.0, -4.0), "Wood", Color(0.45, 0.28, 0.12))
	_add_pickup(Vector3(-4.0, 0.0, -6.0), "Wood", Color(0.45, 0.28, 0.12))
	_add_pickup(Vector3(6.0, 0.0, 3.0), "Wood", Color(0.45, 0.28, 0.12))
	_add_pickup(Vector3(-6.0, 0.0, 4.0), "Stone", Color(0.5, 0.5, 0.55))
	_add_pickup(Vector3(0.0, 0.0, 8.0), "Stone", Color(0.5, 0.5, 0.55))


func _add_box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mesh_inst.mesh = mesh
	body.add_child(mesh_inst)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	add_child(body)
	return body


func _add_pickup(pos: Vector3, item: String, color: Color) -> void:
	var node := Node3D.new()
	node.position = pos
	node.add_to_group("interactable")
	node.set_meta("item", item)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mesh_inst.mesh = mesh
	mesh_inst.position.y = 0.25
	node.add_child(mesh_inst)

	add_child(node)
