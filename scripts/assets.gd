extends RefCounted
## PackedScene caches share immutable meshes/textures, skeleton instances stay distinct.
var cache: Dictionary = {}
var architecture: Node3D
var errors: Array = []

func get_scene(key: String) -> Node3D:
	if not cache.has(key):
		var path="res://assets/models/"+key+(".gltf" if key=="architecture-55" else ".glb")
		if not ResourceLoader.exists(path): errors.append(path); return Node3D.new()
		var scene=load(path)
		if not scene is PackedScene:
			errors.append("Некорректная модель: "+path)
			return Node3D.new()
		cache[key]=scene
	var result=cache[key].instantiate()
	return result

func bounds(node: Node3D, transform=Transform3D.IDENTITY) -> AABB:
	var t=transform*node.transform
	var result=AABB()
	var started=false
	if node is MeshInstance3D and node.mesh!=null:
		result=t*node.get_aabb()
		started=true
	for child in node.get_children():
		if child is Node3D:
			var box=bounds(child,t)
			if box.size.length()>0.0001:
				result=result.merge(box) if started else box
				started=true
	return result

func normalized(key: String, size: float, axis=1) -> Node3D:
	var wrapper=Node3D.new()
	var model=get_scene(key)
	wrapper.add_child(model)
	var box=bounds(model)
	if axis==2 and box.size.x>box.size.z*1.25:
		model.rotation.y+=PI/2
		box=bounds(model)
	var factor=size/max(0.0000001,box.size[axis])
	model.scale*=factor
	model.position-=Vector3(box.get_center().x,box.position.y,box.get_center().z)*factor
	set_geometry(model)
	var animations=find_animation(model)
	if animations!=null:
		wrapper.set_meta("animation",animations)
		for name in animations.get_animation_list():
			if name not in ["RESET","death","attack","attack2","heavyAttack","hit","dodge","bow","jumpStart","land","pickup"]:
				animations.get_animation(name).loop_mode=Animation.LOOP_LINEAR
		animations.play("idle" if animations.has_animation("idle") else animations.get_animation_list()[0])
	return wrapper

func building(type: String) -> Node3D:
	if architecture==null: architecture=get_scene("architecture-55")
	var root=architecture.find_child("building-"+type,true,false)
	if root==null:
		errors.append("building-"+type)
		return Node3D.new()
	var result=root.duplicate()
	set_geometry(result)
	for child in result.get_children():
		if child is Node3D: child.visible=not "lod" in child.name or "lod0" in child.name
	return result

func set_geometry(node: Node):
	if node is MeshInstance3D:
		node.extra_cull_margin=1.0
		# Godot generates mesh LODs on import; architecture additionally has authored LODs.
		node.lod_bias=0.7
	for child in node.get_children(): set_geometry(child)

func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for c in node.get_children():
		var result=find_animation(c)
		if result!=null: return result
	return null

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for c in node.get_children():
		var result=find_skeleton(c)
		if result!=null: return result
	return null

func play(node: Node3D, state: String, speed=1.0):
	var a: AnimationPlayer=node.get_meta("animation",null)
	if a==null: return
	if not a.has_animation(state): state="walk" if state in ["run","sprint","carry","pullCart"] and a.has_animation("walk") else "idle"
	if not a.has_animation(state): return
	if a.current_animation!=state: a.play(state,0.18)
	a.speed_scale=speed

func color_material(color: Color, metallic=0.0) -> StandardMaterial3D:
	var m=StandardMaterial3D.new()
	m.albedo_color=color
	m.metallic=metallic
	m.roughness=0.42 if metallic>0 else 0.85
	return m

func box(size: Vector3, color: Color) -> MeshInstance3D:
	var m=MeshInstance3D.new()
	var mesh=BoxMesh.new()
	mesh.size=size
	m.mesh=mesh
	m.material_override=color_material(color)
	return m

func cloth(width: float,height: float,color: Color) -> MeshInstance3D:
	var s=SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx=12
	var ny=16
	for y in ny:
		for x in nx:
			for p in [Vector2(x,y),Vector2(x+1,y),Vector2(x,y+1),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
				var uv=Vector2(p.x/nx,p.y/ny)
				s.set_uv(uv)
				s.add_vertex(Vector3((uv.x-0.5)*width,-uv.y*height,0))
	s.generate_normals()
	var result=MeshInstance3D.new()
	result.mesh=s.commit()
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/cloth.gdshader")
	mat.set_shader_parameter("cloth_color",color)
	result.material_override=mat
	return result

func dispose():
	if architecture!=null: architecture.free(); architecture=null
	cache.clear()
