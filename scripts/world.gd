extends Node3D
## Native scene, meshes, PBR materials, skeletal animation and touchscreen camera.
var assets=preload("res://scripts/assets.gd").new()
var hud
var camera: Camera3D
var sun: DirectionalLight3D
var environment: WorldEnvironment
var hero: Node3D
var equipment_root: Node3D
var weapon_root: Node3D
var cape: MeshInstance3D
var character_rig
var meshes: Dictionary={}
var construction_meshes: Dictionary={}
var effects: Array=[]
var projectile_meshes: Dictionary={}
var flora: Array=[]
var camera_yaw=0.0
var camera_pitch=0.12
var camera_distance=6.4
var camera_center=Vector3.ZERO
var active=false
var refresh_clock=0.0
var perf_clock=0.0
var hero_equipment=""
var build_type=""
var build_yaw=0.0
var build_point: Dictionary={}
var build_check: Dictionary={}
var ghost: Node3D
var group_build=false
var marker: MeshInstance3D
var look_pointer=-1
var mouse_look=false
var audio_players: Array=[]
var ambience: Array=[]
var audio_on=true
var music_on=true
var loading: Label
var water: MeshInstance3D
var ship_cloth: Dictionary={}
var landscape: Node3D
var collision_root: Node3D
var screenshot_done=false
var ambient_clock=0.0
var last_step=0.0
var last_swimming=false
var last_track={}
var raft: Node3D
var build_snap: bool:
	get: return Game.player.get("buildSnap",true)
	set(value): Game.player["buildSnap"]=value
var audio_levels={"master":0.65,"music":0.16,"ambience":0.45}
var audio_samples: Dictionary={}
var application_paused=false
var last_jumping=false
var creak_clock=4.0
var quality_profile: Dictionary={}
var quality_requested="auto"
var resolution_warmup=4.0
var resolution_total=0.0
var resolution_samples=0
var resolution_slow=0
var resolution_fast=0
var look_movement=0.0
var look_start=Vector2.ZERO
var mouse_button=0
var view_mode="3d"
var map_layer: CanvasLayer
var map_world: Control
var map_scale=7.0
var graphics_ready=false
var graphics_loading=false
var loading_canvas: CanvasLayer
const SETTINGS_PATH="user://aegea_settings.json"
const QUALITY_SPECS={
	"low":{"scale":0.65,"min":0.5,"max":0.75,"target":30,"shadow":0,"range":18,"aa":0},
	"medium":{"scale":0.8,"min":0.6,"max":1.0,"target":40,"shadow":1024,"range":23,"aa":1},
	"iphone":{"scale":0.9,"min":0.65,"max":1.25,"target":50,"shadow":1024,"range":28,"aa":1},
	"high":{"scale":1.0,"min":0.75,"max":1.5,"target":55,"shadow":2048,"range":48,"aa":1},
	"mac":{"scale":1.25,"min":0.8,"max":1.75,"target":55,"shadow":4096,"range":64,"aa":2}
}

func _ready():
	load_preferences()
	_setup_light()
	_setup_camera()
	landscape=Node3D.new()
	landscape.name="Landscape"
	add_child(landscape)
	collision_root=Node3D.new()
	add_child(collision_root)
	hud=preload("res://scripts/hud.gd").new()
	hud.world=self
	add_child(hud)
	Game.effect.connect(_effect)
	Game.world_reloaded.connect(_reload)
	Game.ai.rebuild_grid()
	camera_center=Game.point(Game.player,1.4)
	_make_ambient()
	active=true
	apply_quality(quality_requested)
	set_view_mode(view_mode,false)
	hud.show_start()
	if "--self-test-scene" in OS.get_cmdline_user_args():
		set_view_mode("3d",false)
		while graphics_loading: await get_tree().process_frame
		hud.close_panel()
		await get_tree().create_timer(4.0).timeout
		print("SCENE_READY models=",meshes.size()," hero_animations=",hero.get_meta("animation").get_animation_list().size() if hero!=null and hero.has_meta("animation") else 0," errors=",assets.errors)
		get_tree().quit(0 if graphics_ready and assets.errors.is_empty() else 1)

func _loading_overlay():
	if loading_canvas!=null: return
	loading_canvas=CanvasLayer.new()
	loading_canvas.layer=10
	add_child(loading_canvas)
	var panel=PanelContainer.new()
	panel.position=Vector2(35,35)
	panel.custom_minimum_size=Vector2(540,0)
	loading_canvas.add_child(panel)
	var column=VBoxContainer.new()
	panel.add_child(column)
	loading=Label.new()
	loading.text="AEGEA · Подготовка 3D…"
	loading.add_theme_font_size_override("font_size",24)
	column.add_child(loading)
	var skip=Button.new()
	skip.text="Продолжить в 2D без загрузки моделей"
	skip.custom_minimum_size.y=48
	skip.pressed.connect(func(): set_view_mode("2d"))
	column.add_child(skip)

func _finish_loading_overlay():
	if loading_canvas!=null:
		loading_canvas.queue_free()
		loading_canvas=null
		loading=null

func _load_graphics():
	if graphics_ready or graphics_loading: return
	active=false
	graphics_loading=true
	assets.errors.clear()
	if water!=null: water.queue_free(); water=null
	_loading_overlay()
	await get_tree().process_frame
	for node in landscape.get_children(): node.free()
	for island in Game.catalog.ISLANDS:
		if view_mode=="2d":
			graphics_loading=false
			active=true
			_finish_loading_overlay()
			return
		loading.text="AEGEA · Создание острова "+island.name
		_make_terrain(island)
		await get_tree().process_frame
	if view_mode=="2d":
		graphics_loading=false
		active=true
		_finish_loading_overlay()
		return
	_make_water()
	await get_tree().process_frame
	if view_mode=="2d":
		water.queue_free(); water=null
		graphics_loading=false
		active=true
		_finish_loading_overlay()
		return
	hero=assets.normalized("ranger",1.92)
	if not hero.has_meta("animation"):
		assets.errors.append("Не удалось подготовить модель героя")
		hero.free(); hero=null
		graphics_loading=false
		active=true
		_finish_loading_overlay()
		set_view_mode("2d")
		Game.notify("3D-модель не загружена. Открыт 2D-режим; повторите 3D в настройках.")
		return
	hero.name="Hero"
	add_child(hero)
	_setup_hero()
	_make_raft()
	marker=MeshInstance3D.new()
	var ring=TorusMesh.new()
	ring.inner_radius=0.73; ring.outer_radius=0.8; ring.rings=24; ring.ring_segments=6
	marker.mesh=ring
	marker.material_override=assets.color_material(Color("dcb878"))
	add_child(marker)
	marker.visible=false
	graphics_ready=true
	graphics_loading=false
	active=true
	_finish_loading_overlay()
	_sync_nearby()


func _setup_light():
	environment=WorldEnvironment.new()
	var env=Environment.new()
	var sky=Sky.new()
	var material=ProceduralSkyMaterial.new()
	material.sky_top_color=Color("3b769c")
	material.sky_horizon_color=Color("cbd9cf")
	material.ground_horizon_color=Color("b6c4b2")
	material.ground_bottom_color=Color("3c4436")
	material.sun_angle_max=20
	sky.sky_material=material
	sky.radiance_size=Sky.RADIANCE_SIZE_128
	env.background_mode=Environment.BG_SKY
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy=0.62
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure=1.0
	env.fog_enabled=true
	env.fog_light_color=Color("a1b7b9")
	env.fog_density=0.0009
	env.fog_sky_affect=0.25
	environment.environment=env
	add_child(environment)
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_color=Color("fff1dc")
	sun.light_energy=1.65
	sun.shadow_enabled=true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance=65
	sun.shadow_bias=0.03
	sun.shadow_normal_bias=0.8
	add_child(sun)

func _setup_camera():
	camera=Camera3D.new()
	camera.fov=64
	camera.near=0.15
	camera.far=1700
	camera.current=true
	add_child(camera)

func _make_terrain(island: Dictionary):
	var tool=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid_size=112
	var sx=island.rx*2.35
	var sz=island.rz*2.35
	for z in grid_size:
		for x in grid_size:
			for p in [Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]:
				var px=island.x+(p.x/grid_size-0.5)*sx
				var pz=island.z+(p.y/grid_size-0.5)*sz
				tool.set_uv(Vector2(px,pz)*0.2)
				tool.add_vertex(Vector3(px,Game.height_at(px,pz),pz))
	tool.generate_normals()
	tool.generate_tangents()
	tool.index()
	var mesh=MeshInstance3D.new()
	mesh.mesh=tool.commit()
	mesh.name="Island_"+island.id
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/ground.gdshader")
	for key in ["sand","soil","rock","shore"]: mat.set_shader_parameter(key+"_tex",load("res://assets/pbr/"+key+"-color.jpg"))
	mat.set_shader_parameter("detail_normal",load("res://assets/pbr/shore-normal.jpg"))
	mat.set_shader_parameter("biome_color",Color(island.color))
	mat.set_shader_parameter("volcanic",1.0 if island.id=="thera" else 0.0)
	mesh.material_override=mat
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	landscape.add_child(mesh)

func _make_water():
	var extent=float(Game.catalog.LIMITS.world)
	# Linear-filtered depth field, not a visible tiled shoreline mesh.
	var image=Image.create(256,256,false,Image.FORMAT_RF)
	for z in 256:
		for x in 256:
			var h=Game.height_at((float(x)/255-0.5)*extent*2,(float(z)/255-0.5)*extent*2)
			image.set_pixel(x,z,Color((h+50)/100,0,0))
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/ocean.gdshader")
	mat.set_shader_parameter("seabed",ImageTexture.create_from_image(image))
	mat.set_shader_parameter("world_extent",extent)
	var plane=PlaneMesh.new()
	plane.size=Vector2(extent*2.2,extent*2.2)
	plane.subdivide_width=160
	plane.subdivide_depth=160
	water=MeshInstance3D.new()
	water.mesh=plane
	water.material_override=mat
	water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _setup_hero():
	character_rig=preload("res://scripts/character_rig.gd").new()
	hero.add_child(character_rig)
	character_rig.configure(hero,assets)
	cape=character_rig.cape
	equipment_root=character_rig.equipment_root
	weapon_root=character_rig.weapon_root

func _make_raft():
	raft=Node3D.new()
	add_child(raft)
	for i in 7:
		var log_mesh=MeshInstance3D.new()
		var cylinder=CylinderMesh.new()
		cylinder.top_radius=0.19; cylinder.bottom_radius=0.22; cylinder.height=3.5; cylinder.radial_segments=12
		log_mesh.mesh=cylinder
		log_mesh.material_override=assets.color_material(Color("795532"))
		log_mesh.rotation.x=PI/2
		log_mesh.position.x=(i-3)*0.4
		raft.add_child(log_mesh)
	var mast=assets.box(Vector3(0.09,3.6,0.09),Color("8b643e"))
	mast.position.y=1.8; raft.add_child(mast)
	var sail=assets.cloth(1.9,2.1,Color("ddd3b5"))
	sail.position=Vector3(0,3.4,0.09); raft.add_child(sail)
	raft.hide()

func _equipment():
	var key=JSON.stringify(Game.player.equipment)+str(Game.player.tool)
	if key==hero_equipment: return
	hero_equipment=key
	character_rig.rebuild(Game.player.equipment,Game.player.tool,Game.catalog)

func _physics_process(dt):
	if not active or hud==null or application_paused: return
	if hud.current_page=="start": return
	var input=hud.input_state()
	var move: Vector2=input.move
	move=move.rotated(-camera_yaw) # Source applies camera-relative steering both on foot and aboard.
	input.move=move
	if Input.is_key_pressed(KEY_ALT): input["mode"]="walk"
	elif Input.is_key_pressed(KEY_SHIFT): input["mode"]="sprint"
	Game.step(dt,input)
	if build_type!="": _update_ghost()

func _process(dt):
	if not active: return
	_update_audio(dt)
	_update_effects(dt)
	_sample_resolution(dt)
	if view_mode=="2d" or not graphics_ready:
		if build_type!="": _update_ghost()
		return
	_equipment()
	hero.position=Vector3(Game.player.x,Game.player.y,Game.player.z)
	hero.rotation.y=lerp_angle(hero.rotation.y,Game.player.yaw,1-exp(-dt*13))
	raft.visible=Game.player.sailing and Game.player.shipId=="" and not Game.player.dead
	if raft.visible:
		raft.position=Vector3(Game.player.x,0.16+sin(Game.state.time)*0.08,Game.player.z)
		raft.rotation=Vector3(sin(Game.state.time*1.3)*0.018,Game.player.yaw,cos(Game.state.time)*0.025)
	hero.visible=not Game.player.dead or Game.state.time-Game.player.get("deathAt",Game.state.time)<5
	assets.play(hero,Game.player.actionState)
	if cape!=null: cape.material_override.set_shader_parameter("motion",Game.player.speed)
	var look=Vector3(Game.player.x,Game.player.y+1.45,Game.player.z)
	if Game.player.shipId!="": look.y+=2
	camera_center=camera_center.lerp(look,1-exp(-dt*9))
	var current_ship=Game.entity(Game.player.shipId)
	var range_camera=max(camera_distance,20.0+Game.catalog.SHIPS[current_ship.kind].length*0.6) if not current_ship.is_empty() else camera_distance
	var offset=Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))*range_camera
	var desired=camera_center+offset+Vector3(0,1.1,0)
	# Raycast native building collision, then clamp above exact procedural terrain.
	var query=PhysicsRayQueryParameters3D.create(camera_center,desired,1)
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): desired=hit.position+(camera_center-hit.position).normalized()*0.35
	desired.y=max(desired.y,Game.ground_at(desired.x,desired.z)+0.7)
	camera.position=camera.position.lerp(desired,1-exp(-dt*12))
	if camera.position.distance_to(camera_center)>0.01: camera.look_at(camera_center)
	refresh_clock+=dt
	if refresh_clock>0.22: _sync_nearby(); refresh_clock=0
	_update_meshes(dt)
	var handles: Array=[]
	var cart_id=Game.player.get("cartId","")
	if meshes.has(cart_id):
		for grip in meshes[cart_id].get_meta("grips",[]): handles.append(grip.global_position)
	character_rig.set_contact(Game.player,handles,Game.ground_at)
	var target=Game.entity(Game.player.targetId)
	marker.visible=not target.is_empty() and target.get("hp",0)>0
	if marker.visible: marker.position=Game.point(target,0.08)

func _sync_nearby():
	if not graphics_ready: return
	_sync_construction()
	var p=Game.player
	var wanted={}
	for b in Game.state.buildings:
		if b.hp>0 and Game.distance(b,p)<330:
			wanted[b.id]=b
	for r in Game.ai.resources_near(p,135):
		if r.amount>0: wanted[r.id]=r
	for e in Game.state.npcs+Game.state.animals+Game.state.creatures+Game.state.carts+Game.state.ships+Game.state.seaLife+Game.state.drops:
		var radius=380 if e.entity_kind=="ships" else 150 if e.entity_kind in ["npcs","animals","creatures"] else 95
		if Game.distance(e,p)<radius and (e.get("hp",1)>0 or Game.state.time-e.get("deathAt",-1000)<7): wanted[e.id]=e
	var added=0
	for id in wanted:
		if meshes.has(id): continue
		# One heavy model per frame-budget interval; scenery fills without a loading spike.
		if added>=6: break
		var e=wanted[id]
		var m=_make_entity(e)
		add_child(m)
		meshes[id]=m
		m.set_meta("entity",e)
		if e.entity_kind=="resources" and e.kind=="wood" and absi(e.id.hash())%9==0:
			var tuft=assets.normalized("grass-%02d" % (1+absi(e.id.hash())%20),0.35)
			tuft.position=Vector3(0.45,0,0.25)
			m.add_child(tuft)
		added+=1
	for id in meshes.keys():
		if not wanted.has(id): meshes[id].queue_free(); meshes.erase(id)

func construction_sites() -> Array:
	var sites: Array=[]
	for project in Game.state.projects:
		if not project.get("done",false): sites.append(project)
	for settlement in Game.state.settlements:
		var construction=settlement.get("construction",{})
		if construction is Dictionary and not construction.is_empty():
			var site=construction.duplicate()
			site["id"]="settlement_site_"+settlement.id
			sites.append(site)
	for group in Game.state.groups:
		var building=group.get("building",{})
		if building is Dictionary and not building.is_empty():
			var site=building.duplicate()
			site["id"]="group_site_"+group.id
			site["progress"]=group.get("progress",0.0)
			sites.append(site)
	return sites

func _sync_construction():
	var wanted={}
	for site in construction_sites():
		if Game.distance(site,Game.player)>330: continue
		wanted[site.id]=true
		var model: Node3D=construction_meshes.get(site.id)
		if model==null:
			model=assets.building(site.type)
			var material=assets.color_material(Color(0.74,0.68,0.48,0.55))
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			_override_material(model,material)
			for mesh in model.find_children("*","MeshInstance3D",true,false): mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(model)
			construction_meshes[site.id]=model
		model.position=Vector3(site.x,site.get("height",Game.height_at(site.x,site.z)),site.z)
		model.rotation.y=site.get("yaw",0.0)
		model.scale.y=0.12+clamp(site.get("progress",0.0),0.0,1.0)*0.88
	for id in construction_meshes.keys():
		if not wanted.has(id): construction_meshes[id].queue_free(); construction_meshes.erase(id)

func _refresh_building_collision(model: Node3D,building: Dictionary):
	var signature=str(building.get("open",false))+str(building.get("progress",1.0)>=1.0)+str(building.hp>0)
	if model.get_meta("collision_signature","")==signature: return
	model.set_meta("collision_signature",signature)
	var old=model.get_node_or_null("NativeBuildingCollision")
	if old!=null: model.remove_child(old); old.queue_free()
	var rects=Game.geometry.building_rects(building)
	if rects.is_empty(): return
	var body=StaticBody3D.new()
	body.name="NativeBuildingCollision"
	var height=float(Game.catalog.ARCHITECTURE55.get(building.type,{}).get("height",3.0))
	for rect in rects:
		var local=Vector2(rect.x-building.x,rect.z-building.z).rotated(building.get("yaw",0.0))
		var shape=CollisionShape3D.new()
		var box=BoxShape3D.new()
		box.size=Vector3(rect.hx*2,height,rect.hz*2)
		shape.shape=box
		shape.position=Vector3(local.x,height*0.5,local.y)
		body.add_child(shape)
	model.add_child(body)

func _make_entity(e: Dictionary) -> Node3D:
	var m: Node3D
	match e.entity_kind:
		"buildings":
			m=assets.building(e.type)
			if e.get("foundationDepth",0)>0.2:
				var meta=Game.catalog.ARCHITECTURE55[e.type]
				var foundation=assets.box(Vector3(meta.width*0.98,e.foundationDepth,meta.depth*0.98),Color("817a67"))
				foundation.position.y=-e.foundationDepth*0.5
				m.add_child(foundation)
			_refresh_building_collision(m,e)
		"resources":
			if e.kind=="wood": m=assets.normalized("pine-mature" if int(e.id.hash())%2 else "pine-mature-b",9.5*e.scale)
			elif e.kind in ["stone","ore","coal","clay"]: m=assets.normalized("rocks",(1.2 if e.kind=="stone" else 0.8)*e.scale)
			else: m=assets.normalized("plant-%02d" % (1+absi(e.id.hash())%20),0.4*e.scale)
		"npcs":
			m=assets.normalized("guard" if e.role=="guard" else "woman" if absi(e.id.hash())%3==0 else "worker",1.84)
			var bundle=assets.box(Vector3(0.4,0.28,0.65),Color("8d673c"))
			bundle.position=Vector3(0,1.0,0.35)
			m.add_child(bundle)
			m.set_meta("bundle",bundle)
		"animals": m=assets.normalized(e.kind,{"deer":1.7,"boar":0.98,"wolf":1.03,"goat":1.14,"bear":1.7}[e.kind])
		"creatures": m=assets.normalized(e.kind,Game.catalog.CREATURES[e.kind].height)
		"seaLife": m=assets.normalized(e.kind,e.get("size",1.0),2)
		"ships": m=_make_ship(e)
		"carts": m=_make_cart(e)
		_:
			m=Node3D.new()
			var bag=assets.box(Vector3(0.6,0.35,0.5),Color("997957")); bag.position.y=0.18; m.add_child(bag)
	return m

func _make_ship(e: Dictionary) -> Node3D:
	var d=Game.catalog.SHIPS[e.kind]
	var m=assets.normalized(d.model,d.length,2)
	if e.kind=="warship": m.get_child(0).rotation.y+=PI
	for k in int(d.ballistas):
		var gun=assets.normalized("ballista",2.4,2)
		gun.position=Vector3(0,d.deck,d.length*(0.27 if k==0 else -0.24))
		m.add_child(gun)
	for k in int(d.cannons):
		var gun=assets.normalized("cannon",2.1,2)
		var side=1 if k%2 else -1
		gun.position=Vector3(side*d.beam*0.38,d.deck,(floor(k/2.0)-0.5)*d.length*0.2)
		gun.rotation.y=side*PI/2
		m.add_child(gun)
	# Original sail meshes retain their UVs. Use vertex deformation, no overlapping sail copy.
	_sail_materials(m)
	var surfaces: Array=[]
	_ship_surfaces(m,surfaces)
	# The supplied merchant GLB lists canvas materials but contains ONLY hull geometry.
	# Add a native subdivided canvas rather than deforming the wooden hull.
	if e.kind=="merchant" and not surfaces.any(func(s): return s.cloth):
		var top=float(d.deck)+float(d.length)*0.39
		var sail=assets.cloth(float(d.beam)*1.25,float(d.length)*0.24,Color("d8c8a4"))
		sail.name="NativeMerchantCanvas"
		sail.position=Vector3(0,top,float(d.length)*0.03)
		m.add_child(sail)
		var yard=assets.box(Vector3(float(d.beam)*1.3,0.13,0.13),Color("785839"))
		yard.position=sail.position; m.add_child(yard)
		var mast=assets.box(Vector3(0.17,top-float(d.deck)+0.4,0.17),Color("785839"))
		mast.position=Vector3(0,(top+float(d.deck))*0.5,sail.position.z-0.12)
		m.add_child(mast)
		surfaces.append({"material":sail.material_override,"cloth":true})
	m.set_meta("damage_surfaces",surfaces)
	if e.owner!="player":
		var crew=assets.normalized("worker",1.75)
		crew.position=Vector3(0,d.deck,-d.length*0.15)
		m.add_child(crew)
	return m

func _ship_surfaces(node: Node,surfaces: Array):
	if node is MeshInstance3D and node.mesh!=null:
		for surface in node.mesh.get_surface_count():
			var material=node.get_active_material(surface)
			if material is ShaderMaterial:
				surfaces.append({"material":material,"cloth":true})
			elif material is BaseMaterial3D:
				var label=material.resource_name.to_lower()
				if not ("hull" in label or "timber" in label): continue
				var unique=material.duplicate()
				node.set_surface_override_material(surface,unique)
				surfaces.append({"material":unique,"cloth":false,"color":unique.albedo_color})
	for child in node.get_children(): _ship_surfaces(child,surfaces)

func _ship_damage(m: Node3D,e: Dictionary):
	var damage_value=clampf(1.0-float(e.hp)/maxf(1.0,float(Game.catalog.SHIPS[e.kind].hp)),0,1)
	if is_equal_approx(damage_value,m.get_meta("damage_value",-1.0)): return
	m.set_meta("damage_value",damage_value)
	for surface in m.get_meta("damage_surfaces",[]):
		if surface.cloth: surface.material.set_shader_parameter("damage",damage_value)
		else: surface.material.albedo_color=surface.color.lerp(Color("372d26"),damage_value*0.7)

func _sail_materials(node: Node):
	if node is MeshInstance3D and node.mesh!=null:
		for surface in node.mesh.get_surface_count():
			var original=node.get_active_material(surface)
			if original==null: continue
			var label=original.resource_name.to_lower()
			if not ("sail" in label or "cloth" in label or "canvas" in label): continue
			var mat=ShaderMaterial.new()
			mat.shader=load("res://shaders/cloth.gdshader")
			mat.set_shader_parameter("strength",0.16)
			if original is BaseMaterial3D:
				mat.set_shader_parameter("cloth_color",original.albedo_color)
				if original.albedo_texture!=null:
					mat.set_shader_parameter("cloth_texture",original.albedo_texture)
					mat.set_shader_parameter("use_texture",true)
			node.set_surface_override_material(surface,mat)
	for child in node.get_children(): _sail_materials(child)

func _make_cart(e: Dictionary) -> Node3D:
	var m=assets.normalized("cart",2.7,2)
	if e.kind!="wagon":
		var grips: Array=[]
		for side in [1,-1]:
			var shaft=assets.box(Vector3(0.055,0.055,1.4),Color("79522f"))
			shaft.position=Vector3(side*0.28,1.05,1.4); m.add_child(shaft)
			var grip=Marker3D.new()
			grip.position=Vector3(side*0.28,1.05,2.05); m.add_child(grip)
			grips.append(grip)
		m.set_meta("grips",grips)
	if e.kind=="wagon":
		m.scale=Vector3(1.3,1.1,1.45)
		var horse=assets.normalized("horse",1.85)
		horse.position=Vector3(0,0,3.2)
		m.add_child(horse)
		m.set_meta("horse",horse)
		for side in [-1,1]:
			var shaft=assets.box(Vector3(0.06,0.07,3.2),Color("79522f"))
			shaft.position=Vector3(side*0.4,0.65,1.6)
			m.add_child(shaft)
	var cargo=Node3D.new()
	cargo.name="VisibleCargo"
	m.add_child(cargo)
	m.set_meta("cargo",cargo)
	m.set_meta("cargo_key","")
	return m

func _cargo(m: Node3D,e: Dictionary):
	var key=JSON.stringify(e.store)
	if m.get_meta("cargo_key","")==key: return
	m.set_meta("cargo_key",key)
	var cargo: Node3D=m.get_meta("cargo")
	for child in cargo.get_children(): child.queue_free()
	var stones=e.store.get("stone",0)+e.store.get("ore",0)+e.store.get("coal",0)
	var wood=e.store.get("wood",0)+e.store.get("planks",0)
	var load_value=Game.weight(e.store)
	for i in mini(10,int(ceil(load_value/25))):
		var part: Node3D
		if wood>0 and (stones<=0 or i%2==0):
			var log_mesh=MeshInstance3D.new()
			var log_shape=CylinderMesh.new()
			log_shape.top_radius=0.1; log_shape.bottom_radius=0.12; log_shape.height=1.4; log_shape.radial_segments=8
			log_mesh.mesh=log_shape; log_mesh.material_override=assets.color_material(Color("785435")); log_mesh.rotation.x=PI/2
			part=log_mesh
		elif stones>0: part=assets.normalized("rocks",0.35+(i%3)*0.08)
		else: part=assets.box(Vector3(0.35,0.3,0.4),Color("b29568"))
		part.position=Vector3((i%3-1)*0.27,0.7+floor(i/3.0)*0.16,(i%2-0.5)*0.55)
		cargo.add_child(part)

func _wheels(node: Node,angle: float):
	if node is Node3D and "wheel" in node.name.to_lower(): node.rotation.x=angle; return
	for c in node.get_children(): _wheels(c,angle)

func _update_meshes(dt: float):
	for id in meshes:
		var m: Node3D=meshes[id]
		var e: Dictionary=m.get_meta("entity")
		var kind=e.entity_kind
		var y=Game.ground_at(e.x,e.z)
		if kind=="buildings":
			_refresh_building_collision(m,e)
			y=e.get("foundationY",y)
			var dist=Game.distance(e,Game.player)
			var lod=0 if dist<35 else 1 if dist<95 else 2
			for child in m.get_children():
				if child is Node3D and "lod" in child.name: child.visible=("lod"+str(lod)) in child.name or e.type=="road"
			if e.type=="gate":
				# Exported GLB leaves retain hinge transforms; the node names are gate-left/right, not *door*.
				for door in m.find_children("gate-left-*","Node3D",true,false): door.rotation.y=lerp_angle(door.rotation.y,-PI*0.48 if e.open else 0,1-exp(-dt*8))
				for door in m.find_children("gate-right-*","Node3D",true,false): door.rotation.y=lerp_angle(door.rotation.y,PI*0.48 if e.open else 0,1-exp(-dt*8))
		elif kind=="ships":
			_ship_damage(m,e)
			y=-0.6+sin(Game.state.time*1.2+e.x)*0.08
			m.rotation.z=sin(Game.state.time+e.z)*0.012
			if e.hp<=0: y-=(Game.state.time-e.get("deathAt",Game.state.time))*0.6
			if e.fire>0.1 and Game.state.time>=m.get_meta("next_fire",0.0) and Game.distance(e,Game.player)<130:
				_effect("fire",Vector3(e.x,Game.catalog.SHIPS[e.kind].deck+0.5,e.z))
				m.set_meta("next_fire",Game.state.time+0.35)
			if e.speed>2 and Game.state.time>=m.get_meta("next_wake",0.0) and Game.distance(e,Game.player)<120:
				_effect("splash",Vector3(e.x-sin(e.yaw)*Game.catalog.SHIPS[e.kind].length*0.4,0.12,e.z-cos(e.yaw)*Game.catalog.SHIPS[e.kind].length*0.4))
				m.set_meta("next_wake",Game.state.time+0.22)
		elif kind=="seaLife": y=e.get("y",-2.0)
		elif kind=="carts":
			_cargo(m,e)
			_wheels(m,e.wheelAngle)
			m.rotation.z=sin(Game.state.time*e.speed*2)*0.012*min(e.speed,1.0)
			if m.has_meta("horse"): assets.play(m.get_meta("horse"),"run" if e.speed>4 else "walk" if e.speed>0.2 else "idle")
			if e.speed>0.2 and (not last_track.has(e.id) or Vector2(e.x,e.z).distance_to(last_track[e.id])>0.6):
				last_track[e.id]=Vector2(e.x,e.z)
				for side in [-1,1]:
					var mark=assets.box(Vector3(0.09,0.008,0.55),Color("5b523f"))
					add_child(mark)
					var x=e.x+cos(e.yaw)*0.62*side
					var z=e.z-sin(e.yaw)*0.62*side
					mark.position=Vector3(x,Game.height_at(x,z)+0.014,z)
					mark.rotation.y=e.yaw
					effects.append({"node":mark,"life":18.0})
					if effects.size()>160: effects[0].node.queue_free(); effects.pop_front()
		if kind in ["npcs","animals","creatures"]:
			assets.play(m,e.get("state","idle"))
			if m.has_meta("bundle"): m.get_meta("bundle").visible=Game.weight(e.get("carry",{}))>0.1
			if e.get("shipId"):
				var ship=Game.entity(e.shipId)
				if not ship.is_empty(): y=Game.catalog.SHIPS[ship.kind].deck; e.x=ship.x+0.7; e.z=ship.z
		m.position=Vector3(e.x,y,e.z)
		m.rotation.y=lerp_angle(m.rotation.y,float(e.get("yaw",0)),1-exp(-dt*12))
	for p in Game.projectiles:
		if not projectile_meshes.has(p.id):
			var model=assets.box(Vector3(0.07,0.07,0.9),Color("ab8d60") if p.kind!="cannon" else Color("343936"))
			add_child(model)
			projectile_meshes[p.id]=model
		var m=projectile_meshes[p.id]
		m.position=p.pos
		m.look_at(p.pos+p.velocity)
	for id in projectile_meshes.keys():
		if not Game.projectiles.any(func(p): return p.id==id): projectile_meshes[id].queue_free(); projectile_meshes.erase(id)

func _effect(kind: String,where: Vector3):
	if DisplayServer.get_name()=="headless": return
	if Game.player and where.distance_to(Vector3(Game.player.x,Game.player.y,Game.player.z))>100: return
	_sound(kind,where)
	if view_mode=="2d" or not graphics_ready: return
	if kind in ["swing","bow","loot","inventory"]: return
	var particles=CPUParticles3D.new()
	particles.emitting=false
	particles.one_shot=true
	particles.explosiveness=0.92
	particles.amount=20 if kind in ["cannon","shipDamage","fire"] else 12
	particles.lifetime=0.65
	particles.direction=Vector3.UP
	particles.spread=150
	particles.initial_velocity_min=1.3
	particles.initial_velocity_max=4.5
	particles.gravity=Vector3(0,-8,0)
	particles.scale_amount_min=0.035
	particles.scale_amount_max=0.1
	var mesh=BoxMesh.new()
	mesh.size=Vector3(1,1,1)
	if kind=="shipDamage":
		mesh.size=Vector3(0.55,0.35,5.0)
		particles.lifetime=1.7
		particles.angular_velocity_min=-260
		particles.angular_velocity_max=260
	particles.mesh=mesh
	var color=Color("852b26") if kind=="hit" else Color("e9c47c") if kind=="metal" else Color("d4eee8") if kind in ["water","splash"] else Color("cc8646") if kind in ["fire","cannon"] else Color("927456")
	particles.material_override=assets.color_material(color)
	add_child(particles)
	particles.position=where
	particles.emitting=true
	effects.append({"node":particles,"life":2.0 if kind=="shipDamage" else 1.2})

func _update_effects(dt: float):
	for e in effects.duplicate():
		e.life-=dt
		if e.life<=0: e.node.queue_free(); effects.erase(e)

func _burst_sample(kind: String) -> AudioStreamWAV:
	if audio_samples.has(kind): return audio_samples[kind]
	var sample=AudioStreamWAV.new()
	sample.format=AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate=22050
	var duration=1.6 if kind=="cannon" else 0.7 if kind=="splash" else 0.17
	var frames=int(sample.mix_rate*duration)
	var bytes=PackedByteArray()
	bytes.resize(frames*2)
	var random=RandomNumberGenerator.new()
	random.seed=12345+kind.hash()
	var filtered=0.0
	for i in frames:
		var fraction=float(i)/frames
		var noise=random.randf_range(-1,1)
		filtered=lerp(filtered,noise,0.13 if kind=="cannon" else 0.4)
		var tone=sin(TAU*(85.0-61.0*fraction)*i/sample.mix_rate)*0.25 if kind=="cannon" else 0.0
		var value=clamp((filtered+tone)*exp(-fraction*(5.0 if kind=="cannon" else 8.0)),-1.0,1.0)
		bytes.encode_s16(i*2,int(value*32767))
	sample.data=bytes
	audio_samples[kind]=sample
	return sample

func _sound(kind: String,where: Vector3,level=0.6,rate=1.0):
	if DisplayServer.get_name()=="headless" or not audio_on or application_paused or audio_players.size()>=24: return
	var key={"hit":"arrow","wood":"chop","fire":"wind","ballista":"bow","shipDamage":"chop","guard":"metal","board":"ship","raid":"creak","raidOpen":"creak","power":"swing","sweep":"swing","dodge":"swing"}.get(kind,kind)
	var stream: AudioStream
	if kind in ["cannon","splash","hurt"]:
		stream=_burst_sample(kind)
	else:
		var path="res://assets/audio/"+key+".mp3"
		if not ResourceLoader.exists(path): return
		if not audio_samples.has(path): audio_samples[path]=load(path)
		stream=audio_samples[path]
	var player_audio=AudioStreamPlayer3D.new()
	player_audio.stream=stream
	player_audio.set_meta("level",float(level))
	player_audio.volume_db=linear_to_db(max(0.00001,float(level)*audio_levels.master))
	player_audio.pitch_scale=rate*(0.5 if kind=="ballista" else 0.6 if kind=="shipDamage" else 1.0)
	player_audio.max_distance=220 if kind in ["cannon","sink"] else 65
	add_child(player_audio)
	player_audio.global_position=where
	audio_players.append(player_audio)
	player_audio.finished.connect(func(): audio_players.erase(player_audio); player_audio.queue_free())
	player_audio.play()

func _make_ambient():
	if DisplayServer.get_name()=="headless": return
	for key in ["wind","water","music"]:
		var a=AudioStreamPlayer.new()
		a.stream=load("res://assets/audio/"+key+".mp3").duplicate()
		a.stream.loop=true
		add_child(a)
		a.set_meta("kind",key)
		ambience.append(a)
		a.play()
	_refresh_audio_levels()

func _refresh_audio_levels():
	var sea=1.0-clamp((Game.height_at(Game.player.x,Game.player.z)-0.5)/10.0,0.0,1.0) if not Game.player.is_empty() else 0.0
	for a in ambience:
		var kind=a.get_meta("kind")
		var level=audio_levels.music if kind=="music" else audio_levels.ambience*(0.26 if kind=="wind" else 0.04+sea*0.47)
		if not audio_on or application_paused or (kind=="music" and not music_on): level=0.0
		a.volume_db=linear_to_db(max(0.00001,level*audio_levels.master))
		a.stream_paused=not audio_on or application_paused or (kind=="music" and not music_on)
	for a in audio_players:
		if is_instance_valid(a):
			a.volume_db=linear_to_db(max(0.00001,a.get_meta("level",0.6)*audio_levels.master))
			a.stream_paused=not audio_on or application_paused

func set_sound(enabled: bool,music: bool):
	audio_on=enabled
	music_on=music
	_refresh_audio_levels()
	save_preferences()

func set_volume(channel: String,value: float):
	if not audio_levels.has(channel): return
	audio_levels[channel]=clamp(value,0.0,1.0)
	_refresh_audio_levels()
	save_preferences()

func _update_audio(dt: float):
	_refresh_audio_levels()
	if application_paused or Game.player.get("dead",false): return
	ambient_clock+=dt
	creak_clock-=dt
	if Game.player.speed>0.3 and Game.player.shipId=="" and Game.state.time-last_step>0.38:
		last_step=Game.state.time
		_sound("splash" if Game.player.swimming else "step%d"%(1+randi()%3),Game.point(Game.player,0.15),0.12 if Game.player.swimming else 0.22,randf_range(0.9,1.08))
	var jumping=Game.player.get("jump",0.0)>0.0
	if jumping and not last_jumping: _sound("cloth",Game.point(Game.player,1.0),0.2)
	if not jumping and last_jumping: _sound("step1",Game.point(Game.player,0.15),0.4,0.85)
	last_jumping=jumping
	if creak_clock<=0 and (Game.player.shipId!="" or (Game.player.get("cartId","")!="" and Game.player.speed>0.3)):
		_sound("creak",Game.point(Game.player,0.8),0.17,0.62 if Game.player.get("cartId","")!="" else 0.8)
		creak_clock=1.8 if Game.player.get("cartId","")!="" else randf_range(6,11)
	if Game.player.swimming and not last_swimming: _effect("splash",Vector3(Game.player.x,0.1,Game.player.z))
	last_swimming=Game.player.swimming
	if ambient_clock>8:
		ambient_clock=0
		var candidates=Game.state.animals.filter(func(a): return a.alive and Game.distance(a,Game.player)<55)
		if not candidates.is_empty():
			var animal=candidates[randi()%candidates.size()]
			_sound(animal.kind,Game.point(animal,1),0.38)

func load_preferences():
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var value=JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not value is Dictionary: return
	quality_requested=str(value.get("quality","auto"))
	view_mode="2d" if value.get("view_mode","3d")=="2d" else "3d"
	audio_on=bool(value.get("enabled",true))
	music_on=bool(value.get("music_enabled",true))
	var levels=value.get("audio",{})
	if levels is Dictionary:
		for key in audio_levels:
			if (levels.get(key) is float or levels.get(key) is int) and is_finite(float(levels[key])): audio_levels[key]=clamp(float(levels[key]),0.0,1.0)

func save_preferences():
	var file=FileAccess.open(SETTINGS_PATH,FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"quality":quality_requested,"view_mode":view_mode,"enabled":audio_on,"music_enabled":music_on,"audio":audio_levels}))
		file.close()

func apply_quality(profile: String):
	quality_requested=profile if profile in ["auto","low","medium","balanced","high","iphone","mac"] else "auto"
	Game.quality=quality_requested
	var mobile=OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
	var resolved=quality_requested
	if resolved=="auto": resolved="medium" if mobile else "high"
	if resolved=="balanced": resolved="medium"
	if resolved=="high" and mobile: resolved="iphone"
	quality_profile=QUALITY_SPECS[resolved].duplicate()
	quality_profile["id"]=resolved
	get_viewport().scaling_3d_scale=quality_profile.scale
	get_viewport().msaa_3d=quality_profile.aa
	sun.shadow_enabled=quality_profile.shadow>0
	sun.directional_shadow_max_distance=quality_profile.range
	if DisplayServer.get_name()!="headless": RenderingServer.directional_shadow_atlas_set_size(max(512,quality_profile.shadow),true)
	var forward=RenderingServer.get_current_rendering_method()=="forward_plus"
	environment.environment.ssao_enabled=forward and resolved in ["high","mac"]
	environment.environment.ssr_enabled=forward and resolved=="mac"
	environment.environment.glow_enabled=resolved=="mac" and RenderingServer.get_current_rendering_method()!="gl_compatibility"
	resolution_warmup=4.0
	resolution_total=0.0
	resolution_samples=0
	resolution_slow=0
	resolution_fast=0
	save_preferences()

func _sample_resolution(dt: float):
	if quality_profile.is_empty() or DisplayServer.get_name()=="headless" or view_mode=="2d" or dt<=0.0 or dt>0.2: return
	if resolution_warmup>0:
		resolution_warmup-=dt
		return
	resolution_total+=dt
	resolution_samples+=1
	if resolution_total<1.0: return
	var frame_ms=resolution_total/resolution_samples*1000.0
	var budget=1000.0/quality_profile.target
	resolution_total=0.0
	resolution_samples=0
	resolution_slow=resolution_slow+1 if frame_ms>budget*1.12 else 0
	resolution_fast=resolution_fast+1 if frame_ms<budget*0.78 else 0
	var next=get_viewport().scaling_3d_scale
	if resolution_slow>=2:
		next=max(quality_profile.min,next-0.12)
		resolution_slow=0; resolution_fast=0
	elif resolution_fast>=6:
		next=min(quality_profile.max,next+0.06)
		resolution_slow=0; resolution_fast=0
	get_viewport().scaling_3d_scale=next

func set_view_mode(mode: String,persist=true):
	view_mode="2d" if mode=="2d" else "3d"
	if map_layer==null:
		map_layer=CanvasLayer.new()
		map_layer.layer=-2
		add_child(map_layer)
		map_world=preload("res://scripts/map_world.gd").new()
		map_world.world=self
		map_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		map_world.mouse_filter=Control.MOUSE_FILTER_IGNORE
		map_layer.add_child(map_world)
	visible=view_mode=="3d"
	map_layer.visible=view_mode=="2d"
	if view_mode=="2d": active=true
	get_viewport().disable_3d=view_mode=="2d"
	reset_pointer_input()
	if view_mode=="3d":
		if graphics_ready: _sync_nearby()
		elif active: _load_graphics()
	if persist: save_preferences()

func reset_pointer_input():
	look_pointer=-1
	mouse_look=false
	mouse_button=0
	look_movement=0.0

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		application_paused=true
		reset_pointer_input()
		if active: _refresh_audio_levels()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		application_paused=false
		if active: _refresh_audio_levels()

func _input(event):
	# Releases must clear the captured camera pointer even outside the 3D view or over UI.
	if event is InputEventScreenTouch and not event.pressed and event.index==look_pointer:
		var tap=look_movement<6.0 and not event.canceled
		look_pointer=-1
		if tap and active and not hud.panel_open(): _tap_world(event.position,true)
	elif event is InputEventMouseButton and not event.pressed and event.button_index==mouse_button:
		var tap=mouse_look and look_movement<6.0 and mouse_button==MOUSE_BUTTON_LEFT
		reset_pointer_input()
		if tap and active and not hud.panel_open(): _tap_world(event.position,false)

func _unhandled_input(event):
	if not active or hud.panel_open(): return
	if event is InputEventMouseButton:
		if event.device==InputEvent.DEVICE_ID_EMULATION: return
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			mouse_look=true; mouse_button=event.button_index; look_movement=0.0; look_start=event.position
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var direction=1.0 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1.0
			camera_distance=clamp(camera_distance+direction,4.5,35.0)
			map_scale=clamp(map_scale-direction*0.5,3.0,14.0)
	elif event is InputEventMouseMotion and mouse_look:
		look_movement+=abs(event.relative.x)+abs(event.relative.y)
		camera_yaw-=event.relative.x*0.005
		camera_pitch=clamp(camera_pitch+event.relative.y*0.003,-0.13,0.8)
	elif event is InputEventScreenTouch:
		if event.pressed and look_pointer==-1:
			look_pointer=event.index; look_movement=0.0; look_start=event.position
	elif event is InputEventScreenDrag and event.index==look_pointer:
		look_movement+=abs(event.relative.x)+abs(event.relative.y)
		camera_yaw-=event.relative.x*0.005
		camera_pitch=clamp(camera_pitch+event.relative.y*0.003,-0.13,0.8)

func attack_action():
	if not active or hud.panel_open() or build_type!="": return false
	if Game.entity(Game.player.targetId).is_empty() and Game.player.shipId=="": Game.player.yaw=atan2(-sin(camera_yaw),-cos(camera_yaw))
	return Game.attack()

func _tap_world(screen: Vector2,touch: bool):
	if build_type!="": confirm_build(); return
	var old=Game.player.targetId
	var picked=_pick(screen)
	if picked!="":
		if old==picked: attack_action()
	elif not touch: attack_action()

func project_point(point: Vector3) -> Dictionary:
	if view_mode=="2d": return {"position":map_world.project_entity({"x":point.x,"z":point.z}),"visible":true}
	return {"position":camera.unproject_position(point),"visible":not camera.is_position_behind(point)}

func project_entity(entity: Dictionary) -> Dictionary:
	return project_point(Game.point(entity,2.0))

func _pick(screen: Vector2) -> String:
	var best={}
	var score=28.0 if view_mode=="2d" else 48.0
	for e in Game.state.npcs+Game.state.animals+Game.state.creatures+Game.state.ships+Game.state.buildings:
		if e.get("hp",0)<=0 or not e.get("alive",true): continue
		var pos=Game.point(e,1.3)
		if view_mode=="3d" and camera.is_position_behind(pos): continue
		var projected=map_world.project_entity(e) if view_mode=="2d" else camera.unproject_position(pos)
		var d=projected.distance_to(screen)
		if d<score: best=e; score=d
	if not best.is_empty() and Game.select_target(best.id): return best.id
	return ""

func start_build(type: String,team=false):
	build_type=type
	group_build=team
	if ghost!=null: ghost.queue_free()
	ghost=assets.building(type) if graphics_ready else Node3D.new()
	add_child(ghost)
	var material=StandardMaterial3D.new()
	material.albedo_color=Color(0.35,0.8,0.65,0.4)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_override_material(ghost,material)
	hud.close_panel()
	hud.build_bar.visible=true

func _override_material(node: Node,material: Material):
	if node is MeshInstance3D: node.material_override=material
	for child in node.get_children(): _override_material(child,material)

func placement_point() -> Dictionary:
	var q={"x":Game.player.x-sin(camera_yaw)*8.0,"z":Game.player.z-cos(camera_yaw)*8.0,"yaw":build_yaw}
	if build_snap:
		var step=4.0 if build_type=="road" else 1.0
		var angle=PI/2.0 if build_type=="road" else PI/4.0
		q.x=snapped(q.x,step); q.z=snapped(q.z,step); q.yaw=snapped(q.yaw,angle)
	return q

func _update_ghost():
	build_point=placement_point()
	build_check=Game.placement(build_type,build_point,build_point.yaw)
	ghost.position=Vector3(build_point.x,build_check.get("height",Game.height_at(build_point.x,build_point.z)),build_point.z)
	ghost.rotation.y=build_point.yaw
	hud.build_status.text=build_check.reason
	var color=Color(0.2,0.85,0.5,0.4) if build_check.ok else Color(0.95,0.2,0.18,0.4)
	for mesh in ghost.find_children("*","MeshInstance3D",true,false): mesh.material_override.albedo_color=color

func confirm_build():
	if build_type=="": return
	_update_ghost()
	if group_build:
		var result=Game.place_company_project(build_type,build_point,build_point.yaw)
		if not result.is_empty(): cancel_build()
	else:
		var result=Game.build(build_type,build_point,build_point.yaw)
		if not result.is_empty():
			if build_type=="road": _update_ghost()
			else: cancel_build()

func cancel_build():
	build_type=""
	if ghost!=null: ghost.queue_free(); ghost=null
	if hud!=null: hud.build_bar.visible=false

func _reload():
	if not active: return
	for m in meshes.values(): m.queue_free()
	meshes.clear()
	for model in construction_meshes.values(): model.queue_free()
	construction_meshes.clear()
	Game.ai.rebuild_grid()
	apply_quality(Game.quality)
	camera_center=Game.point(Game.player,1.4)
	hero_equipment=""
	cancel_build()

func _exit_tree():
	for a in ambience+audio_players:
		if is_instance_valid(a):
			for connection in a.finished.get_connections(): a.finished.disconnect(connection.callable)
			a.stop()
			a.stream=null
	ambience.clear()
	audio_players.clear()
	assets.dispose()
	if hud!=null: hud.world=null
	if map_world!=null: map_world.world=null
	audio_samples.clear()
