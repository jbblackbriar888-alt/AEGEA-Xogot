extends RefCounted
## Native port of AEGEA 5.6 expansion.js → frontiers.js → combat.js → systems-53.js.
## Absolute cooldown deadlines replace browser countdowns; all other timings and
## gameplay values follow that final installed method chain. Rendering is advisory.
var g
var events: Array=[]
var event_sequence=0
signal event_added(event: Dictionary)

func _init(game):
	g = game

func record_event(kind: String, entity: Dictionary, amount=0.0, critical=false, guarded=false):
	var position=g.point(entity,1.6)
	if entity.get("entity_kind","")=="ships": position=Vector3(entity.x,g.catalog.SHIPS[entity.kind].deck+1.6,entity.z)
	elif entity==g.player: position=Vector3(entity.x,entity.get("y",g.height_at(entity.x,entity.z))+1.8,entity.z)
	event_sequence+=1
	var event={"id":event_sequence,"kind":kind,"amount":float(amount),"target_id":entity.get("id","player"),"position":position,"time":float(g.state.time),"critical":critical,"guarded":guarded}
	events.append(event)
	if events.size()>160: events.pop_front()
	event_added.emit(event)

func current_ship() -> Dictionary:
	var s = g.entity(g.player.get("shipId", ""))
	return s if not s.is_empty() and s.get("hp", 0) > 0 else {}

func can_attack(e: Dictionary, source = "player") -> bool:
	if e.is_empty() or e.get("dead", false) or e.get("hp", 0) <= 0 or not e.get("alive", true): return false
	var type = e.get("entity_kind", "")
	if type == "npcs" and e.get("ally", false):
		if source == "player" or g.entity(source).get("ally", false): return false
	if source != "player": return true
	if e == g.player: return false
	if type in ["animals", "creatures"]: return current_ship().is_empty()
	if type == "npcs":
		return e.get("home", "") != "player" and (g.state.pvp or e.get("hostile", 0) > 0 or (g.player.karma <= -50 and e.get("role", "") == "guard"))
	if type not in ["ships", "buildings"]: return false
	return e.get("owner", "") != "player" and (g.state.pvp or e.get("owner", "") == "pirates" or e.get("hostile", 0) > 0)

func clear_shot(a: Dictionary, b: Dictionary) -> bool:
	var start = Vector2(a.x, a.z)
	var finish = Vector2(b.x, b.z)
	for o in g.state.buildings:
		if o.hp <= 0 or o.id == b.get("id", "") or o.get("progress", 1) != 1 or o.type in ["road", "dock", "campfire", "farm", "well"] or g.distance(a, o) <= 3: continue
		var center = Vector2(o.x, o.z)
		var nearest = Geometry2D.get_closest_point_to_segment(center, start, finish)
		if nearest.distance_to(center) < g.catalog.BUILDING_BY_ID[o.type].size * 0.55: return false
	return true

func aim_score(e: Dictionary) -> float:
	var p = g.player
	var d = g.distance(p, e)
	var dot = ((e.x-p.x)*sin(p.yaw)+(e.z-p.z)*cos(p.yaw))/max(d, 0.00001)
	return d+(1-dot)*7-(2 if e.get("hostile", 0)>0 else 0)

func in_arc(e: Dictionary, reach: float, arc: float) -> bool:
	var d = g.distance(g.player, e)
	return d <= reach and (d < 0.001 or ((e.x-g.player.x)*sin(g.player.yaw)+(e.z-g.player.z)*cos(g.player.yaw))/d >= arc)

func cycle_target() -> Dictionary:
	var p = g.player
	var aboard = not current_ship().is_empty()
	var pool: Array = []
	for e in (g.state.ships if aboard else g.state.animals+g.state.npcs+g.state.creatures):
		if can_attack(e) and g.distance(p,e)<(210 if aboard else 55) and clear_shot(p,e): pool.append(e)
	pool.sort_custom(func(a,b): return aim_score(a)<aim_score(b))
	if pool.is_empty(): p.targetId=""; p.autoBattle=false; return {}
	var at = -1
	for i in pool.size():
		if pool[i].id == p.get("targetId", ""): at=i
	p.targetId=pool[(at+1)%pool.size()].id
	g.changed.emit()
	return g.entity(p.targetId)

func select_target(id: String) -> bool:
	var e = g.entity(id)
	if e.is_empty() or e.get("hp",0)<=0 or not e.get("alive",true) or g.distance(g.player,e)>230: return false
	g.player.targetId=id
	g.changed.emit()
	return true

func attack(skill_key = "") -> bool:
	var p = g.player
	p["gatherApproach"]=""
	if p.get("staggerUntil",0)>g.state.time or not g.pending_gather.is_empty(): return false
	if skill_key!="": return skill(skill_key)
	if not current_ship().is_empty(): return fire_ship(current_ship(),p.navalWeapon)
	var tool = g.catalog.TOOLS.get(p.tool,{})
	return _ranged_attack() if tool.get("ranged",false) else _begin_melee()

func _find_attack_target(reach: float, arc: float, aim = true) -> Dictionary:
	var e = g.entity(g.player.get("targetId",""))
	if not e.is_empty() and (e.get("hp",0)<=0 or not e.get("alive",true)): e={}
	if not e.is_empty(): return e
	var pool: Array=[]
	for candidate in g.state.animals+g.state.npcs+g.state.creatures+(g.state.buildings if g.state.pvp else []):
		if can_attack(candidate) and in_arc(candidate,reach,arc) and (not aim or clear_shot(g.player,candidate)): pool.append(candidate)
	pool.sort_custom(func(a,b): return aim_score(a)<aim_score(b) if aim else g.distance(g.player,a)<g.distance(g.player,b))
	if pool.is_empty(): return {}
	g.player.targetId=pool[0].id
	return pool[0]

func _next_combo():
	var p=g.player
	p.combo=int(p.get("combo",0))%3+1 if g.state.time-p.get("lastStrike",-10)<1.8 else 1
	p.lastStrike=g.state.time

func _release_cart():
	if g.player.get("cartId","")!="":
		g.player.cartId=""
		g.notify("Тележка оставлена для боя.")

func _begin_melee(skill_key = "") -> bool:
	var p=g.player
	var profile=g.catalog.MELEE.get(p.tool,{})
	var tool=g.catalog.TOOLS.get(p.tool,{})
	var definition=g.catalog.SKILLS.get(skill_key,{})
	if profile.is_empty() or p.dead or p.swimming or p.get("actionUntil",0)>g.state.time or p.get("staggerUntil",0)>g.state.time or not g.pending_gather.is_empty(): return false
	var cost=definition.get("stamina",tool.stamina)
	if p.stamina<cost: return false
	var target=_find_attack_target(profile.reach+0.35,0.15)
	if not target.is_empty() and (not can_attack(target) or g.distance(p,target)>profile.reach+0.4 or not clear_shot(p,target)): return false
	if skill_key!="" and target.is_empty(): return false
	_next_combo()
	var heavy=skill_key=="power"
	var sweep=skill_key=="sweep"
	var windup=profile.windup*(1.65 if heavy else 1.2 if sweep else 1.0)
	var total=windup+profile.recovery+(0.18 if heavy else 0.0)
	p.stamina-=cost
	p.actionUntil=g.state.time+total
	p["attackAnim"]=total
	p["actionDuration"]=total
	p["actionImpact"]=windup/total
	p["actionSequence"]=p.get("actionSequence",0)+1
	p.actionState="heavyAttack" if heavy else "attack2" if sweep or (p.tool=="sword" and p.combo==2) else "attack"
	p["meleeStyle"]=p.tool
	if not target.is_empty(): p.yaw=atan2(target.x-p.x,target.z-p.z)
	if skill_key!="": p.skillCooldowns[skill_key]=g.state.time+definition.cooldown
	g.strikes.append({"left":windup,"target":target.get("id",""),"damage":round(tool.damage*profile.multiplier*definition.get("multiplier",[1.0,1.12,1.3][p.combo-1])),"reach":profile.reach+(0.35 if sweep else 0.0),"arc":-0.5 if sweep else profile.arc,"yaw":p.yaw,"x":p.x,"z":p.z,"heavy":heavy,"sweep":sweep,"tool":p.tool,"sequence":p.actionSequence})
	g.effect.emit(skill_key if skill_key!="" else "swing",g.point(p,1))
	_release_cart()
	g.changed.emit()
	return true

func _ranged_attack(skill_key = "") -> bool:
	var p=g.player
	var tool=g.catalog.TOOLS.get(p.tool,{})
	if p.dead or p.get("actionUntil",0)>g.state.time or not tool.get("ranged",false): return false
	var definition=g.catalog.SKILLS.get(skill_key,{})
	var target=g.entity(p.get("targetId","")) if skill_key!="" else _find_attack_target(tool.reach,0.0,false)
	if skill_key!="" and target.is_empty(): return false
	if not target.is_empty() and (not can_attack(target) or g.distance(p,target)>tool.reach+1 or not clear_shot(p,target)): return false
	var cost=definition.get("stamina",tool.stamina)
	var count=3 if skill_key=="sweep" else 1
	if p.stamina<cost or p.inventory.get(tool.ammo,0)<count: return false
	p.stamina-=cost
	p.inventory[tool.ammo]-=count
	p.actionUntil=g.state.time+tool.delay
	p["attackAnim"]=0.6 if skill_key=="" else 0.8
	if skill_key=="": _next_combo()
	else: p.skillCooldowns[skill_key]=g.state.time+definition.cooldown
	p.actionState="bow" if skill_key=="" else "heavyAttack" if skill_key=="power" else "attack2"
	if not target.is_empty():
		p.yaw=atan2(target.x-p.x,target.z-p.z)
		var amount=round(tool.damage*definition.get("multiplier",[1.0,1.12,1.3][int(p.get("combo",1))-1]))
		for i in count:
			spawn_projectile(p,target,amount,40 if skill_key=="" else 62 if skill_key=="power" else 42,"arrow",tool.reach+(10 if skill_key=="" else 8),i*0.10)
	g.effect.emit("bow" if skill_key=="" else skill_key,g.point(p,1))
	_release_cart()
	g.changed.emit()
	return true

func skill(key: String) -> bool:
	var p=g.player
	var d=g.catalog.SKILLS.get(key,{})
	if d.is_empty() or p.dead or p.get("staggerUntil",0)>g.state.time or p.sailing or p.skillCooldowns.get(key,0)>g.state.time or p.stamina<d.stamina: return false
	if key not in ["guard","dodge"]:
		return _ranged_attack(key) if g.catalog.TOOLS.get(p.tool,{}).get("ranged",false) else _begin_melee(key)
	g.strikes.clear()
	g.pending_gather.clear()
	p["gatherApproach"]=""
	p["attackAnim"]=0.0
	p.actionState="idle"
	p.stamina-=d.stamina
	p.skillCooldowns[key]=g.state.time+d.cooldown
	if key=="guard":
		p.guardUntil=g.state.time+3
		p.guardStarted=g.state.time
	else:
		p.invulnerable=0.55
		p["dodge"]={"left":0.3,"yaw":p.get("dodgeAim",p.yaw)}
	g.effect.emit(key,g.point(p,1))
	g.changed.emit()
	return true

func damage(e: Dictionary, amount: float, source = "player", heavy = false, kind = "") -> bool:
	if not can_attack(e,source): return false
	if e==g.player: hurt(amount); return true
	if kind=="": kind="heavy" if heavy else "melee"
	var p=g.player
	var type=e.get("entity_kind","")
	var melee=kind not in ["arrow","cannon","ballista","fire"]
	var guarded=false
	var strike=e.get("strike",{})
	if source=="player" and type=="npcs" and e.get("role","")=="guard" and melee and strike.is_empty() and e.get("staggerUntil",0)<=g.state.time and e.get("blockCooldown",0)<=g.state.time:
		var front=((p.x-e.x)*sin(e.yaw)+(p.z-e.z)*cos(e.yaw))/max(0.001,g.distance(p,e))
		if front>0.35 and kind!="heavy":
			guarded=true
			amount*=0.45
			e["blockCooldown"]=g.state.time+3
			e["blockUntil"]=g.state.time+0.35
			g.effect.emit("metal",g.point(e,1))
			record_event("block",e)
	var poise_amount=amount
	var critical=false
	if source=="player" and type!="creatures" and kind not in ["cannon","ballista"] and g.rng.randf()<0.13:
		amount=round(amount*1.65)
		critical=true
		e["criticalAt"]=g.state.time
	if source=="player":
		if type=="npcs":
			if e.get("hostile",0)<=0 and not (p.karma<=-50 and e.role=="guard"): p.karma=clamp(p.karma-8,-100,100)
			alert_settlement(e.home)
		elif type=="buildings":
			p.karma=clamp(p.karma-3,-100,100)
			alert_settlement(e.owner)
		elif type=="ships" and e.owner!="pirates":
			if e.get("hostile",0)<=0: p.karma=clamp(p.karma-10,-100,100)
			e.hostile=90.0
			alert_settlement(e.owner)
	var before=e.hp
	e.hp=max(0,e.hp-amount)
	record_event("damage",e,before-e.hp,critical,guarded)
	if type=="animals": e.hostile=18.0
	elif type=="creatures": e.hostile=25.0; e["hitAt"]=g.state.time
	g.effect.emit("metal" if type=="npcs" and e.role=="guard" else "hit" if type in ["npcs","animals","creatures"] else "wood",g.point(e,1))
	if e.hp<=0: _kill(e,source)
	if type=="ships":
		e["damageMarks"]=e.get("damageMarks",[])
		e.damageMarks.append({"angle":g.rng.randf()*TAU,"along":(g.rng.randf()-0.5)*0.65,"time":g.state.time})
		if e.damageMarks.size()>8: e.damageMarks.pop_front()
		if kind=="cannon" or e.hp/e.maxHp<0.5: e.fire=min(1,e.get("fire",0)+(0.22 if kind=="cannon" else 0.08))
		g.effect.emit("shipDamage",Vector3(e.x,g.catalog.SHIPS[e.kind].deck+0.3,e.z))
	if e.hp>0 and type in ["npcs","animals","creatures"]:
		e["hitUntil"]=g.state.time+0.24
		e["hitSequence"]=e.get("hitSequence",0)+1
		e["poise"]=e.get("poise",0)+poise_amount*(2 if kind=="heavy" else 1.5 if kind=="axe" else 1)
		var threshold=150 if type=="creatures" and e.kind=="dragon" else 65 if type=="creatures" else 30
		if e.poise>=threshold and e.get("poiseReset",0)<=g.state.time:
			e.poise=0
			e["poiseReset"]=g.state.time+1.1
			e.staggerUntil=g.state.time+(0.25 if type=="creatures" else 0.48)
			if not e.get("strike",{}).is_empty():
				g.effect.emit("interrupt",g.point(e,2))
				record_event("interrupt",e)
			e.strike={}
			e.cooldown=max(e.get("cooldown",0),0.8)
		if melee:
			e["reaction"]="block" if guarded else "stumble" if kind=="heavy" else "recoil"
			e["reactionUntil"]=g.state.time+(0.6 if kind=="heavy" else 0.3)
			if not guarded and source=="player":
				var push=0.10 if type=="creatures" else 0.55 if kind=="heavy" else 0.18
				var dist=max(0.01,g.distance(p,e))
				var q={"x":e.x+(e.x-p.x)/dist*push,"z":e.z+(e.z-p.z)/dist*push}
				if g.height_at(q.x,q.z)>0.35 and not g.blocked(q,0.35,e.id,true): e.x=q.x; e.z=q.z
	g.changed.emit()
	return true

func _drop(e: Dictionary, inventory: Dictionary, label: String, lifetime=600.0, floating=false):
	g.state.drops.append({"id":g.uid("drop"),"x":e.x,"z":e.z,"inventory":inventory.duplicate(),"name":label,"expires":g.state.time+lifetime,"floating":floating})
	g.reindex()

func _kill(e: Dictionary, source: String):
	var type=e.get("entity_kind","")
	e["state"]="death"
	e["deathAt"]=g.state.time
	e["strike"]={}
	if type in ["npcs","animals","creatures"]:
		e.alive=false
		e.respawn=g.state.time+(180 if type=="animals" else 240 if type=="npcs" else 480)
		if type=="npcs":
			if source=="player":
				g.player.kills=g.player.get("kills",0)+1
				g.state.stats.kills+=1
				g.player.karma=clamp(g.player.karma-25,-100,100)
			_drop(e,e.get("carry",g.blank()),"Припасы "+e.get("name","жителя"))
		elif type=="animals":
			var d=g.catalog.ANIMALS[e.kind]
			_drop(e,{"food":d.food,"leather":d.leather},d.name+" — добыча")
			g.state.stats.kills+=1
		else:
			_drop(e,g.catalog.CREATURES[e.kind].loot,g.catalog.CREATURES[e.kind].name)
			g.state.stats.kills+=1
	elif type=="buildings":
		if g.weight(e.get("store",{}))>0: _drop(e,e.store,"Разрушенный склад")
		e.store=g.blank()
		for settlement in g.state.settlements:
			if e.type=="warehouse" and settlement.id==e.owner: settlement.store=e.store
		g.notify("Разрушено: "+g.catalog.BUILDING_BY_ID[e.type].name)
	elif type=="ships": sink_ship(e)
	if g.player.get("targetId","")==e.id: g.player.targetId=""
	g.effect.emit("death",g.point(e,1))
	record_event("death",e)

func hurt(amount: float, attacker: Dictionary = {}):
	var p=g.player
	if p.dead or p.invulnerable>0: return
	# systems-53 is the outer wrapper: equipment reduction precedes block stamina.
	amount*=1-g.defense()/100.0
	var old_guard=p.get("guardUntil",0)
	var front=true
	if not attacker.is_empty():
		var d=g.distance(p,attacker)
		front=d<0.2 or ((attacker.x-p.x)*sin(p.yaw)+(attacker.z-p.z)*cos(p.yaw))/max(d,0.00001)>0.25
	var guarding=old_guard>g.state.time and front
	if guarding and g.state.time-p.get("guardStarted",-10)<0.25 and p.stamina>=5:
		p.stamina-=5
		if not attacker.is_empty(): attacker.staggerUntil=g.state.time+0.55; attacker.strike={}
		g.effect.emit("parry",g.point(p,1.6))
		record_event("parry",p)
		return
	if guarding:
		var cost=max(4,ceil(amount*0.45))
		if p.stamina>=cost: p.stamina-=cost
		else:
			p.stamina=0
			p.guardUntil=0
			p.staggerUntil=g.state.time+0.65
			g.effect.emit("guardBreak",g.point(p,1.6))
			record_event("guardBreak",p)
	else: p.guardUntil=0
	var before=p.hp
	p.hp=max(0,p.hp-amount*(0.3 if p.guardUntil>g.state.time else 1.0))
	if not front and old_guard>g.state.time: p.guardUntil=old_guard
	if p.hp<before:
		record_event("damage",p,before-p.hp,false,p.guardUntil>g.state.time and front)
		p["hitSequence"]=p.get("hitSequence",0)+1
		p["hitUntil"]=g.state.time+0.24
		p["hitFlash"]=0.2
		g.state["raid"]={}
		g.effect.emit("hit",g.point(p,1))
		if amount>=12 and not guarding:
			g.strikes.clear(); g.pending_gather.clear()
			p["gatherApproach"]=""; p["attackAnim"]=0.0
			p.staggerUntil=g.state.time+0.22
	if p.hp<=0:
		p.dead=true; p.sailing=false; p.autoBattle=false
		p.shipId=""; p.cartId=""; p.targetId=""
		p.actionState="death"
		record_event("death",p)
		g.strikes.clear(); g.pending_gather.clear()
		_drop(p,p.inventory,"Ваш рюкзак",900)
		p.inventory=g.blank()
		g.notify("Вы погибли. Ресурсы остались в рюкзаке на месте гибели.")
	g.changed.emit()

func respawn():
	var p=g.player
	p.x=p.respawn.x; p.z=p.respawn.z
	p.hp=100; p.stamina=100; p.hunger=65; p.invulnerable=8
	p.dead=false; p.swimming=false; p.sailing=false
	p.shipId=""; p.cartId=""; p.targetId=""; p.autoBattle=false
	p.actionUntil=0; p.staggerUntil=0; p.guardUntil=0
	p["dodge"]={}; p["dodgeUntil"]=0; p.actionState="idle"
	p.y=g.height_at(p.x,p.z)
	g.state["raid"]={}
	g.notify("Вы вернулись в лагерь. Инструменты сохранены.")

func alert_settlement(owner: String):
	for n in g.state.npcs:
		if n.get("home","")==owner and n.get("alive",true): n.hostile=max(n.get("hostile",0),90.0)
	for s in g.state.ships:
		if s.owner==owner: s.hostile=90.0

func start_raid(id: String) -> bool:
	var p=g.player
	var b=g.entity(id)
	if b.is_empty() or b.get("entity_kind","")!="buildings" or b.get("type","") not in ["warehouse","granary"] or b.hp<=0 or b.owner=="player" or p.dead or p.sailing or not g.state.pvp or g.distance(p,b)>10:
		g.notify("Подойдите к чужому складу и включите свободный бой.")
		return false
	g.state["raid"]={"id":id,"left":3.0,"total":3.0,"x":p.x,"z":p.z,"hp":p.hp}
	p.autoBattle=false
	alert_settlement(b.owner)
	p.karma=clamp(p.karma-12,-100,100)
	g.effect.emit("raid",g.point(p,1))
	record_event("raid",p)
	g.notify("Взлом склада: удерживайте позицию 3 секунды. Карма −12.")
	return true

func fire_ship(s: Dictionary, weapon: String, target: Dictionary = {}) -> bool:
	if s.is_empty() or s.get("hp",0)<=0: return false
	var d=g.catalog.SHIPS.get(s.kind,{})
	var def=g.catalog.NAVAL_WEAPONS.get(weapon,{})
	if def.is_empty() or d.get("cannons" if weapon=="cannon" else "ballistas",0)<=0 or s.get("cooldowns",{}).get(weapon,0)>g.state.time: return false
	var own=s.owner=="player"
	var enemy=target if not target.is_empty() else g.entity(g.player.get("targetId","")) if own else {}
	if not enemy.is_empty() and (enemy.get("entity_kind","")!="ships" or not can_attack(enemy,"player" if own else s.id) or g.distance(s,enemy)>def.range): return false
	if s.get("escortTaskId","")!="":
		for key in def.cost:
			if s.store.get(key,0)<def.cost[key]:
				for task in g.state.get("tasks",[]):
					if task.id==s.escortTaskId: task.reason="В трюме эскорта закончились боеприпасы"
				return false
	var stores=[s.store,g.player.inventory] if own else [s.store]
	for key in def.cost:
		var available=0
		for store in stores: available+=store.get(key,0)
		if available<def.cost[key]:
			if own: g.notify("Нет боеприпасов: "+("2 камня и 1 уголь" if weapon=="cannon" else "1 дерево и 1 камень")+".")
			return false
	for key in def.cost:
		var left=def.cost[key]
		for store in stores:
			var take=min(left,store.get(key,0)); store[key]=store.get(key,0)-take; left-=take
	s["cooldowns"]=s.get("cooldowns",{})
	s.cooldowns[weapon]=g.state.time+def.delay
	s["shot"]=0.35
	var yaw=atan2(enemy.x-s.x,enemy.z-s.z) if not enemy.is_empty() else s.yaw
	s["gunYaw"]=yaw
	var origin={"x":s.x+sin(yaw)*d.beam*0.55,"z":s.z+cos(yaw)*d.beam*0.55,"y":d.deck+1.2,"yaw":yaw,"owner":"player" if own else s.id,"projectileOrigin":true}
	spawn_projectile(origin,enemy,def.damage,def.speed,weapon,def.range)
	g.effect.emit(weapon,Vector3(origin.x,origin.y,origin.z))
	g.changed.emit()
	return true

func spawn_projectile(a: Dictionary,b: Dictionary,amount: float,speed: float,kind: String,reach: float,delay=0.0):
	var y=a.get("y",g.height_at(a.x,a.z))+1.4
	if a.get("projectileOrigin",false): y=a.y
	elif a.get("entity_kind","")=="ships": y=g.catalog.SHIPS[a.kind].deck+1.2
	var start=Vector3(a.x,y,a.z)
	var tx=b.get("x",a.x+sin(a.get("yaw",0))*reach)
	var tz=b.get("z",a.z+cos(a.get("yaw",0))*reach)
	var ty=1.5 if b.get("entity_kind","")=="ships" else max(0.3,g.height_at(tx,tz))+1 if not b.is_empty() else 0.5
	var finish=Vector3(tx,ty,tz)
	var duration=min(reach/speed,max(0.1,Vector2(tx-a.x,tz-a.z).length()/speed))
	g.projectiles.append({"id":g.uid("projectile"),"pos":start,"velocity":(finish-start).normalized()*speed,"from":start,"to":finish,"elapsed":-delay,"duration":duration,"arc":8.0 if kind=="cannon" else 2.0 if kind=="ballista" else 1.0,"target":b.get("id",""),"damage":amount,"kind":kind,"source":a.get("owner","player"),"life":duration+delay})

func sink_ship(s: Dictionary):
	if s.get("sunk",false): return
	s.hp=0; s.speed=0; s["sunk"]=true; s["sunkAt"]=g.state.time; s["deathAt"]=g.state.time
	s["respawnAt"]=0 if s.owner=="player" else g.state.time+180
	_drop(s,s.store,"Плавающий груз · "+s.get("name",g.catalog.SHIPS[s.kind].name),900,true)
	s.store=g.blank()
	if g.player.shipId==s.id:
		g.player.shipId=""; g.player.sailing=false
		hurt(35)
		g.player.swimming=not g.player.dead and g.height_at(g.player.x,g.player.z)<-1.05
		g.notify("Судно затонуло. Груз можно подобрать в воде.")
	for n in g.state.npcs:
		if n.get("shipId","")==s.id: n.shipId=""; n.x=s.x; n.z=s.z
	g.state.stats["shipsSunk"]=g.state.stats.get("shipsSunk",0)+1
	g.effect.emit("sink",Vector3(s.x,0,s.z))
	record_event("sink",s)

func water_clear(x: float,z: float,radius=1.0) -> bool:
	if abs(x)>=g.catalog.LIMITS.world-12 or abs(z)>=g.catalog.LIMITS.world-12: return false
	for offset in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
		if g.height_at(x+offset.x,z+offset.y)>=-0.55: return false
	return true

func move_ship(s: Dictionary,yaw: float,throttle: float,dt: float):
	if s.is_empty() or s.get("hp",0)<=0: return
	var d=g.catalog.SHIPS[s.kind]
	var difference=angle_difference(s.yaw,yaw)
	s.yaw+=clamp(difference,-d.turn*dt,d.turn*dt)
	s.speed=lerp(float(s.speed),float(throttle*d.speed),min(1.0,dt*0.65))
	var x=s.x+sin(s.yaw)*s.speed*dt
	var z=s.z+cos(s.yaw)*s.speed*dt
	var front=Vector2(x+sin(s.yaw)*d.length*0.36,z+cos(s.yaw)*d.length*0.36)
	if water_clear(x,z,d.beam*0.45) and water_clear(front.x,front.y,d.beam*0.25): s.x=x; s.z=z
	else:
		s.speed*=0.4
		if s.owner!="player": s["route"]=[]; s["wait"]=1.0

func prepare_input(dt: float, input: Dictionary) -> Dictionary:
	var p=g.player
	var result=input.duplicate()
	var move: Vector2=input.get("move",Vector2.ZERO)
	p["dodgeAim"]=atan2(move.x,move.y) if move.length()>0.1 else p.yaw
	if p.dead: return result
	var dodge=p.get("dodge",{})
	if not dodge.is_empty() and dodge.get("left",0)>0:
		dodge.left-=dt
		var q={"x":p.x+sin(dodge.yaw)*18*dt,"z":p.z+cos(dodge.yaw)*18*dt}
		if g.height_at(q.x,q.z)>0.3 and not g.blocked(q): p.x=q.x; p.z=q.z
	if p.get("staggerUntil",0)>g.state.time:
		result.move=Vector2.ZERO; result.jump=false
		return result
	if p.autoBattle and current_ship().is_empty():
		var e=g.entity(p.targetId)
		if not can_attack(e): p.targetId=""; e=cycle_target()
		if not e.is_empty() and g.distance(p,e)<75:
			var dist=g.distance(p,e)
			if dist<=g.catalog.TOOLS.get(p.tool,{}).get("reach",3): attack()
			elif move.length()<0.08 and g.height_at(e.x,e.z)>0.3:
				result.move=Vector2(e.x-p.x,e.z-p.z).normalized()
	return result

func resolve(dt: float):
	var p=g.player
	for hit in g.strikes.duplicate():
		hit.left-=dt
		if hit.left>0: continue
		g.strikes.erase(hit)
		if p.dead or p.get("staggerUntil",0)>g.state.time or g.distance(p,hit)>1.8 or p.tool!=hit.tool: continue
		var landed=0
		var pool=g.state.animals+g.state.npcs+g.state.creatures if hit.get("sweep",false) else [g.entity(hit.target)]
		for e in pool:
			if not can_attack(e): continue
			var dist=g.distance(p,e)
			var dot=((e.x-p.x)*sin(hit.yaw)+(e.z-p.z)*cos(hit.yaw))/max(dist,0.00001)
			if dist>hit.reach+0.25 or (dist>0.55 and dot<hit.arc) or abs(g.height_at(e.x,e.z)-g.height_at(p.x,p.z))>2.8 or not clear_shot(p,e): continue
			if damage(e,hit.damage,"player",hit.heavy,"heavy" if hit.heavy else hit.tool): landed+=1
		if landed==0:
			g.effect.emit("miss",g.point(p,1.6))
			record_event("miss",p)
	_resolve_projectiles(dt)
	_update_ships(dt)
	var raid=g.state.get("raid",{})
	if not raid.is_empty():
		var b=g.entity(raid.id)
		if b.is_empty() or b.hp<=0 or p.dead or g.distance(p,raid)>1 or p.hp<raid.hp or g.distance(p,b)>10: g.state.raid={}
		else:
			raid.left-=dt
			if raid.left<=0.000001:
				b["raidOpenUntil"]=g.state.time+45
				g.effect.emit("raidOpen",g.point(b,1))
				record_event("raidOpen",b)
				g.state.raid={}
				g.notify("Склад открыт на 45 секунд. Заберите припасы.")
	if p.get("targetId","")!="":
		var target=g.entity(p.targetId)
		if target.is_empty() or target.get("hp",0)<=0 or not target.get("alive",true) or g.distance(p,target)>(230 if not current_ship().is_empty() else 85): p.targetId=""; p.autoBattle=false

func _resolve_projectiles(dt: float):
	for shot in g.projectiles.duplicate():
		shot.elapsed+=dt
		shot.life=max(0,shot.duration-shot.elapsed)
		if shot.elapsed<0: continue
		var fraction=clamp(shot.elapsed/shot.duration,0.0,1.0)
		var target=g.player if shot.target=="player" else g.entity(shot.target)
		if not target.is_empty() and (target.get("hp",0)<=0 or not target.get("alive",true)): target={}
		if shot.kind=="arrow" and not target.is_empty():
			shot.to.x=lerp(shot.to.x,float(target.x),min(1.0,dt*3))
			shot.to.z=lerp(shot.to.z,float(target.z),min(1.0,dt*3))
		var old: Vector3=shot.pos
		shot.pos=shot.from.lerp(shot.to,fraction)+Vector3.UP*sin(fraction*PI)*shot.arc
		if old.distance_to(shot.pos)>0.00001: shot.velocity=(shot.pos-old)/max(dt,0.00001)
		var at={"x":shot.pos.x,"z":shot.pos.z}
		var origin={"x":shot.from.x,"z":shot.from.z}
		if shot.pos.y<g.height_at(shot.pos.x,shot.pos.z)+0.1 or (shot.kind=="arrow" and not clear_shot(origin,at)):
			g.projectiles.erase(shot); g.effect.emit("impact",shot.pos); continue
		var direct=false
		if not target.is_empty():
			if target.get("entity_kind","")=="ships": direct=g.distance(at,target)<g.catalog.SHIPS[target.kind].length*0.4 and shot.pos.y<g.catalog.SHIPS[target.kind].deck+3
			else: direct=fraction>=1 and g.distance(at,target)<2.2
		if direct:
			damage(target,shot.damage,shot.source,shot.kind=="cannon",shot.kind)
			g.projectiles.erase(shot)
		elif fraction>=1:
			g.projectiles.erase(shot); g.effect.emit("impact",shot.pos)

func _update_ships(dt: float):
	for s in g.state.ships:
		if s.hp<=0:
			s.fire=max(0,s.get("fire",0)-dt*0.08)
			if s.get("respawnAt",0)>0 and g.state.time>s.respawnAt:
				var port=g.ai.port_point(s.get("home",g.catalog.ISLANDS[0].id))
				s.x=port.x; s.z=port.z; s.hp=s.maxHp; s["alive"]=true; s["sunk"]=false
				s["route"]=[]; s.wait=15; s.respawnAt=0; s.hostile=0; s["state"]="idle"
				s.store.wood=35; s.store.stone=60; s.store.coal=20
			continue
		s.hostile=max(0,s.get("hostile",0)-dt)
		s["shot"]=max(0,s.get("shot",0)-dt)
		if s.owner!="player":
			var enemy={}
			var best=185.0
			for other in g.state.ships:
				if other.hp<=0 or other.id==s.id: continue
				var hostile=(s.get("role","")=="pirate" and other.owner!="pirates") or (s.get("role","")!="pirate" and other.owner=="pirates") or (s.hostile>0 and other.owner=="player")
				if hostile and g.distance(s,other)<best: enemy=other; best=g.distance(s,other)
			if not enemy.is_empty():
				fire_ship(s,"ballista",enemy)
				if g.catalog.SHIPS[s.kind].get("cannons",0)>0: fire_ship(s,"cannon",enemy)
		if s.get("fire",0)>0:
			s.fire=max(0,s.fire-dt*0.006)
			s["fireTick"]=s.get("fireTick",0)+dt
			if s.fireTick>=1:
				s.fireTick-=1
				s.hp=max(0,s.hp-s.fire*1.5)
				if s.hp<=0: sink_ship(s)

func enemy_attack(actor: Dictionary, dt: float) -> bool:
	var type=actor.get("entity_kind","")
	var p=g.player
	if not actor.get("alive",true):
		if g.state.time>=actor.get("respawn",INF):
			actor.hp=actor.maxHp; actor.alive=true; actor.hostile=0; actor.state="idle"; actor.strike={}; actor.cooldown=0
			var origin=actor.get("origin",actor)
			if type=="npcs":
				for settlement in g.state.settlements:
					if settlement.id==actor.home: origin={"x":settlement.x-7,"z":settlement.z+6}; break
				actor.carry=g.blank()
				if actor.get("ally",false): actor.order={"type":"follow"}
			actor.x=origin.x; actor.z=origin.z
		return true
	if actor.get("staggerUntil",0)>g.state.time: actor.state="hit"; return true
	actor.cooldown=max(0,actor.get("cooldown",0)-dt)
	actor.hostile=max(0,actor.get("hostile",0)-dt)
	actor["speed"]=0.0
	var hit=actor.get("strike",{})
	if not hit.is_empty():
		hit.left-=dt
		if hit.left<=0:
			actor.strike={}
			var dist=g.distance(actor,p)
			var dot=((p.x-actor.x)*sin(hit.get("yaw",actor.yaw))+(p.z-actor.z)*cos(hit.get("yaw",actor.yaw)))/max(dist,0.00001)
			if not p.dead and not p.sailing and dist<=hit.reach and (type=="creatures" or dist<0.5 or dot>0.3) and clear_shot(actor,p):
				hurt(hit.damage,actor)
				if type=="creatures": g.effect.emit("fire" if actor.kind=="dragon" else "monsterHit",g.point(actor,2))
	var dist=g.distance(actor,p)
	if type=="npcs":
		if actor.get("ally",false) or actor.home=="player": return false
		if actor.role=="guard" and p.karma<=-50 and dist<30 and not p.dead: actor.hostile=5
		if actor.hostile>0 and not p.dead:
			actor.yaw=atan2(p.x-actor.x,p.z-actor.z)
			if dist<2.2:
				actor.state="attack"
				if actor.cooldown<=0: actor.strike={"left":0.55 if actor.role=="guard" else 0.42,"damage":15 if actor.role=="guard" else 9,"reach":2.35,"yaw":actor.yaw}; actor.cooldown=1.65
			else: actor.state="run"; g.ai.move_actor(actor,p,5.5 if actor.role=="guard" else 4.8,dt)
			return true
		return false
	var def=g.catalog.CREATURES[actor.kind] if type=="creatures" else g.catalog.ANIMALS[actor.kind]
	if type=="creatures":
		var hunt=not p.dead and not p.sailing and not p.swimming and g.distance(actor,actor.origin)<80 and (dist<def.aggro or (actor.hostile>0 and dist<40))
		if not hunt: return false
		actor.yaw=atan2(p.x-actor.x,p.z-actor.z)
		var breath=actor.kind=="dragon" and dist>7 and dist<16 and actor.cooldown<=0
		if dist<def.reach or breath:
			actor.state="attack"
			if actor.cooldown<=0:
				actor.cooldown=3.8 if actor.kind=="dragon" else 2.2
				actor.strike={"left":0.65,"reach":17 if breath else def.reach+1,"damage":def.damage,"yaw":actor.yaw}
				g.effect.emit("monsterWindup",g.point(actor,def.height))
		else: actor.state="run"; g.ai.move_actor(actor,p,def.speed,dt)
		return true
	if not p.dead and ((actor.kind=="wolf" and dist<12) or (actor.kind=="bear" and dist<7) or actor.hostile>0) and def.damage>0:
		actor.hostile=max(2,actor.hostile)
		actor.state="attack"
		if dist>1.9: g.ai.move_actor(actor,p,def.speed,dt)
		elif actor.cooldown<=0:
			actor.strike={"left":0.62 if actor.kind=="bear" else 0.35,"damage":def.damage,"reach":2.15,"yaw":atan2(p.x-actor.x,p.z-actor.z)}
			actor.cooldown=1.7
		return true
	if not p.dead and ((def.damage==0 and dist<11) or (actor.kind=="boar" and dist<5)):
		actor.state="run"
		g.ai.move_actor(actor,{"x":actor.x+(actor.x-p.x),"z":actor.z+(actor.z-p.z)},def.speed,dt)
		return true
	return false
