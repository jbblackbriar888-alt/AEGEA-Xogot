extends RefCounted
## Pure JSON boundary. No nodes, filesystem writes, eval, or mutation of the live world.
## Browser Game.save serializes company state and uses countdown combat timers;
## the native simulation uses top-level company arrays and deadline timers.
const MAX_BYTES = 5 * 1024 * 1024
const BROWSER_VERSIONS = ["3.0.0","3.1.0","4.0.0","5.0.0","5.0.1","5.1.0","5.2.0","5.3.0","5.3.1","5.4.0","5.5.0","5.6.0"]
const NATIVE_VERSIONS = ["0.1.0","0.2.0","0.3.0"]
const CATEGORIES = ["resources","buildings","npcs","animals","creatures","ships","carts","drops","seaLife","settlements"]
const CAPS = {"resources":12000,"buildings":2000,"npcs":500,"animals":1000,"creatures":200,"ships":150,"carts":100,"drops":2000,"seaLife":1000,"settlements":32}
const POINT_KEYS = ["origin","respawn","target","construction","lastTrack","order","marketAnchor","vehicleOrder","point","building"]
const NUMERIC_KEYS = ["x","y","z","yaw","hp","maxHp","stamina","hunger","karma","coins","kills","time","sequence","amount","max","level","timer","hostile","attackCooldown","actionCooldown","invulnerable","attackAnim","actionDuration","actionImpact","actionSequence","staggerUntil","guardUntil","guardStarted","dodgeUntil","actionUntil","cooldown","speed","jump","vy","combo","lastStrike","fire","fireTick","shot","gunYaw","wheelAngle","travel","capacity","foundationY","foundationDepth","height","depth","scale","size","phaseTime","wait","waypoint","expires","progress","total","quantity","taskUnits","carried","created","clock","formationClock","economyClock","tradeUnits","tradeReputation","plan","built","poise","poiseReset","blockCooldown","blockUntil","hitUntil","reactionUntil","hitAt","deathAt","sunkAt","respawnAt","raidOpenUntil","raidCooldown","angle","along","left","reach","damage","range","cartEffort","cartLoad","detourSign","pathBlocked","born","productionClock","workshopClock","buildTimer","defenseClock","routeRefresh","hitSequence","hitFlash","dodgeAim","blocked","lastProduced"]
const BOOL_KEYS = ["sailing","dead","autoBattle","swimming","buildSnap","alive","ally","open","starter","starterWagonGranted","foodShortage","pvp","demo","returning","deliveringCart","autonomous","shared","cancelled","sunk"]
var catalog: Dictionary
var base: Dictionary
var error = ""
var warnings: Array = []
var identities: Dictionary = {}
var objects: Dictionary = {}
var nodes = 0
var browser = false
var source_version = ""
var random_seed = 0

func decode(text: String, definitions: Dictionary, initial_template: Dictionary = {}) -> Dictionary:
	catalog = definitions
	base = initial_template
	error = ""
	warnings = []
	identities = {}
	objects = {}
	nodes = 0
	if text.to_utf8_buffer().size() > MAX_BYTES: return _failed("Файл больше 5 МиБ")
	if not _depth_safe(text): return _failed("Слишком глубокая структура JSON")
	var parser = JSON.new()
	if parser.parse(text) != OK: return _failed("Некорректный JSON: строка %d" % parser.get_error_line())
	if not parser.data is Dictionary: return _failed("В корне сохранения должен быть объект")
	var s: Dictionary = parser.data
	if not _tree(s, "save", 0): return _failed(error)
	browser = not s.has("native_version")
	source_version = s.get("version", "") if browser else s.get("native_version", "")
	if not source_version is String or source_version not in (BROWSER_VERSIONS if browser else NATIVE_VERSIONS): return _failed("Неподдерживаемая версия сохранения")
	if not s.get("player") is Dictionary or not s.get("buildings") is Array: return _failed("Отсутствует герой или список построек")
	for key in ["seed","time","sequence"]:
		if not _number(s.get(key),0,1000000000,key): return _failed(error)
	if floor(s.seed) != s.seed or floor(s.sequence) != s.sequence: return _failed("Seed и sequence должны быть целыми")
	if s.has("worldScale") and not _number(s.worldScale,1,catalog.WORLD_SCALE,"worldScale"): return _failed(error)
	if not _dict_field(s,"company",{}) or not _dict_field(s,"stats",{}) or not _dict_field(s,"civic",{}): return _failed(error)
	for key in ["tasks","projects","groups"]:
		if s.company.has(key) and not s.company[key] is Array: return _failed("company."+key+": нужен список")
		if s.has(key) and not s[key] is Array: return _failed(key+": нужен список")
		if browser: s[key] = s.company.get(key, []).duplicate(true)
		elif not s.has(key): s[key] = s.company.get(key, []).duplicate(true)
	for category in CATEGORIES:
		if s.has(category) and (not s[category] is Array or s[category].size()>CAPS[category]): return _failed(category+": некорректный список")
		if not s.has(category):
			if category in ["resources","npcs","animals","drops","settlements"]: return _failed("Отсутствует "+category)
			s[category] = []
	if browser and source_version in ["3.0.0","3.1.0"]:
		if not _legacy(s): return _failed(error)
	elif browser:
		var previous: float = catalog.WORLD_SCALE
		if source_version in ["4.0.0","5.0.0","5.0.1"]: previous = catalog.PREVIOUS_WORLD_SCALE
		elif source_version in ["5.1.0","5.2.0","5.3.0","5.3.1"]: previous = sqrt(10.0)
		# Match world-migration.js: modern versions are already full-scale.
		if previous != catalog.WORLD_SCALE:
			_scale_world(s,catalog.WORLD_SCALE / float(s.get("worldScale",previous)))
			warnings.append("Координаты старого мира перенесены в масштаб 5.6")
	if browser and source_version in ["3.0.0","3.1.0","4.0.0","5.0.0","5.0.1"]:
		for r in s.resources:
			if not r is Dictionary: return _failed("resources: нужен объект")
			if r.get("kind")=="ore" and r.get("island")!="keos" or r.get("kind")=="coal" and r.get("island")!="thera": r.kind="stone"
	if browser: _add_new_populations(s)
	if not _player(s.player,s.time): return _failed(error)
	for category in CATEGORIES:
		for e in s[category]:
			if not _entity(e,category,s.time): return _failed(error)
	if not _company(s): return _failed(error)
	if not _references(s): return _failed(error)
	if browser: _ensure_merchants(s)
	if not _dict_field(s,"economyTimers",{}): return _failed(error)
	if browser:
		for pair in [["production","productionClock"],["food","economyClock"],["workshop","workshopClock"]]: s.economyTimers[pair[0]]=s.get(pair[1],0)
		s.economyTimers.merchant=s.company.get("clock",0)
		s.economyTimers.formation=s.company.get("formationClock",0)
	for key in s.economyTimers:
		if not _number(s.economyTimers[key],0,1000000000,"economyTimers."+key): return _failed(error)
	for key in s.stats:
		if not _number(s.stats[key],0,1000000000,"stats."+key): return _failed(error)
	for key in ["gathered","built","kills","npcBuilt"]:
		if not _default_number(s.stats,key,0,0,1000000000): return _failed(error)
	for key in ["tradeUnits","tradeReputation"]:
		if not _default_number(s.civic,key,0,0,1000000000): return _failed(error)
	if not _default_bool(s.civic,"foodShortage",false) or not _default_bool(s,"pvp",false): return _failed(error)
	if not _default_bool(s,"demo",false) or not _default_bool(s,"starterWagonGranted",false): return _failed(error)
	if browser: ensure_starter_wagon(s)
	if not _default_number(s,"economyClock",0,0,1000000000): return _failed(error)
	if not _default_number(s.company,"clock",0,0,1000000000) or not _default_number(s.company,"formationClock",0,0,1000000000): return _failed(error)
	if s.has("homeHarbor") and not _point(s.homeHarbor,"homeHarbor"): return _failed(error)
	if not s.has("homeHarbor"): s.homeHarbor=base.get("homeHarbor",{"x":0,"z":0}).duplicate(true)
	if s.get("quality","iphone") not in ["iphone","mac","balanced","desktop","low","medium","high","auto"]: return _failed("Неизвестное качество графики")
	s.quality=s.get("quality","iphone")
	# Sequence must exceed all restored identities, including task and job IDs.
	for id in identities:
		var suffix: String = str(id).get_slice("-",str(id).get_slice_count("-")-1)
		if suffix.is_valid_int(): s.sequence=max(s.sequence,int(suffix)+1)
	s.worldScale=catalog.WORLD_SCALE
	s.version=catalog.VERSION
	s.native_version="0.3.0"
	s["migration_source"]=("browser:" if browser else "native:")+source_version
	# One authoritative collection, shared aliases within the decoded candidate.
	for key in ["tasks","projects","groups"]: s.company[key]=s[key]
	return {"ok":true,"state":s,"error":"","source":s.migration_source,"warnings":warnings}

func _failed(reason: String) -> Dictionary:
	return {"ok":false,"state":{},"error":reason,"source":"","warnings":warnings}

func _bad(reason: String) -> bool:
	error=reason
	return false

func _depth_safe(text: String) -> bool:
	var depth=0
	var quoted=false
	var escaped=false
	for i in text.length():
		var c=text.unicode_at(i)
		if quoted:
			if escaped: escaped=false
			elif c==92: escaped=true
			elif c==34: quoted=false
		elif c==34: quoted=true
		elif c==91 or c==123:
			depth+=1
			if depth>32: return false
		elif c==93 or c==125: depth-=1
	return true

func _tree(v, path: String, depth: int) -> bool:
	nodes+=1
	if depth>32 or nodes>350000: return _bad(path+": превышен предел структуры")
	if v is Dictionary:
		if v.size()>512: return _bad(path+": слишком много полей")
		for k in v:
			if not k is String or k.length()>128: return _bad(path+": некорректное имя поля")
			if (k in NUMERIC_KEYS or k.ends_with("Until") or k.ends_with("Clock") or k.ends_with("Cooldown") or k.ends_with("Sequence")) and not _number(v[k],-1000000000000,1000000000000,path+"."+k): return false
			if k in BOOL_KEYS and not v[k] is bool: return _bad(path+"."+k+": нужно логическое значение")
			if not _tree(v[k],path+"."+k,depth+1): return false
	elif v is Array:
		if v.size()>15000: return _bad(path+": слишком длинный список")
		for item in v:
			if not _tree(item,path+"[]",depth+1): return false
	elif v is String:
		if v.length()>8192: return _bad(path+": слишком длинная строка")
	elif v is float or v is int:
		if not is_finite(float(v)) or abs(float(v))>1000000000000: return _bad(path+": число вне допустимого диапазона")
	elif v!=null and not v is bool: return _bad(path+": запрещённый тип")
	return true

func _number(v, low: float, high: float, path: String) -> bool:
	if not (v is float or v is int) or not is_finite(float(v)) or v<low or v>high: return _bad(path+": некорректное число")
	return true

func _default_number(d: Dictionary,key: String,fallback,low: float=-1000000000,high: float=1000000000) -> bool:
	if not d.has(key): d[key]=fallback
	return _number(d[key],low,high,key)

func _default_bool(d: Dictionary,key: String,fallback: bool) -> bool:
	if not d.has(key): d[key]=fallback
	return true if d[key] is bool else _bad(key+": нужно логическое значение")

func _dict_field(d: Dictionary,key: String,fallback: Dictionary) -> bool:
	if not d.has(key): d[key]=fallback.duplicate(true)
	return true if d[key] is Dictionary else _bad(key+": нужен объект")

func _string(d: Dictionary,key: String,fallback: String="", nullable: bool=false) -> bool:
	if not d.has(key) or nullable and d[key]==null: d[key]=fallback
	if not d[key] is String or d[key].length()>512: return _bad(key+": нужна строка")
	return true

func _point(v,path: String) -> bool:
	if not v is Dictionary: return _bad(path+": нужна точка")
	return _number(v.get("x"),-catalog.LIMITS.world-100,catalog.LIMITS.world+100,path+".x") and _number(v.get("z"),-catalog.LIMITS.world-100,catalog.LIMITS.world+100,path+".z")

func _inventory(v,path: String,capacity: float=100000000,tools: Array=[],slots: int=1000000,preserve_overflow: bool=false) -> bool:
	if not v is Dictionary: return _bad(path+": нужен список ресурсов")
	var weight=0.0
	var used_slots=tools.size()
	for k in v:
		if not catalog.RESOURCES.has(k) or not _number(v[k],0,100000000,path+"."+k): return _bad(path+": неизвестный ресурс или количество")
		if floor(v[k])!=v[k]: return _bad(path+": количество должно быть целым")
		weight+=v[k]*catalog.RESOURCES[k].weight
		used_slots+=int(ceil(v[k]/25.0))
	for k in tools: weight+=catalog.TOOLS[k].get("weight",0)
	if weight>capacity+0.01 or used_slots>slots:
		if not preserve_overflow: return _bad(path+": превышена вместимость")
		var warning=path+": сохранён существующий сверхнормативный груз; новые поступления ограничены вместимостью"
		if warning not in warnings: warnings.append(warning)
	for k in catalog.RESOURCES:
		if not v.has(k): v[k]=0
	return true

func _stored_inventory(v,path: String,capacity: float) -> bool:
	# Browser Game.load/restoreCompany sanitize each resource but do not reject
	# total cargo weight or slots. Preserve existing goods, including in subsequent
	# native roundtrips; add_inventory still enforces capacity for every new input.
	# Numeric, integer, key and global JSON-size limits remain identical.
	return _inventory(v,path,capacity,[],1000000,true)

func _tools(v,path: String,gear_only: bool=false) -> bool:
	if not v is Array or v.size()>64: return _bad(path+": нужен список снаряжения")
	var seen={}
	for k in v:
		if not k is String or not (catalog.GEAR if gear_only else catalog.TOOLS).has(k) or seen.has(k): return _bad(path+": неизвестное или повторное снаряжение")
		seen[k]=true
	return true

func _identity(d: Dictionary,category: String,allow_alias: bool=false) -> bool:
	if not d.get("id") is String or d.id.is_empty() or d.id.length()>128 or d.id in ["player","bag","all"]: return _bad(category+": некорректный идентификатор")
	if identities.has(d.id) and not allow_alias: return _bad("Повторный идентификатор: "+d.id)
	identities[d.id]=category
	if category in CATEGORIES: objects[d.id]=d
	return true

func _player(p: Dictionary,time: float) -> bool:
	if p.has("id") and p.id!="player": return _bad("Неверная личность героя")
	if p.has("owner") and p.owner!="player": return _bad("Неверный владелец героя")
	if not _point(p,"player"): return false
	for k in ["hp","stamina","hunger"]:
		if not _number(p.get(k),0,100,"player."+k): return false
	if not _number(p.get("karma"),-100,100,"player.karma"): return false
	if browser and source_version not in ["5.2.0","5.3.0","5.3.1","5.4.0","5.5.0","5.6.0"]: p.coins=120
	if not _default_number(p,"coins",120,0,100000000) or floor(p.coins)!=p.coins: return _bad("player.coins: некорректные монеты")
	if not _tools(p.get("tools"),"player.tools"): return false
	if not p.has("legacyGear"): p.legacyGear=[]
	if not _tools(p.legacyGear,"player.legacyGear",true): return false
	if not _inventory(p.get("inventory"),"player.inventory",catalog.LIMITS.weight,p.tools,int(catalog.LIMITS.slots)): return false
	if not _string(p,"tool","",true): return false
	if p.tool!="" and (not catalog.TOOLS.has(p.tool) or p.tool not in p.tools): return _bad("Оружие героя отсутствует в инвентаре")
	if not _dict_field(p,"equipment",{}): return false
	if browser and p.equipment.is_empty():
		for id in ["ironArmor" if p.get("armor")=="iron" else "leatherArmor","leatherGloves","leatherBoots"]:
			p.equipment[catalog.GEAR[id].slot]=id
			if id not in p.tools and id not in p.legacyGear: p.legacyGear.append(id)
		p.equipment.weapon=p.tool
	for slot in p.equipment:
		if not catalog.EQUIPMENT_SLOTS.has(slot): return _bad("Неизвестный слот снаряжения")
		var item=p.equipment[slot]
		if item==null or item=="": continue
		if not item is String or not catalog.TOOLS.has(item) or item not in p.tools and item not in p.legacyGear: return _bad("Надетая вещь отсутствует у героя")
		if slot!="weapon" and (not catalog.GEAR.has(item) or catalog.GEAR[item].slot!=slot): return _bad("Предмет в неверном слоте")
	for slot in catalog.EQUIPMENT_SLOTS:
		if not p.equipment.has(slot): p.equipment[slot]=null
	if not p.has("dodge") or p.dodge==null: p.dodge={}
	if not p.dodge is Dictionary: return _bad("Повреждён манёвр героя")
	if not p.dodge.is_empty() and (not _number(p.dodge.get("left"),0,10,"dodge.left") or not _number(p.dodge.get("yaw"),-1000000000,1000000000,"dodge.yaw")): return false
	if not _dict_field(p,"skillCooldowns",{}): return false
	for skill in p.skillCooldowns:
		if not catalog.SKILLS.has(skill) or not _number(p.skillCooldowns[skill],0,1000000000,"skillCooldowns"): return _bad("Неизвестное умение или таймер")
		if browser: p.skillCooldowns[skill]=time+p.skillCooldowns[skill]
	for k in ["sailing","dead","autoBattle","swimming","buildSnap"]:
		if not _default_bool(p,k,k=="buildSnap"): return false
	for k in ["shipId","cartId","targetId","gatherApproach"]:
		if not _string(p,k,"",true): return false
	for k in ["yaw","y","speed","invulnerable","attackCooldown","actionCooldown","guardUntil","staggerUntil","dodgeUntil","actionUntil","jump","vy","combo","kills","cartEffort"]:
		if not _default_number(p,k,0): return false
	if not _default_number(p,"lastStrike",-10) or not _default_number(p,"guardStarted",-100): return false
	if not _string(p,"actionState","idle") or not _string(p,"mode","jog") or not _string(p,"armor","leather") or not _string(p,"navalWeapon","ballista"): return false
	if p.navalWeapon not in catalog.NAVAL_WEAPONS: return _bad("Неизвестное корабельное оружие")
	if not p.has("respawn"): p.respawn={"x":p.x,"z":p.z}
	if not _point(p.respawn,"player.respawn"): return false
	if browser:
		p.actionUntil=time+max(0,max(p.attackCooldown,p.actionCooldown))
		p.dodge={}
		p.actionState="idle"
		p.attackAnim=0
		p.erase("pendingStrike")
	return true

func _entity(e,category: String,time: float) -> bool:
	if not e is Dictionary: return _bad(category+": нужен объект")
	if not _identity(e,category) or not _point(e,category): return false
	if not _default_number(e,"yaw",0): return false
	for key in ["name","state","role","owner","home","island","originHome","formerHome","status"]:
		if e.has(key) and not _string(e,key): return false
	for key in ["origin","marketAnchor","lastTrack"]:
		if e.has(key) and e[key]!=null and not _point(e[key],category+"."+key): return false
	if category=="resources":
		if not catalog.RESOURCES.has(e.get("kind","")): return _bad("Неизвестный природный ресурс")
		for k in ["amount","max"]:
			if not _number(e.get(k),0,100000000,"resource."+k) or floor(e[k])!=e[k]: return _bad("Повреждено количество ресурса")
		if e.amount>e.max: return _bad("Ресурса больше максимума")
		if not _default_number(e,"respawn",0,-1,1000000000) or not _default_number(e,"scale",1,0.01,100): return false
		# -1 is the browser sentinel for a permanently depleted resource.
		if e.respawn==-1: e["depletedForever"]=true
	elif category=="buildings":
		if not catalog.BUILDING_BY_ID.has(e.get("type","")): return _bad("Неизвестный тип постройки")
		if not _default_number(e,"level",1,1,3) or floor(e.level)!=e.level: return _bad("Неверный уровень постройки")
		var def=catalog.BUILDING_BY_ID[e.type]
		var max_hp=round(def.hp*(1+(e.level-1)*0.45))
		if not _owned(e,max_hp) or not _default_bool(e,"open",false): return false
		var store_capacity=(800 if e.type=="warehouse" else 1200)*e.level if e.type in ["warehouse","granary"] else 1200 if e.type=="dock" else 400
		if not _stored_inventory(e.get("store"),"building.store",store_capacity): return false
		if not _default_number(e,"progress",1,0,1) or not _default_number(e,"foundationDepth",0,0,4): return false
		if e.has("foundationY") and not _number(e.foundationY,-100,200,"foundationY"): return false
		if not _jobs(e): return false
	elif category in ["npcs","animals","creatures"]:
		var max_hp=100.0
		if category!="npcs":
			var defs=catalog.ANIMALS if category=="animals" else catalog.CREATURES
			if not defs.has(e.get("kind","")): return _bad("Неизвестный вид животного")
			max_hp=defs[e.kind].hp
		if not _number(e.get("hp"),0,max_hp,"actor.hp") or not e.get("alive") is bool: return _bad("Некорректное здоровье персонажа")
		e.maxHp=max_hp
		for key in ["timer","hostile","respawn","staggerUntil","cooldown"]:
			if not _default_number(e,key,0): return false
		if not _string(e,"state","idle"): return false
		if not e.has("origin"): e.origin={"x":e.x,"z":e.z}
		if not _point(e.origin,"actor.origin"): return false
		if browser:
			e.cooldown=max(0,e.get("attackCooldown",0))
			e.strike={}; e.pendingStrike=null; e.companyHit=null
		elif not _dict_field(e,"strike",{}): return false
		if e.has("target") and e.target!=null and not e.target is String and not _point(e.target,"actor.target"): return false
		if browser and category in ["animals","creatures"] and e.get("target") is Dictionary: e.goal=e.target.duplicate()
		if not e.has("goal") or e.goal==null: e.goal={}
		if not e.goal is Dictionary or not e.goal.is_empty() and not _point(e.goal,"actor.goal"): return _bad("Повреждена цель движения")
		if category=="npcs" and not _npc(e): return false
	elif category=="ships":
		if not catalog.SHIPS.has(e.get("kind","")): return _bad("Неизвестное судно")
		if not _owned(e,catalog.SHIPS[e.kind].hp) or not _stored_inventory(e.get("store"),"ship.store",catalog.SHIPS[e.kind].capacity): return false
		if not _dict_field(e,"cooldowns",{}): return false
		for weapon in e.cooldowns:
			if not catalog.NAVAL_WEAPONS.has(weapon) or not _number(e.cooldowns[weapon],0,1000000000,"ship.cooldowns"): return _bad("Неверный корабельный таймер")
			if browser: e.cooldowns[weapon]=time+e.cooldowns[weapon]
		for weapon in catalog.NAVAL_WEAPONS:
			if not e.cooldowns.has(weapon): e.cooldowns[weapon]=0
		for k in ["speed","wait","hostile","shot","waypoint"]:
			if not _default_number(e,k,0): return false
		if not _default_number(e,"fire",0,0,1) or not _string(e,"role","idle") or not _string(e,"destination","",true): return false
		if not _point_list(e,"route",512): return false
		if not _number(e.waypoint,0,e.route.size(),"ship.waypoint") or floor(e.waypoint)!=e.waypoint: return _bad("Неверная точка маршрута")
		if not _string(e,"escortTaskId","",true): return false
		if not e.has("damageMarks"): e.damageMarks=[]
		if not e.damageMarks is Array or e.damageMarks.size()>32: return _bad("Повреждены следы урона")
		for mark in e.damageMarks:
			if not mark is Dictionary: return _bad("Повреждены следы урона")
			for k in ["angle","along","time"]:
				if not _number(mark.get(k),-1000000000,1000000000,"damageMark."+k): return false
		e.sunk=e.hp<=0
	elif category=="carts":
		if not _string(e,"kind","cart") or e.kind not in ["cart","wagon"]: return _bad("Неизвестная повозка")
		if not _owned(e,450 if e.kind=="wagon" else 220): return false
		e.capacity=900 if e.kind=="wagon" else 700
		if not _stored_inventory(e.get("store"),"cart.store",e.capacity): return false
		for k in ["followId","driverId"]:
			if not _string(e,k,"",true): return false
		for k in ["speed","wheelAngle"]:
			if not _default_number(e,k,0): return false
	elif category=="drops":
		if not _inventory(e.get("inventory"),"drop.inventory") or not _default_number(e,"expires",time+900,0,1000000000): return false
	elif category=="seaLife":
		if e.get("kind") not in ["fish","dolphin"]: return _bad("Неизвестное морское животное")
		for k in ["depth","size","phase"]:
			if not _default_number(e,k,1,0,1000): return false
	elif category=="settlements":
		if not _stored_inventory(e.get("store"),"settlement.store",1000000): return false
		for k in ["plan","timer","built"]:
			if not _default_number(e,k,0): return false
		if e.has("construction") and e.construction!=null and (not e.construction is Dictionary or not e.construction.is_empty() and not _construction(e.construction)): return _bad("Повреждена стройка поселения")
	return true

func _owned(e: Dictionary,max_hp: float) -> bool:
	if not e.get("owner") is String or e.owner.is_empty(): return _bad("Нет владельца объекта")
	if not _number(e.get("hp"),0,max_hp,"hp"): return false
	e.maxHp=max_hp
	return true

func _point_list(d: Dictionary,key: String,limit: int) -> bool:
	if not d.has(key): d[key]=[]
	if not d[key] is Array or d[key].size()>limit: return _bad(key+": неверный маршрут")
	for p in d[key]:
		if not _point(p,key): return false
	return true

func _jobs(b: Dictionary) -> bool:
	if not b.has("jobs"): b.jobs=[]
	if not b.jobs is Array or b.jobs.size()>8: return _bad("Неверная очередь производства")
	for j in b.jobs:
		if not j is Dictionary or not _identity(j,"jobs"): return _bad("Неверное производственное задание")
		if not catalog.RECIPES.has(j.get("recipe","")) or catalog.RECIPES[j.recipe].station!=b.type: return _bad("Рецепт не подходит мастерской")
		for k in ["total","done"]:
			if not _number(j.get(k),0,100,"job."+k) or floor(j[k])!=j[k]: return _bad("Повреждено количество партий")
		if j.total<1 or j.done>j.total or not _number(j.get("progress"),0,catalog.RECIPES[j.recipe].seconds,"job.progress"): return _bad("Повреждён прогресс производства")
		if j.has("paid") and not _inventory(j.paid,"job.paid"): return false
		if not _string(j,"status","В работе"): return false
	return true

func _npc(n: Dictionary) -> bool:
	if not _string(n,"name","Житель") or not _string(n,"role","worker") or not _string(n,"home","eos"): return false
	if not _default_bool(n,"ally",false): return false
	if not _stored_inventory(n.get("carry"),"npc.carry",120): return false
	if not n.has("marketStock"): n.marketStock={}
	if not _stored_inventory(n.marketStock,"npc.marketStock",650): return false
	if not _dict_field(n,"marketPressure",{}): return false
	for k in n.marketPressure:
		if not catalog.RESOURCES.has(k) or not _number(n.marketPressure[k],-30,30,"marketPressure"): return _bad("Неверный спрос у торговца")
	if not _default_number(n,"coins",500,0,100000000): return false
	for k in ["taskId","taskCargoId","shipId","groupId","workCartId","resourceId"]:
		if not _string(n,k,"",true): return false
	if not _default_number(n,"taskUnits",0,0,10000): return false
	if not n.has("order") or n.order==null: n.order={"type":"follow" if n.ally else "wait"}
	if not _order(n.order): return false
	if n.ally and n.taskId=="":
		if n.order.type in ["guard","gather","repair","wait"] and not _point(n.order,"npc.order"):
			if n.order.type=="wait" and not n.order.has("x") and not n.order.has("z"): n.order.x=n.x; n.order.z=n.z; error=""
			else: return false
		if n.order.type in ["gather","deliver"] and not catalog.RESOURCES.has(n.order.get("resource","")): return _bad("Отсутствует ресурс личного приказа")
		for key in ["quantity","done"]:
			if not _default_number(n.order,key,0,0,1000000000): return false
	if not n.has("taskReport") or n.taskReport==null: n.taskReport={}
	if not n.taskReport is Dictionary: return _bad("Повреждён отчёт NPC")
	for key in ["taskId","status","reason","stage"]:
		if n.taskReport.has(key) and not _string(n.taskReport,key): return false
	if n.has("vehicleOrder") and n.vehicleOrder!=null and (not n.vehicleOrder is Dictionary or not n.vehicleOrder.is_empty()):
		var j=n.vehicleOrder
		if not j is Dictionary or not _string(j,"stationId") or not _number(j.get("progress"),0,12,"vehicleOrder.progress") or not _point(j.get("point"),"vehicleOrder.point") or not _inventory(j.get("paid"),"vehicleOrder.paid"): return _bad("Повреждено производство тележки")
	return true

func _order(o) -> bool:
	if not o is Dictionary or not catalog.ORDERS.has(o.get("type","")): return _bad("Неизвестный приказ")
	for k in ["resource","key"]:
		if o.has(k) and o[k]==null: o.erase(k)
		if o.has(k) and (not o[k] is String or not catalog.RESOURCES.has(o[k])): return _bad("Неизвестный ресурс приказа")
	if o.has("key") and not o.has("resource"): o.resource=o.key
	if o.has("x") or o.has("z"):
		if not _point(o,"order"): return false
	for k in ["id","npcId","targetId","projectId","source","destination","sourceId","destId","shipId","escortId","status","reason"]:
		if o.has(k) and not _string(o,k,"",true): return false
	if o.has("members") and not o.members is Array: return _bad("Повреждён состав приказа")
	return true

func _members(v) -> bool:
	if not v is Array or v.size()>72: return _bad("Повреждён список участников")
	var seen={}
	for id in v:
		if not id is String or seen.has(id) or not objects.has(id) or identities[id]!="npcs": return _bad("Неизвестный или повторный участник")
		seen[id]=true
	return true

func _construction(c) -> bool:
	if not c is Dictionary or not catalog.BUILDING_BY_ID.has(c.get("type","")) or not _point(c,"construction"): return _bad("Повреждена стройка")
	if c.has("progress") and not _number(c.progress,0,1000000000,"construction.progress"): return false
	return true

func _company(s: Dictionary) -> bool:
	if s.tasks.size()>1000 or s.projects.size()>200 or s.groups.size()>32: return _bad("Слишком много поручений или групп")
	for t in s.tasks:
		if not t is Dictionary or not _identity(t,"tasks") or not _order(t): return false
		var shared=browser or t.get("shared",false)
		t.shared=shared
		if not shared:
			if not _string(t,"npcId"): return false
			continue
		if not _members(t.get("members")): return false
		for id in t.members:
			if not objects[id].ally: return _bad("Поручение назначено не спутнику")
		var key=t.get("key",t.get("resource","wood"))
		if not key is String or not catalog.RESOURCES.has(key): return _bad("Неверный ресурс поручения")
		t.key=key; t.resource=key
		for k in ["total","done"]:
			if not _default_number(t,k,0,0,10000) or floor(t[k])!=t[k]: return _bad("Неверный счётчик поручения")
		if t.done>t.total and t.type in ["gather","deliver"]: return _bad("Выполнено больше заказа")
		t.quantity=t.total
		for pair in [["source","sourceId"],["destination","destId"]]:
			var value=t.get(pair[1],t.get(pair[0],""))
			if value==null: value=""
			if not value is String: return _bad("Неверная цель поручения")
			t[pair[0]]=value; t[pair[1]]=value
		for k in ["shipId","escortId","status","reason"]:
			if not _string(t,k,"",true): return false
		for k in ["x","z"]:
			if not t.has(k): t[k]=s.player[k]
		if not _point(t,"task"): return false
		if not _default_number(t,"created",s.time,0,1000000000) or not _default_number(t,"carried",0,0,10000): return false
		if not t.has("cost"): t.cost={}
		if not _inventory(t.cost,"task.cost"): return false
	for p in s.projects:
		if not p is Dictionary or not _identity(p,"projects") or not _construction(p): return false
		if not _default_bool(p,"done",false) or not _default_number(p,"progress",0,0,1000000000) or not _default_number(p,"yaw",0): return false
		if not _default_number(p,"height",_current_height(p.x,p.z),-100,200) or not _default_number(p,"foundationDepth",0,0,4): return false
	for group in s.groups:
		if not group is Dictionary: return _bad("Повреждена группа")
		var alias=identities.get(group.get("id",""),"")=="settlements"
		if not _identity(group,"groups",alias) or not _point(group,"group") or not _members(group.get("members")): return false
		if not group.get("island") is String or not catalog.ISLAND_ECONOMY.has(group.island): return _bad("Неизвестный остров группы")
		if not _string(group,"name","Лагерь") or not _string(group,"phase","travel"): return false
		if group.phase not in ["travel","gather","camp","settlement"]: return _bad("Неизвестная стадия группы")
		if not _default_number(group,"stage",0,0,3) or not _default_number(group,"progress",0,0,1): return false
		if not _stored_inventory(group.get("store"),"group.store",800): return false
		if group.has("building") and group.building!=null and (not group.building is Dictionary or not group.building.is_empty() and not _construction(group.building)): return _bad("Повреждена стройка группы")
	return true

func _references(s: Dictionary) -> bool:
	var p=s.player
	for key in ["shipId","cartId","targetId"]:
		var id=p[key]
		if id=="": continue
		var category="ships" if key=="shipId" else "carts" if key=="cartId" else ""
		if not objects.has(id) or category!="" and identities[id]!=category: return _bad("Некорректная ссылка героя: "+key)
		if category!="" and (objects[id].owner!="player" or objects[id].hp<=0): return _bad("Герой привязан к чужому или разрушенному транспорту")
	for cart in s.carts:
		for key in ["followId","driverId"]:
			var id=cart[key]
			if id=="" or key=="followId" and id=="player": continue
			if not objects.has(id) or identities[id]!="npcs": return _bad("Неизвестный водитель тележки")
	for n in s.npcs:
		for pair in [["shipId","ships"],["workCartId","carts"],["taskCargoId","carts"]]:
			var id=n[pair[0]]
			if id!="" and not (pair[0]=="taskCargoId" and id=="carry") and (not objects.has(id) or identities[id]!=pair[1]): return _bad("Неизвестный транспорт NPC: "+pair[0])
		if n.taskId!="" and identities.get(n.taskId,"")!="tasks": return _bad("Неизвестное поручение NPC")
		if n.groupId!="" and identities.get(n.groupId,"")!="groups": return _bad("Неизвестная группа NPC")
		for task in s.tasks:
			if task.id==n.taskId:
				if task.shared and n.id not in task.members: return _bad("NPC не входит в своё поручение")
				var cargo=n.carry if n.taskCargoId in ["","carry"] else objects[n.taskCargoId].store
				if n.taskUnits>0 and cargo.get(task.resource,0)<n.taskUnits: return _bad("Учтённый груз NPC отсутствует")
			if n.order.get("id","")==task.id: n.order=task
	for st in s.settlements:
		for b in s.buildings:
			if b.type=="warehouse" and b.owner==st.id and b.hp>0:
				st.store=b.store
				break
	return true

func _scale_point(p: Dictionary,factor: float):
	if p.get("x") is float or p.get("x") is int: p.x*=factor
	if p.get("z") is float or p.get("z") is int: p.z*=factor
	for key in POINT_KEYS:
		if p.get(key) is Dictionary: _scale_point(p[key],factor)

func _scale_world(s: Dictionary,factor: float):
	for category in CATEGORIES+["tasks","projects","groups"]:
		for e in s[category]:
			if e is Dictionary: _scale_point(e,factor)
	_scale_point(s.player,factor)
	if s.get("homeHarbor") is Dictionary: _scale_point(s.homeHarbor,factor)

func _add_new_populations(s: Dictionary):
	# Ambient sea life is absent from browser Game.save by design. Use the native
	# seeded ambient population; never copy economic inventory/player data.
	var generated=_browser_populations(int(s.seed))
	if source_version in ["3.0.0","3.1.0"]:
		s.resources.append_array(generated.resources.slice(s.resources.size()))
	var used={}
	for category in CATEGORIES:
		for e in s[category]:
			if e is Dictionary and e.get("id") is String: used[e.id]=true
	for category in ["seaLife","creatures","ships","carts"]:
		if not s[category].is_empty() or not base.get(category) is Array: continue
		if category in ["ships","carts"] and source_version not in ["3.0.0","3.1.0"]: continue
		if category=="creatures" and source_version not in ["3.0.0","3.1.0","4.0.0"]: continue
		for original in generated.get(category,base[category]):
			if category=="carts" and original.get("starter",false): continue
			var e=original.duplicate(true)
			# Old worlds gained a fleet and wildlife in browser's restore wrappers.
			var id="migrated-"+str(int(s.sequence)+1)
			while used.has(id): s.sequence+=1; id="migrated-"+str(int(s.sequence)+1)
			s.sequence+=1; e.id=id; used[id]=true
			s[category].append(e)
	if source_version in ["3.0.0","3.1.0","4.0.0"]:
		for category in ["npcs","animals"]:
			for original in generated.get(category,base.get(category,[])):
				var desired=18 if category=="npcs" else 6
				var count=0
				for e in s[category]:
					if e is Dictionary and e.get("home")==original.home and (category=="npcs" or e.get("kind")==original.kind): count+=1
				if count>=desired: continue
				var fresh=original.duplicate(true)
				s.sequence+=1; fresh.id="migrated-"+str(int(s.sequence)); s[category].append(fresh)
		warnings.append("Восстановлены новые популяции мира из миграции старой версии")

# Mulberry32 and the 3.x generator rebuild position-less legacy resource rows
# from the saved seed. Only generated resource coordinates are used; inventories
# and quantities always come from the imported save.
func _random() -> float:
	random_seed=(random_seed+0x6D2B79F5)&0xffffffff
	var t=random_seed
	t=((t^(t>>15))*(t|1))&0xffffffff
	t=(t ^ ((t+(((t^(t>>7))*(t|61))&0xffffffff))&0xffffffff))&0xffffffff
	return float((t^(t>>14))&0xffffffff)/4294967296.0

func _hash(x: float,z: float) -> float:
	return fposmod(sin(x*127.1+z*311.7)*43758.5453123,1.0)

func _noise(x: float,z: float) -> float:
	var ix=floor(x); var iz=floor(z)
	var fx=x-ix; var fz=z-iz
	fx=fx*fx*(3-2*fx); fz=fz*fz*(3-2*fz)
	return lerp(lerp(_hash(ix,iz),_hash(ix+1,iz),fx),lerp(_hash(ix,iz+1),_hash(ix+1,iz+1),fx),fz)

func _legacy_height(x: float,z: float) -> float:
	var height=-3.0
	for original in catalog.ISLANDS:
		var ix=original.x/catalog.WORLD_SCALE; var iz=original.z/catalog.WORLD_SCALE
		var xx=(x-ix)/(original.rx/catalog.WORLD_SCALE); var zz=(z-iz)/(original.rz/catalog.WORLD_SCALE)
		var a=atan2(zz,xx); var r=sqrt(xx*xx+zz*zz)
		var edge=1+0.055*sin(a*5+0.4)+0.04*cos(a*3)
		var radial=clamp(1-r/edge,0,1)
		if radial<=0: continue
		var n=_noise(x*0.029,z*0.029); var detail=_noise(x*0.13,z*0.13)*0.8
		var mountain=pow(clamp((radial-0.26)/0.74,0,1),1.55)*original.peak*(0.55+n*0.9)
		height=max(height,-1.9+radial*10+mountain+(n-0.5)*radial*6+detail*radial)
	return height

func _legacy_point(i: Dictionary,min_height: float,max_height: float) -> Dictionary:
	var scale=catalog.WORLD_SCALE
	for k in 120:
		var angle=_random()*TAU; var radius=sqrt(_random())*0.90
		var x=(i.x+cos(angle)*radius*i.rx)/scale; var z=(i.z+sin(angle)*radius*i.rz)/scale
		var h=_legacy_height(x,z)
		if h>min_height and h<max_height: return {"x":x,"z":z}
	return {"x":i.x/scale+15,"z":i.z/scale+35}

func _legacy(s: Dictionary) -> bool:
	var states={}
	for r in s.resources:
		if not r is Dictionary or not r.get("id") is String or states.has(r.id): return _bad("Повреждены ресурсы 3.x")
		if not _number(r.get("amount"),0,100000000,"legacy.amount") or not _number(r.get("respawn"),-1,1000000000,"legacy.respawn"): return false
		states[r.id]=r
	random_seed=int(s.seed)
	var seq=1
	var resources=[]
	var generated_ids={}
	for i in catalog.ISLANDS:
		var center=Vector2(i.x/catalog.WORLD_SCALE-15,i.z/catalog.WORLD_SCALE+31)
		seq+=4
		for n in 6:
			seq+=1; _random(); _random()
		for kind in ["wood","stone","fiber","food","ore","coal","clay"]:
			var count=85 if kind=="wood" else 34 if kind=="stone" else 23 if kind=="fiber" else 15 if kind=="food" else 18
			for n in count:
				var p=_legacy_point(i,0.4 if kind=="clay" else 1,22 if kind=="wood" else 60)
				if Vector2(p.x,p.z).distance_to(center)<18 or Vector2(p.x,p.z).distance_to(Vector2(-142,160))<5: continue
				var id="res-"+str(seq); seq+=1
				var amount=14 if kind=="wood" else 12 if kind=="stone" else 18 if kind==i.rich else 8
				var r={"id":"legacy-"+id,"kind":kind,"x":p.x,"z":p.z,"island":i.id,"amount":amount,"max":amount,"respawn":0,"scale":0.72+_random()*0.9,"yaw":_random()*6.28}
				if states.has(id): r.amount=states[id].amount; r.respawn=states[id].respawn
				generated_ids[id]=true; resources.append(r)
		for kind in catalog.ANIMALS:
			for n in 2:
				_legacy_point(i,2,30); seq+=1; _random(); _random()
	for entry in [["wood",-140,155,14,0],["stone",-146,155,12,0.8]]:
		var id="res-"+str(seq); seq+=1
		var r={"id":"legacy-"+id,"kind":entry[0],"x":entry[1],"z":entry[2],"island":"eos","amount":entry[3],"max":entry[3],"respawn":0,"scale":1,"yaw":entry[4]}
		if states.has(id): r.amount=states[id].amount; r.respawn=states[id].respawn
		generated_ids[id]=true; resources.append(r)
	for id in states:
		if not generated_ids.has(id): return _bad("Ресурс 3.x не соответствует seed: "+id)
	s.resources=resources
	for n in s.npcs:
		if n is Dictionary and n.get("target") is String and n.target!="": n.target="legacy-"+n.target
	_scale_world(s,catalog.WORLD_SCALE)
	warnings.append("Мир 3.x восстановлен по исходному seed")
	return true

func _current_height(x: float,z: float) -> float:
	var h=-50.0
	for i in catalog.ISLANDS:
		var xx=(x-i.x)/i.rx; var zz=(z-i.z)/i.rz
		var a=atan2(zz,xx); var r=sqrt(xx*xx+zz*zz)
		var edge=1+0.055*sin(a*5+0.4)+0.04*cos(a*3)
		var radial=clamp(1-r/edge,0,1)
		if radial<=0:
			h=max(h,-1.9-min(46.0,pow(max(0.0,r/edge-1),0.8)*70))
			continue
		var n=_noise(x*0.029/catalog.WORLD_SCALE,z*0.029/catalog.WORLD_SCALE)
		var detail=_noise(x*0.13/catalog.WORLD_SCALE,z*0.13/catalog.WORLD_SCALE)*0.8
		var mountain=pow(clamp((radial-0.26)/0.74,0,1),1.55)*i.peak*(0.55+n*0.9)
		h=max(h,-1.9+radial*10+mountain+(n-0.5)*radial*6+detail*radial)
	return h

func _current_point(i: Dictionary,min_height: float,max_height: float) -> Dictionary:
	for k in 120:
		var a=_random()*TAU; var r=sqrt(_random())*0.9
		var x=i.x+cos(a)*r*i.rx; var z=i.z+sin(a)*r*i.rz
		var h=_current_height(x,z)
		if h>min_height and h<max_height: return {"x":x,"z":z}
	return {"x":i.x+15,"z":i.z+35}

func _browser_populations(seed_value: int) -> Dictionary:
	# Replay the browser constructor's RNG calls through generate, initExpansion
	# (no random calls), and initFrontiers. This preserves arbitrary saved seeds,
	# including the ambient population intentionally omitted from browser JSON.
	random_seed=seed_value
	var result={"resources":[],"npcs":[],"animals":[],"creatures":[],"seaLife":[]}
	var seq=1
	var player_point=Vector2(-142*catalog.WORLD_SCALE,160*catalog.WORLD_SCALE)
	var centers=[]
	for index in catalog.ISLANDS.size():
		var i=catalog.ISLANDS[index]
		var center=Vector2(i.x-15*catalog.WORLD_SCALE,i.z+31*catalog.WORLD_SCALE)
		centers.append(center)
		seq+=4
		for n in 18:
			result.npcs.append({"id":"npc-"+str(seq),"name":catalog.NPC_NAMES[(index*6+n)%catalog.NPC_NAMES.size()]+(" "+str(1+n/6) if n>=6 else ""),"home":i.id,"role":"guard" if n%6==0 else "builder" if n%6==1 else "worker","x":center.x+_random()*10-5,"z":center.y+_random()*10-5,"hp":100,"maxHp":100,"alive":true,"respawn":0,"yaw":0,"state":"idle","target":null,"carry":{},"timer":0,"hostile":0,"attackCooldown":0})
			seq+=1
		for kind in ["wood","stone","fiber","food","ore","coal","clay"]:
			for n in int(catalog.ISLAND_ECONOMY[i.id].counts.get(kind,0)):
				var p=_current_point(i,0.4 if kind=="clay" else 1,22 if kind=="wood" else 60)
				if Vector2(p.x,p.z).distance_to(center)<18 or Vector2(p.x,p.z).distance_to(player_point)<5: continue
				var amount=(24 if kind=="wood" else 26 if kind=="ore" else 22) if kind==i.rich else 12 if kind=="wood" else 14 if kind=="stone" else 8
				result.resources.append({"id":"res-"+str(seq),"kind":kind,"x":p.x,"z":p.z,"island":i.id,"amount":amount,"max":amount,"respawn":0,"scale":0.72+_random()*0.9,"yaw":_random()*6.28})
				seq+=1
		for kind in catalog.ANIMALS:
			for n in 6:
				var p=_current_point(i,2,30)
				if Vector2(p.x,p.z).distance_to(player_point)<25: p.x=i.x+32; p.z=i.z-25
				result.animals.append({"id":"animal-"+str(seq),"kind":kind,"home":i.id,"x":p.x,"z":p.z,"hp":catalog.ANIMALS[kind].hp,"alive":true,"yaw":_random()*6.28,"timer":_random()*3,"attackCooldown":0,"hostile":0,"respawn":0,"origin":p.duplicate()})
				seq+=1
	for entry in [["wood",2,-4,14,0],["stone",-3,-4,12,0.8]]:
		result.resources.append({"id":"res-"+str(seq),"kind":entry[0],"x":player_point.x+entry[1],"z":player_point.y+entry[2],"island":"eos","amount":entry[3],"max":entry[3],"scale":1,"yaw":entry[4],"respawn":0})
		seq+=1
	seq+=15 # Four owned ships, eight merchants/escorts, two pirates, one cart.
	for i in catalog.ISLANDS:
		for n in 7:
			var kind="dragon" if n<2 else ["troll","warwolf","golem","warwolf","troll"][n-2]
			var p={}
			for tries in 80:
				p=_current_point(i,12 if kind=="dragon" else 4,60)
				var far=Vector2(p.x,p.z).distance_to(player_point)>80
				for center in centers:
					if center.distance_to(Vector2(p.x,p.z))<=65: far=false
				if far: break
			result.creatures.append({"id":"creature-"+str(seq),"kind":kind,"home":i.id,"x":p.x,"z":p.z,"origin":p.duplicate(),"hp":catalog.CREATURES[kind].hp,"maxHp":catalog.CREATURES[kind].hp,"alive":true,"yaw":_random()*6.28,"timer":n,"state":"idle","attackCooldown":0,"respawn":0})
			seq+=1
		var a=atan2(-i.x,-i.z)
		var port={"x":i.x,"z":i.z+i.rz*1.15}
		var radius=1.06
		while radius<1.4:
			var q={"x":i.x+sin(a)*i.rx*radius,"z":i.z+cos(a)*i.rz*radius}
			var clear=abs(q.x)<catalog.LIMITS.world-12 and abs(q.z)<catalog.LIMITS.world-12
			for delta in [Vector2.ZERO,Vector2(18,0),Vector2(-18,0),Vector2(0,18),Vector2(0,-18)]:
				if _current_height(q.x+delta.x,q.z+delta.y)>=-0.55: clear=false
			if clear: port=q; break
			radius+=0.015
		for n in 43:
			var p=port.duplicate()
			for k in 60:
				var b=a+(_random()-0.5)*1.5; var r=1.09+_random()*0.24
				var q={"x":i.x+sin(b)*i.rx*r,"z":i.z+cos(b)*i.rz*r}
				if _current_height(q.x,q.z)<-3 and abs(q.x)<catalog.LIMITS.world-20 and abs(q.z)<catalog.LIMITS.world-20: p=q; break
			var kind="dolphin" if n<3 else "fish"
			result.seaLife.append({"id":"sea-"+str(seq),"kind":kind,"home":i.id,"x":p.x,"z":p.z,"origin":p.duplicate(),"yaw":_random()*6.28,"phase":_random()*6.28,"depth":1.2 if kind=="dolphin" else 1.1+_random()*4,"size":2.2+_random()*0.6 if kind=="dolphin" else 0.32+_random()*0.5})
			seq+=1
	return result

func ensure_starter_wagon(s: Dictionary) -> bool:
	# Source logistics-54 restore: grant once, only after locating a safe footprint.
	# May also be reused by the game when a boat/death/blocked location postpones it.
	if s.get("starterWagonGranted",false): return false
	var p=s.player
	if p.dead or p.sailing or p.shipId!="" or _current_height(p.x,p.z)<0.8: return false
	for cart in s.carts:
		if cart.get("kind","cart")=="wagon" and cart.owner=="player" and cart.hp>0 and _distance(cart,p)<=12:
			s.starterWagonGranted=true
			return false
	var geometry=preload("res://scripts/building_geometry.gd").new({"catalog":catalog})
	for radius in [5,7,9,11]:
		for j in 24:
			var yaw=j*PI/12.0
			var point={"x":p.x+sin(yaw)*radius,"z":p.z+cos(yaw)*radius}
			var h=_current_height(point.x,point.z)
			if h<0.8: continue
			var clear=true
			for c in s.carts:
				if c.hp>0 and _distance(c,point)<4: clear=false
			if not clear: continue
			for along in [-1.8,0,1.8,3.2,4.5]:
				for side in [-0.9,0,0.9]:
					var q={"x":point.x+sin(yaw)*along+cos(yaw)*side,"z":point.z+cos(yaw)*along-sin(yaw)*side}
					var y=_current_height(q.x,q.z)
					if abs(q.x)>catalog.LIMITS.world or abs(q.z)>catalog.LIMITS.world or y<0.65 or abs(y-h)>1.3: clear=false; break
					for b in s.buildings:
						if geometry.contains(b,q,0.55): clear=false; break
					for r in s.resources:
						if r.kind in ["wood","stone","ore","coal"] and r.amount>0 and _distance(r,q)<0.55+(0.36 if r.kind=="wood" else 0.55)*r.scale: clear=false; break
					for n in s.npcs:
						if n.alive and n.shipId=="" and _distance(n,q)<0.89: clear=false; break
					if not p.dead and p.shipId=="" and _distance(p,q)<0.89: clear=false
					for c in s.carts:
						if c.hp>0 and _distance(c,q)<1.8: clear=false; break
					if not clear: break
				if not clear: break
			if not clear: continue
			var id="wagon-"+str(int(s.sequence)+1)
			while identities.has(id) or s.carts.any(func(c): return c.id==id): s.sequence+=1; id="wagon-"+str(int(s.sequence)+1)
			s.sequence+=1
			var wagon={"id":id,"kind":"wagon","x":point.x,"z":point.z,"yaw":yaw,"hp":450,"maxHp":450,"owner":"player","store":{},"capacity":900,"followId":"","driverId":"","speed":0,"wheelAngle":0,"starter":true,"status":"Ожидает"}
			_inventory(wagon.store,"starter.store",900)
			s.carts.append(wagon)
			s.starterWagonGranted=true
			identities[id]="carts"; objects[id]=wagon
			return true
	return false

func _distance(a: Dictionary,b: Dictionary) -> float:
	return sqrt(pow(a.x-b.x,2)+pow(a.z-b.z,2))

func _ensure_merchants(s: Dictionary):
	# company.js restoreCompany calls ensureMerchants after warehouse aliases are
	# reconnected. Stock changes hands physically; it is never invented or copied.
	for island in catalog.ISLANDS:
		var exists=false
		for n in s.npcs:
			if n.role=="merchant" and n.get("originHome","")==island.id: exists=true; break
		if exists: continue
		var settlement={}
		for st in s.settlements:
			if st.id==island.id: settlement=st; break
		if settlement.is_empty(): continue
		var merchant={}
		for n in s.npcs:
			if n.home==island.id and n.role=="worker" and not n.ally and n.groupId=="": merchant=n
		if merchant.is_empty(): continue
		merchant.role="merchant"; merchant.originHome=island.id
		merchant.name="Торговец "+island.name; merchant.state="trade"; merchant.coins=600
		merchant.marketPressure={}; merchant.marketStock={}
		for key in catalog.RESOURCES:
			var take=min(settlement.store[key],28 if key==catalog.ISLAND_ECONOMY[island.id].export else 10)
			settlement.store[key]-=take; merchant.marketStock[key]=take; merchant.marketPressure[key]=0
		merchant.marketAnchor={"x":merchant.x,"z":merchant.z}
