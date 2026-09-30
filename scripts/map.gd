extends Control
## Shared native archipelago map: minimap, menu and live 2D view.
var compact=false
var zoom=1.0
func _ready(): clip_contents=true
func _process(_dt): queue_redraw()
func world_to_map(point: Dictionary) -> Vector2:
	var extent=Game.catalog.LIMITS.world
	var scale_map=min(size.x,size.y)/(extent*2.15)*zoom
	return size*0.5+Vector2(point.x,point.z)*scale_map
func _draw():
	if Game.catalog.is_empty() or Game.state.is_empty(): return
	var extent=Game.catalog.LIMITS.world
	var scale_map=min(size.x,size.y)/(extent*2.15)*zoom
	var center=size*0.5
	draw_rect(Rect2(Vector2.ZERO,size),Color("142a32"))
	if not compact:
		for v in range(-1200,1201,200):
			var x=center.x+v*scale_map
			var y=center.y+v*scale_map
			draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.7,0.75,0.7,0.12))
			draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.7,0.75,0.7,0.12))
	for i in Game.catalog.ISLANDS:
		var points=PackedVector2Array()
		for j in 64:
			var a=j*TAU/64
			var edge=1+0.055*sin(a*5+0.4)+0.04*cos(a*3)
			points.append(center+Vector2(i.x+cos(a)*i.rx*edge,i.z+sin(a)*i.rz*edge)*scale_map)
		draw_colored_polygon(points,Color(i.color))
		if not compact:
			draw_string(ThemeDB.fallback_font,world_to_map(i)+Vector2(-80,-8),i.name,HORIZONTAL_ALIGNMENT_CENTER,160,18,Color("f0e4c8"))
	for b in Game.state.buildings:
		if b.hp>0:
			var marker_size=Vector2(4,4) if not compact else Vector2(2,2)
			draw_rect(Rect2(world_to_map(b)-marker_size*0.5,marker_size),Color("b1ca8d") if b.owner=="player" else Color("ece3c7"))
	for site in construction_sites():
		var at=world_to_map(site)
		var radius=2.5 if compact else 6.0
		draw_rect(Rect2(at-Vector2(radius,radius),Vector2.ONE*radius*2),Color(0.95,0.75,0.3,0.7),false,1)
		draw_arc(at,radius+2,-PI/2,-PI/2+TAU*clampf(site.get("progress",0.0),0,1),24,Color("ffe4a3"),2)
	if not compact:
		for n in Game.state.npcs:
			if n.alive: draw_circle(world_to_map(n),1.6,Color("d67c67") if n.get("hostile",0)>0 else Color("ddd3ae"))
	for ship in Game.state.ships:
		if ship.hp<=0: continue
		if not compact:
			var route=PackedVector2Array([world_to_map(ship)])
			for waypoint in ship.get("route",[]):
				if waypoint is Dictionary and waypoint.has("x") and waypoint.has("z"): route.append(world_to_map(waypoint))
			if route.size()>1: draw_polyline(route,Color(0.55,0.75,0.8,0.24),1,true)
		var color=Color("efc26f") if ship.owner=="player" else Color("df756c") if ship.owner=="pirates" else Color("8bc6cd")
		_marker(world_to_map(ship),ship.get("yaw",0),3 if compact else 6,color)
	_marker(world_to_map(Game.player),Game.player.yaw,5 if compact else 9,Color("ffe1a2"))
	if not compact:
		draw_string(ThemeDB.fallback_font,Vector2(18,25),"СЕВЕР ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c7d4c8"))
		draw_string(ThemeDB.fallback_font,Vector2(18,size.y-18),"Вы: %d / %d м" % [Game.player.x,Game.player.z],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c7d4c8"))
		var ruler_start=Vector2(size.x-145,size.y-22)
		draw_line(ruler_start,ruler_start+Vector2(100*scale_map,0),Color("c7c2a2"),2)
		draw_string(ThemeDB.fallback_font,ruler_start-Vector2(0,10),"100 м",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c7d4c8"))
func _marker(point: Vector2,yaw: float,length: float,color: Color):
	var direction=Vector2(sin(yaw),cos(yaw))
	var side=Vector2(direction.y,-direction.x)
	draw_colored_polygon(PackedVector2Array([point+direction*length,point-direction*length*0.55+side*length*0.55,point-direction*length*0.55-side*length*0.55]),color)

func construction_sites() -> Array:
	var sites=[]
	for project in Game.state.get("projects",[]):
		if not project.get("done",false) and project.has("x") and project.has("z"): sites.append(project)
	for settlement in Game.state.settlements:
		var site=settlement.get("construction")
		if site is Dictionary and not site.is_empty() and site.has("x") and site.has("z"): sites.append(site)
	for group in Game.state.get("groups",[]):
		var site=group.get("building")
		if site is Dictionary and not site.is_empty() and site.has("x") and site.has("z"):
			site=site.duplicate(false)
			site["progress"]=group.get("progress",site.get("progress",0))
			sites.append(site)
	return sites
