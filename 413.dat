extends Node3D
## One rig for the game hero and inventory preview. Rigid equipment follows bones.
var actor: Node3D
var assets
var skeleton: Skeleton3D
var contact
var equipment_root: Node3D
var weapon_root: Node3D
var cape: MeshInstance3D = null # Player and inventory deliberately have no cape
var mounts: Array=[]

func configure(model: Node3D,library):
	actor=model; assets=library
	skeleton=assets.find_skeleton(actor)
	equipment_root=Node3D.new(); add_child(equipment_root)
	weapon_root=Node3D.new(); add_child(weapon_root)
	if skeleton!=null:
		contact=preload("res://scripts/character_contact.gd").new()
		contact.actor=actor
		skeleton.add_child(contact)
		contact.modification_processed.connect(sync_mounts)

func _bone_rest_position(bone_name: String,fallback: Vector3) -> Vector3:
	if skeleton==null: return fallback
	var index=skeleton.find_bone(bone_name)
	if index<0: return fallback
	return (global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_rest(index)).origin

func bind(node: Node3D,bone_name: String,rest_position: Vector3,persistent=false):
	if skeleton==null: node.position=rest_position; return
	var index=skeleton.find_bone(bone_name)
	if index<0: node.position=rest_position; return
	var rest=global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_rest(index)
	var desired=Transform3D(Basis.IDENTITY,rest_position)
	mounts.append({"node":node,"bone":index,"offset":rest.affine_inverse()*desired,"persistent":persistent})
	sync_mounts()

func sync_mounts():
	if skeleton==null or not is_inside_tree(): return
	for binding in mounts:
		if not is_instance_valid(binding.node): continue
		var world=skeleton.global_transform*skeleton.get_bone_global_pose(binding.bone)*binding.offset
		binding.node.global_transform=world

func rebuild(equipment: Dictionary,tool,catalog: Dictionary):
	mounts=mounts.filter(func(m): return m.persistent)
	for node in equipment_root.get_children(): node.queue_free()
	for node in weapon_root.get_children(): node.queue_free()
	for slot in ["helmet","armor","gloves","boots"]:
		var id=equipment.get(slot)
		if id==null or id=="": continue
		var definition=catalog.GEAR.get(id,{})
		var color=Color.hex(int(definition.get("color",0x79553b))*256+255)
		var material=assets.color_material(color,0.65 if "iron" in id else 0.0)
		if slot=="armor":
			var mesh=MeshInstance3D.new()
			var shape=CylinderMesh.new()
			shape.top_radius=0.24; shape.bottom_radius=0.20; shape.height=0.5; shape.radial_segments=20
			mesh.mesh=shape; mesh.scale.z=0.64; mesh.material_override=material
			var mount=Node3D.new(); mount.add_child(mesh); equipment_root.add_child(mount)
			bind(mount,"spine_02",Vector3(0,1.24,0.015))
		elif slot=="helmet":
			var mesh=MeshInstance3D.new(); var shape=SphereMesh.new()
			shape.radius=0.17; shape.height=0.26; shape.radial_segments=20; shape.rings=12
			mesh.mesh=shape; mesh.material_override=material
			equipment_root.add_child(mesh); bind(mesh,"Head",Vector3(0,1.79,0))
		else:
			for side in ["l","r"]:
				var sign_value=1 if side=="l" else -1
				var part=_equipment_cuff(slot,material,"iron" in id)
				equipment_root.add_child(part)
				var bone_name=("foot_" if slot=="boots" else "hand_")+side
				var fallback=Vector3(sign_value*(0.094 if slot=="boots" else 0.76),0.14 if slot=="boots" else 1.515,0.02 if slot=="boots" else -0.045)
				var rest=_bone_rest_position(bone_name,fallback)
				# Let the authored textured gloves/boots remain visible; equipment
				# adds fitted reinforcement and a buckle, rather than a solid box.
				if slot=="boots": rest+=Vector3(0,0.105,0)
				else: rest.x-=sign_value*0.025
				bind(part,bone_name,rest)
	if tool!=null and tool!="":
		var grip=Node3D.new(); weapon_root.add_child(grip)
		var hand=skeleton.find_bone("hand_r") if skeleton!=null else -1
		var position_rest=Vector3(-0.75,1.52,-0.04)
		if hand>=0: position_rest=(global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_rest(hand)).origin+Vector3(-0.045,0,0.025)
		bind(grip,"hand_r",position_rest)
		if tool in ["bow","longbow","compositebow"]:
			var bow=assets.normalized(catalog.TOOLS[tool].model,1.4); bow.position.y=-0.55; grip.add_child(bow)
		else:
			var shaft=assets.box(Vector3(0.045,1.6 if tool=="spear" else 0.85,0.045),Color("795533"))
			shaft.position.y=0.23; grip.add_child(shaft)
			var head=assets.box(Vector3(0.3 if tool=="axe" else 0.4 if tool=="pickaxe" else 0.075,0.14 if tool in ["axe","pickaxe"] else 0.6,0.055),Color("adb4b5"))
			head.material_override=assets.color_material(Color("adb4b5"),0.75)
			head.position.y=0.64 if tool in ["axe","pickaxe"] else 0.85; grip.add_child(head)
	sync_mounts()

func _equipment_cuff(slot: String,material: Material,metal: bool) -> Node3D:
	var root=Node3D.new()
	var cuff=MeshInstance3D.new()
	var shape=CylinderMesh.new()
	shape.top_radius=0.082 if slot=="boots" else 0.057
	shape.bottom_radius=0.075 if slot=="boots" else 0.051
	shape.height=0.085 if slot=="boots" else 0.055
	shape.radial_segments=24
	shape.cap_top=false
	shape.cap_bottom=false
	cuff.mesh=shape
	cuff.material_override=material
	root.add_child(cuff)
	if slot=="gloves": cuff.rotation.z=PI/2.0
	else: cuff.scale.z=1.16
	var buckle=assets.box(Vector3(0.028,0.023,0.009),Color("aab1b4") if metal else Color("977346"))
	buckle.material_override=assets.color_material(Color("aab1b4") if metal else Color("977346"),0.7)
	buckle.position=Vector3(0,0,0.096 if slot=="boots" else 0.058)
	root.add_child(buckle)
	return root

func set_contact(state: Dictionary,handles: Array,height_function: Callable):
	if contact==null: return
	contact.state=state; contact.targets=handles; contact.ground_height=height_function
	weapon_root.visible=handles.is_empty()

func _exit_tree():
	if is_instance_valid(contact):
		contact.actor=null; contact.ground_height=Callable(); contact.targets=[]
