extends RefCounted
## Budgeted local AI. Inventories are physically carried; no remote resource credit.
var g
var grid: Dictionary = {}
var grid_count = -1
var wander_clock = 0.0
var group_clock = 0.0
var farm_clock = 0.0
var sea_path: AStarGrid2D
const NAV_STEP=32.0
var nav_extent=1400.0

func build_sea_paths():
	if sea_path!=null: return
	nav_extent=float(g.catalog.LIMITS.world)
	var count=int(ceil(nav_extent*2/NAV_STEP))
	sea_path=AStarGrid2D.new()
	sea_path.region=Rect2i(0,0,count,count)
	sea_path.cell_size=Vector2(NAV_STEP,NAV_STEP)
	sea_path.offset=Vector2(-nav_extent,-nav_extent)
	sea_path.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	sea_path.update()
	for x in count:
		for z in count:
			if g.height_at(x*NAV_STEP-nav_extent,z*NAV_STEP-nav_extent)>-2.5: sea_path.set_point_solid(Vector2i(x,z))

func sea_cell(q: Dictionary) -> Vector2i:
	var c=Vector2i(round((q.x+nav_extent)/NAV_STEP),round((q.z+nav_extent)/NAV_STEP))
	for radius in 5:
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				var v=c+Vector2i(dx,dz)
				if sea_path.is_in_boundsv(v) and not sea_path.is_point_solid(v): return v
	return Vector2i(-1,-1)

func port_point(island_id: String) -> Dictionary:
	for i in g.catalog.ISLANDS:
		if i.id!=island_id: continue
		var angle=atan2(-i.x,-i.z)
		for j in 23:
			var r=1.06+j*0.015
			var q={"x":i.x+sin(angle)*i.rx*r,"z":i.z+cos(angle)*i.rz*r}
			if g.combat.water_clear(q.x,q.z,18): return q
		return {"x":i.x,"z":i.z+i.rz*1.15}
	return {"x":0.0,"z":0.0}

func route_to(s: Dictionary,destination: String):
	build_sea_paths()
	var goal=port_point(destination)
	var a=sea_cell(s)
	var b=sea_cell(goal)
	if a.x<0 or b.x<0: return
	s["route"]=[]
	for p in sea_path.get_point_path(a,b): s.route.append({"x":p.x,"z":p.y})
	s["waypoint"]=0
	s["destination"]=destination

func _init(game):
	g=game

func rebuild_grid():
	grid.clear()
	for r in g.state.resources:
		var key=Vector2i(floor(r.x/24.0),floor(r.z/24.0))
		if not grid.has(key): grid[key]=[]
		grid[key].append(r)
	grid_count=g.state.resources.size()

func resources_near(q: Dictionary,radius: float) -> Array:
	if grid_count!=g.state.resources.size(): rebuild_grid()
	var result=[]
	for x in range(int(floor((q.x-radius)/24.0)),int(floor((q.x+radius)/24.0))+1):
		for z in range(int(floor((q.z-radius)/24.0)),int(floor((q.z+radius)/24.0))+1):
			for r in grid.get(Vector2i(x,z),[]):
				if g.distance(r,q)<=radius: result.append(r)
	return result

func move_actor(e: Dictionary,q: Dictionary,speed: float,dt: float,land=true) -> bool:
	if e.get("entity_kind")=="npcs":
		var cart=g.entity(e.get("workCartId",""))
		if not cart.is_empty() and cart.hp>0 and cart.owner==("player" if e.get("ally",false) else e.home):
			if g.distance(e,cart)>6: e["speed"]=0.0; return false
			if g.weight(cart.store)>0: speed=min(speed,4.5)
	var dist=g.distance(e,q)
	if dist<0.4: return true
	var wanted=atan2(q.x-e.x,q.z-e.z)
	var step=min(dist,speed*dt)
	var best={}
	var score=INF
	var origin_ground=g.ground_at(e.x,e.z) if land else 0.0
	for turn in [0.0,0.45,-0.45,0.9,-0.9,1.4,-1.4,1.9,-1.9]:
		var a=wanted+turn
		var p={"x":e.x+sin(a)*step,"z":e.z+cos(a)*step}
		if land:
			var candidate_ground=g.ground_at(p.x,p.z)
			if candidate_ground<0.35 or abs(candidate_ground-origin_ground)>1.5: continue
		if g.blocked(p,0.31,e.get("id",""),true): continue
		var test=g.distance(p,q)+abs(turn)*0.04
		if test<score: best=p; best["yaw"]=a; score=test
		if turn==0: break
	if best.is_empty():
		e["blocked"]=e.get("blocked",0.0)+dt
		return false
	e.x=best.x
	e.z=best.z
	e.yaw=lerp_angle(e.yaw,best.yaw,min(1.0,dt*10))
	e["blocked"]=0.0
	e["speed"]=speed
	return g.distance(e,q)<0.5

func storage(q: Dictionary,owner: String,range_limit=100000.0) -> Dictionary:
	var result={}
	var best=range_limit
	for b in g.state.buildings:
		if b.hp<=0 or b.owner!=owner or b.type not in ["warehouse","granary"]: continue
		var d=g.distance(b,q)
		if d<best: best=d; result=b
	return result

func deposit(n: Dictionary,b: Dictionary) -> int:
	var total=0
	var dest=g.player.inventory if b.is_empty() else b.store
	for key in n.carry:
		var amount=g.add_inventory(dest,key,int(n.carry[key]),g.player.tools if b.is_empty() else [],120 if b.is_empty() else g.capacity(b),24 if b.is_empty() else 10000)
		n.carry[key]-=amount
		total+=amount
	return total

func step(dt: float):
	for n in g.state.npcs: update_npc(n,dt)
	for a in g.state.animals+g.state.creatures: update_beast(a,dt)
	for s in g.state.ships:
		if s.id!=g.player.shipId: update_ship(s,dt)
	_update_towers(dt)
	for f in g.state.seaLife:
		var d=g.distance(f,g.player)
		if d>350: continue
		f.yaw+=sin(g.state.time*0.3+f.phase)*dt*0.2
		var speed=3.8 if f.kind=="dolphin" else 1.2
		var q={"x":f.x+sin(f.yaw)*speed*dt,"z":f.z+cos(f.yaw)*speed*dt}
		if g.height_at(q.x,q.z)> -2 or g.distance(f,f.origin)>36: f.yaw+=dt*2
		else: f.x=q.x; f.z=q.z
		f["y"]=-f.depth+(max(0,sin(g.state.time*0.62+f.phase)-0.65)*6 if f.kind=="dolphin" else 0)
	for r in g.state.resources:
		if r.amount<=0 and r.respawn>0 and g.state.time>=r.respawn:
			if g.state.buildings.any(func(b): return b.hp>0 and g.distance(r,b)<g.catalog.BUILDING_BY_ID[b.type].size+1): r.respawn=g.state.time+30; continue
			r.amount=r.max; r.respawn=0
	# Quietly rest near civic buildings; movement cancels the effect.
	if not g.player.dead and g.player.speed<0.1 and g.player.hunger>0:
		for b in g.state.buildings:
			if b.hp>0 and b.type in ["campfire","longhouse","townhall","temple","inn"] and g.distance(b,g.player)<(11 if b.type=="inn" else 7):
				g.player.hp=min(100,g.player.hp+dt*2.5)
				break

func _update_towers(dt: float):
	# Source game.js towers are player defenses, not general NPC/monster turrets.
	for building in g.state.buildings:
		if building.type!="tower" or building.hp<=0 or building.owner!="player": continue
		building["shot"]=building.get("shot",0.0)-dt
		if building.shot>0: continue
		for target in g.state.npcs+g.state.animals:
			if not target.alive or target.get("hostile",0)<=0 or g.distance(target,building)>=21: continue
			var before=target.hp
			target.hp=max(0,target.hp-18)
			building.shot=2.0
			g.combat.record_event("damage",target,before-target.hp)
			g.effect.emit("arrow",g.point(target,1))
			if target.hp<=0:
				target.alive=false
				target["deathAt"]=g.state.time
				if target.get("entity_kind")=="animals":
					target.respawn=g.state.time+180
					var definition=g.catalog.ANIMALS[target.kind]
					g.combat._drop(target,{"food":definition.food,"leather":definition.leather},definition.name+" — добыча",600)
				else: target.respawn=g.state.time+240
			g.changed.emit()
			break

func update_npc(n: Dictionary,dt: float):
	if not n.alive:
		# The source passenger wrapper clears a dead passenger before role-specific respawn.
		n["shipId"]=""
		if g.state.time<n.get("respawn",INF): return
		var home={}
		for settlement in g.state.settlements:
			if settlement.id==n.home: home=settlement; break
		var player_home={}
		for building in g.state.buildings:
			if building.type=="warehouse" and building.owner=="player" and building.hp>0: player_home=building; break
		if n.get("ally",false):
			if home.is_empty(): home=player_home
			if home.is_empty(): return
			n.alive=true; n.hp=100; n.x=home.x-7; n.z=home.z+6; n.carry=g.blank(); n.order={"type":"follow"}
			return
		if n.role=="merchant" and n.get("hostile",0)<=0:
			n.alive=true; n.hp=100
			return
		if n.get("groupId"):
			for group in g.state.groups:
				if group.id==n.groupId and group.get("phase","")!="settlement":
					if home.is_empty(): home=group
					n.alive=true; n.hp=100; n.x=home.x-7; n.z=home.z+6; n.carry=g.blank(); n["resourceId"]=""; n.goal={}; n.state="idle"
					return
		if n.home=="player":
			if player_home.is_empty(): return
			n.alive=true; n.hp=100; n.x=player_home.x-7; n.z=player_home.z+5
			return
		g.combat.enemy_attack(n,dt)
		return
	n["speed"]=0.0
	if n.get("shipId"):
		var ship=g.entity(n.shipId)
		if not ship.is_empty() and ship.hp>0:
			var active_escort=false
			for task in g.state.tasks:
				if task.id==n.get("taskId") and task.type=="escort" and task.get("escortId")==ship.id and task.status not in ["Отменено","Готово"]: active_escort=true
			if active_escort: n.x=ship.x; n.z=ship.z; n.state="escort"; return
			var landing=land_near(ship)
			if not landing.is_empty() and g.distance(landing,ship)<max(10,g.catalog.SHIPS[ship.kind].length*0.55): n.shipId=""; n.x=landing.x; n.z=landing.z
			else: n.x=ship.x; n.z=ship.z; n.state="idle"; return
		n.shipId=""
	if g.economy.update_vehicle_work(n,dt): return
	if n.ally: update_companion(n,dt); return
	if n.get("staggerUntil",0)>g.state.time: n["companyHit"]={}
	if g.combat.enemy_attack(n,dt): return
	g.economy.update_npc(n,dt)

func worker_cart(n: Dictionary) -> Dictionary:
	var current=g.entity(n.get("workCartId",""))
	if not current.is_empty() and current.hp>0 and current.owner==n.home: return current
	for c in g.state.carts:
		if c.hp>0 and c.owner==n.home and c.followId=="" and g.distance(c,n)<55:
			n["workCartId"]=c.id
			c.followId=n.id
			return c
	return {}

func catalog_width(b: Dictionary) -> float:
	return g.catalog.ARCHITECTURE55[b.type].width

func work_resource(n: Dictionary,r: Dictionary,dt: float,limit=999999) -> int:
	if g.distance(n,r)>1.35:
		n.state="walk"
		move_actor(n,r,4.5,dt)
		return 0
	n.yaw=atan2(r.x-n.x,r.z-n.z)
	n.state="chop" if r.kind=="wood" else "mine" if r.kind in ["stone","ore","coal","clay"] else "harvest"
	if n.get("timer",0.0)>0: return 0
	var qty=int(min(2,min(r.amount,limit)))
	var accepted=g.add_inventory(n.carry,r.kind,qty,[],25,10000)
	r.amount-=accepted
	if r.amount<=0: r.respawn=g.state.time+240
	n.timer=2.2
	return accepted

func update_companion(n: Dictionary,dt: float):
	n.hostile=0
	n.timer=n.get("timer",0.0)-dt
	n.cooldown=max(0.0,n.get("cooldown",0.0)-dt)
	if n.get("staggerUntil",0)>g.state.time: n["companyHit"]={}; n.state="idle"; return
	if g.player.dead: n.state="idle"; return
	if not n.get("companyHit",{}).is_empty():
		n.companyHit.left-=dt
		n.state="attack"
		if n.companyHit.left<=0:
			var target=g.entity(n.companyHit.id)
			if g.can_attack(target) and g.distance(n,target)<2.8 and g.clear_line(n,target): g.damage(target,16,"player",false,"companion")
			n.companyHit={}
		return
	for task in g.state.tasks:
		if task.get("shared",false) and task.id==n.get("taskId"):
			if update_task_member(n,task,dt): return
	var order=n.order
	var kind=order.get("type","follow")
	order["reason"]=""
	if kind in ["follow","guard","attack"]:
		var target=g.entity(order.get("targetId",g.player.targetId)) if kind=="attack" else {}
		if target.is_empty():
			for e in g.state.animals+g.state.creatures+g.state.npcs:
				if g.can_attack(e) and e.get("hostile",0)>0 and g.distance(e,order if kind=="guard" else g.player)<15: target=e; break
		if not target.is_empty() and g.can_attack(target) and g.distance(n,target)<70:
			if g.distance(n,target)>2.25: n.state="run"; move_actor(n,target,5.5,dt)
			elif n.cooldown<=0:
				n.state="attack"
				n.cooldown=1.2
				n["companyHit"]={"id":target.id,"left":0.38}
			return
		if kind=="attack": n.order={"type":"follow"}; order=n.order; kind="follow"
	if kind=="gather":
		var desired=order.quantity if order.get("quantity",0)>0 else 1000000000
		if order.get("done",0)>=desired and g.weight(n.carry)<0.01: order.status="Завершено"; n.state="idle"; return
		var store=storage(n,"player",80)
		if g.weight(n.carry)>=10 or order.get("done",0)+n.carry.get(order.resource,0)>=desired or order.get("returning",false):
			order["returning"]=true
			var q=g.player if store.is_empty() else {"x":store.x-catalog_width(store)*0.55-1,"z":store.z+1}
			if g.distance(n,q)>2.0: n.state="carry"; move_actor(n,q,4.5,dt)
			else:
				var before=n.carry.get(order.resource,0)
				deposit(n,store)
				order.done=order.get("done",0)+before-n.carry.get(order.resource,0)
				if g.weight(n.carry)<0.01: order.returning=false; n.goal={}
				else: order.reason="Нет места в хранилище"; order.status="Ожидание"
			return
		var res=g.entity(n.get("resourceId",""))
		if res.is_empty() or res.get("kind")!=order.resource or res.amount<=0:
			var candidates=resources_near(order,95).filter(func(r): return r.kind==order.resource and r.amount>0 and g.island_at(n).get("id")==g.island_at(r).get("id"))
			candidates.sort_custom(func(a,b): return g.distance(a,n)<g.distance(b,n))
			res=candidates[0] if not candidates.is_empty() else {}
			n["resourceId"]=res.get("id","")
		if res.is_empty():
			if g.weight(n.carry)>0: order.returning=true
			order.reason="Нет нужного ресурса в зоне задания"; order.status="Ожидание"; n.state="idle"; return
		work_resource(n,res,dt,desired-order.get("done",0)-n.carry.get(order.resource,0))
		order.status="Добывает и переносит"
		order.carried=n.carry.get(order.resource,0)
		return
	if kind=="deliver":
		var dest=g.container(order.get("destination",""))
		if dest.is_empty() or dest.owner!="player": order.reason="Выберите своё хранилище назначения"; n.state="idle"; return
		if order.done>=order.quantity: order.status="Завершено"; n.state="idle"; return
		if g.weight(n.carry)>0:
			if g.distance(n,dest)>6: n.state="carry"; move_actor(n,dest,4.0,dt)
			else:
				var moved=deposit(n,dest)
				order.done+=moved
				if moved==0: order.reason="Хранилище назначения заполнено"
		else:
			var source=storage(n,"player",160)
			if source.is_empty() or source.id==dest.id or source.store.get(order.resource,0)<=0: order.reason="Нет груза на ближайшем своём складе"; n.state="idle"; return
			if g.distance(n,source)>6: n.state="walk"; move_actor(n,source,4.0,dt)
			else:
				var qty=int(min(source.store[order.resource],min(10,order.quantity-order.done)))
				var moved=g.add_inventory(n.carry,order.resource,qty,[],25,10000)
				source.store[order.resource]-=moved
		order.carried=n.carry.get(order.resource,0)
		order.status="Доставляет" if order.reason=="" else "Ожидание"
		return
	if kind=="escort":
		var s=g.entity(order.get("destination",""))
		if s.is_empty() or s.entity_kind!="ships" or s.owner!="player": order.reason="Выберите свой корабль"; n.state="idle"; return
		if g.distance(n,s)>10:
			n.state="walk"
			move_actor(n,s,4.5,dt)
			order.reason="Идёт к кораблю; подведите корабль к берегу"
		else: n["shipId"]=s.id; order.status="На борту, охраняет корабль"
		return
	if kind=="repair":
		var target={}
		for b in g.state.buildings:
			if b.owner=="player" and b.hp>0 and b.hp<b.maxHp and g.distance(b,order)<65: target=b; break
		if target.is_empty(): order.reason="Нет повреждённых зданий"; n.state="idle"; return
		if g.distance(n,target)>6: n.state="walk"; move_actor(n,target,4.0,dt)
		elif n.cooldown<=0:
			n.state="interact"
			if g.distance(g.player,target)>18 or not g.consume(g.maintenance_cost(target),target): order.reason="Нужны материалы и герой в пределах 18 м"
			else: target.hp=target.maxHp
			n.cooldown=3
		return
	if kind=="build":
		var proj={}
		for p in g.state.projects:
			if not p.done and p.id==order.get("projectId",p.id): proj=p; break
		if proj.is_empty(): order.reason="Разместите проект отряда в меню строительства"; n.state="idle"; return
		if g.distance(n,proj)>5: n.state="walk"; move_actor(n,{"x":proj.x+3,"z":proj.z},4.5,dt)
		else:
			n.state="interact"
			proj.progress=min(1,proj.progress+dt/18)
			if proj.progress>=1:
				if g.state.buildings.any(func(b): return b.hp>0 and g.distance(b,proj)<g.catalog.BUILDING_BY_ID[proj.type].size): n.state="idle"; return
				var b=g.add_building(proj.type,proj,"player",proj.yaw)
				b.foundationY=proj.height
				b["foundationDepth"]=proj.get("foundationDepth",0)
				g.state.stats.built+=1
				proj.done=true
				order.status="Завершено"
		return
	var follow=kind in ["follow","attack"]
	var anchor=g.player if follow else order
	var index=g.state.npcs.filter(func(member): return member.ally).find(n)
	var q={"x":anchor.get("x",n.x)+(sin(g.player.yaw+PI+(index-2.5)*0.42)*(3+index%2) if follow else 0),"z":anchor.get("z",n.z)+(cos(g.player.yaw+PI+(index-2.5)*0.42)*(3+index%2) if follow else 0)}
	if g.distance(n,q)>1.5: n.state="run" if g.distance(n,q)>8 else "walk"; move_actor(n,q,7.7 if follow and g.distance(n,g.player)>8 else 4.5,dt)
	else: n.state="idle"
	if n.get("blocked",0)>5: order.reason="Путь перекрыт"

# Shared tasks reserve only the assigned goods. Unrelated carried inventory never
# counts as delivered, and cancellation leaves physical goods in their container.
func land_near(q: Dictionary) -> Dictionary:
	for radius in range(2,160,3):
		for j in 27:
			var p={"x":q.x+sin(j*TAU/27)*radius,"z":q.z+cos(j*TAU/27)*radius}
			if g.height_at(p.x,p.z)>0.55 and not g.blocked(p,0.4,"",false): return p
	return {}

func cargo_approach(c: Dictionary,n: Dictionary) -> Dictionary:
	if c.get("entity_kind")=="ships": return land_near(c)
	if c.get("entity_kind")=="buildings": return g.geometry.building_approach(c,n)
	return c

func task_carrier(n: Dictionary) -> Dictionary:
	if n.get("taskUnits",0)>0 and n.get("taskCargoId")=="carry": return {"store":n.carry,"capacity":18,"id":"carry","cart":{},"waiting":false,"missing":false}
	var id=n.get("taskCargoId","") if n.get("taskUnits",0)>0 else n.get("workCartId","")
	var cart=g.entity(id)
	if not cart.is_empty() and cart.get("entity_kind")=="carts" and cart.hp>0:
		return {"store":cart.store,"capacity":g.capacity(cart),"id":cart.id,"cart":cart,"waiting":g.distance(cart,n)>8 or cart.followId!=n.id,"missing":false}
	return {"store":n.carry,"capacity":18,"id":"carry","cart":{},"waiting":false,"missing":n.get("taskUnits",0)>0 and id not in ["","carry"]}

func task_block(n: Dictionary,t: Dictionary,reason: String):
	n.state="idle"
	t.reason=reason
	t.status="Остановлено"

func update_task_member(n: Dictionary,t: Dictionary,dt: float) -> bool:
	var handled=_update_task_member(n,t,dt)
	n["taskReport"]={"taskId":t.id,"status":t.status,"reason":t.reason,"stage":n.state,"carried":n.get("taskUnits",0)}
	t.carried=0
	if t.status not in ["Готово","Отменено"]:
		var reasons=[]
		var stopped=0
		for member_id in t.members:
			var member=g.entity(member_id)
			if member.is_empty(): continue
			t.carried+=member.get("taskUnits",0)
			var report=member.get("taskReport",{})
			if report.get("taskId")!=t.id: continue
			if report.get("status")=="Остановлено": stopped+=1
			if report.get("reason","")!="" and report.reason not in reasons: reasons.append(report.reason)
		t.reason="; ".join(reasons)
		if stopped>0: t.status="Остановлено" if stopped==t.members.size() else "Часть отряда ожидает"
	return handled

func _update_task_member(n: Dictionary,t: Dictionary,dt: float) -> bool:
	if t.status in ["Готово","Отменено"]: n.state="idle"; return true
	t.status="В работе"
	t.reason=""
	if t.type=="guard":
		var protected=g.container(t.destId)
		if protected.is_empty() or protected.owner!="player": task_block(n,t,"Склад недоступен"); return true
		n.order={"type":"guard","x":protected.x,"z":protected.z}
		return false
	if t.type=="escort":
		var ship=g.entity(t.escortId)
		var leader=g.entity(t.shipId)
		if ship.is_empty() or ship.hp<=0 or leader.is_empty() or leader.hp<=0: task_block(n,t,"Судно потеряно"); return true
		if n.get("shipId")==ship.id: n.x=ship.x; n.z=ship.z; n.state="escort"; return true
		var land=land_near(ship)
		if land.is_empty() or g.distance(ship,land)>max(10,g.catalog.SHIPS[ship.kind].length*0.55): task_block(n,t,"Подведите судно эскорта к берегу для посадки"); return true
		if g.distance(n,land)>3: n.state="walk"; move_actor(n,land,5.6,dt); t.reason="Отряд идёт к судну"; return true
		n["shipId"]=ship.id
		n.x=ship.x; n.z=ship.z; n.state="escort"
		return true
	var destination=g.container(t.destId)
	var source=g.container(t.sourceId) if t.type=="deliver" else {}
	if destination.is_empty() or t.type=="deliver" and source.is_empty(): task_block(n,t,"Хранилище недоступно"); return true
	if destination.owner!="player" or not source.is_empty() and source.owner!="player": task_block(n,t,"Хранилище больше не принадлежит вам"); return true
	var carrier=task_carrier(n)
	if carrier.missing: n.taskUnits=0; n.taskCargoId=""; task_block(n,t,"Транспорт с грузом потерян"); return true
	if carrier.waiting: task_block(n,t,"Верните проводнику тележку с грузом" if carrier.cart.followId!=n.id else "Ожидание транспорта: он отстал"); return true
	var store=carrier.store
	n.taskUnits=min(n.get("taskUnits",0),store.get(t.resource,0))
	var reserved=0
	for other in g.state.npcs:
		if other.get("taskId")==t.id: reserved+=other.get("taskUnits",0)
	var remaining=t.quantity-t.done-reserved
	if not source.is_empty() and source.id==carrier.id and n.taskUnits==0 and remaining>0:
		n.taskUnits=min(remaining,store.get(t.resource,0)); n.taskCargoId=carrier.id; n.returning=n.taskUnits>0
		remaining-=n.taskUnits
	if n.taskUnits>0 and (destination.id==carrier.id or n.get("returning",false) or g.weight(store)>=carrier.capacity-g.catalog.RESOURCES[t.resource].weight or remaining<=0):
		deliver_task_cargo(n,t,destination,carrier,dt)
		return true
	if remaining<=0:
		if t.done>=t.quantity: t.status="Готово"
		n.state="idle"
		return true
	if g.weight(store)>carrier.capacity-g.catalog.RESOURCES[t.resource].weight: task_block(n,t,"Нет места в транспорте: уберите посторонний груз"); return true
	if t.type=="deliver":
		var q=cargo_approach(source,n)
		if q.is_empty(): task_block(n,t,"Нет свободного подхода к исходному хранилищу"); return true
		if g.island_at(n).get("id")!=g.island_at(q).get("id"): task_block(n,t,"Исходный груз находится на другом острове"); return true
		if source.get("entity_kind")=="ships" and g.distance(source,q)>g.cargo_range(source): task_block(n,t,"Подведите судно с грузом ближе к берегу"); return true
		if g.distance(n,q)>(1.5 if source.get("entity_kind")=="buildings" else 3.1): n.state="walk"; move_actor(n,q,5.6,dt); return true
		var got=0 if source.id==carrier.id else g.add_inventory(store,t.resource,int(min(remaining,source.store.get(t.resource,0))),[],carrier.capacity,10000)
		source.store[t.resource]=source.store.get(t.resource,0)-got
		n.taskUnits+=got
		if got: n.taskCargoId=carrier.id
		n.returning=n.taskUnits>0
		if not got: task_block(n,t,"Нет ресурса в исходном хранилище")
		return true
	var resource=g.entity(n.get("resourceId",""))
	if resource.is_empty() or resource.get("kind")!=t.resource or resource.amount<=0:
		var candidates=resources_near(t,160).filter(func(r): return r.kind==t.resource and r.amount>0 and g.island_at(r).get("id")==g.island_at(n).get("id"))
		candidates.sort_custom(func(a,b): return g.distance(a,n)<g.distance(b,n))
		resource=candidates[0] if not candidates.is_empty() else {}
		n["resourceId"]=resource.get("id","")
	if resource.is_empty():
		if n.taskUnits>0: n.returning=true; deliver_task_cargo(n,t,destination,carrier,dt)
		else: task_block(n,t,"Ресурс не найден в радиусе 160 м")
		return true
	if g.distance(n,resource)>max(1.35,0.65+(0.36 if resource.kind=="wood" else 0.55)*resource.get("scale",1)):
		n.state="walk"; move_actor(n,resource,5.2,dt)
		if n.get("blocked",0)>3: task_block(n,t,"Путь перекрыт")
		return true
	n.state="chop" if resource.kind=="wood" else "mine" if resource.kind in ["ore","stone","coal","clay"] else "harvest"
	if n.cooldown<=0:
		var got=g.add_inventory(store,t.resource,int(min(3,min(resource.amount,remaining))),[],carrier.capacity,10000)
		resource.amount-=got
		if resource.amount<=0: resource.respawn=g.state.time+240
		n.taskUnits+=got
		n.cooldown=2.2
		if got: n.taskCargoId=carrier.id
		if not got or remaining<=got: n.returning=true
	return true

func deliver_task_cargo(n: Dictionary,t: Dictionary,destination: Dictionary,carrier: Dictionary,dt: float):
	if destination.id!=carrier.id:
		var q=cargo_approach(destination,n)
		if q.is_empty(): task_block(n,t,"Нет свободного подхода к разгрузке"); return
		if g.island_at(n).get("id")!=g.island_at(q).get("id"): task_block(n,t,"Нужна морская перевозка на другой остров"); return
		if g.distance(n,q)>(1.5 if destination.get("entity_kind")=="buildings" else 3.1):
			n.state="carry"; move_actor(n,q,4.5,dt)
			if n.get("blocked",0)>3: task_block(n,t,"Путь к разгрузке перекрыт")
			return
		if destination.get("entity_kind")=="ships" and g.distance(n,destination)>g.cargo_range(destination): task_block(n,t,"Подведите грузовое судно ближе к берегу"); return
		if not carrier.cart.is_empty() and g.distance(carrier.cart,destination)>g.cargo_range(destination)+2: task_block(n,t,"Ожидание транспорта у разгрузки"); return
	var amount=int(min(n.taskUnits,min(carrier.store.get(t.resource,0),t.quantity-t.done)))
	var got=amount if destination.id==carrier.id else g.add_inventory(destination.store,t.resource,amount,[],g.capacity(destination),10000)
	if destination.id!=carrier.id: carrier.store[t.resource]-=got
	n.taskUnits-=got
	t.done+=got
	if n.taskUnits>0: task_block(n,t,"Хранилище заполнено")
	else: n.returning=false; n.taskCargoId=""
	if t.done>=t.quantity: t.done=t.quantity; t.status="Готово"; t.reason=""

func update_escorts(dt: float):
	for task in g.state.tasks:
		if not task.get("shared",false) or task.type!="escort" or task.status in ["Отменено","Готово"]: continue
		var ship=g.entity(task.escortId)
		var leader=g.entity(task.shipId)
		if ship.is_empty() or leader.is_empty() or ship.hp<=0 or leader.hp<=0: continue
		var crew=task.members.filter(func(id): return g.entity(id).get("alive",false))
		var aboard=crew.filter(func(id): return g.entity(id).get("shipId")==ship.id)
		if aboard.is_empty(): continue
		if aboard.size()<crew.size(): ship.speed=0; task.reason="Ожидание посадки отряда: %d / %d" % [aboard.size(),crew.size()]; continue
		task.status="В работе"; task.reason=""
		var gap=g.catalog.SHIPS[leader.kind].length+18
		var target={"x":leader.x-sin(leader.yaw)*gap,"z":leader.z-cos(leader.yaw)*gap}
		ship["routeRefresh"]=ship.get("routeRefresh",0)-dt
		if ship.routeRefresh<=0:
			build_sea_paths()
			var start=sea_cell(ship)
			var end=sea_cell(target)
			ship["route"]=[]
			if start.x>=0 and end.x>=0:
				for point in sea_path.get_point_path(start,end): ship.route.append({"x":point.x,"z":point.y})
			ship["waypoint"]=0; ship.routeRefresh=4
		var index=int(ship.get("waypoint",0))
		if index<ship.route.size() and g.distance(ship,ship.route[index])<8: index+=1; ship.waypoint=index
		var q=ship.route[index] if index<ship.route.size() else target
		g.combat.move_ship(ship,atan2(q.x-ship.x,q.z-ship.z),0.85 if g.distance(ship,target)>10 else 0.0,dt)
		for id in aboard:
			var member=g.entity(id); member.x=ship.x; member.z=ship.z; member.yaw=ship.yaw
		var threats=g.state.ships.filter(func(enemy): return enemy.hp>0 and enemy.owner!="player" and (enemy.owner=="pirates" or enemy.get("hostile",0)>0) and g.distance(enemy,leader)<170)
		threats.sort_custom(func(a,b): return g.distance(a,ship)<g.distance(b,ship))
		if not threats.is_empty(): g.fire_ship(ship,"cannon" if g.catalog.SHIPS[ship.kind].cannons>0 else "ballista",threats[0])

func point_on_island(island: Dictionary,min_height=1.0,max_height=28.0) -> Dictionary:
	for attempt in 120:
		var angle=g.rng.randf()*TAU
		var radius=sqrt(g.rng.randf())*0.9
		var point={"x":island.x+cos(angle)*radius*island.rx,"z":island.z+sin(angle)*radius*island.rz}
		var height=g.height_at(point.x,point.z)
		if height>min_height and height<max_height: return point
	return {"x":island.x+15,"z":island.z+35}

func update_beast(a: Dictionary,dt: float):
	if not a.alive:
		g.combat.enemy_attack(a,dt)
		if a.alive and a.get("entity_kind")=="creatures": a.timer=2.0
		return
	if a.get("staggerUntil",0)>g.state.time:
		g.combat.enemy_attack(a,dt)
		return
	a.timer-=dt
	if g.combat.enemy_attack(a,dt): return
	if a.get("entity_kind")=="animals":
		a.state="graze"
		if a.timer<=0:
			var home={}
			for island in g.catalog.ISLANDS:
				if island.id==a.home: home=island; break
			if home.is_empty(): return
			a.goal=point_on_island(home,1,28)
			a.timer=8.0+g.rng.randf()*7.0
		if not a.goal.is_empty(): move_actor(a,a.goal,0.65,dt)
		return
	var definition=g.catalog.CREATURES[a.kind]
	var territory=g.distance(a,a.origin)
	if a.timer<=0 or territory>80:
		var angle=g.rng.randf()*6.28
		var radius=0.0 if territory>80 else 12.0
		var point={"x":a.origin.x+sin(angle)*radius,"z":a.origin.z+cos(angle)*radius}
		a.goal=point if g.height_at(point.x,point.z)>0.5 else a.origin.duplicate()
		a.timer=5.0+g.rng.randf()*7.0
	if not a.goal.is_empty() and g.distance(a,a.goal)>1: a.state="walk"; move_actor(a,a.goal,definition.speed*0.35,dt)
	else: a.state="idle"

func update_vehicles(dt: float):
	update_escorts(dt)
	for c in g.state.carts:
		if c.hp<=0: continue
		c.speed=0.0
		var leader=g.player if c.id==g.player.cartId or c.followId=="player" else g.entity(c.followId)
		if leader.is_empty() or not leader.get("alive",true) or leader.get("dead",false) or leader.get("sailing",false) or leader.get("shipId"): continue
		var space=6.5 if c.kind=="wagon" else 2.15
		var q={"x":leader.x-sin(leader.yaw)*space,"z":leader.z-cos(leader.yaw)*space}
		if g.height_at(q.x,q.z)<0.4: c["status"]="Ожидает у воды"; continue
		var before=Vector2(c.x,c.z)
		if g.distance(c,q)>0.15:
			move_actor(c,q,6.0 if c.kind=="wagon" else 4.5 if g.weight(c.store)>0 else 6.0,dt)
			c.yaw=lerp_angle(c.yaw,leader.yaw,min(1,dt*4))
		var traveled=before.distance_to(Vector2(c.x,c.z))
		c.wheelAngle+=traveled/0.49
		c.speed=traveled/max(dt,0.001)
		c["status"]="Следует" if traveled>0 else "Ожидает"
		if c.id==g.player.cartId and g.distance(c,g.player)>3.3:
			g.player.x=c.x+sin(c.yaw)*2.2
			g.player.z=c.z+cos(c.yaw)*2.2

func update_ship(s: Dictionary,dt: float):
	g.economy.update_ship(s,dt)

func naval_trade(s: Dictionary):
	g.economy.naval_trade(s)

func economy_tick():
	g.economy.passive_production()

func form_group():
	return g.economy.form_group()

func update_group_member(n: Dictionary,group: Dictionary,dt: float):
	g.economy.update_group_member(n,group,dt)

func update_groups(dt: float):
	g.economy.update_groups(dt)
