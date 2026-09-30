extends Node
## Authoritative local simulation. All menus call these same validated operations.
signal changed
signal message(text: String)
signal effect(kind: String, point: Vector3)
signal world_reloaded

var catalog: Dictionary = {}
var state: Dictionary = {}
var player: Dictionary = {}
var entities: Dictionary = {}
var logs: Array = []
var strikes: Array = []
var projectiles: Array = []
var pending_gather: Dictionary = {}
var ai
var combat
var geometry
var economy
var clock = 0.0
var economy_clock = 0.0
var autosave_clock = 0.0
var starter_wagon_retry = 0.0
var revision = 0
var ready_for_play = false
var autosave_enabled = false
var demo = false
var quality = "iphone"
var rng = RandomNumberGenerator.new()
const SAVE = "user://aegea_xogot_v1.json"
const VERSION = "0.2.0"
const BARTER_VALUE = {"wood":2.0,"stone":1.0,"fiber":1.0,"food":2.0,"ore":5.0,"leather":4.0,"coal":4.0,"clay":1.5}
const NON_SOLID = ["road", "farm", "campfire", "dock", "quarry", "mine", "well", "workbench"]

func _ready():
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	rng.seed = 32417
	ai = preload("res://scripts/ai.gd").new(self)
	combat = preload("res://scripts/combat_parity.gd").new(self)
	geometry = preload("res://scripts/building_geometry.gd").new(self)
	economy = preload("res://scripts/economy_parity.gd").new(self)
	new_world(false)
	ready_for_play = true

func new_world(showcase = false):
	autosave_enabled=ready_for_play
	state = JSON.parse_string(FileAccess.get_file_as_string("res://data/initial_world.json"))
	_normalize(true)
	demo = showcase
	if showcase:
		# Explicit demo mode: supplies are in the wagon, never overfill the backpack.
		player.coins = 5000
		for key in ["sword", "bow", "longbow", "compositebow", "ironHelmet", "ironArmor", "ironGloves", "ironBoots"]:
			if not player.tools.has(key): player.tools.append(key)
		for c in state.carts:
			if c.kind == "wagon" and c.owner == "player":
				c.store = {"wood":120,"stone":100,"fiber":100,"food":80,"ore":30,"leather":30,"coal":40,"clay":80,"planks":120,"ingots":45,"cloth":60}
		notify("Демонстрация: материалы находятся в повозке рядом.")
	else:
		notify("Эос. Топор рубит дерево, кирка добывает камень. Повозка рядом с вами.")
	world_reloaded.emit()

func _normalize(resolve_initial_spawns=false):
	player = state.player
	player["speed"] = 0.0
	player["mode"] = player.get("mode", "jog")
	player["staggerUntil"] = player.get("staggerUntil",0.0)
	player["actionUntil"] = player.get("actionUntil",0.0)
	player["dodgeUntil"] = player.get("dodgeUntil",0.0)
	player["guardStarted"] = player.get("guardStarted",-100.0)
	player["targetId"] = player.get("targetId", "") if player.get("targetId")!=null else ""
	for k in ["shipId", "cartId"]:
		if player.get(k) == null: player[k] = ""
	state["raid"] = {}
	state["tasks"] = state.get("tasks", [])
	state["projects"] = state.get("projects", [])
	state["groups"] = state.get("groups", [])
	state["civic"] = state.get("civic", {})
	for key in ["tradeUnits", "tradeReputation"]: state.civic[key] = state.civic.get(key, 0)
	state.civic["foodShortage"] = state.civic.get("foodShortage", false)
	for k in ["resources", "buildings", "npcs", "animals", "creatures", "ships", "carts", "drops", "seaLife"]:
		if not state.has(k): state[k] = []
	for b in state.buildings:
		b["level"] = b.get("level", 1)
		b["jobs"] = b.get("jobs", [])
		b["foundationY"] = b.get("foundationY", height_at(b.x, b.z))
	for n in state.npcs + state.animals + state.creatures:
		n["cooldown"] = n.get("cooldown",0.0)
		n["staggerUntil"] = n.get("staggerUntil",0.0)
		n["strike"] = {}
		n["companyHit"] = {}
		n["goal"] = n.get("goal",{})
		n["origin"] = n.get("origin", {"x":n.x, "z":n.z})
		n["state"] = n.get("state","idle")
		n["maxHp"] = n.get("maxHp", n.hp)
	for n in state.npcs:
		n["order"] = n.get("order", {"type":"wait"})
		n["ally"] = n.get("ally", false)
		n["marketPressure"] = n.get("marketPressure", {})
		n["marketStock"] = n.get("marketStock", blank())
		n["coins"] = n.get("coins", 500)
		n["taskId"] = n.get("taskId", "")
		n["taskUnits"] = n.get("taskUnits", 0)
		n["taskCargoId"] = n.get("taskCargoId", "")
		for task in state.tasks:
			if task.get("id") == n.order.get("id"): n.order = task
	for s in state.ships:
		s["cooldowns"] = s.get("cooldowns",{"ballista":0.0, "cannon":0.0})
		s["fire"] = s.get("fire", 0.0)
	for c in state.carts:
		c["kind"] = c.get("kind", "cart")
		c["followId"] = c.get("followId") if c.get("followId") != null else ""
		c["wheelAngle"] = 0.0
		c["speed"] = 0.0
	clock = 0.0
	economy_clock = 0.0
	autosave_clock = 0.0
	starter_wagon_retry = 0.0
	strikes.clear()
	projectiles.clear()
	pending_gather.clear()
	if combat!=null: combat.events.clear()
	reindex()
	if ai!=null:
		ai.rebuild_grid()
		ai.group_clock=0.0
		# The web meshes used different footprints. Resolve initial intersections
		# against the native collider sizes, without teleporting working NPCs later.
		for n in state.npcs:
			if not resolve_initial_spawns or not n.alive or n.get("shipId") or not blocked(n,0.32,n.id,true): continue
			var found=false
			for radius in [3,6,10,15,22,30]:
				for j in 32:
					var q={"x":n.x+sin(j*TAU/32)*radius,"z":n.z+cos(j*TAU/32)*radius}
					if height_at(q.x,q.z)>0.6 and not blocked(q,0.35,n.id,true):
						n.x=q.x; n.z=q.z; n.origin=q.duplicate(); found=true; break
				if found: break
	if economy!=null: economy.normalize()

func reindex():
	entities.clear()
	for kind in ["resources", "buildings", "npcs", "animals", "creatures", "ships", "carts", "drops", "seaLife"]:
		for e in state[kind]:
			e["entity_kind"] = kind
			entities[e.id] = e
	revision += 1

func entity(id) -> Dictionary:
	return entities.get(id, {}) if id != null else {}

func uid(prefix: String) -> String:
	state.sequence += 1
	return prefix + "-" + str(int(state.sequence))

func notify(text: String):
	logs.push_front(text)
	if logs.size() > 70: logs.pop_back()
	message.emit(text)
	changed.emit()

func blank() -> Dictionary:
	var out = {}
	for k in catalog.RESOURCES: out[k] = 0
	return out

func distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func point(e: Dictionary, lift = 0.0) -> Vector3:
	return Vector3(e.x, height_at(e.x, e.z) + lift, e.z)

func hash2(x: float, z: float) -> float:
	return fposmod(sin(x * 127.1 + z * 311.7) * 43758.5453123, 1.0)

func noise2(x: float, z: float) -> float:
	var ix = floor(x)
	var iz = floor(z)
	var fx = smoothstep(0.0, 1.0, x - ix)
	var fz = smoothstep(0.0, 1.0, z - iz)
	return lerp(lerp(hash2(ix,iz),hash2(ix+1,iz),fx),lerp(hash2(ix,iz+1),hash2(ix+1,iz+1),fx),fz)

func island_height(i: Dictionary, x: float, z: float) -> float:
	var xx = (x-i.x)/i.rx
	var zz = (z-i.z)/i.rz
	var a = atan2(zz,xx)
	var r = sqrt(xx*xx+zz*zz)
	var edge = 1.0+0.055*sin(a*5+0.4)+0.04*cos(a*3)
	var radial = clamp(1-r/edge,0.0,1.0)
	if radial <= 0: return -1.9-min(46.0,pow(max(0.0,r/edge-1),0.8)*70)
	var scale = catalog.WORLD_SCALE
	var n = noise2(x*0.029/scale,z*0.029/scale)
	var detail = noise2(x*0.13/scale,z*0.13/scale)*0.8
	var mountain = pow(clamp((radial-0.26)/0.74,0.0,1.0),1.55)*i.peak*(0.55+n*0.9)
	return -1.9+radial*10+mountain+(n-0.5)*radial*6+detail*radial

func height_at(x: float, z: float) -> float:
	var h = -50.0
	for i in catalog.ISLANDS: h = max(h,island_height(i,x,z))
	return h

func island_at(e: Dictionary) -> Dictionary:
	var result = {}
	var h = -3.0
	for i in catalog.ISLANDS:
		var v = island_height(i,e.x,e.z)
		if v > h:
			h = v
			result = i
	return result

func weight(inv: Dictionary, equipment: Array = []) -> float:
	var total = 0.0
	for k in inv: total += catalog.RESOURCES.get(k,{}).get("weight",0.0)*max(0,inv[k])
	for k in equipment: total += catalog.TOOLS.get(k,{}).get("weight",0.0)
	return total

func slots(inv: Dictionary, equipment: Array = []) -> int:
	var total = equipment.size()
	for k in inv: total += int(ceil(float(inv[k])/25.0))
	return total

func add_inventory(inv: Dictionary, key: String, count: int, equipment: Array = [], capacity = 120.0, max_slots = 24) -> int:
	if not catalog.RESOURCES.has(key) or count <= 0: return 0
	var by_weight = max(0,int(floor((capacity-weight(inv,equipment)+0.00001)/catalog.RESOURCES[key].weight)))
	var partial = int(inv.get(key,0)) % 25
	var by_slots = max(0,(max_slots-slots(inv,equipment))*25+(25-partial if partial else 0))
	var accepted = mini(count,mini(by_weight,by_slots))
	inv[key] = inv.get(key,0)+accepted
	return accepted

func capacity(e: Dictionary) -> float:
	if e.get("id", "") == "bag": return 120
	if e.entity_kind == "carts": return 900 if e.kind == "wagon" else 700
	if e.entity_kind == "ships": return catalog.SHIPS[e.kind].capacity
	if e.type in ["warehouse","granary"]: return (800 if e.type=="warehouse" else 1200)*clamp(e.get("level",1),1,3)
	return 1200 if e.type=="dock" else 400

func container(id: String) -> Dictionary:
	if id == "bag": return {"id":"bag","store":player.inventory,"owner":"player","x":player.x,"z":player.z}
	var e = entity(id)
	if e.is_empty() or e.get("hp",0)<=0 or not e.has("store"): return {}
	if e.get("entity_kind")=="buildings" and e.type not in ["warehouse","granary","lumbercamp","forge","workbench","dock"]: return {}
	return e

func material_stores(at: Dictionary = {}) -> Array:
	var q = player if at.is_empty() else at
	var list = [player.inventory]
	for b in state.buildings:
		if b.owner=="player" and b.hp>0 and b.type in ["warehouse","granary"] and distance(b,q)<=18: list.append(b.store)
	for c in state.carts:
		if c.owner=="player" and c.hp>0 and distance(c,player)<=12: list.append(c.store)
	return list

func available(at: Dictionary = {}) -> Dictionary:
	var total = blank()
	for inv in material_stores(at):
		for k in total: total[k] += inv.get(k,0)
	return total

func can_afford(cost: Dictionary, at: Dictionary = {}) -> bool:
	var have = available(at)
	for k in cost:
		if not have.has(k) or cost[k]<0 or have[k]<cost[k]: return false
	return true

func consume(cost: Dictionary, at: Dictionary = {}) -> bool:
	if not can_afford(cost,at): return false
	for k in cost:
		var left = cost[k]
		for inv in material_stores(at):
			var take = min(left,inv.get(k,0))
			inv[k] = inv.get(k,0)-take
			left -= take
	changed.emit()
	return true

func transfer(from_id: String, to_id: String, key = "", count = 999999, steal = false) -> int:
	if from_id == to_id or player.dead: return 0
	var a = container(from_id)
	var b = container(to_id)
	if a.is_empty() or b.is_empty(): return 0
	if distance(a,player)>cargo_range(a) or distance(b,player)>cargo_range(b): return 0
	if a.owner!="player" and not (steal and state.pvp and a.get("entity_kind")=="buildings" and a.type in ["warehouse","granary"] and a.get("raidOpenUntil",0)>state.time): return 0
	if b.owner!="player": return 0
	var moved = 0
	for k in ([key] if key!="" else catalog.RESOURCES.keys()):
		var n = add_inventory(b.store,k,int(min(count,a.store.get(k,0))),player.tools if to_id=="bag" else [],capacity(b),24 if to_id=="bag" else 10000)
		a.store[k] = a.store.get(k,0)-n
		moved += n
	if moved>0 and a.owner!="player":
		player.karma=max(-100,player.karma-1)
		state.stats["stolen"]=state.stats.get("stolen",0)+moved
		combat.alert_settlement(a.owner)
	if moved: notify("Перемещено: %d ед." % moved)
	return moved

func equip(id: String) -> bool:
	if player.dead or id=="raft" or not player.tools.has(id) and not player.get("legacyGear",[]).has(id): return false
	if catalog.GEAR.has(id):
		player.equipment[catalog.GEAR[id].slot]=id
		player.armor="iron" if player.equipment.get("armor")=="ironArmor" else "leather"
	else:
		player.tool=id
		player.equipment.weapon=id
	changed.emit()
	return true

func unequip(slot: String) -> bool:
	if player.dead or not catalog.EQUIPMENT_SLOTS.has(slot): return false
	var item=player.equipment.get(slot)
	if item!=null and item!="" and player.get("legacyGear",[]).has(item) and not player.tools.has(item):
		var items=player.tools.duplicate(); items.append(item)
		if weight(player.inventory,items)>120 or slots(player.inventory,items)>24: notify("Освободите место в рюкзаке для снятой вещи"); return false
		player.tools.append(item)
		player.legacyGear.erase(item)
	player.equipment[slot]=null
	if slot=="weapon": player.tool=""
	if slot=="armor": player.armor="leather"
	changed.emit()
	return true

func toggle_raft() -> bool:
	if player.dead or player.shipId!="" or not player.tools.has("raft"): return false
	if not player.sailing and height_at(player.x,player.z)>3.5:
		notify("Подойдите к воде или войдите в мелководье, чтобы развернуть плот")
		return false
	player.sailing=not player.sailing
	player.swimming=not player.sailing and height_at(player.x,player.z)<-1.05
	notify("Плот развёрнут" if player.sailing else "Вы сошли с плота")
	return true

func defense() -> float:
	var result = 0.0
	for id in player.equipment.values(): result += catalog.GEAR.get(id,{}).get("defense",0)
	return result

func eat() -> bool:
	if player.dead or player.inventory.food<1: return false
	player.inventory.food -= 1
	player.hp = min(100,player.hp+15)
	player.hunger = min(100,player.hunger+30)
	notify("Пища: +15 здоровья, +30 сытости")
	return true

func drop(key: String, count = 5):
	var n = min(count,player.inventory.get(key,0))
	if n<=0: return
	var inv = blank()
	inv[key] = n
	player.inventory[key] -= n
	add_drop(player,inv,"Оставленные припасы")

func add_drop(q: Dictionary, inv: Dictionary, label: String, lifetime=600.0):
	state.drops.append({"id":uid("drop"),"x":q.x,"z":q.z,"inventory":inv.duplicate(),"name":label,"expires":state.time+lifetime})
	reindex()

func loot(id: String):
	var e = entity(id)
	if player.dead or e.is_empty() or e.get("entity_kind")!="drops" or e.get("expires",INF)<=state.time or distance(e,player)>5: return
	for k in e.inventory:
		var n = add_inventory(player.inventory,k,int(e.inventory[k]),player.tools)
		e.inventory[k] -= n
	if weight(e.inventory)<=0: state.drops.erase(e)
	reindex()
	effect.emit("loot",point(player,1))

func station(type: String, radius = 12.0) -> Dictionary:
	for b in state.buildings:
		if b.hp>0 and b.owner=="player" and b.type==type and distance(b,player)<=radius: return b
	return {}

func craft(id: String) -> bool:
	if not catalog.TOOLS.has(id) or player.tools.has(id) or player.dead: return false
	var d = catalog.TOOLS[id]
	if d.has("requires") and station(d.requires).is_empty():
		notify("Нужна постройка: "+catalog.BUILDING_BY_ID[d.requires].name)
		return false
	var cost = d.cost.duplicate()
	if not station("shipyard" if id=="raft" else "workbench").is_empty():
		for k in cost: cost[k] = ceil(cost[k]*(0.5 if id=="raft" else 0.75))
	var bag = player.inventory.duplicate()
	for k in cost: bag[k] = max(0,bag.get(k,0)-cost[k])
	var items = player.tools.duplicate()
	items.append(id)
	if weight(bag,items)>120 or slots(bag,items)>24 or not consume(cost):
		notify("Не хватает материалов или места в рюкзаке")
		return false
	player.tools.append(id)
	effect.emit("build",point(player,1))
	notify("Изготовлено: "+d.name)
	return true

func local_point(q: Dictionary, b: Dictionary) -> Vector2:
	var v = Vector2(q.x-b.x,q.z-b.z)
	return v.rotated(float(b.get("yaw",0)))

func blocked(q: Dictionary, radius = 0.35, ignore = "", actors = false) -> bool:
	if abs(q.x)>catalog.LIMITS.world or abs(q.z)>catalog.LIMITS.world: return true
	if geometry.blocked(q,radius,ignore): return true
	for r in nearby_resources(q,4):
		if r.id!=ignore and r.amount>0 and r.kind in ["wood","stone","ore","coal"] and distance(r,q)<radius+(0.36 if r.kind=="wood" else 0.55)*r.scale: return true
	if actors:
		if ignore!="" and not player.dead and player.shipId=="" and distance(player,q)<radius+0.30: return true
		for n in state.npcs:
			if n.id!=ignore and n.alive and not n.get("shipId") and distance(n,q)<radius+0.32: return true
	return false

func nearby_resources(q: Dictionary, radius: float) -> Array:
	return ai.resources_near(q,radius) if ai!=null else []

func clear_line(a: Dictionary, b: Dictionary) -> bool:
	var steps = int(ceil(distance(a,b)/1.5))
	for i in range(1,steps):
		var f = float(i)/steps
		var q = {"x":lerp(a.x,b.x,f),"z":lerp(a.z,b.z,f)}
		if blocked(q,0.05,b.get("id","")): return false
	return true

func placement(type: String, q: Dictionary, yaw=0.0, ignore_cost=false) -> Dictionary:
	return geometry.placement(type,q,yaw,ignore_cost)

func ground_at(x: float,z: float) -> float:
	return geometry.ground_at(x,z)

func build(type: String, q: Dictionary, yaw = 0.0) -> Dictionary:
	if player.dead: return {}
	q=geometry.snap_placement(type,q,yaw,player.get("buildSnap",true))
	yaw=q.yaw
	var check = placement(type,q,yaw)
	if not check.ok:
		notify(check.reason)
		return {}
	if not consume(check.cost,q): return {}
	var b = add_building(type,q,"player",yaw)
	b.foundationY = check.height
	b["foundationDepth"] = check.depth
	state.stats.built += 1
	effect.emit("build",point(q,1))
	notify("Построено: "+catalog.BUILDING_BY_ID[type].name)
	return b

func add_building(type: String, q: Dictionary, owner = "player", yaw = 0.0) -> Dictionary:
	var def = catalog.BUILDING_BY_ID[type]
	var b = {"id":uid("building"),"type":type,"x":q.x,"z":q.z,"yaw":yaw,"owner":owner,"hp":def.hp,"maxHp":def.hp,"level":1,"open":false,"store":blank(),"jobs":[],"foundationY":height_at(q.x,q.z),"progress":1.0}
	state.buildings.append(b)
	reindex()
	return b

func maintenance_cost(b: Dictionary, upgrade=false) -> Dictionary:
	if b.is_empty() or not catalog.BUILDING_BY_ID.has(b.get("type","")): return {}
	var cost={}
	var factor=0.6*b.get("level",1) if upgrade else max(0,(b.maxHp-b.hp)/b.maxHp)*0.55
	if factor<=0: return {}
	for k in catalog.BUILDING_BY_ID[b.type].cost: cost[k]=max(1,ceil(catalog.BUILDING_BY_ID[b.type].cost[k]*factor))
	if upgrade and b.type!="road": cost.ore=cost.get("ore",0)+3*b.get("level",1)
	return cost

func maintain(id: String, upgrade=false) -> bool:
	var b=entity(id)
	if player.dead or b.is_empty() or b.get("entity_kind")!="buildings" or b.owner!="player" or b.hp<=0 or distance(b,player)>12: return false
	if upgrade and b.level>=3 or not upgrade and b.hp>=b.maxHp: return false
	var cost=maintenance_cost(b,upgrade)
	if not consume(cost,b): notify("Не хватает материалов для ремонта/улучшения"); return false
	if upgrade:
		b.level+=1
		b.maxHp=catalog.BUILDING_BY_ID[b.type].hp*(1+(b.level-1)*0.45)
	b.hp=b.maxHp
	notify("Здание улучшено" if upgrade else "Здание отремонтировано")
	return true

func queue_production(recipe: String, batches = 1) -> bool:
	if player.dead or not catalog.RECIPES.has(recipe) or batches<1 or batches>100 or int(batches)!=batches: return false
	var d = catalog.RECIPES[recipe]
	var b = station(d.station)
	if b.is_empty():
		notify("Подойдите к своей постройке: "+catalog.BUILDING_BY_ID[d.station].name)
		return false
	if b.jobs.size()>=8: return false
	var cost = d.input.duplicate()
	for k in cost: cost[k] = int(cost[k]*batches)
	if not consume(cost): return false
	b.jobs.append({"id":uid("job"),"recipe":recipe,"total":batches,"done":0,"progress":0.0,"paid":cost.duplicate(),"status":"В работе"})
	notify("Производство запущено. Готовая продукция остаётся в мастерской.")
	return true

func cancel_job(b: Dictionary, id: String) -> bool:
	if b.is_empty() or b.get("entity_kind")!="buildings" or b.owner!="player" or b.hp<=0 or distance(b,player)>12: return false
	for job in b.jobs:
		if job.id!=id: continue
		var refund = b.store.duplicate()
		for k in catalog.RECIPES[job.recipe].input:
			var n = int(catalog.RECIPES[job.recipe].input[k]*(job.total-job.done))
			if add_inventory(refund,k,n,[],capacity(b),10000)!=n: job.status="Для возврата освободите мастерскую"; changed.emit(); return false
		b.store = refund
		b.jobs.erase(job)
		changed.emit()
		return true
	return false

func gather(id: String) -> bool:
	var r = entity(id)
	if r.is_empty() or r.get("amount",0)<=0 or distance(r,player)>3.8 or not pending_gather.is_empty() or player.actionUntil>state.time or player.dead or player.sailing or player.staggerUntil>state.time: return false
	var tool = catalog.RESOURCES[r.kind].get("tool")
	if tool!=null and player.tool!=tool:
		notify("Нужен инструмент: "+catalog.TOOLS[tool].name)
		return false
	if player.stamina<5 or player.swimming or player.cartId!="": return false
	if add_inventory(player.inventory.duplicate(),r.kind,1,player.tools)!=1: notify("Рюкзак заполнен"); return false
	if distance(r,player)>1.35: player["gatherApproach"]=id; player.autoBattle=false; return true
	player["gatherApproach"]=""
	player.yaw = atan2(r.x-player.x,r.z-player.z)
	player.actionState = "chop" if tool=="axe" else "mine" if tool=="pickaxe" else "harvest"
	player.actionUntil = state.time+(0.9 if tool!=null else 0.65)
	pending_gather = {"id":id,"left":0.48 if tool!=null else 0.32,"tool":player.tool,"x":player.x,"z":player.z}
	return true

func nearest(radius = 6.0) -> Dictionary:
	var best = {}
	var score = radius
	for e in state.carts+state.drops+state.npcs+nearby_resources(player,radius)+state.buildings+state.ships:
		if e.get("amount",1)<=0 or e.get("hp",1)<=0 or not e.get("alive",true): continue
		var d = distance(e,player)
		if e.entity_kind=="buildings": d = max(0.5,d-min(6,catalog.BUILDING_BY_ID[e.type].size*0.5))
		if e.entity_kind=="ships": d = max(0.5,d-catalog.SHIPS[e.kind].beam)
		if d<score:
			score = d
			best = e
	return best

func label(e: Dictionary) -> String:
	if e.is_empty(): return "Подойдите к объекту"
	match e.entity_kind:
		"resources": return catalog.RESOURCES[e.kind].name
		"buildings": return catalog.BUILDING_BY_ID[e.type].name
		"npcs": return ("Торговец · " if e.role=="merchant" else "")+e.name
		"animals": return catalog.ANIMALS[e.kind].name
		"creatures": return catalog.CREATURES[e.kind].name
		"ships": return catalog.SHIPS[e.kind].name
		"carts": return "Конная повозка" if e.kind=="wagon" else "Тележка"
	return e.get("name","Предмет")

func can_attack(e: Dictionary, source="player") -> bool:
	return combat.can_attack(e,source)

func cycle_target():
	return combat.cycle_target()

func select_target(id: String) -> bool:
	return combat.select_target(id)

func attack(skill_key="") -> bool:
	return combat.attack(skill_key)

func skill(key: String) -> bool:
	return combat.skill(key)

func damage(e: Dictionary, amount: float, source="player", heavy=false, kind="") -> bool:
	return combat.damage(e,amount,source,heavy,kind)

func hurt(amount: float, attacker: Dictionary = {}):
	combat.hurt(amount,attacker)

func respawn():
	combat.respawn()

func make_vehicle(kind: String) -> bool:
	if player.dead or not catalog.VEHICLE_COSTS.has(kind): return false
	if station("workbench").is_empty() and (kind!="wagon" or station("stable").is_empty()):
		notify("Нужна своя мастерская или конюшня")
		return false
	var q = free_point(player,5)
	if q.is_empty() or not consume(catalog.VEHICLE_COSTS[kind]): return false
	var c = {"id":uid(kind),"kind":kind,"x":q.x,"z":q.z,"yaw":player.yaw,"hp":450 if kind=="wagon" else 220,"maxHp":450 if kind=="wagon" else 220,"owner":"player","store":blank(),"followId":"","wheelAngle":0.0,"speed":0.0}
	state.carts.append(c)
	reindex()
	return true

func free_point(q: Dictionary, radius: float) -> Dictionary:
	for j in 32:
		var a = j*TAU/32
		var p = {"x":q.x+sin(a)*radius,"z":q.z+cos(a)*radius}
		if height_at(p.x,p.z)>0.7 and not blocked(p,1.2): return p
	return {}

func toggle_cart(id: String) -> bool:
	var cart=entity(id)
	if cart.is_empty() or cart.get("entity_kind")!="carts" or cart.owner!="player": return false
	if cart.kind=="wagon": return set_vehicle_follow(id,"" if cart.followId!="" else "player")
	if player.dead or player.sailing or cart.hp<=0 or distance(cart,player)>5 or cart.followId!="": return false
	player.cartId="" if player.cartId==id else id
	notify("Тележка оставлена" if player.cartId=="" else "Тележка прицеплена")
	return true

func follow_vehicle(id: String, leader="player") -> bool:
	# Compatibility for old object panels; explicit following has its own API.
	if leader=="player": return toggle_cart(id)
	var cart=entity(id)
	if cart.is_empty(): return false
	return set_vehicle_follow(id,"" if cart.get("followId")==leader else leader)

func set_vehicle_follow(id: String, leader="") -> bool:
	var cart=entity(id)
	var actor=player if leader=="player" else entity(leader)
	if player.dead or cart.is_empty() or cart.get("entity_kind")!="carts" or cart.hp<=0 or cart.owner!="player" or distance(cart,player)>12: return false
	if leader!="" and leader!="player" and (actor.is_empty() or not actor.get("ally",false) or not actor.get("alive",false)): return false
	if player.cartId==id or leader=="player": player.cartId=""
	if leader!="":
		for other in state.carts:
			if other.id!=id and other.followId==leader: other.followId=""; other["driverId"]=""; other.speed=0; other["status"]="Ожидает нового проводника"
	for n in state.npcs:
		if n.get("workCartId")==id: n.workCartId=""
	cart.followId=leader
	cart["driverId"]=leader if leader!="player" else ""
	cart.speed=0
	if leader!="" and leader!="player": actor["workCartId"]=id
	cart["status"]="Следует за проводником" if leader!="" else "Ожидает"
	changed.emit()
	return true

func place_company_project(type: String, q: Dictionary, yaw=0.0) -> Dictionary:
	if player.dead or type not in ["campfire","hut","warehouse","road"] or not state.npcs.any(func(n): return n.ally and n.alive) or state.projects.filter(func(project): return not project.done).size()>=3: return {}
	var site=geometry.snap_placement(type,q,yaw,player.get("buildSnap",true))
	var test=placement(type,site,site.yaw)
	if not test.ok: notify(test.reason); return {}
	if not consume(test.cost,site): return {}
	var project={"id":uid("project"),"type":type,"x":site.x,"z":site.z,"yaw":site.yaw,"height":test.height,"foundationDepth":test.depth,"progress":0.0,"done":false}
	state.projects.append(project)
	command("all","build")
	for n in state.npcs:
		if n.ally and n.alive: n.order["projectId"]=project.id
	return project

func create_company_project(type: String) -> Dictionary:
	if player.dead or type not in ["campfire","hut","warehouse","road"] or not state.npcs.any(func(n): return n.ally and n.alive) or state.projects.filter(func(p): return not p.done).size()>=3: return {}
	for j in 16:
		var angle=player.yaw+j*PI/8
		var site=geometry.snap_placement(type,{"x":player.x+sin(angle)*9,"z":player.z+cos(angle)*9},0,player.get("buildSnap",true))
		var test=placement(type,site,site.yaw)
		if not test.ok or state.projects.any(func(p): return not p.done and distance(p,site)<8): continue
		return place_company_project(type,site,site.yaw)
	notify("Нужны свободная площадка рядом и материалы")
	return {}

func build_ship(kind: String) -> bool:
	var d=catalog.SHIPS.get(kind,{})
	if player.dead or d.is_empty(): return false
	if kind!="rowboat" and station("shipyard",22).is_empty(): notify("Нужна своя верфь в пределах 22 м"); return false
	if not can_afford(d.cost): notify("Не хватает материалов для судна"); return false
	var q={}
	for radius in range(8,55,4):
		for j in 18:
			var angle=j*0.35
			var candidate={"x":player.x+sin(angle)*radius,"z":player.z+cos(angle)*radius}
			if combat.water_clear(candidate.x,candidate.z,d.beam*0.7) and not state.ships.any(func(ship): return ship.hp>0 and distance(ship,candidate)<d.length*0.6+6): q=candidate; break
		if not q.is_empty(): break
	if q.is_empty(): notify("У верфи нет свободной глубокой воды"); return false
	if not consume(d.cost): return false
	state.ships.append({"id":uid("ship"),"kind":kind,"name":d.name+" · ваш","x":q.x,"z":q.z,"yaw":0.0,"speed":0.0,"hp":d.hp,"maxHp":d.hp,"owner":"player","store":blank(),"cooldowns":{"ballista":0.0,"cannon":0.0},"role":"idle","fire":0.0,"hostile":0.0})
	reindex()
	effect.emit("build",point(q))
	notify("Спущено на воду: "+d.name)
	return true

func board(id: String) -> bool:
	var ship=entity(id)
	if player.dead or ship.is_empty() or ship.get("entity_kind")!="ships" or ship.hp<=0 or ship.owner!="player" or ship.get("escortTaskId") or distance(ship,player)>catalog.SHIPS[ship.kind].length*0.55+6: return false
	if player.cartId!="": notify("Отцепите тележку перед посадкой"); return false
	player.shipId=id
	player.swimming=false
	player.sailing=true
	player.autoBattle=false
	player.targetId=""
	player.x=ship.x; player.z=ship.z
	player.y=catalog.SHIPS[ship.kind].deck+0.2
	state.raid={}
	effect.emit("board",point(ship))
	notify("Вы у штурвала: "+ship.name)
	return true

func disembark() -> bool:
	var ship=entity(player.shipId)
	if player.dead or ship.is_empty(): return false
	var radius=catalog.SHIPS[ship.kind].beam*0.6
	while radius<=19:
		for j in 16:
			var angle=j*0.4
			var q={"x":ship.x+sin(angle)*radius,"z":ship.z+cos(angle)*radius}
			if height_at(q.x,q.z)>0.5 and not geometry.blocked(q,0.4):
				player.x=q.x; player.z=q.z; player.y=ground_at(q.x,q.z)
				ship.speed=0
				player.shipId=""; player.sailing=false; player.swimming=false
				notify("Вы сошли на берег")
				return true
		radius+=2
	notify("Для высадки подойдите ближе к берегу")
	return false

func fire_ship(s: Dictionary, weapon: String, target: Dictionary = {}) -> bool:
	return combat.fire_ship(s,weapon,target)

func spawn_projectile(a: Dictionary,b: Dictionary,amount: float,speed: float,kind: String,reach: float,delay=0.0):
	combat.spawn_projectile(a,b,amount,speed,kind,reach,delay)

func start_raid(id: String) -> bool:
	return combat.start_raid(id)

func recruit(id: String, resident=false) -> bool:
	if not resident: return join_companion(id)
	var n=entity(id)
	if player.dead or n.is_empty() or n.get("entity_kind")!="npcs" or not n.alive or n.ally or n.home=="player" or n.role in ["guard","merchant"] or n.get("groupId") or n.get("hostile",0)>0 or player.karma<0 or distance(n,player)>15: return false
	var home={}
	for b in state.buildings:
		if b.owner=="player" and b.type=="warehouse" and b.hp>0: home=b; break
	if home.is_empty() or island_at(n).get("id")!=island_at(home).get("id"): notify("Нужен свой склад на этом острове"); return false
	if beds()<=state.npcs.filter(func(person): return person.home=="player").size(): notify("Сначала постройте жильё"); return false
	if not consume({"food":5},home): return false
	n["formerHome"]=n.home
	n.home="player"
	n.role="worker"
	n.order={"type":"wait"}
	n.goal={}
	n.hostile=0
	notify(n.name+" присоединился к поселению")
	return true

func join_companion(id: String) -> bool:
	var n=entity(id)
	if player.dead or n.is_empty() or n.get("entity_kind")!="npcs" or not n.alive or n.ally or n.role=="merchant" or n.get("hostile",0)>0 or player.karma<0 or distance(n,player)>12: return false
	if state.npcs.filter(func(member): return member.ally).size()>=6: notify("В отряде уже шесть спутников"); return false
	if not consume({"food":3}): return false
	if n.get("groupId"):
		for group in state.groups:
			if group.id==n.groupId: group.members.erase(n.id)
		n.groupId=""
	n.ally=true
	n.order={"type":"follow"}
	n.goal={}
	n.strike={}
	n["companyHit"]={}
	n.hostile=0
	notify(n.name+" вступил в отряд")
	return true

func donate(id: String) -> bool:
	var n=entity(id)
	if player.dead or n.is_empty() or n.get("entity_kind")!="npcs" or not n.alive or n.get("hostile",0)>0 or player.karma<=-50 or distance(n,player)>12 or player.inventory.get("food",0)<2: return false
	player.inventory.food-=2
	player.karma=min(100,player.karma+4)
	n.hp=min(n.get("maxHp",100),n.hp+20)
	notify(n.name+": спасибо за припасы. Карма +4")
	return true

func stop_member_task(n: Dictionary):
	for task in state.tasks:
		if task.get("id")==n.get("taskId") or task.get("npcId")==n.id and task.get("id")==n.order.get("id"):
			if task.has("members"):
				task.members.erase(n.id)
				if not task.members.is_empty(): continue
			if task.get("status") not in ["Готово","Завершено"]: task.status="Отменено"
			var ship=entity(task.get("escortId",""))
			if not ship.is_empty(): ship["escortTaskId"]=""; ship.speed=0
	n["taskId"]=""
	n["taskUnits"]=0
	n["taskCargoId"]=""
	n["taskReport"]={}

func dismiss_companion(id: String) -> bool:
	var n=entity(id)
	if player.dead or n.is_empty() or not n.get("ally",false): return false
	stop_member_task(n)
	n.ally=false
	n.order={"type":"wait"}
	n.goal={}
	n.strike={}
	n["companyHit"]={}
	n.state="return"
	for c in state.carts:
		if c.owner=="player" and c.followId==id: c.followId=""; c["driverId"]=""; c.speed=0
	n["workCartId"]=""
	notify(n.name+" покинул отряд")
	return true

func dismiss(id: String) -> bool:
	return dismiss_companion(id)

func cancel_task(id: String) -> bool:
	if player.dead: return false
	for task in state.tasks:
		if task.id!=id or task.get("status") in ["Отменено","Завершено","Готово"]: continue
		for n in state.npcs:
			if n.get("taskId")==id or n.order.get("id")==id:
				stop_member_task(n)
				n.order={"type":"follow"}
				n.goal={}
		task.status="Отменено"
		var ship=entity(task.get("escortId",""))
		if not ship.is_empty(): ship["escortTaskId"]=""; ship.speed=0
		notify("Поручение отменено. Груз остался у перевозчика")
		return true
	return false

func settlement_summary() -> Dictionary:
	return economy.settlement_summary()

func beds() -> int:
	var total=0
	var bmap={"tent":1,"hut":3,"longhouse":8,"townhall":4,"farmstead":3,"barracks":8,"inn":10}
	for b in state.buildings:
		if b.owner=="player" and b.hp>0: total+=bmap.get(b.type,0)*b.level
	return total

func residents() -> int:
	return state.npcs.filter(func(n): return n.alive and n.home=="player").size()

func command(id: String, type: String, resource="wood", quantity=0, destination="", source="") -> bool:
	if player.dead or not catalog.ORDERS.has(type): return false
	var members=state.npcs.filter(func(n): return n.ally and n.alive and (id=="all" or n.id==id))
	if members.is_empty(): notify("Сначала пригласите рабочих в отряд"); return false
	if type=="gather" and (not catalog.RESOURCES.has(resource) or quantity<0 or quantity>10000): return false
	if type=="attack":
		var target=entity(player.targetId)
		if target.is_empty() or target.get("entity_kind") not in ["npcs","animals","creatures"] or not can_attack(target) or distance(target,player)>65: notify("Выберите доступную цель рядом"); return false
	if type=="build" and state.projects.filter(func(p): return not p.done).is_empty(): notify("Сначала разместите проект отряда"); return false
	if type in ["deliver","escort"]:
		return not new_company_task(id,type,resource,quantity,destination,source,destination if type=="escort" else "").is_empty()
	for n in members:
		stop_member_task(n)
		var task={"id":uid("task"),"npcId":n.id,"type":type,"resource":resource,"quantity":quantity,"done":0,"destination":destination,"source":source,"targetId":player.targetId,"x":n.x if type=="wait" else player.x,"z":n.z if type=="wait" else player.z,"status":"В работе","reason":"","paid":0,"carried":0}
		if type=="build":
			for project in state.projects:
				if not project.done: task["projectId"]=project.id; break
		n.order=task
		n.goal={}
		n.strike={}
		n["companyHit"]={}
	notify("Отряд: "+catalog.ORDERS[type])
	return true

func new_company_task(id: String, type: String, resource: String, quantity, destination: String, source="", ship_id="") -> Dictionary:
	if player.dead or type not in ["gather","deliver","guard","escort"] or not catalog.RESOURCES.has(resource): return {}
	var members=state.npcs.filter(func(n): return n.ally and n.alive and (id=="all" or n.id==id))
	if members.is_empty(): return {}
	var dest=container(destination)
	var origin=container(source)
	if type in ["gather","deliver"]:
		if not catalog.RESOURCES.has(resource) or quantity<1 or quantity>10000 or int(quantity)!=quantity or dest.is_empty() or destination=="bag" or dest.owner!="player": return {}
		if type=="gather" and catalog.RESOURCES[resource].get("processed",false): return {}
	if type=="deliver" and (origin.is_empty() or source=="bag" or origin.owner!="player" or source==destination): return {}
	if type=="guard" and (dest.is_empty() or dest.owner!="player" or dest.get("entity_kind")!="buildings" or dest.type not in ["warehouse","granary"]): return {}
	var ship=entity(ship_id if ship_id!="" else destination)
	var escort={}
	if type=="escort":
		if ship.is_empty() or ship.get("entity_kind")!="ships" or ship.hp<=0 or ship.owner!="player": return {}
		var free=state.ships.filter(func(s): return s.hp>0 and s.owner=="player" and s.id!=ship.id and s.id!=player.shipId and not s.get("escortTaskId"))
		free.sort_custom(func(a,b): return distance(a,members[0])<distance(b,members[0]))
		if free.is_empty(): notify("Нужно свободное собственное судно для эскорта"); return {}
		escort=free[0]
	if not consume({"food":members.size()}): notify("Нужна 1 пища на каждого участника поручения"); return {}
	var task={"id":uid("task"),"type":type,"resource":resource,"key":resource,"quantity":0 if type in ["guard","escort"] else quantity,"total":0 if type in ["guard","escort"] else quantity,"done":0,"destination":destination,"destId":destination,"source":source,"sourceId":source,"shipId":ship.get("id","") if type=="escort" else "","escortId":escort.get("id",""),"members":[],"cost":{"food":members.size()},"status":"В работе","reason":"","x":player.x,"z":player.z,"created":state.time,"carried":0,"shared":true}
	for n in members:
		stop_member_task(n)
		task.members.append(n.id)
		n.taskId=task.id
		n.taskUnits=0
		n.order={"type":type}
		n.goal={}
		n.strike={}
		n["companyHit"]={}
		n["returning"]=false
	state.tasks.append(task)
	if not escort.is_empty(): escort["escortTaskId"]=task.id
	notify("Поручение: "+catalog.ORDERS[type])
	return task

func cargo_range(c: Dictionary) -> float:
	if c.get("id")=="bag": return 0
	if c.get("entity_kind")=="ships": return catalog.SHIPS[c.kind].length*0.55+6
	return 10 if c.get("entity_kind")=="buildings" else 5

func market_depot(island: String) -> Dictionary:
	for building in state.buildings:
		if building.hp>0 and building.owner==island and building.type=="warehouse": return building
	return {}

func nearest_market() -> Dictionary:
	var best={}
	var nearest=INF
	for settlement in state.settlements:
		var port=ai.port_point(settlement.id)
		var d=distance(player,settlement)
		var sea=distance(player,port)
		if (d<18 or sea<32) and min(d,sea)<nearest: best=settlement; nearest=min(d,sea)
	if best.is_empty():
		for building in state.buildings:
			if building.owner=="player" and building.type=="market" and building.hp>0 and distance(building,player)<15:
				for settlement in state.settlements:
					if settlement.id==island_at(building).get("id"): best=settlement; break
	if not best.is_empty():
		var depot=market_depot(best.id)
		if not depot.is_empty(): best.store=depot.store
	return best

func barter_quote(island: String, key: String, count=5) -> Dictionary:
	var economy=catalog.ISLAND_ECONOMY.get(island,{})
	if economy.is_empty() or key not in economy.imports or count<1 or count>1000 or int(count)!=count: return {}
	for settlement in state.settlements:
		if settlement.id!=island: continue
		var depot=market_depot(island)
		if depot.is_empty(): return {}
		var demand=clamp((90.0-depot.store.get(key,0))/60.0,0.65,1.5)
		var reward=max(1,int(floor(count*BARTER_VALUE[key]/BARTER_VALUE[economy.export]*demand)))
		return {"key":key,"count":count,"export":economy.export,"reward":reward,"demand":demand,"available":depot.store.get(economy.export,0)>=reward}
	return {}

func barter(island: String, key: String, count=5, source_id="bag") -> bool:
	var market=nearest_market()
	if player.dead or player.karma<=-50 or market.is_empty() or market.id!=island: return false
	var quote_data=barter_quote(island,key,count)
	if quote_data.is_empty() or not quote_data.available: return false
	var cargo=container(source_id if source_id!="" else "bag")
	if cargo.is_empty() or cargo.owner!="player" or distance(cargo,player)>cargo_range(cargo) or cargo.store.get(key,0)<count: return false
	var depot=market_depot(island)
	if depot.is_empty(): return false
	var next=cargo.store.duplicate()
	var stock=depot.store.duplicate()
	next[key]-=count
	stock[quote_data.export]-=quote_data.reward
	if add_inventory(next,quote_data.export,quote_data.reward,player.tools if cargo.id=="bag" else [],capacity(cargo),24 if cargo.id=="bag" else 10000)!=quote_data.reward: return false
	if add_inventory(stock,key,count,[],capacity(depot),10000)!=count: return false
	cargo.store.merge(next,true)
	depot.store.merge(stock,true)
	market.store=depot.store
	state.civic.tradeUnits+=count
	state.civic.tradeReputation+=int(ceil(count/5.0))
	notify("Обмен: %d %s → %d %s" % [count,catalog.RESOURCES[key].name,quote_data.reward,catalog.RESOURCES[quote_data.export].name])
	return true

func quote(n: Dictionary,key: String,count: int,buy=true) -> int:
	if not catalog.RESOURCE_PRICES.has(key) or count<1 or count>100: return 0
	var base=catalog.RESOURCE_PRICES[key]
	var stock=n.marketStock.get(key,0)
	var home=catalog.ISLAND_ECONOMY.get(n.get("originHome",n.home),{})
	var target=45.0 if home.get("export")==key else 20.0
	var total=0
	for i in count:
		var demand=clamp(1+(target-stock+(i if buy else -i))/(target*1.5)+clamp(n.marketPressure.get(key,0)+(i if buy else -i),-30,30)*0.018,0.55,2.1)
		total+=max(1,ceil(base*demand*1.15) if buy else floor(base*demand*0.76))
	return total

func trade(id: String,key: String,count: int,buy=true) -> bool:
	var n=entity(id)
	if player.dead or n.is_empty() or n.get("role")!="merchant" or not n.alive or player.karma<=-50 or n.get("hostile",0)>0 or distance(n,player)>12 or count<1 or count>100: return false
	var price=quote(n,key,count,buy)
	if price<=0: return false
	var bag=player.inventory.duplicate()
	var stock=n.marketStock.duplicate()
	if buy:
		if stock.get(key,0)<count or player.coins<price or add_inventory(bag,key,count,player.tools)!=count: notify("Не хватает монет, товара или места"); return false
		stock[key]-=count
	else:
		if bag.get(key,0)<count or n.coins<price or add_inventory(stock,key,count,[],650,10000)!=count: return false
		bag[key]-=count
	player.inventory=bag
	n.marketStock=stock
	player.coins+= -price if buy else price
	n.coins+=price if buy else -price
	n.marketPressure[key]=clamp(n.marketPressure.get(key,0)+(count if buy else -count),-30,30)
	state.civic.tradeUnits+=count
	notify(("Куплено" if buy else "Продано")+": %d × %s · %d монет" % [count,catalog.RESOURCES[key].name,price])
	return true

func step(dt: float, input: Dictionary):
	if not ready_for_play: return
	dt=min(dt,0.1)
	state.time+=dt
	player.invulnerable=max(0,player.invulnerable-dt)
	player["attackAnim"]=max(0,player.get("attackAnim",0)-dt)
	if not player.dead:
		player.hunger=max(0,player.hunger-dt*0.025)
		if player.hunger<=0: hurt(dt*0.8)
	state["day"]=1+int(state.time/1200.0)
	var old_drops=state.drops.size()
	state.drops=state.drops.filter(func(drop): return drop.get("expires",INF)>state.time)
	if state.drops.size()!=old_drops: reindex()
	input=_prepare_gather_input(input)
	input=combat.prepare_input(dt,input)
	_move_player(dt,input)
	_resolve_actions(dt)
	ai.update_vehicles(dt)
	clock+=dt
	if clock>=0.2:
		ai.step(clock)
		clock=0.0
	_update_production(dt)
	economy.step(dt)
	_retry_starter_wagon(dt)
	autosave_clock+=dt
	if autosave_clock>=20:
		if autosave_enabled: save_game(false)
		autosave_clock=0

func _retry_starter_wagon(dt: float):
	if state.get("starterWagonGranted",true): return
	starter_wagon_retry-=dt
	if starter_wagon_retry>0.0: return
	starter_wagon_retry=2.0
	var migration=preload("res://scripts/save_migration.gd").new()
	migration.catalog=catalog
	migration.identities=entities.duplicate()
	migration.objects=entities.duplicate()
	if migration.ensure_starter_wagon(state):
		reindex()
		notify("Ваша повозка ждёт рядом: грузоподъёмность 900 кг")

func _prepare_gather_input(input: Dictionary) -> Dictionary:
	if not player.get("gatherApproach"): return input
	var resource=entity(player.gatherApproach)
	var movement: Vector2=input.get("move",Vector2.ZERO)
	if resource.is_empty() or resource.get("amount",0)<=0 or movement.length()>0.1 or distance(player,resource)>6 or player.dead:
		player.gatherApproach=""
		return input
	if distance(player,resource)<=1.35: gather(resource.id); return input
	var result=input.duplicate()
	result.move=Vector2(resource.x-player.x,resource.z-player.z).normalized()*0.7
	result.mode="jog"
	result.jump=false
	return result

func _move_player(dt: float,input: Dictionary):
	var effective_mode=input.get("mode",player.mode)
	if not pending_gather.is_empty() or not strikes.is_empty(): effective_mode="jog"; input=input.duplicate(); input.jump=false
	if player.dead: player.speed=0; return
	var direction: Vector2=input.get("move",Vector2.ZERO)
	var ship=entity(player.shipId)
	if not ship.is_empty():
		var d=catalog.SHIPS[ship.kind]
		combat.move_ship(ship,atan2(direction.x,direction.y) if direction.length()>0.08 else ship.yaw,1.0 if direction.length()>0.08 else 0.0,dt)
		player.x=ship.x; player.z=ship.z; player.yaw=ship.yaw
		player.y=d.deck+0.2; player.speed=ship.speed; player.actionState="idle"
		return
	var moving=direction.length()>0.1
	player.swimming=not player.sailing and height_at(player.x,player.z)< -1.05
	var desired=atan2(direction.x,direction.y)
	if player.sailing:
		if moving:
			player.yaw=lerp_angle(player.yaw,desired,1-exp(-dt*15))
			var vector=direction.limit_length()*15*dt
			var q={"x":player.x+vector.x,"z":player.z+vector.y}
			if not blocked(q,0.32,"",true) and height_at(q.x,q.z)-height_at(player.x,player.z)<1.8: player.x=q.x; player.z=q.z
			if height_at(player.x,player.z)>4: player.sailing=false; notify("Высадка на берег")
		player.stamina=min(100,player.stamina+dt*(5 if moving else 13))
		player.y=max(ground_at(player.x,player.z),0.42)
		player.speed=15.0*min(1,direction.length()) if moving else 0.0
		player.actionState="idle"
		return
	var speed=5.6
	if effective_mode=="walk": speed=4.5
	elif effective_mode=="sprint" and player.stamina>1: speed=7.7
	if player.swimming: speed=3.5 if effective_mode=="sprint" and player.stamina>5 else 2.35
	var cart=entity(player.cartId)
	if not cart.is_empty(): speed=4.5 if weight(cart.store)>0 else speed
	if not player.swimming: speed*=geometry.road_bonus(player)
	if not pending_gather.is_empty() or not strikes.is_empty(): speed*=0.18
	speed*=min(1,direction.length())
	if player.staggerUntil>state.time: speed=0
	if moving:
		if player.actionUntil<=state.time or not cart.is_empty(): player.yaw=lerp_angle(player.yaw,desired,1-exp(-dt*15))
		var q={"x":player.x+sin(desired)*speed*dt,"z":player.z+cos(desired)*speed*dt}
		if not blocked(q,0.3,"",true): player.x=q.x; player.z=q.z
		else:
			q={"x":player.x+sin(desired)*speed*dt,"z":player.z}
			if not blocked(q,0.3,"",true): player.x=q.x
			q={"x":player.x,"z":player.z+cos(desired)*speed*dt}
			if not blocked(q,0.3,"",true): player.z=q.z
		if effective_mode=="sprint" and cart.is_empty(): player.stamina=max(0,player.stamina-dt*13)
		else: player.stamina=min(100,player.stamina+dt*(1 if player.swimming else 5))
	else: player.stamina=min(100,player.stamina+dt*13)
	player.speed=speed if moving else 0.0
	if input.get("jump",false) and player.jump<=0 and not player.swimming and cart.is_empty(): player.vy=6.0; player.jump=0.01
	if player.jump>0:
		player.vy-=15*dt
		player.jump=max(0,player.jump+player.vy*dt)
	player.y=(-1.0 if player.swimming else ground_at(player.x,player.z))+player.jump
	if player.actionUntil<=state.time:
		player.actionState="swim" if player.swimming and moving else "swimIdle" if player.swimming else "pullCart" if moving and not cart.is_empty() else "sprint" if moving and speed>6 else "run" if moving and speed>3 else "walk" if moving else "idle"

func _resolve_actions(dt: float):
	if not pending_gather.is_empty():
		pending_gather.left-=dt
		if pending_gather.left<=0:
			var r=entity(pending_gather.id)
			if not player.dead and not r.is_empty() and distance(r,player)<=3.8 and distance(player,pending_gather)<1.1 and player.tool==pending_gather.tool and player.staggerUntil<=state.time and r.amount>0:
				var got=add_inventory(player.inventory,r.kind,int(min(2 if r.kind in ["food","fiber"] else 3,r.amount)),player.tools)
				r.amount-=got
				if r.amount<=0: r.respawn=state.time+240
				player.stamina-=5
				state.stats.gathered+=got
				effect.emit("chop" if r.kind=="wood" else "stone" if r.kind in ["stone","coal","ore","clay"] else "loot",point(r,0.8))
				if got==0: notify("Рюкзак заполнен")
				changed.emit()
			pending_gather={}
	combat.resolve(dt)

func _update_production(dt: float):
	for b in state.buildings:
		if b.hp<=0 or b.jobs.is_empty(): continue
		var j=b.jobs[0]
		var r=catalog.RECIPES[j.recipe]
		var trial=b.store.duplicate()
		var fits=true
		for k in r.output:
			if add_inventory(trial,k,int(r.output[k]),[],capacity(b),10000)!=r.output[k]: fits=false
		if not fits: j.status="Выход заполнен"; continue
		j.status="В работе"
		j.progress+=dt
		if j.progress>=r.seconds:
			b.store=trial
			j.progress=0
			j.done+=1
			if j.done>=j.total: b.jobs.pop_front()
			changed.emit()

func export_json() -> String:
	var snapshot=state.duplicate(true)
	snapshot["native_version"]=VERSION
	snapshot["demo"]=demo
	snapshot["quality"]=quality
	snapshot["company"]=snapshot.get("company",{})
	for key in ["tasks","projects","groups"]: snapshot.company[key]=snapshot.get(key,[])
	return JSON.stringify(snapshot,"\t")

func valid_inventory(value) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if not catalog.RESOURCES.has(key) or not value[key] is float and not value[key] is int or not is_finite(float(value[key])) or value[key]<0 or value[key]>100000000: return false
	return true

func decode_save(text: String) -> Dictionary:
	return preload("res://scripts/save_migration.gd").new().decode(text,catalog,JSON.parse_string(FileAccess.get_file_as_string("res://data/initial_world.json")))

func valid_save(value) -> bool:
	return decode_save(JSON.stringify(value)).ok

func import_json(text: String) -> bool:
	var result=decode_save(text)
	if not result.ok: notify("Не удалось импортировать: "+result.error+". Мир не изменён"); return false
	var loaded=result.state
	var prior_backup_exists=FileAccess.file_exists(SAVE+".bak")
	var prior_backup=FileAccess.get_file_as_bytes(SAVE+".bak") if prior_backup_exists else PackedByteArray()
	# Back up the current in-memory world, including changes not manually saved.
	var backup=FileAccess.open(SAVE+".bak.tmp",FileAccess.WRITE)
	if backup==null: notify("Не удалось создать резервную копию. Мир не изменён"); return false
	backup.store_string(export_json()); backup.close()
	if DirAccess.rename_absolute(SAVE+".bak.tmp",SAVE+".bak")!=OK: notify("Не удалось создать резервную копию. Мир не изменён"); return false
	var previous=state
	var previous_demo=demo
	var previous_quality=quality
	state=loaded
	demo=bool(state.get("demo",false))
	quality=str(state.get("quality","iphone"))
	_normalize()
	if not save_game(false,false):
		if prior_backup_exists:
			var restore=FileAccess.open(SAVE+".bak",FileAccess.WRITE)
			if restore!=null: restore.store_buffer(prior_backup); restore.close()
		else: DirAccess.remove_absolute(SAVE+".bak")
		state=previous; demo=previous_demo; quality=previous_quality; _normalize()
		notify("Не удалось записать импортированное сохранение")
		return false
	autosave_enabled=true
	world_reloaded.emit()
	notify("Сохранение импортировано")
	return true

func save_game(announce=true,backup_previous=true) -> bool:
	state["native_version"]=VERSION
	state["demo"]=demo
	state["quality"]=quality
	var file=FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if file==null:
		if announce: notify("Не удалось записать сохранение")
		return false
	file.store_string(JSON.stringify(state))
	file.close()
	var check=JSON.parse_string(FileAccess.get_file_as_string(SAVE+".tmp"))
	if not check is Dictionary or not check.has("player"): return false
	if backup_previous and FileAccess.file_exists(SAVE): DirAccess.copy_absolute(SAVE,SAVE+".bak")
	var err=DirAccess.rename_absolute(SAVE+".tmp",SAVE)
	if announce: notify("Игра сохранена" if err==OK else "Ошибка сохранения")
	return err==OK

func load_game() -> bool:
	var result=decode_save(FileAccess.get_file_as_string(SAVE)) if FileAccess.file_exists(SAVE) else {"ok":false}
	if not result.ok:
		result=decode_save(FileAccess.get_file_as_string(SAVE+".bak")) if FileAccess.file_exists(SAVE+".bak") else {"ok":false}
	if not result.ok:
		notify("Нет исправного сохранения. Импортируйте файл игры через меню")
		return false
	state=result.state
	autosave_enabled=true
	demo=state.get("demo",false)
	quality=state.get("quality","iphone")
	_normalize()
	ai.rebuild_grid()
	world_reloaded.emit()
	notify("Сохранение загружено")
	return true

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST] and ready_for_play and autosave_enabled: save_game(false)

func _exit_tree():
	if ready_for_play and autosave_enabled: save_game(false)
	if ai!=null:
		ai.g=null
		ai=null
	if combat!=null: combat.g=null; combat=null
	if geometry!=null: geometry.g=null; geometry=null
	if economy!=null: economy.g=null; economy=null
