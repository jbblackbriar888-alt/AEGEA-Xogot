extends Node3D
## Open this scene and run Current Scene to inspect all 28 approved native models.
var assets=preload("res://scripts/assets.gd").new()
var camera: Camera3D
var index=0
var angle=0.65
var dragging=false
var title: Label
var collection: Array=[]
func _ready():
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_energy=1.7; sun.shadow_enabled=true
	add_child(sun)
	var env=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("91aab3")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("beced0")
	env.environment.ambient_light_energy=0.6
	add_child(env)
	var floor_mesh=assets.box(Vector3(160,0.12,200),Color("928b74"))
	floor_mesh.position=Vector3(50,-0.08,65)
	add_child(floor_mesh)
	var definitions=Game.catalog.BUILDINGS.duplicate()
	definitions.sort_custom(func(a,b): return a.approvalId<b.approvalId)
	for i in definitions.size():
		var d=definitions[i]
		var model=assets.building(d.id)
		model.position=Vector3((i%4)*30,0,floor(i/4.0)*27)
		model.set_meta("definition",d)
		add_child(model)
		collection.append(model)
	camera=Camera3D.new()
	camera.current=true; camera.far=350
	add_child(camera)
	var canvas=CanvasLayer.new()
	add_child(canvas)
	var controls=HBoxContainer.new()
	controls.position=Vector2(35,25)
	canvas.add_child(controls)
	var previous=Button.new(); previous.text="<"; previous.custom_minimum_size=Vector2(70,50)
	previous.pressed.connect(func(): index=posmod(index-1,28))
	controls.add_child(previous)
	title=Label.new(); title.add_theme_font_size_override("font_size",24); title.custom_minimum_size.x=660
	controls.add_child(title)
	var next=Button.new(); next.text=">"; next.custom_minimum_size=Vector2(70,50)
	next.pressed.connect(func(): index=(index+1)%28)
	controls.add_child(next)
func _process(_dt):
	if collection.is_empty(): return
	var model=collection[index]
	var definition=model.get_meta("definition")
	var meta=Game.catalog.ARCHITECTURE55[definition.id]
	var radius=max(meta.width,meta.depth)*1.3+5
	var target=model.position+Vector3(0,meta.height*0.35,0)
	camera.position=target+Vector3(sin(angle)*radius,radius*0.45,cos(angle)*radius)
	camera.look_at(target)
	title.text=definition.approvalId+" · "+definition.name
func _unhandled_input(event):
	if event is InputEventMouseButton: dragging=event.pressed
	if event is InputEventMouseMotion and dragging: angle-=event.relative.x*0.01
	if event is InputEventScreenDrag: angle-=event.relative.x*0.01
func _exit_tree(): assets.dispose()
