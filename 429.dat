extends Control
## Explicit, playable 2D view of the same live simulation (not a claim of 3D rendering).
var world
func _process(_dt):
	if visible: queue_redraw()
func project_entity(entity: Dictionary) -> Vector2:
	return size*0.5+Vector2(entity.x-Game.player.x,entity.z-Game.player.z)*world.map_scale
func _poly(points: Array,color: Color):
	draw_colored_polygon(PackedVector2Array(points),color)
func _draw():
	if world==null or Game.player.is_empty(): return
	var scale_map=world.map_scale
	draw_rect(Rect2(Vector2.ZERO,size),Color("244b58"))
	for island in Game.catalog.ISLANDS:
		var vertices=PackedVector2Array()
		for i in 72:
			var angle=TAU*i/72
			vertices.append(project_entity({"x":island.x+cos(angle)*island.rx*0.86,"z":island.z+sin(angle)*island.rz*0.86}))
		draw_colored_polygon(vertices,Color(island.color))
		vertices.append(vertices[0])
		draw_polyline(vertices,Color("bfb185"),9,true)
	for r in Game.ai.resources_near(Game.player,120):
		if r.amount<=0: continue
		draw_circle(project_entity(r),9 if r.kind=="wood" else 5,Color("344c36") if r.kind=="wood" else Color(Game.catalog.RESOURCES[r.kind].color))
	for b in Game.state.buildings:
		if b.hp<=0 or Game.distance(b,Game.player)>140: continue
		var spec=Game.catalog.BUILDING_BY_ID[b.type]
		var radius=spec.size*0.7*scale_map
		var corners=PackedVector2Array()
		for point in [Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(radius,radius),Vector2(-radius,radius)]: corners.append(project_entity(b)+point.rotated(-b.yaw))
		draw_colored_polygon(corners,Color("d7c096") if b.owner=="player" else Color("a99d81"))
		draw_string(ThemeDB.fallback_font,project_entity(b)+Vector2(-radius,0),spec.name,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("17282a"))
	for site in world.construction_sites():
		if Game.distance(site,Game.player)>140: continue
		var radius=Game.catalog.BUILDING_BY_ID[site.type].size*0.7*scale_map
		var rectangle=Rect2(project_entity(site)-Vector2(radius,radius),Vector2(radius*2,radius*2))
		draw_rect(rectangle,Color(0.94,0.75,0.38,0.5),false,2)
		draw_string(ThemeDB.fallback_font,project_entity(site),"%d%%"%int(site.get("progress",0.0)*100),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff0ba"))
	for npc in Game.state.npcs:
		if npc.alive: draw_circle(project_entity(npc),5,Color("cf6b5c") if npc.hostile else Color("e2d9be"))
	for creature in Game.state.creatures:
		if creature.alive: draw_circle(project_entity(creature),12 if creature.kind=="dragon" else 8,Color("ed7b49") if creature.kind=="dragon" else Color("b582b8"))
	for animal in Game.state.animals:
		if animal.alive: draw_rect(Rect2(project_entity(animal)-Vector2(4,3),Vector2(8,6)),Color("967557"))
	for cart in Game.state.carts:
		if cart.get("hp",1)>0: draw_rect(Rect2(project_entity(cart)-Vector2(7,4),Vector2(14,8)),Color("9c774a"))
	for ship in Game.state.ships:
		if ship.hp<=0: continue
		var position=project_entity(ship)
		var points=[]
		for point in [Vector2(0,12),Vector2(-5,-8),Vector2(5,-8)]: points.append(position+point.rotated(-ship.yaw))
		_poly(points,Color("e8d0a0") if ship.owner=="player" else Color("bd7464") if ship.owner=="pirates" else Color("83b8c6"))
	for drop in Game.state.drops: draw_circle(project_entity(drop),4,Color("ecce86"))
	for shot in Game.projectiles:
		var point=project_entity({"x":shot.pos.x,"z":shot.pos.z})
		draw_circle(point,3 if shot.kind=="cannon" else 1.5,Color("f0e7c7"))
	var target=Game.entity(Game.player.targetId)
	if not target.is_empty(): draw_arc(project_entity(target),16,0,TAU,32,Color("f6cc78"),2,true)
	if world.build_type!="" and not world.build_point.is_empty():
		var q=world.build_point
		var radius=Game.catalog.BUILDING_BY_ID[world.build_type].size*0.7*scale_map
		var color=Color(0.55,0.9,0.65,0.6) if world.build_check.get("ok",false) else Color(0.95,0.4,0.35,0.6)
		var corners=PackedVector2Array()
		for point in [Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(radius,radius),Vector2(-radius,radius)]: corners.append(project_entity(q)+point.rotated(-q.yaw))
		draw_colored_polygon(corners,color)
	var hero_points=[]
	for point in [Vector2(0,10),Vector2(-5,-5),Vector2(5,-5)]: hero_points.append(size*0.5+point.rotated(-Game.player.yaw))
	_poly(hero_points,Color("ffdd9c"))
	draw_string(ThemeDB.fallback_font,Vector2(24,size.y-16),"2D · та же симуляция и управление",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("eee8d7"))
