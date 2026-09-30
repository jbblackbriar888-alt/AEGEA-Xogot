extends RefCounted
## AEGEA 5.6 economy, settlement builders, independent groups, and physical trade.
## Sources: game.js, settlements.js, company.js, systems-53.js, expansion.js.
## Paid construction and vehicle orders live in the save, not transient timers.
var g
var nav_grids: Dictionary = {}
var port_points: Dictionary = {}
var resource_pools: Dictionary = {}
var resource_array: Array = []
var resource_count = -1
const PERIODS = {"production":35.0,"food":60.0,"merchant":30.0,"formation":45.0,"workshop":20.0}
const NPC_PLAN = ["hut","campfire","lumbercamp","quarry","farm","hut","palisade","well","tower","forge","longhouse","townhall"]
const GROUP_PLAN = ["campfire","hut","warehouse"]
const NAV_STEP = 22.0

func _init(game):
	g=game

func normalize():
	resource_count=-1
	resource_pools.clear()
	var timers=g.state.get("economyTimers",{})
	if not timers is Dictionary: timers={}
	for key in PERIODS:
		var value=timers.get(key,0.0)
		timers[key]=clampf(float(value),0.0,PERIODS[key]) if (value is float or value is int) and is_finite(float(value)) else 0.0
	g.state["economyTimers"]=timers
	for s in g.state.settlements:
		s["plan"]=max(0,int(s.get("plan",s.get("built",0))))
		s["built"]=max(0,int(s.get("built",0)))
		s["timer"]=max(0,float(s.get("timer",0)))
		if not s.get("construction") is Dictionary: s["construction"]={}
		settlement_depot(s)
	for group in g.state.groups:
		group["stage"]=clampi(int(group.get("stage",0)),0,3)
		group["progress"]=clampf(float(group.get("progress",0)),0.0,1.0)
		if not group.get("building") is Dictionary: group["building"]={}
	for n in g.state.npcs:
		if not n.get("vehicleOrder") is Dictionary: n["vehicleOrder"]={}
		if not n.get("marketAnchor") is Dictionary: n["marketAnchor"]={"x":n.x,"z":n.z}

func settlement(id: String) -> Dictionary:
	for s in g.state.settlements:
		if s.id==id: return s
	return {}

func settlement_depot(s: Dictionary) -> Dictionary:
	# JSON cannot preserve shared dictionary identity. Relink the actual warehouse.
	var nearest={}
	var best=INF
	for b in g.state.buildings:
		if b.hp<=0 or b.owner!=s.id or b.type!="warehouse": continue
		if g.distance(b,s)<best: nearest=b; best=g.distance(b,s)
	if not nearest.is_empty(): s.store=nearest.store
	return nearest

func step(dt: float):
	if dt<=0: return
	if not g.state.has("economyTimers"): normalize()
	# Keep the remainder: independent clocks must not drift with frame size.
	var timers=g.state.economyTimers
	for s in g.state.settlements.duplicate(): update_settlement(s,dt)
	update_groups(dt)
	for key in PERIODS:
		timers[key]+=dt
		while timers[key]+0.0000001>=PERIODS[key]:
			timers[key]=max(0.0,timers[key]-PERIODS[key])
			match key:
				"production": passive_production()
				"food": consume_food()
				"merchant": replenish_merchants()
				"formation": form_group()
				"workshop": update_workshops()

func production_spec(b: Dictionary) -> Dictionary:
	var spec=g.catalog.BUILDING_BY_ID.get(b.get("type",""),{}).get("production",{}).duplicate(true)
	if spec.is_empty(): return {}
	var island=g.island_at(b).get("id","")
	if b.type=="mine":
		if island not in ["keos","thera"]: spec.amount=0; spec["reason"]="Рудник добывает руду на Кеосе или уголь на Тере"; return spec
		spec.out="ore" if island=="keos" else "coal"; spec.amount=4
	if b.type=="lumbercamp": spec.amount=6 if island=="eos" else 2
	if b.type=="farm": spec.amount=8 if island=="naxos" else 3
	spec.amount=max(1,int(floor(spec.amount*(1+(clampi(int(b.get("level",1)),1,3)-1)*0.5))))
	return spec

func production_state(b: Dictionary) -> Dictionary:
	var spec=production_spec(b)
	if spec.is_empty(): return {}
	spec["active"]=false
	if b.hp<=0: spec["status"]="Постройка разрушена"; return spec
	if spec.amount<=0: spec["status"]=spec.get("reason",""); return spec
	var depot=g.ai.storage(b,b.owner,50.0)
	if depot.is_empty(): spec["status"]="Нужен склад в пределах 50 м"; return spec
	spec["warehouse"]=depot
	if b.owner=="player" and g.state.civic.foodShortage: spec["status"]="Жителям не хватает пищи"; return spec
	if not affords(depot.store,spec.get("input",{})): spec["status"]="Нет сырья для переработки"; return spec
	var trial=depot.store.duplicate(); pay(trial,spec.get("input",{}))
	if g.add_inventory(trial,spec.out,int(spec.amount),[],g.capacity(depot),10000)!=spec.amount: spec["status"]="Склад заполнен"; return spec
	spec.active=true; spec["status"]="Работает"
	return spec

func passive_production():
	for b in g.state.buildings:
		var spec=production_state(b)
		if spec.is_empty(): continue
		b["productionStatus"]=spec.status
		if not spec.active: continue
		pay(spec.warehouse.store,spec.get("input",{}))
		spec.warehouse.store[spec.out]=spec.warehouse.store.get(spec.out,0)+spec.amount
		b["lastProduced"]=g.state.time
		b.productionStatus="Работает · %d %s / 35 с" % [spec.amount,g.catalog.RESOURCES[spec.out].name]

func settlement_summary() -> Dictionary:
	var buildings=g.state.buildings.filter(func(b): return b.owner=="player" and b.hp>0)
	var warehouses=buildings.filter(func(b): return b.type in ["warehouse","granary"])
	var residents=g.state.npcs.filter(func(n): return n.home=="player" and n.alive)
	var stocks=g.blank(); var output=g.blank(); var input=g.blank()
	var capacity=0.0
	for b in warehouses:
		capacity+=g.capacity(b)
		for key in stocks: stocks[key]+=b.store.get(key,0)
	var production=[]
	for b in buildings:
		var spec=production_state(b)
		if spec.is_empty(): continue
		spec["building"]=b; production.append(spec)
		if not spec.active: continue
		output[spec.out]+=spec.amount*60.0/35.0
		for key in spec.get("input",{}): input[key]+=spec.input[key]*60.0/35.0
	input.food+=int(ceil(residents.size()/3.0))
	return {"buildings":buildings,"warehouses":warehouses,"residents":residents,"stocks":stocks,"output":output,"input":input,"production":production,"beds":g.beds(),"capacity":capacity,"weight":g.weight(stocks),"shortage":g.state.civic.foodShortage}

func consume_food():
	var remaining=int(ceil(g.residents()/3.0))
	for b in g.state.buildings:
		if b.hp<=0 or b.owner!="player" or b.type not in ["warehouse","granary"]: continue
		var eaten=int(min(remaining,b.store.get("food",0)))
		b.store.food=b.store.get("food",0)-eaten
		remaining-=eaten
	var was=g.state.civic.foodShortage
	g.state.civic.foodShortage=remaining>0
	if was!=g.state.civic.foodShortage:
		g.notify("Жителям не хватает пищи. Пополните склад, чтобы возобновить работу." if remaining>0 else "Жители получили пищу и вернулись к работе.")
	for s in g.state.settlements:
		if settlement_depot(s).is_empty(): continue
		var count=g.state.npcs.filter(func(n): return n.alive and n.home==s.id).size()
		s.store.food=max(0,s.store.get("food",0)-int(ceil(count/3.0)))

func replenish_merchants():
	for n in g.state.npcs:
		if n.role!="merchant" or not n.alive: continue
		var home=settlement(n.home)
		var depot=settlement_depot(home) if not home.is_empty() else {}
		var export_key=g.catalog.ISLAND_ECONOMY.get(n.get("originHome",n.home),{}).get("export","")
		for key in g.catalog.RESOURCES:
			n.marketPressure[key]=n.marketPressure.get(key,0)*0.9
			if depot.is_empty() or g.distance(n,home)>=25: continue
			var wanted=35 if key==export_key else 12
			var amount=int(min(4,min(max(0,wanted-n.marketStock.get(key,0)),max(0,depot.store.get(key,0)-8))))
			var got=g.add_inventory(n.marketStock,key,amount,[],650,10000)
			depot.store[key]=depot.store.get(key,0)-got

func affords(store: Dictionary,cost: Dictionary) -> bool:
	for key in cost:
		if store.get(key,0)<cost[key]: return false
	return true

func pay(store: Dictionary,cost: Dictionary):
	for key in cost: store[key]=store.get(key,0)-cost[key]

func fits_building(type: String,q: Dictionary,factor=0.95) -> bool:
	if g.height_at(q.x,q.z)<1: return false
	var size=g.catalog.BUILDING_BY_ID[type].size
	for b in g.state.buildings:
		if b.hp>0 and g.distance(q,b)<(size+g.catalog.BUILDING_BY_ID[b.type].size)*factor: return false
	return true

func update_settlement(s: Dictionary,dt: float):
	var construction=s.get("construction",{})
	if construction is Dictionary and not construction.is_empty():
		if construction.get("progress",0)<1: return
		g.add_building(construction.type,construction,s.id)
		s.construction={}; s.plan=int(s.get("plan",0))+1; s.built=int(s.get("built",0))+1; s.timer=20.0
		g.state.stats.npcBuilt=g.state.stats.get("npcBuilt",0)+1
		g.notify(s.name+": завершена постройка «"+g.catalog.BUILDING_BY_ID[construction.type].name+"»")
		return
	s["timer"]=s.get("timer",0)-dt
	if s.timer>0 or s.get("built",0)>=18: return
	var depot=settlement_depot(s)
	if depot.is_empty(): return
	var index=int(s.get("plan",0))
	var type=NPC_PLAN[index%NPC_PLAN.size()]
	var definition=g.catalog.BUILDING_BY_ID[type]
	if definition.cost.get("leather",0)>depot.store.get("leather",0) and depot.store.get("food",0)>=3:
		# The original abstract hunting conversion is paid with real food.
		var next=depot.store.duplicate(); next.food-=3
		if g.add_inventory(next,"leather",2,[],g.capacity(depot),10000)==2: depot.store.merge(next,true)
	if not affords(depot.store,definition.cost): return
	for attempt in 30:
		var angle=(index+attempt)*2.399
		var radius=17+floor((index+attempt)/6.0)*6
		var q={"x":s.x+cos(angle)*radius,"z":s.z+sin(angle)*radius}
		if not fits_building(type,q): continue
		pay(depot.store,definition.cost)
		for r in g.state.resources:
			if r.kind=="wood" and g.distance(r,q)<definition.size+1: r.amount=0; r.respawn=-1.0
		s.construction={"id":g.uid("npc-site"),"type":type,"x":q.x,"z":q.z,"progress":0.0,"paid":definition.cost.duplicate()}
		return
	s.timer=10.0

func update_workshops():
	for s in g.state.settlements:
		var depot=settlement_depot(s)
		if depot.is_empty(): continue
		var workers=g.state.npcs.filter(func(n): return n.home==s.id and n.alive and not n.ally and n.role=="worker")
		var workshop={}
		for b in g.state.buildings:
			if b.owner==s.id and b.type=="workbench" and b.hp>0: workshop=b; break
		if workshop.is_empty():
			var cost={"wood":10,"stone":4}
			if not affords(depot.store,cost): continue
			for attempt in 12:
				var q={"x":s.x+sin(attempt*0.524)*24,"z":s.z+cos(attempt*0.524)*24}
				if not fits_building("workbench",q,0.76) or g.blocked(q,1.5,"",false): continue
				pay(depot.store,cost); g.add_building("workbench",q,s.id); break
			continue
		for recipe in [{"input":{"wood":4},"out":"planks"},{"input":{"ore":6,"coal":2},"out":"ingots"}]:
			if not affords(depot.store,recipe.input): continue
			var next=depot.store.duplicate(); pay(next,recipe.input)
			if g.add_inventory(next,recipe.out,3,[],g.capacity(depot),10000)==3: depot.store.merge(next,true)
		if workers.is_empty() or g.state.carts.any(func(c): return c.owner==s.id and c.hp>0) or workers.any(func(n): return n.get("vehicleOrder") is Dictionary and not n.vehicleOrder.is_empty()): continue
		var cost=g.catalog.VEHICLE_COSTS.cart
		if not affords(depot.store,cost): continue
		var point={"x":workshop.x+g.catalog.BUILDING_BY_ID.workbench.size*0.72+2,"z":workshop.z}
		if g.blocked(point,0.7,"",false) or g.height_at(point.x,point.z)<0.5: continue
		pay(depot.store,cost)
		workers[0]["vehicleOrder"]={"stationId":workshop.id,"progress":0.0,"point":point,"paid":cost.duplicate(),"status":"Идёт к мастерской"}
		workers[0].state="build"

func update_vehicle_order(n: Dictionary,dt: float) -> bool:
	var job=n.get("vehicleOrder",{})
	if not job is Dictionary or job.is_empty(): return false
	var station=g.entity(job.stationId)
	if station.is_empty() or station.hp<=0:
		n.state="idle"; job.status="Мастерская недоступна"; return true
	var point=g.geometry.building_approach(station,n)
	if point.is_empty(): n.state="idle"; job.status="Нет подхода к мастерской"; return true
	if g.distance(n,point)>1.6:
		n.state="walk"; job.status="Идёт к мастерской"; g.ai.move_actor(n,point,4.5,dt); return true
	n.state="build"; job.status="Изготовление тележки"
	job.progress=min(12.0,job.get("progress",0)+dt)
	if job.progress+0.000001<12: return true
	var cart={"id":g.uid("npc-cart"),"kind":"cart","x":job.point.x,"z":job.point.z,"yaw":0.0,"hp":220,"maxHp":220,"owner":n.home,"store":g.blank(),"followId":n.id,"driverId":n.id,"wheelAngle":0.0,"speed":0.0}
	g.state.carts.append(cart); n["workCartId"]=cart.id; n.vehicleOrder={}
	g.reindex()
	return true

func total_units(store: Dictionary) -> int:
	var count=0
	for value in store.values(): count+=int(value)
	return count

func transfer_store(source: Dictionary,destination: Dictionary,capacity: float):
	for key in g.catalog.RESOURCES:
		var got=g.add_inventory(destination,key,int(source.get(key,0)),[],capacity,10000)
		source[key]=source.get(key,0)-got

func update_vehicle_work(n: Dictionary,dt: float) -> bool:
	# systems-53 wraps all ordinary combat/worker behavior with active vehicle work.
	if not n.alive or n.ally: return false
	if update_vehicle_order(n,dt): return true
	var cart=g.entity(n.get("workCartId",""))
	var home=settlement(n.home)
	if cart.is_empty() or cart.hp<=0 or home.is_empty() or g.distance(cart,n)>=6: return false
	var depot=settlement_depot(home)
	if depot.is_empty(): return false
	transfer_store(n.carry,cart.store,g.capacity(cart))
	if g.weight(cart.store)>40 or n.get("deliveringCart",false):
		n["deliveringCart"]=true; n.state="return"
		if g.distance(n,home)>5:
			g.ai.move_actor(n,{"x":home.x+4,"z":home.z},4.5,dt)
			return true
		if g.distance(cart,home)<10:
			transfer_store(cart.store,depot.store,800)
			n.deliveringCart=g.weight(cart.store)>0
			if n.deliveringCart: return true
	return false

func update_npc(n: Dictionary,dt: float) -> bool:
	# AI calls this after passengers/combat so interrupted work never progresses.
	if not n.alive or n.ally: return false
	n["timer"]=n.get("timer",0)-dt
	if n.home=="player" and g.state.civic.foodShortage: n.state="idle"; return true
	if n.role=="merchant":
		n.state="trade"
		var anchor=n.get("marketAnchor",n)
		if anchor is Dictionary and g.distance(n,anchor)>1: g.ai.move_actor(n,anchor,2.0,dt)
		return true
	if n.get("groupId"):
		for group in g.state.groups:
			if group.id==n.groupId and group.phase!="settlement": update_group_member(n,group,dt); return true
	var home=settlement(n.home)
	if n.home=="player":
		for b in g.state.buildings:
			if b.owner=="player" and b.type=="warehouse" and b.hp>0: home={"id":"player","x":b.x,"z":b.z,"island":g.island_at(b).get("id","")}; break
	if home.is_empty(): n.state="idle"; return true
	var depot=settlement_depot(home)
	if depot.is_empty(): n.state="idle"; return true
	if n.role=="guard":
		var angle=g.state.time*0.04+str(n.home).unicode_at(0)%7
		n.state="patrol"; g.ai.move_actor(n,{"x":home.x+sin(angle)*17,"z":home.z+cos(angle)*17},1.6,dt); return true
	var construction=home.get("construction",{})
	if n.role=="builder" and construction is Dictionary and not construction.is_empty():
		n.state="build"; g.ai.move_actor(n,{"x":construction.x+4,"z":construction.z+2},2.8,dt)
		if g.distance(n,construction)<8: construction.progress=min(1.0,construction.progress+dt/40.0)
		return true
	if total_units(n.carry)>=6 or n.state=="return":
		n.state="return"
		if g.distance(n,home)<7:
			transfer_store(n.carry,depot.store,g.capacity(depot))
			if total_units(n.carry)==0: n.state="idle"; n["resourceId"]=""
		else: g.ai.move_actor(n,{"x":home.x-5,"z":home.z+(4 if n.home=="player" else 2)},2.5,dt)
		return true
	var resource=g.entity(n.get("resourceId",n.get("target","")))
	if resource.is_empty() or resource.get("amount",0)<=0:
		var needed=[]
		if n.home!="player":
			var cost=g.catalog.BUILDING_BY_ID[NPC_PLAN[int(home.get("plan",0))%NPC_PLAN.size()]].cost
			for key in cost:
				if depot.store.get(key,0)<cost[key]: needed.append(key)
		resource=select_resource(n,str(home.island),needed,home,95.0 if n.home=="player" else INF,depot.store if n.home=="player" else {},n.home!="player")
		n["resourceId"]=resource.get("id","")
	if resource.is_empty(): n.state="idle"; return true
	gather(n,resource,dt,2.2)
	return true

func resources_on(island: String) -> Array:
	if resource_count!=g.state.resources.size() or not is_same(resource_array,g.state.resources):
		resource_pools.clear()
		resource_array=g.state.resources; resource_count=resource_array.size()
		for r in resource_array:
			var id=str(r.get("island",""))
			if not resource_pools.has(id): resource_pools[id]=[]
			resource_pools[id].append(r)
	return resource_pools.get(island,[])

func select_resource(n: Dictionary,island: String,needed: Array,anchor: Dictionary,radius: float=INF,stocks: Dictionary={},fallback=false) -> Dictionary:
	# One stable minimum is equivalent to the browser's full sort, but avoids
	# sorting thousands of resources for every worker. Buckets retain source order.
	var best={}; var first={}; var score=INF; var stock_score=INF
	var radius_squared=radius*radius
	for r in resources_on(island):
		if r.amount<=0: continue
		if first.is_empty(): first=r
		if not needed.is_empty() and r.kind not in needed: continue
		var ax=r.x-anchor.x; var az=r.z-anchor.z
		if ax*ax+az*az>=radius_squared: continue
		var dx=r.x-n.x; var dz=r.z-n.z; var squared=dx*dx+dz*dz
		var supply=stocks.get(r.kind,0) if not stocks.is_empty() else 0
		if supply<stock_score or supply==stock_score and squared<score:
			best=r; score=squared; stock_score=supply
	return first if best.is_empty() and fallback else best

func gather(n: Dictionary,r: Dictionary,dt: float,speed: float):
	if g.distance(n,r)>1.35: n.state="walk"; g.ai.move_actor(n,r,speed,dt); return
	n.state="chop" if r.kind=="wood" else "mine" if r.kind in ["stone","ore","coal","clay"] else "harvest"
	n.yaw=atan2(r.x-n.x,r.z-n.z)
	if n.get("timer",0)>0: return
	var quantity=int(min(2,r.amount))
	r.amount-=quantity; n.carry[r.kind]=n.carry.get(r.kind,0)+quantity; n.timer=2.2
	if r.amount<=0: r.respawn=g.state.time+240

func form_group(island_id="") -> Dictionary:
	if island_id=="":
		for island in g.catalog.ISLANDS:
			if not g.state.groups.any(func(group): return group.island==island.id): island_id=island.id; break
	if island_id=="" or g.state.groups.any(func(group): return group.island==island_id): return {}
	var home=settlement(island_id)
	var candidates=g.state.npcs.filter(func(n): return n.home==island_id and n.alive and not n.ally and not n.get("groupId") and n.role in ["worker","builder"])
	if home.is_empty() or candidates.size()<3: return {}
	candidates=candidates.slice(candidates.size()-3)
	var point={}
	for attempt in 32:
		var angle=attempt*2.399
		var radius=55+(attempt%5)*8
		var q={"x":home.x+sin(angle)*radius,"z":home.z+cos(angle)*radius}
		var height=g.height_at(q.x,q.z)
		if height>2 and height<27 and not g.blocked(q,7,"",false) and g.state.resources.any(func(r): return r.kind=="wood" and r.amount>0 and g.distance(r,q)<30): point=q; break
	if point.is_empty(): return {}
	var group={"id":g.uid("group"),"name":"Вольный лагерь "+str(g.state.groups.size()+1),"island":island_id,"members":[],"phase":"travel","x":point.x,"z":point.z,"store":g.blank(),"stage":0,"progress":0.0,"building":{}}
	for n in candidates:
		n["groupId"]=group.id; n["originHome"]=n.get("originHome",n.home); n["resourceId"]=""; group.members.append(n.id)
	g.state.groups.append(group)
	return group

func update_group_member(n: Dictionary,group: Dictionary,dt: float):
	if group.phase=="travel":
		n.state="walk"; g.ai.move_actor(n,{"x":group.x+(group.members.find(n.id)-1)*2,"z":group.z},3.1,dt); return
	if group.phase=="settlement": return
	if total_units(n.carry)>=6 or n.state=="return":
		n.state="return"
		if g.distance(n,group)>5: g.ai.move_actor(n,group,3.1,dt)
		else:
			transfer_store(n.carry,group.store,800)
			if total_units(n.carry)==0: n.state="idle"; n["resourceId"]=""
		return
	var building=group.get("building",{})
	if building is Dictionary and not building.is_empty():
		n.state="build"; g.ai.move_actor(n,{"x":building.x+3,"z":building.z},2.8,dt); return
	var stage=int(group.get("stage",0))
	if stage>=GROUP_PLAN.size(): return
	var cost=g.catalog.BUILDING_BY_ID[GROUP_PLAN[stage]].cost
	var needed=[]
	for key in cost:
		if group.store.get(key,0)<cost[key]: needed.append(key)
	var resource=g.entity(n.get("resourceId",""))
	if resource.is_empty() or resource.get("amount",0)<=0 or (not needed.is_empty() and resource.kind not in needed):
		resource=select_resource(n,str(group.island),needed,group,100.0)
		n["resourceId"]=resource.get("id","")
	if resource.is_empty(): n.state="idle"; return
	gather(n,resource,dt,2.8)

func update_groups(dt: float):
	for group in g.state.groups:
		var members=[]
		for id in group.members:
			var n=g.entity(id)
			if not n.is_empty() and n.alive and not n.ally: members.append(n)
		if members.is_empty() or group.phase=="settlement": continue
		if group.phase=="travel":
			if members.all(func(n): return g.distance(n,group)<9): group.phase="gather"
			continue
		var building=group.get("building",{})
		if building is Dictionary and not building.is_empty():
			group.progress=group.get("progress",0)+dt*members.filter(func(n): return g.distance(n,building)<7).size()/30.0
			if group.progress+0.000001<1: continue
			var b=g.add_building(building.type,building,group.id)
			group.building={}; group.progress=0.0; group.stage=int(group.get("stage",0))+1
			g.state.stats.npcBuilt=g.state.stats.get("npcBuilt",0)+1
			if group.stage>=3:
				group.phase="settlement"; b.store=group.store
				g.state.settlements.append({"id":group.id,"name":group.name,"island":group.island,"x":b.x,"z":b.z,"store":b.store,"plan":0,"timer":20.0,"construction":{},"built":0,"autonomous":true})
				for index in members.size():
					var n=members[index]; n.home=group.id; n.role="builder" if index==0 else "worker"; n["groupId"]=""; n["resourceId"]=""
				g.notify(group.name+" вырос в самостоятельное поселение.")
			else: group.phase="camp"
			continue
		var stage=int(group.get("stage",0))
		if stage>=GROUP_PLAN.size(): continue
		var type=GROUP_PLAN[stage]
		var cost=g.catalog.BUILDING_BY_ID[type].cost
		if not affords(group.store,cost): continue
		for attempt in 20:
			var angle=attempt*2.399
			var radius=0 if stage==0 else 10+floor(attempt/6.0)*4
			var point={"x":group.x+sin(angle)*radius,"z":group.z+cos(angle)*radius}
			if not fits_building(type,point,0.85): continue
			pay(group.store,cost)
			group["building"]={"type":type,"x":point.x,"z":point.z,"paid":cost.duplicate()}; group.progress=0.0; break

func naval_trade(ship: Dictionary):
	if ship.get("role")!="trader": return
	var home=settlement(str(ship.get("destination","")))
	if home.is_empty(): return
	var depot=settlement_depot(home)
	var economy=g.catalog.ISLAND_ECONOMY.get(home.id,{})
	if depot.is_empty() or economy.is_empty(): return
	for key in g.catalog.RESOURCES:
		if key==economy.export: continue
		var reserve=12 if key in ["wood","stone","coal"] else 0
		var amount=g.add_inventory(depot.store,key,int(max(0,ship.store.get(key,0)-reserve)),[],g.capacity(depot),10000)
		ship.store[key]=ship.store.get(key,0)-amount
		g.state.stats["delivered"]=g.state.stats.get("delivered",0)+amount
	var loaded=g.add_inventory(ship.store,economy.export,int(min(45,max(0,depot.store.get(economy.export,0)-18))),[],g.capacity(ship),10000)
	depot.store[economy.export]=depot.store.get(economy.export,0)-loaded
	ship["lastTradeIsland"]=home.id

func water_line(a: Dictionary,b: Dictionary,radius: float) -> bool:
	var count=int(ceil(g.distance(a,b)/7.0))
	for index in range(count+1):
		var t=float(index)/max(1,count)
		if not g.combat.water_clear(lerp(a.x,b.x,t),lerp(a.z,b.z,t),radius): return false
	return true

func sea_grid(radius: float) -> AStarGrid2D:
	var key=snappedf(radius,0.01)
	if nav_grids.has(key): return nav_grids[key]
	var limit=int(floor((g.catalog.LIMITS.world-15)/NAV_STEP))
	var grid=AStarGrid2D.new()
	grid.region=Rect2i(-limit,-limit,limit*2+1,limit*2+1)
	grid.cell_size=Vector2(NAV_STEP,NAV_STEP)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(-limit,limit+1):
		for z in range(-limit,limit+1):
			grid.set_point_solid(Vector2i(x,z),not g.combat.water_clear(x*NAV_STEP,z*NAV_STEP,radius+2))
	nav_grids[key]=grid
	return grid

func sea_snap(point: Dictionary,grid: AStarGrid2D,radius: float) -> Vector2i:
	var center=Vector2i(round(point.x/NAV_STEP),round(point.z/NAV_STEP))
	var result=Vector2i(1000000,1000000)
	var best=INF
	for dx in range(-4,5):
		for dz in range(-4,5):
			var cell=center+Vector2i(dx,dz)
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell): continue
			var q={"x":cell.x*NAV_STEP,"z":cell.y*NAV_STEP}
			var distance=g.distance(point,q)
			if distance<best and water_line(point,q,radius): result=cell; best=distance
	return result

func water_path(start: Dictionary,finish: Dictionary,radius: float) -> Array:
	if water_line(start,finish,radius): return [{"x":finish.x,"z":finish.z}]
	var grid=sea_grid(radius)
	var a=sea_snap(start,grid,radius)
	var b=sea_snap(finish,grid,radius)
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b): return []
	var raw=[]
	for point in grid.get_point_path(a,b): raw.append({"x":point.x,"z":point.y})
	if raw.is_empty(): return []
	raw.append({"x":finish.x,"z":finish.z})
	var route=[]
	var current=start
	var index=0
	while index<raw.size():
		var next=index
		while next+1<raw.size() and water_line(current,raw[next+1],radius): next+=1
		if not water_line(current,raw[next],radius): return []
		route.append(raw[next]); current=raw[next]; index=next+1
	return route

func port_point(destination: String) -> Dictionary:
	# Coast geometry is immutable. Like the browser's ports array, generate once.
	if not port_points.has(destination): port_points[destination]=g.ai.port_point(destination)
	return port_points[destination]

func update_ship(ship: Dictionary,dt: float) -> bool:
	if ship.hp<=0 or ship.owner=="player": return true
	ship["wait"]=ship.get("wait",0)-dt
	if ship.wait>0: ship.speed=max(0,ship.get("speed",0)-dt*3); return true
	var destination=str(ship.get("destination",g.catalog.ISLANDS[0].id))
	if not g.catalog.ISLANDS.any(func(island): return island.id==destination): destination=g.catalog.ISLANDS[0].id; ship["destination"]=destination
	var port=port_point(destination)
	if g.distance(ship,port)<15:
		naval_trade(ship)
		var index=0
		for i in g.catalog.ISLANDS.size():
			if g.catalog.ISLANDS[i].id==destination: index=i; break
		ship.destination=g.catalog.ISLANDS[(index+1)%g.catalog.ISLANDS.size()].id
		ship.wait=12.0; ship.route=[]; ship.speed=0.0; return true
	var radius=ceil(g.catalog.SHIPS[ship.kind].length*0.5)
	if ship.get("route",[]).is_empty() or ship.get("routeRadius",-1)!=radius:
		var failed=ship.get("failedRoute",{})
		# An identical failed query on static terrain cannot acquire a path by
		# waiting. Keep the source retry delay; retry immediately once endpoints
		# or hull radius change (for example after collision, respawn, or towing).
		if failed is Dictionary and not failed.is_empty() and failed.x==ship.x and failed.z==ship.z and failed.destination==destination and failed.radius==radius:
			ship.wait=5.0; ship.speed=0.0; return true
		ship["route"]=water_path(ship,port,radius); ship["waypoint"]=0; ship["routeRadius"]=radius
		if ship.route.is_empty():
			ship["failedRoute"]={"x":ship.x,"z":ship.z,"destination":destination,"radius":radius}
			ship.wait=5.0; ship.speed=0.0; return true
		ship["failedRoute"]={}

	var index=int(ship.get("waypoint",0))
	if index>=ship.route.size(): ship.route=[]; return true
	var point=ship.route[index]
	if g.distance(ship,point)<8:
		index+=1; ship.waypoint=index
		if index>=ship.route.size(): ship.route=[]; return true
		point=ship.route[index]
	g.combat.move_ship(ship,atan2(point.x-ship.x,point.z-ship.z),1.0,dt)
	return true
