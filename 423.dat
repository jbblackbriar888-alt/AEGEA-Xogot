extends CanvasLayer
## Native Control UI: mobile HUD, bag grid, equipment preview and functional menus.
var world
var root: Control
var panel: PanelContainer
var modal_backdrop: ColorRect
var death_panel: PanelContainer
var walk_button: Button
var sprint_button: Button
var numeric_vitals: Label
var save_status: Label
var content: VBoxContainer
var panel_title: Label
var status: Label
var context: Label
var toast: Label
var ship_status: Label
var target_status: Label
var hp: ProgressBar
var stamina: ProgressBar
var hunger: ProgressBar
var joystick
var jump_requested=false
var build_bar: HBoxContainer
var build_status: Label
var timer=0.0
var toast_time=0.0
var current_page=""
var current_id=""
var bag_filter="all"
var bag_sort="type"
var item_info=true
var squad_member="all"
var squad_source=""
var squad_ship=""
var squad_building="campfire"
var barter_source="bag"
var attack_held=false
var gather_held=false
var hold_clock=0.0
var jump_button: Button
var hold_pointers: Dictionary={}
var attack_button: Button
var gather_button: Button
var heal_button: Button
var pvp_button: Button
var sound_button: Button
var boat_button: Button
var clear_target_button: Button
var snap_button: Button
var naval_controls: VBoxContainer
var naval_buttons: Dictionary={}
var skill_buttons: Dictionary={}
var quick_buttons: Array=[]
var damage_labels: Array=[]
var last_combat_event=0
var live_labels: Array=[]
var settlement_snapshot: Dictionary={}
var cart_button: Button
var raid_status: Label
var shortcut_status: Label
var building_filter="Все"
var squad_resource="wood"
var basic_resource="wood"
var squad_quantity=100
var squad_destination=""
var cargo_from="bag"
var cargo_to=""
var trade_count=1
var team_build=false
var preview: Node3D
var preview_drag=false
var ui_theme: Theme
var navigation: HFlowContainer
var auto_button: Button

func _ready():
	ui_theme=Theme.new()
	ui_theme.default_font=load("res://assets/Interface.ttf")
	ui_theme.default_font_size=17
	ui_theme.set_stylebox("normal","Button",style(Color("202c31"),Color("5d635b"),5))
	ui_theme.set_stylebox("hover","Button",style(Color("344449"),Color("d9ba7c"),5))
	ui_theme.set_stylebox("pressed","Button",style(Color("51462d"),Color("efc980"),5))
	ui_theme.set_stylebox("panel","PanelContainer",style(Color(0.065,0.095,0.12,0.97),Color("736750"),8))
	ui_theme.set_color("font_color","Label",Color("e4dfce"))
	ui_theme.set_color("font_color","Button",Color("e4dfce"))
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.theme=ui_theme
	add_child(root)
	_make_hud()
	_make_panel()
	Game.message.connect(func(text): toast.text=text; toast_time=5.0)
	Game.changed.connect(func(): timer=0.2)
	get_viewport().size_changed.connect(_resize)
	_resize()

func style(fill: Color,line: Color,roundness=0) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=fill
	s.border_color=line
	s.set_border_width_all(1)
	s.set_corner_radius_all(roundness)
	s.content_margin_left=10; s.content_margin_right=10
	s.content_margin_top=8; s.content_margin_bottom=8
	return s

func button(parent: Node,text: String,call: Callable,width=0) -> Button:
	var b=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(width,43)
	b.focus_mode=Control.FOCUS_ALL if panel!=null and (parent==panel or panel.is_ancestor_of(parent)) else Control.FOCUS_NONE
	b.pressed.connect(call)
	parent.add_child(b)
	return b

func label(parent: Node,text: String,font_size=17) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",font_size)
	parent.add_child(l)
	return l

func paragraph(text: String):
	var l=label(content,text,16)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x=470

func live_paragraph(get_text: Callable) -> Label:
	var l=label(content,str(get_text.call()),16)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x=470
	live_labels.append({"node":l,"read":get_text})
	return l

func row(parent: Node) -> HBoxContainer:
	var r=HBoxContainer.new()
	r.add_theme_constant_override("separation",8)
	parent.add_child(r)
	return r

func _make_hud():
	var top=VBoxContainer.new()
	top.name="Vitals"
	top.position=Vector2(35,20)
	top.custom_minimum_size.x=260
	root.add_child(top)
	label(top,"Λ  AEGEA",27)
	label(top,"XOGOT  ·  НАТИВНЫЙ ПРОТОТИП",11)
	hp=_bar(top,Color("a74137"))
	stamina=_bar(top,Color("b09846"))
	hunger=_bar(top,Color("538b77"))
	numeric_vitals=label(top,"",12)
	status=label(top,"",13)
	navigation=HFlowContainer.new()
	navigation.custom_minimum_size.x=595
	navigation.size.x=595
	navigation.name="Navigation"
	root.add_child(navigation)
	for item in [["Сумка · I","bag"],["Строить · B","build"],["Ремесло · C","craft"],["Отряд · P","squad"],["Меню","menu"],["Поселение · N","settlement"],["Торговля · J","economy"],["Флот · L","fleet"]]:
		button(navigation,item[0],func(): show_page(item[1]),88)
	var minimap=preload("res://scripts/map.gd").new()
	minimap.name="Minimap"
	minimap.compact=true
	minimap.custom_minimum_size=Vector2(144,144)
	minimap.size=Vector2(144,144)
	minimap.mouse_filter=Control.MOUSE_FILTER_STOP
	minimap.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: show_page("map"))
	root.add_child(minimap)
	joystick=preload("res://scripts/joystick.gd").new()
	joystick.name="Joystick"
	joystick.size=Vector2(180,180)
	root.add_child(joystick)
	var actions=VBoxContainer.new()
	actions.name="Actions"
	root.add_child(actions)
	var movement=row(actions)
	walk_button=button(movement,"Шаг · Alt",func(): Game.player.mode="jog" if Game.player.mode=="walk" else "walk",78)
	sprint_button=button(movement,"Бег · Shift",func(): Game.player.mode="jog" if Game.player.mode=="sprint" else "sprint",78)
	jump_button=button(movement,"Прыжок ␣",func(): jump_requested=true,94)
	var skills=row(actions)
	for item in [["power","Мощный · Q"],["sweep","Круговой · R"],["guard","Защита · G"]]:
		skill_buttons[item[0]]=button(skills,item[1],func(): Game.skill(item[0]),82)
	var combat=row(actions)
	skill_buttons["dodge"]=button(combat,"Уклон · T",func(): Game.skill("dodge"),95)
	button(combat,"Цель · Z",func(): Game.cycle_target(),72)
	attack_button=button(combat,"УДАР · F",func(): pass,88)
	attack_button.custom_minimum_size.y=58
	attack_button.button_down.connect(func(): _begin_hold("attack"))
	attack_button.button_up.connect(func(): attack_held=false)
	var interact_row=row(actions)
	gather_button=button(interact_row,"Действие · E",func(): pass,138)
	gather_button.button_down.connect(func(): _begin_hold("gather"))
	gather_button.button_up.connect(func(): gather_held=false)
	auto_button=button(interact_row,"Автобой · Y",func(): Game.player.autoBattle=not Game.player.autoBattle,120)
	var utilities=row(actions)
	heal_button=button(utilities,"Поесть",func(): Game.eat(),82)
	pvp_button=button(utilities,"Мирный",func(): Game.state.pvp=not Game.state.pvp,95)
	boat_button=button(utilities,"На борт · V",_toggle_boat,105)
	var quick=HBoxContainer.new()
	quick.name="Quickbar"
	root.add_child(quick)
	for i in 5:
		var b=button(quick,"",func(): _equip_quick(i),85)
		b.add_theme_font_size_override("font_size",13)
		quick_buttons.append(b)
	context=Label.new()
	context.name="Context"
	context.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	context.add_theme_font_size_override("font_size",15)
	root.add_child(context)
	toast=Label.new()
	toast.name="Toast"
	toast.add_theme_font_size_override("font_size",15)
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast)
	target_status=Label.new()
	target_status.name="Target"
	target_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(target_status)
	clear_target_button=button(root,"×",func(): Game.player.targetId=""; Game.player.autoBattle=false,38)
	clear_target_button.tooltip_text="Снять выделение цели"
	sound_button=button(root,"♫",func(): world.set_sound(not world.audio_on,world.music_on),46)
	sound_button.tooltip_text="Включить / выключить звук"
	shortcut_status=label(root,"",12)
	shortcut_status.name="WorldStatus"
	save_status=label(root,"ЛОКАЛЬНЫЙ МИР · АВТОСОХРАНЕНИЕ",11)
	save_status.name="SaveStatus"
	ship_status=Label.new()
	ship_status.name="ShipStatus"
	root.add_child(ship_status)
	naval_controls=VBoxContainer.new()
	root.add_child(naval_controls)
	var weapons=row(naval_controls)
	for key in Game.catalog.NAVAL_WEAPONS:
		naval_buttons[key]=button(weapons,Game.catalog.NAVAL_WEAPONS[key].name,func(): Game.player.navalWeapon=key,100)
	var ship_actions=row(naval_controls)
	button(ship_actions,"Трюм",func(): cargo_from=Game.player.shipId; cargo_to="bag"; show_page("cargo"),100)
	button(ship_actions,"За борт",func(): Game.disembark(),100)
	cart_button=button(root,"",func(): cargo_from=Game.player.cartId; cargo_to="bag"; show_page("cargo"),200)
	raid_status=label(root,"",16)
	build_bar=HBoxContainer.new()
	build_bar.name="BuildBar"
	root.add_child(build_bar)
	button(build_bar,"Поставить",func(): world.confirm_build(),110)
	button(build_bar,"Повернуть · R",func(): world.build_yaw+=PI/4,110)
	snap_button=button(build_bar,"Сетка: ВКЛ",func(): world.build_snap=not world.build_snap; Game.player.buildSnap=world.build_snap,110)
	button(build_bar,"Отмена",func(): world.cancel_build(),90)
	build_status=label(build_bar,"",14)
	build_bar.visible=false

func _bar(parent: Node,color: Color) -> ProgressBar:
	var bar=ProgressBar.new()
	bar.custom_minimum_size=Vector2(260,18)
	bar.show_percentage=false
	bar.max_value=100
	bar.add_theme_stylebox_override("fill",style(color,color))
	bar.add_theme_stylebox_override("background",style(Color("283138"),Color("66675c")))
	parent.add_child(bar)
	return bar

func _make_panel():
	modal_backdrop=ColorRect.new()
	modal_backdrop.name="ModalBackdrop"
	modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.color=Color(0,0,0,0.2)
	modal_backdrop.mouse_filter=Control.MOUSE_FILTER_STOP
	modal_backdrop.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed: close_panel(); modal_backdrop.accept_event()
	)
	root.add_child(modal_backdrop)
	modal_backdrop.hide()
	panel=PanelContainer.new()
	panel.name="SidePanel"
	root.add_child(panel)
	var layout=VBoxContainer.new()
	panel.add_child(layout)
	var header=row(layout)
	panel_title=label(header,"",24)
	panel_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(header,"×",close_panel,48)
	var scroll=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	scroll.add_child(content)
	panel.hide()
	_make_death_panel()

func _make_death_panel():
	death_panel=PanelContainer.new()
	death_panel.name="DeathPanel"
	root.add_child(death_panel)
	var box=VBoxContainer.new()
	death_panel.add_child(box)
	label(box,"Вы пали",26)
	label(box,"Ресурсы остались на месте гибели.\nИнструменты сохранены.",17)
	button(box,"Возродиться в лагере",func(): Game.respawn(); Game.save_game(false); close_panel())
	death_panel.hide()

func _resize():
	if root==null: return
	var size=get_viewport().get_visible_rect().size
	navigation.position=Vector2(max(335,size.x-805),20)
	root.get_node("Minimap").position=Vector2(size.x-174,120)
	joystick.position=Vector2(30,size.y-232)
	root.get_node("Actions").position=Vector2(size.x-345,size.y-290)
	root.get_node("Quickbar").position=Vector2(size.x*0.5-225,size.y-60)
	save_status.position=Vector2(35,size.y-35)
	context.position=Vector2(size.x*0.5-270,size.y-94)
	context.size.x=540
	toast.position=Vector2(220,size.y-128)
	toast.size.x=size.x-550
	target_status.position=Vector2(size.x*0.5-210,118)
	target_status.size.x=420
	clear_target_button.position=Vector2(size.x*0.5+205,118)
	sound_button.position=Vector2(310,20)
	shortcut_status.position=Vector2(35,190)
	ship_status.position=Vector2(35,245)
	naval_controls.position=Vector2(35,320)
	cart_button.position=Vector2(35,245)
	raid_status.position=Vector2(size.x*0.5-180,165)
	build_bar.position=Vector2(230,size.y-185)
	panel.position=Vector2(max(20,size.x-720),78)
	panel.size=Vector2(min(680,size.x-40),max(250,size.y-162))
	death_panel.position=(size-Vector2(410,190))*0.5
	death_panel.size=Vector2(410,190)

func _layout_status_blocks():
	if root==null or status==null: return
	var vitals=root.get_node("Vitals")
	shortcut_status.position=Vector2(35,vitals.position.y+vitals.size.y+8)
	var cargo_y=shortcut_status.position.y+shortcut_status.size.y+12
	ship_status.position=Vector2(35,cargo_y)
	cart_button.position=Vector2(35,cargo_y)
	naval_controls.position=Vector2(35,cargo_y+ship_status.size.y+8)
	var viewport_size=get_viewport().get_visible_rect().size
	var actions=root.get_node("Actions")
	actions.position=Vector2(viewport_size.x-actions.size.x-30,viewport_size.y-actions.size.y-90)
	var quick=root.get_node("Quickbar")
	quick.position=Vector2((viewport_size.x-quick.size.x)*0.5,viewport_size.y-quick.size.y-17)

func input_state() -> Dictionary:
	var movement=joystick.value
	if not panel.visible:
		movement+=Vector2((1 if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) else 0)-(1 if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) else 0),(1 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) else 0)-(1 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) else 0))
	var jump=jump_requested
	jump_requested=false
	return {"move":movement.limit_length() if not panel.visible else Vector2.ZERO,"jump":jump}

func _input(event):
	# Own each hold finger through release; a joystick/camera finger cannot steal it.
	if event is InputEventScreenTouch:
		if not event.pressed and hold_pointers.has(event.index):
			var kind=hold_pointers[event.index]
			hold_pointers.erase(event.index)
			if kind=="attack": attack_held=false
			if kind=="gather": gather_held=false
			get_viewport().set_input_as_handled()
			return
		if not event.pressed or panel.visible: return
		for entry in [[attack_button,"attack"],[gather_button,"gather"],[jump_button,"jump"]]:
			var control=entry[0]
			if control.disabled or not control.is_visible_in_tree() or not control.get_global_rect().has_point(event.position): continue
			if hold_pointers.values().has(entry[1]): return
			hold_pointers[event.index]=entry[1]
			if entry[1]=="jump": jump_requested=true
			else: _begin_hold(entry[1])
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventScreenDrag and hold_pointers.has(event.index):
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event):
	if not event is InputEventKey: return
	if not event.pressed:
		if event.physical_keycode==KEY_F: attack_held=false
		if event.physical_keycode==KEY_E: gather_held=false
		return
	if event.echo: return
	if event.physical_keycode==KEY_ESCAPE:
		if panel.visible: close_panel()
		elif world.build_type!="": world.cancel_build()
		else: show_page("settings")
		get_viewport().set_input_as_handled()
		return
	if panel.visible: return
	var menu_keys={KEY_I:"bag",KEY_TAB:"bag",KEY_B:"build",KEY_C:"craft",KEY_M:"map",KEY_K:"karma",KEY_H:"help",KEY_L:"fleet",KEY_N:"settlement",KEY_J:"economy",KEY_P:"squad"}
	if menu_keys.has(event.physical_keycode): show_page(menu_keys[event.physical_keycode]); get_viewport().set_input_as_handled(); return
	match event.physical_keycode:
		KEY_1,KEY_2,KEY_3,KEY_4,KEY_5: _equip_quick(event.physical_keycode-KEY_1)
		KEY_E: _begin_hold("gather")
		KEY_F: _begin_hold("attack")
		KEY_Q: if world.build_type=="": Game.skill("power")
		KEY_R:
			if world.build_type!="": world.build_yaw+=PI/4
			else: Game.skill("sweep")
		KEY_G: if world.build_type=="": Game.skill("guard")
		KEY_T: if world.build_type=="": Game.skill("dodge")
		KEY_Z: Game.cycle_target()
		KEY_Y: Game.player.autoBattle=not Game.player.autoBattle
		KEY_V: _toggle_boat()
		KEY_ENTER,KEY_KP_ENTER: if world.build_type!="": world.confirm_build()
		KEY_SPACE: jump_requested=true

func _quick_tool(index: int) -> String:
	if index==4 and Game.catalog.TOOLS.get(Game.player.tool,{}).get("ranged",false): return Game.player.tool
	return ["spear","axe","pickaxe","sword","bow"][index]

func _equip_quick(index: int):
	if not Game.equip(_quick_tool(index)): show_page("craft")

func _toggle_boat():
	if Game.player.shipId!="": Game.disembark(); return
	var nearest={}
	var distance=INF
	for ship in Game.state.ships:
		if ship.owner!="player" or ship.hp<=0: continue
		var d=Game.distance(ship,Game.player)
		if d<distance: nearest=ship; distance=d
	if not nearest.is_empty() and distance<=Game.catalog.SHIPS[nearest.kind].length*0.55+6:
		Game.board(nearest.id)
	else: Game.toggle_raft()

func reset_controls():
	Game.player.mode="jog"
	hold_pointers.clear()
	attack_held=false; gather_held=false; jump_requested=false
	preview_drag=false
	if joystick!=null: joystick.reset()

func _begin_hold(kind: String):
	if panel.visible or Game.player.dead: return
	if kind=="attack":
		if world.build_type!="": return
		attack_held=true
		world.attack_action()
	else:
		gather_held=true
		interact()
	hold_clock=Game.state.time

func _update_held_actions(_dt: float):
	if panel.visible or Game.player.dead: attack_held=false; gather_held=false; return
	if attack_held and world.build_type=="": world.attack_action()
	if gather_held and Game.state.time-hold_clock>0.8:
		hold_clock=Game.state.time
		interact()

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: reset_controls()

func _process(dt):
	_layout_status_blocks()
	_update_combat_feedback(dt)
	_update_held_actions(dt)
	timer+=dt
	toast_time-=dt
	toast.visible=toast_time>0
	if timer<0.2: return
	timer=0
	if current_page=="settlement": settlement_snapshot=Game.settlement_summary()
	for entry in live_labels:
		if is_instance_valid(entry.node): entry.node.text=str(entry.read.call())
	hp.value=Game.player.hp
	stamina.value=Game.player.stamina
	hunger.value=Game.player.hunger
	var saved_time=FileAccess.get_modified_time(Game.SAVE)
	save_status.text="СОХРАНЕНО · "+Time.get_time_string_from_unix_time(saved_time) if saved_time>0 else "ЛОКАЛЬНЫЙ МИР · АВТОСОХРАНЕНИЕ"
	numeric_vitals.text="Здоровье %d · Силы %d · Сытость %d" % [Game.player.hp,Game.player.stamina,Game.player.hunger]
	death_panel.visible=Game.player.dead
	if Game.player.dead: reset_controls()
	var island=Game.island_at(Game.player)
	status.text="%s · День %d\n%.1f / 120 кг · Карма %d\n%s · %d FPS" % [island.get("name","Эгейское море"),1+int(Game.state.time/1200),Game.weight(Game.player.inventory,Game.player.tools),Game.player.karma,{"jog":"Бег","walk":"Ходьба","sprint":"Быстрый бег"}.get(Game.player.mode,"Бег"),Engine.get_frames_per_second()]
	context.text=Game.label(Game.nearest())
	var target=Game.entity(Game.player.targetId)
	target_status.text="%s  ·  %d / %d" % [Game.label(target),target.get("hp",0),target.get("maxHp",100)] if not target.is_empty() else ""
	var ship=Game.entity(Game.player.shipId)
	ship_status.text="%s\n%d / %d  ·  %.1f м/с\n%s · E — управление" % [Game.label(ship),ship.hp,ship.maxHp,ship.speed,Game.catalog.NAVAL_WEAPONS[Game.player.navalWeapon].name] if not ship.is_empty() else ""
	_update_action_status(ship,target)
	# Preview orientation stays where the player places it; rotate with touch/mouse/arrows.

func _update_combat_feedback(dt: float):
	for entry in damage_labels.duplicate():
		entry.age+=dt
		if entry.age>=1.05 or not is_instance_valid(entry.label):
			if is_instance_valid(entry.label): entry.label.queue_free()
			damage_labels.erase(entry)
			continue
		entry.label.position=entry.origin+Vector2(-35,-entry.age*55)
		entry.label.modulate.a=clampf((1.05-entry.age)/0.35,0,1)
	var combat=Game.get("combat")
	if combat==null: return
	var events=combat.get("events")
	if not events is Array or events.is_empty(): return
	if events[-1].id<last_combat_event: last_combat_event=0
	for event in events:
		if event.id<=last_combat_event: continue
		last_combat_event=event.id
		var text={"parry":"ПАРИРОВАНИЕ","block":"БЛОК","guardBreak":"ЗАЩИТА СЛОМЛЕНА","interrupt":"СБИТО","miss":"МИМО"}.get(event.kind,"")
		if event.get("amount",0)>0: text=("КРИТ! " if event.get("critical",false) else "")+str(ceili(event.amount))
		if text.is_empty() or not event.get("position") is Vector3: continue
		var position=event.position
		if Vector2(position.x-Game.player.x,position.z-Game.player.z).length()>160: continue
		var projected=world.project_point(position)
		if not projected.visible: continue
		var number=label(root,text,22 if event.get("critical",false) else 17)
		number.name="CombatFeedback"
		number.mouse_filter=Control.MOUSE_FILTER_IGNORE
		number.add_theme_color_override("font_color",Color("ff8e79") if event.get("target_id","")=="player" else Color("ffe2a1"))
		number.position=projected.position-Vector2(35,0)
		damage_labels.append({"label":number,"age":0.0,"origin":projected.position})
		if damage_labels.size()>40:
			var old=damage_labels.pop_front()
			old.label.queue_free()

func _update_action_status(ship: Dictionary,target: Dictionary):
	walk_button.toggle_mode=true; walk_button.button_pressed=Game.player.mode=="walk"
	sprint_button.toggle_mode=true; sprint_button.button_pressed=Game.player.mode=="sprint"
	auto_button.text="Авто: ВКЛ · Y" if Game.player.autoBattle else "Автобой · Y"
	auto_button.disabled=not ship.is_empty() or Game.player.dead
	attack_button.text="ОГОНЬ · F" if not ship.is_empty() else "УДАР %d/3 · F" % Game.player.combo if Game.player.get("combo",0)>0 and Game.state.time-Game.player.get("lastStrike",-100)<1.8 else "УДАР · F"
	attack_button.disabled=Game.player.dead or world.build_type!=""
	gather_button.text="Поставить · E" if world.build_type!="" else "Действие · E"
	heal_button.text="Поесть · %d" % Game.player.inventory.get("food",0)
	heal_button.disabled=Game.player.dead or Game.player.inventory.get("food",0)<=0
	pvp_button.text="PvP · NPC" if Game.state.pvp else "Мирный"
	pvp_button.button_pressed=Game.state.pvp
	boat_button.text="Высадка · V" if not ship.is_empty() or Game.player.get("sailing",false) else "На борт · V"
	sound_button.text="♫" if world.audio_on else "♫ ×"
	clear_target_button.visible=not target.is_empty()
	if not target.is_empty():
		target_status.text+=" · %.0f м" % Game.distance(target,Game.player)
		target_status.text+=" · "+("ГОТОВИТ УДАР" if not target.get("strike",{}).is_empty() else "ОГЛУШЁН" if target.get("staggerUntil",0)>Game.state.time else "Боевая цель" if Game.can_attack(target) else "Мирная цель")
	var ranged=Game.catalog.TOOLS.get(Game.player.tool,{}).get("ranged",false)
	for key in skill_buttons:
		var def=Game.catalog.SKILLS[key]
		var left=maxf(0,Game.player.skillCooldowns.get(key,0)-Game.state.time)
		var b=skill_buttons[key]
		var title=def.rangedName if ranged else def.name
		var short_title={"power":"Пробой" if ranged else "Мощный","sweep":"Залп" if ranged else "Круговой","guard":"Защита","dodge":"Уклонение"}[key]
		b.text=short_title+" · "+def.key+("\n%d с" % ceili(left) if left>0 else "")
		b.add_theme_font_size_override("font_size",12)
		b.tooltip_text=title+" · %d выносливости" % def.stamina
		b.disabled=not ship.is_empty() or Game.player.dead or left>0 or Game.player.stamina<def.stamina or world.build_type!=""
	for i in quick_buttons.size():
		var id=_quick_tool(i)
		quick_buttons[i].text="%d · %s%s" % [i+1,Game.catalog.TOOLS[id].name," ✓" if Game.player.tool==id else ""]
		quick_buttons[i].modulate=Color.WHITE if Game.player.tools.has(id) else Color(0.65,0.65,0.65)
	naval_controls.visible=not ship.is_empty() and not panel.visible
	ship_status.visible=not ship.is_empty() and not panel.visible
	if not ship.is_empty():
		ship_status.text+="\nТрюм: дерево %d · камень %d · уголь %d" % [ship.store.get("wood",0),ship.store.get("stone",0),ship.store.get("coal",0)]
		for key in naval_buttons:
			var left=maxf(0,ship.get("cooldowns",{}).get(key,0)-Game.state.time)
			var def=Game.catalog.NAVAL_WEAPONS[key]
			naval_buttons[key].text=def.name+(" ✓" if Game.player.navalWeapon==key else "")+(" · %d с" % ceili(left) if left>0 else "")
			naval_buttons[key].disabled=Game.catalog.SHIPS[ship.kind].get("cannons" if key=="cannon" else "ballistas",0)<=0
	var cart=Game.entity(Game.player.cartId)
	cart_button.visible=not cart.is_empty() and ship.is_empty() and not panel.visible
	if not cart.is_empty(): cart_button.text="Груз: %.0f / %.0f кг" % [Game.weight(cart.store),Game.capacity(cart)]
	var types={}
	for b in Game.state.buildings:
		if b.owner=="player" and b.hp>0: types[b.type]=true
	var bearing=fposmod(-rad_to_deg(world.camera_yaw),360)
	var compass=["С","СВ","В","ЮВ","Ю","ЮЗ","З","СЗ"][int(round(bearing/45.0))%8]
	shortcut_status.text="Дерево %d · Руда %d · Торговля %d\n%s · %d/28 · %s %.0f°\nЗащита %d%%%s%s" % [Game.player.inventory.get("wood",0),Game.player.inventory.get("ore",0),Game.state.civic.get("tradeReputation",0),"Развитие поселения" if types.has("warehouse") else "Основать лагерь: склад",types.size(),compass,bearing,Game.defense()," · БЛОК" if Game.player.get("guardUntil",0)>Game.state.time else ""," · Тележка" if Game.player.cartId!="" else ""]
	var raid=Game.state.get("raid",{})
	raid_status.visible=raid is Dictionary and not raid.is_empty()
	if raid_status.visible: raid_status.text="Взлом · %.1f с" % raid.get("left",0)
	snap_button.text="Сетка: ВКЛ" if world.build_snap else "Сетка: ВЫКЛ"

func panel_open() -> bool: return panel.visible

func close_panel():
	modal_backdrop.hide()
	live_labels.clear()
	reset_controls()
	panel.hide()
	current_page=""
	preview=null
	# A hidden inventory should not keep its own 3D viewport rendering.
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	joystick.value=Vector2.ZERO

func show_page(page: String,id=""):
	live_labels.clear()
	reset_controls()
	Game.player.autoBattle=false
	if page=="squad" and Game.entity(id).get("ally",false): squad_member=id
	current_page=page
	current_id=id
	preview=null
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	modal_backdrop.show()
	panel.show()
	_resize()
	match page:
		"bag": _bag()
		"build": _build()
		"craft": _craft()
		"cargo": _cargo()
		"squad": _squad()
		"settlement": _settlement()
		"trade": _trade(id)
		"object": _object(id)
		"map": _map()
		"fleet": _fleet()
		"economy": _economy()
		"karma": _karma()
		"settings": _settings()
		"save_transfer": _save_transfer()
		"licenses": _licenses()
		"help": _help()
		"start": _start()
		_: _menu()

func refresh(): show_page(current_page,current_id)

func show_start(): show_page("start")

func _start():
	panel_title.text="AEGEA · Острова и поселения"
	paragraph("Нативная версия для Xogot / Godot 4.6. Модели и игровые данные перенесены из AEGEA 5.6.")
	button(content,"Продолжить сохранённую игру",func(): if Game.load_game(): close_panel())
	button(content,"Новая игра · выживание",func(): _confirm_new(false))
	button(content,"Демонстрация · материалы в повозке",func(): _confirm_new(true))
	button(content,"3D-мир",func(): world.set_view_mode("3d"); close_panel())
	button(content,"2D-карта · совместимый режим",func(): world.set_view_mode("2d"); close_panel())
	button(content,"Управление и справка",func(): show_page("help"))
	paragraph("Рюкзак 120 кг / 24 ячейки · тележка 700 кг · повозка 900 кг. Игра рассчитана на горизонтальную ориентацию.")

func _confirm_new(showcase: bool):
	var dialog=ConfirmationDialog.new()
	dialog.dialog_text="Новая игра заменит текущий мир. Сначала будет сохранена отдельная резервная копия JSON. Продолжить?"
	dialog.title="Новый мир"
	root.add_child(dialog)
	dialog.confirmed.connect(func():
		if _write_export_file("user://aegea-before-new-"+str(int(Time.get_unix_time_from_system()))+"-"+str(Time.get_ticks_msec())+".json"):
			Game.new_world(showcase); close_panel()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(600,190))

func _menu():
	panel_title.text="Меню"
	for item in [["Инвентарь и экипировка","bag"],["28 построек","build"],["Ремесло и производство","craft"],["Грузы и транспорт","cargo"],["Флот","fleet"],["Экономика островов","economy"],["Отряд и поручения","squad"],["Поселение","settlement"],["Карма и PvP","karma"],["Карта архипелага","map"],["Графика и звук","settings"],["Справка","help"]]: button(content,item[0],func(): show_page(item[1]))
	button(content,"Сохранить игру",func(): Game.save_game())
	button(content,"Загрузить сохранение",_confirm_load)
	button(content,"Экспорт / импорт JSON",func(): show_page("save_transfer"))
	button(content,"PvP / нападения: "+("ВКЛ" if Game.state.pvp else "ВЫКЛ"),func(): Game.state.pvp=not Game.state.pvp; refresh())
	if Game.player.dead: button(content,"Возродиться в лагере",func(): Game.respawn(); close_panel())
	button(content,"Новая игра…",func(): show_start())

func _bag():
	panel_title.text="Инвентарь"
	label(content,"%.1f / 120 кг   ·   %d / 24 ячейки   ·   %d монет" % [Game.weight(Game.player.inventory,Game.player.tools),Game.slots(Game.player.inventory,Game.player.tools),Game.player.coins],16)
	var body=row(content)
	var left=VBoxContainer.new()
	left.custom_minimum_size.x=205
	body.add_child(left)
	_character_preview(left)
	for slot in Game.catalog.EQUIPMENT_SLOTS:
		var id=Game.player.equipment.get(slot)
		var equipment_button=button(left,Game.catalog.EQUIPMENT_SLOTS[slot]+":\n"+(Game.catalog.TOOLS.get(id,{}).get("name","—")),func(): Game.unequip(slot); show_page("bag"),180)
		equipment_button.add_theme_font_size_override("font_size",12)
		equipment_button.disabled=id==null or id==""
	label(left,"Защита: %d%%" % Game.defense(),14)
	var right=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var filters=HFlowContainer.new()
	right.add_child(filters)
	for filter in [["Все","all"],["Снаряжение","gear"],["Материалы","resources"],["Пища","food"]]:
		var choice=button(filters,filter[0],func(): bag_filter=filter[1]; refresh())
		choice.toggle_mode=true; choice.button_pressed=bag_filter==filter[1]
	var grid=GridContainer.new()
	grid.name="InventoryGrid"
	grid.columns=4
	right.add_child(grid)
	var entries=_bag_entries()
	for entry in entries:
		var id=entry.key
		var d=Game.catalog.TOOLS[id] if entry.gear else Game.catalog.RESOURCES[id]
		var b=button(grid,d.name,func():
			if entry.gear: _item_details(id)
			else: _resource_details(id)
		,94)
		b.custom_minimum_size.y=76
		b.add_theme_font_size_override("font_size",12)
		_item_icon(b,id,0 if entry.gear else entry.count)
		b.set_meta("item_key",id)
		if entry.gear and (Game.player.tool==id or Game.player.equipment.values().has(id)):
			var equipped=label(b,"E",13)
			equipped.position=Vector2(5,3)
			equipped.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i in max(0,24-entries.size()):
		var empty=button(grid,"—",func(): pass,94)
		empty.custom_minimum_size.y=76
		empty.disabled=true
	if entries.is_empty(): label(right,"В этой категории пока нет предметов",14)
	var quick=row(content)
	button(quick,"Съесть пищу",func(): Game.eat(); refresh())
	button(quick,"Ремесло · C",func(): show_page("craft"))
	button(quick,"По имени" if bag_sort=="type" else "По типу",func(): bag_sort="name" if bag_sort=="type" else "type"; refresh())
	_quick_transfer(content)

func _bag_entries() -> Array:
	var entries=[]
	if bag_filter in ["all","gear"]:
		for id in Game.player.tools: entries.append({"key":id,"gear":true,"count":1})
	if bag_filter!="gear":
		for key in Game.catalog.RESOURCES:
			if bag_filter in ["resources","res"] and key=="food": continue
			if bag_filter=="food" and key!="food": continue
			var amount=int(Game.player.inventory.get(key,0))
			while amount>0:
				entries.append({"key":key,"gear":false,"count":mini(25,amount)})
				amount-=25
	if bag_sort=="name":
		entries.sort_custom(func(a,b): return str(Game.catalog.TOOLS.get(a.key,Game.catalog.RESOURCES.get(a.key,{})).get("name",a.key)).naturalnocasecmp_to(str(Game.catalog.TOOLS.get(b.key,Game.catalog.RESOURCES.get(b.key,{})).get("name",b.key)))<0)
	return entries

func _quick_transfer(parent: Node):
	var containers=_near_containers()
	if containers.size()<2: label(parent,"Для переноса подойдите к своему транспорту или складу",13); return
	label(parent,"Быстрый перенос ресурсов",16)
	var ids=containers.map(func(c): return c.id)
	if not ids.has(cargo_from): cargo_from="bag"
	if not ids.has(cargo_to) or cargo_to==cargo_from: cargo_to=containers[1].id if cargo_from=="bag" else "bag"
	var selections=row(parent)
	for direction in [0,1]:
		var choose=OptionButton.new()
		choose.custom_minimum_size=Vector2(240,43)
		for c in containers: choose.add_item(c.name)
		choose.select(ids.find(cargo_from if direction==0 else cargo_to))
		choose.item_selected.connect(func(i):
			if direction==0: cargo_from=ids[i]
			else: cargo_to=ids[i]
		)
		selections.add_child(choose)
	button(parent,"Перенести всё →",func(): Game.transfer(cargo_from,cargo_to); refresh())

func _item_icon(cell: Button,key: String,count=0):
	cell.tooltip_text=cell.text
	cell.text=""
	var picture=TextureRect.new()
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.texture=load("res://assets/icons/"+key+".svg")
	picture.position=Vector2(23,3)
	picture.size=Vector2(48,48)
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cell.add_child(picture)
	var caption=Label.new()
	caption.text=Game.catalog.RESOURCES.get(key,Game.catalog.TOOLS.get(key,{})).get("name",key)
	caption.position=Vector2(3,54); caption.size=Vector2(88,18)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.add_theme_font_size_override("font_size",11)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cell.add_child(caption)
	if count>0:
		var amount=Label.new()
		amount.text=str(count); amount.position=Vector2(55,32); amount.size=Vector2(32,18)
		amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		amount.add_theme_font_size_override("font_size",16)
		amount.mouse_filter=Control.MOUSE_FILTER_IGNORE
		cell.add_child(amount)

func _character_preview(parent: Node):
	if not world.graphics_ready:
		var unavailable=label(parent,"3D-предпросмотр доступен\nв 3D-режиме",14)
		unavailable.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		unavailable.custom_minimum_size=Vector2(205,100)
		return
	var container=SubViewportContainer.new()
	container.custom_minimum_size=Vector2(205,290)
	container.stretch=true
	container.focus_mode=Control.FOCUS_ALL
	container.tooltip_text="Перетащите героя или используйте стрелки ← / →"
	parent.add_child(container)
	var viewport=SubViewport.new()
	viewport.size=Vector2i(205,290)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	preview=world.assets.normalized("ranger",1.92)
	viewport.add_child(preview)
	# Show precisely the same visible equipment pieces as the world hero.
	var rig=preload("res://scripts/character_rig.gd").new()
	preview.add_child(rig)
	rig.configure(preview,world.assets)
	rig.rebuild(Game.player.equipment,Game.player.tool,Game.catalog)
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-25,-25,0)
	light.light_energy=2.0
	viewport.add_child(light)
	var env=WorldEnvironment.new()
	env.environment=world.environment.environment
	viewport.add_child(env)
	var cam=Camera3D.new()
	cam.fov=40.0
	cam.position=Vector3(0,1.05,3.3)
	viewport.add_child(cam)
	cam.look_at(Vector3(0,1.0,0))
	container.gui_input.connect(func(e):
		if e is InputEventMouseButton:
			preview_drag=e.pressed
			if e.pressed: container.grab_focus()
		elif e is InputEventKey and e.pressed and e.physical_keycode in [KEY_LEFT,KEY_RIGHT] and is_instance_valid(preview):
			preview.rotation.y+= -0.18 if e.physical_keycode==KEY_LEFT else 0.18
			container.accept_event()
		elif e is InputEventMouseMotion and preview_drag and is_instance_valid(preview): preview.rotation.y+=e.relative.x*0.02
		elif e is InputEventScreenDrag and is_instance_valid(preview): preview.rotation.y+=e.relative.x*0.02
	)

func _item_details(id: String):
	show_page("item")
	for c in content.get_children(): content.remove_child(c); c.queue_free()
	var d=Game.catalog.TOOLS[id]
	panel_title.text=d.name
	var equipped=Game.player.tool==id or Game.player.equipment.values().has(id)
	paragraph("Масса: %.1f кг%s" % [d.weight," · Сейчас надето" if equipped else ""])
	if d.has("defense"):
		var current=Game.player.equipment.get(d.slot)
		var previous=Game.catalog.GEAR.get(current,{}).get("defense",0)
		paragraph("Защита: %d%% · изменение %+d%%" % [d.defense,d.defense-previous])
	if d.has("damage"):
		var current=Game.catalog.TOOLS.get(Game.player.tool,{})
		paragraph("Урон: %d (%+d) · Дальность: %.1f м (%+.1f)" % [d.damage,d.damage-current.get("damage",0),d.reach,d.reach-current.get("reach",0)])
	if item_info:
		if d.has("stamina"): paragraph("Удар расходует %d выносливости. Интервал: %.2f с." % [d.stamina,d.get("delay",0)])
		elif d.has("defense"): paragraph("Защита действует, только когда предмет надет в свою ячейку.")
		else: paragraph("Плот позволяет передвигаться по воде.")
		var old_id=Game.player.equipment.get(d.get("slot","weapon"),Game.player.tool)
		paragraph("Изменение веса: %+.1f кг" % (d.weight-Game.catalog.TOOLS.get(old_id,{}).get("weight",0)))
	button(content,"Скрыть описание" if item_info else "Описание предмета",func(): item_info=not item_info; _item_details(id))
	if id=="raft": button(content,"Свернуть / развернуть плот",func(): if Game.toggle_raft(): close_panel())
	else: button(content,"Сейчас надето" if equipped else "Надеть / взять в руки",func(): Game.equip(id); show_page("bag")).disabled=equipped
	button(content,"Назад в инвентарь",func(): show_page("bag"))

func _resource_details(key: String):
	show_page("resource")
	for c in content.get_children(): content.remove_child(c); c.queue_free()
	panel_title.text=Game.catalog.RESOURCES[key].name
	paragraph("Количество: %d · %.1f кг / ед." % [Game.player.inventory[key],Game.catalog.RESOURCES[key].weight])
	if item_info: paragraph("Восстанавливает 15 здоровья и 30 сытости. Пища нужна жителям поселения." if key=="food" else "Материал для строительства, ремесла и торговли. До 25 единиц в стопке.")
	button(content,"Скрыть описание" if item_info else "Описание предмета",func(): item_info=not item_info; _resource_details(key))
	button(content,"Перенести в транспорт / склад",func(): show_page("cargo"))
	button(content,"Оставить 5 единиц на земле",func(): Game.drop(key,5); show_page("bag"))
	if key=="food": button(content,"Съесть",func(): Game.eat(); show_page("bag"))
	button(content,"Назад",func(): show_page("bag"))

func _cost(cost: Dictionary) -> String:
	var parts=[]
	for k in cost: parts.append("%s %d" % [Game.catalog.RESOURCES.get(k,{}).get("name",k),cost[k]])
	return ", ".join(parts)

func _build():
	panel_title.text="Строительство · 28 моделей"
	var filters=OptionButton.new()
	var categories=["Все","Лагерь","Жильё","Ремесло","Хозяйство","Море","Защита"]
	for cat in categories: filters.add_item(cat)
	filters.select(max(0,categories.find(building_filter)))
	filters.item_selected.connect(func(i): building_filter=categories[i]; refresh())
	content.add_child(filters)
	var team=CheckButton.new()
	team.text="Поручить строительство отряду"
	team.button_pressed=team_build
	team.toggled.connect(func(v): team_build=v)
	content.add_child(team)
	paragraph("Привязка: 1 м, дороги: 4 м. Поворот: 45°. Ресурсы берутся из рюкзака, своих складов в 18 м и транспорта в 12 м от героя.")
	for b in Game.catalog.BUILDINGS:
		if building_filter!="Все" and b.category!=building_filter: continue
		var card=PanelContainer.new()
		content.add_child(card)
		var layout=row(card)
		var image=TextureRect.new()
		image.texture=load("res://assets/buildings/"+b.id+".jpg")
		image.custom_minimum_size=Vector2(115,90)
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layout.add_child(image)
		var desc=VBoxContainer.new()
		desc.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		layout.add_child(desc)
		label(desc,b.approvalId+" · "+b.name,17)
		var description=label(desc,b.description,12)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var text=label(desc,_cost(b.cost),12)
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button(desc,"Разместить",func(): world.start_build(b.id,team_build))

func _craft():
	panel_title.text="Ремесло и производство"
	for key in Game.catalog.RECIPES:
		var r=Game.catalog.RECIPES[key]
		label(content,r.name+" · "+Game.catalog.BUILDING_BY_ID[r.station].name,18)
		paragraph(_cost(r.input)+" → "+_cost(r.output)+" · %d с" % r.seconds)
		var actions=row(content)
		for amount in [1,5,10]: button(actions,"Заказать ×%d" % amount,func():
			if not Game.queue_production(key,amount): Game.notify("Нужны материалы, место в очереди и мастерская рядом")
			refresh()
		).disabled=Game.station(r.station).is_empty()
	for b in Game.state.buildings:
		if b.owner!="player" or b.jobs.is_empty(): continue
		label(content,Game.label(b),16)
		for j in b.jobs:
			live_paragraph(func(): return "%s · %d/%d · %s · %d%%\nОплачено: %s" % [Game.catalog.RECIPES[j.recipe].name,j.done,j.total,j.status,100.0*j.progress/Game.catalog.RECIPES[j.recipe].seconds,_cost(_job_paid(j))])
			button(content,"Отменить с возвратом сырья",func():
				if not Game.cancel_job(b,j.id): Game.notify("Для отмены подойдите к мастерской и освободите место для возврата сырья")
				refresh()
			)
		paragraph("Продукция: "+_cost(b.store))
		button(content,"Открыть груз мастерской",func(): cargo_from=b.id; cargo_to="bag"; show_page("cargo"))
	button(content,"Забрать продукцию / грузы",func(): show_page("cargo"))
	for id in Game.catalog.TOOLS:
		var d=Game.catalog.TOOLS[id]
		paragraph(d.name+" · "+_cost(_craft_cost(id)))
		if d.has("requires"): paragraph("Нужна постройка: "+Game.catalog.BUILDING_BY_ID[d.requires].name)
		button(content,"Есть в рюкзаке: "+d.name if Game.player.tools.has(id) else "Изготовить "+d.name,func(): Game.craft(id); refresh()).disabled=Game.player.tools.has(id)
	for kind in ["cart","wagon"]:
		paragraph(("Тележка" if kind=="cart" else "Конная повозка")+" · "+_cost(Game.catalog.VEHICLE_COSTS[kind]))
		button(content,"Создать транспорт",func(): Game.make_vehicle(kind); refresh())
	for kind in Game.catalog.SHIPS:
		var d=Game.catalog.SHIPS[kind]
		paragraph(d.name+" · "+_cost(d.cost))
		button(content,"Построить "+d.name,func(): Game.build_ship(kind); refresh())

func _craft_cost(id: String) -> Dictionary:
	var cost=Game.catalog.TOOLS[id].cost.duplicate()
	if not Game.station("shipyard" if id=="raft" else "workbench").is_empty():
		for key in cost: cost[key]=ceil(cost[key]*(0.5 if id=="raft" else 0.75))
	return cost

func _job_paid(job: Dictionary) -> Dictionary:
	if job.get("paid") is Dictionary: return job.paid
	var cost=Game.catalog.RECIPES[job.recipe].input.duplicate()
	for key in cost: cost[key]*=job.total
	return cost

func _near_containers() -> Array:
	var list=[{"id":"bag","name":"Рюкзак","store":Game.player.inventory,"owner":"player","x":Game.player.x,"z":Game.player.z}]
	for e in Game.state.buildings+Game.state.carts+Game.state.ships:
		if e.hp>0 and e.owner=="player" and e.has("store") and Game.distance(e,Game.player)<=Game.cargo_range(e):
			var c=e.duplicate(false)
			c["name"]=Game.label(e)
			list.append(c)
	return list

func _cargo():
	panel_title.text="Грузы · быстрый перенос"
	var list=_near_containers()
	if list.size()<2: paragraph("Подойдите к своей тележке, повозке, кораблю, складу или мастерской. Доступная дальность зависит от хранилища.")
	var ids=list.map(func(e): return e.id)
	if not ids.has(cargo_from): cargo_from="bag"
	if not ids.has(cargo_to): cargo_to=list[1].id if list.size()>1 else "bag"
	label(content,"Откуда → куда",15)
	var selections=row(content)
	for direction in [0,1]:
		var choose=OptionButton.new()
		choose.custom_minimum_size.x=280
		for e in list: choose.add_item(e.name)
		choose.select(max(0,ids.find(cargo_from if direction==0 else cargo_to)))
		choose.item_selected.connect(func(i):
			if direction==0: cargo_from=ids[i]
			else: cargo_to=ids[i]
			refresh()
		)
		selections.add_child(choose)
	button(content,"Перенести все доступные ресурсы",func(): Game.transfer(cargo_from,cargo_to); refresh())
	var source=Game.container(cargo_from)
	if not source.is_empty():
		for key in Game.catalog.RESOURCES:
			var r=row(content)
			var l=label(r,Game.catalog.RESOURCES[key].name+": %d" % source.store.get(key,0),15)
			l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			for amount in [1,5,10,99999]: button(r,str(amount) if amount!=99999 else "Все",func(): Game.transfer(cargo_from,cargo_to,key,amount); refresh(),58)
	for c in Game.state.carts:
		if c.owner!="player" or Game.distance(c,Game.player)>12: continue
		paragraph("%s · %.1f / %.0f кг" % [Game.label(c),Game.weight(c.store),Game.capacity(c)])
		if c.kind=="cart": button(content,"Отпустить тележку" if Game.player.cartId==c.id else "Прицепить тележку",func(): Game.toggle_cart(c.id); refresh())
		var controls=row(content)
		button(controls,"Следовать за героем",func(): Game.set_vehicle_follow(c.id,"player"); refresh())
		button(controls,"Остановиться",func(): Game.set_vehicle_follow(c.id,""); refresh())
		for n in Game.state.npcs:
			if n.ally and n.alive: button(content,"Следовать за "+n.name,func(): Game.set_vehicle_follow(c.id,n.id); refresh())

func _squad():
	panel_title.text="Отряд и поручения · P"
	var nearby=Game.state.npcs.filter(func(n): return n.alive and not n.ally and n.home!="player" and n.role!="merchant" and n.get("hostile",0)<=0 and Game.distance(n,Game.player)<=12)
	var members=Game.state.npcs.filter(func(n): return n.ally)
	paragraph("Спутников: %d / 6. Приглашение стоит 3 пищи. Выберите одного участника или весь отряд." % members.size())
	var member_ids=["all"]
	var member_choice=OptionButton.new()
	member_choice.name="CompanyMember"
	member_choice.add_item("Весь отряд")
	for n in members: member_choice.add_item(n.name); member_ids.append(n.id)
	if not member_ids.has(squad_member): squad_member="all"
	member_choice.select(member_ids.find(squad_member))
	member_choice.item_selected.connect(func(i): squad_member=member_ids[i])
	content.add_child(member_choice)
	label(content,"Ресурс для обычного приказа",14)
	var basic_choice=OptionButton.new()
	var basic_keys=Game.catalog.RESOURCES.keys().filter(func(k): return not Game.catalog.RESOURCES[k].get("processed",false))
	for key in basic_keys: basic_choice.add_item(Game.catalog.RESOURCES[key].name)
	basic_choice.select(maxi(0,basic_keys.find(basic_resource)))
	basic_choice.item_selected.connect(func(i): basic_resource=basic_keys[i])
	content.add_child(basic_choice)
	var commands=GridContainer.new()
	commands.columns=3
	content.add_child(commands)
	for type in ["follow","wait","guard","gather","attack","repair"]:
		button(commands,Game.catalog.ORDERS[type],func():
			if not Game.command(squad_member,type,basic_resource): Game.notify("Приказ недоступен: проверьте участника и выбранную цель")
			refresh()
		,175).disabled=members.is_empty()
	label(content,"Совместное строительство",18)
	var build_options=row(content)
	var building=OptionButton.new()
	var build_keys=["campfire","hut","warehouse","road"]
	for key in build_keys: building.add_item(Game.catalog.BUILDING_BY_ID[key].name)
	building.select(max(0,build_keys.find(squad_building)))
	building.item_selected.connect(func(i): squad_building=build_keys[i])
	build_options.add_child(building)
	button(build_options,"Поручить рядом",func(): Game.create_company_project(squad_building); refresh()).disabled=members.is_empty()
	button(content,"Выбрать площадку для отряда",func(): team_build=true; show_page("build"))
	label(content,"Поручение с результатом",18)
	var opts=row(content)
	var resource=OptionButton.new()
	resource.name="TaskResource"
	var keys=Game.catalog.RESOURCES.keys()
	for key in keys: resource.add_item(Game.catalog.RESOURCES[key].name)
	resource.select(max(0,keys.find(squad_resource)))
	resource.item_selected.connect(func(i): squad_resource=keys[i])
	opts.add_child(resource)
	var quantity=SpinBox.new()
	quantity.name="TaskQuantity"
	quantity.min_value=1; quantity.max_value=10000; quantity.value=squad_quantity
	quantity.value_changed.connect(func(v): squad_quantity=int(v))
	opts.add_child(quantity)
	var containers=Game.state.buildings+Game.state.carts+Game.state.ships
	containers=containers.filter(func(e): return e.owner=="player" and e.hp>0 and e.has("store"))
	var ids=containers.map(func(e): return e.id)
	if not ids.has(squad_source): squad_source=ids[0] if not ids.is_empty() else ""
	if not ids.has(squad_destination): squad_destination=ids[1] if ids.size()>1 else ids[0] if not ids.is_empty() else ""
	for direction in [0,1]:
		label(content,"Забрать из" if direction==0 else "Доставить / охранять",14)
		var choose=OptionButton.new()
		choose.name="TaskSource" if direction==0 else "TaskDestination"
		for e in containers: choose.add_item(Game.label(e)+" · %d м" % Game.distance(e,Game.player))
		choose.select(ids.find(squad_source if direction==0 else squad_destination))
		choose.item_selected.connect(func(i):
			if direction==0: squad_source=ids[i]
			else: squad_destination=ids[i]
		)
		content.add_child(choose)
	label(content,"Сопровождать корабль",14)
	var ships=Game.state.ships.filter(func(e): return e.owner=="player" and e.hp>0)
	var ship_ids=ships.map(func(e): return e.id)
	if not ship_ids.has(squad_ship): squad_ship=ship_ids[0] if not ship_ids.is_empty() else ""
	var ship_choice=OptionButton.new()
	ship_choice.name="TaskShip"
	for ship in ships: ship_choice.add_item(Game.label(ship))
	ship_choice.select(ship_ids.find(squad_ship))
	ship_choice.item_selected.connect(func(i): squad_ship=ship_ids[i])
	content.add_child(ship_choice)
	var tasks=GridContainer.new()
	tasks.columns=2
	content.add_child(tasks)
	for task in [["gather","Заготовить"],["deliver","Доставить груз"],["guard","Охранять склад"],["escort","Морской эскорт"]]:
		button(tasks,task[1],func():
			if Game.new_company_task(squad_member,task[0],squad_resource,squad_quantity,squad_destination,squad_source,squad_ship).is_empty(): Game.notify("Поручение недоступно: проверьте груз, хранилища, участников и провиант")
			refresh()
		,235).disabled=members.is_empty()
	paragraph("Провиант: 1 пища на участника. Эскорт занимает ещё одно ваше судно и расходует боеприпасы из его трюма. Сухопутная доставка работает в пределах острова.")
	var task_list=Game.state.tasks.filter(func(t): return t.get("shared",false))
	task_list=task_list.slice(maxi(0,task_list.size()-12))
	task_list.reverse()
	for task in task_list:
		live_paragraph(func(): return "%s · %s · %d/%d\n%s\nПровиант: %s · участников: %d" % [Game.catalog.ORDERS.get(task.get("type",""),"Поручение"),task.get("status",""),task.get("done",0),task.get("total",task.get("quantity",0)),task.get("reason",""),_cost(task.get("cost",{})),task.get("members",[]).size()])
		if task.get("status","") not in ["Готово","Отменено"]: button(content,"Отменить поручение",func(): Game.cancel_task(task.id); refresh())
	label(content,"Участники",18)
	for n in members:
		live_paragraph(func():
			var order=n.get("order",{}) if n.get("order",{}) is Dictionary else {}
			var report=n.get("taskReport",{})
			return "%s · %d HP · %d м\n%s · несёт %.1f кг\n%s" % [n.name,n.hp,Game.distance(n,Game.player),Game.catalog.ORDERS.get(order.get("type",""),"Ожидает"),Game.weight(n.get("carry",{})),report.get("reason",report.get("stage",order.get("reason",order.get("status",""))))]
		)
		button(content,"Отпустить "+n.name,func(): Game.dismiss(n.id); refresh())
	label(content,"Можно пригласить рядом",18)
	for n in nearby:
		label(content,n.name+" · %d м" % Game.distance(n,Game.player),17)
		var join=row(content)
		button(join,"В отряд · 3 пищи",func(): Game.join_companion(n.id); refresh())
		button(join,"Дать 2 пищи · карма +4",func(): Game.donate(n.id); refresh())
		if n.role!="guard": button(content,"В поселение · 5 пищи",func(): Game.recruit(n.id,true); refresh())
	for group in Game.state.groups: paragraph(group.name+" · "+group.phase)
	button(content,"Обновить прогресс",refresh)

func _settlement():
	settlement_snapshot=Game.settlement_summary()
	panel_title.text="Поселение"
	live_paragraph(func(): return "Запасы складов: %.1f / %.0f кг" % [settlement_snapshot.weight,settlement_snapshot.capacity])
	paragraph("Жители: %d / %d мест · Потребление пищи: %d / 60 с\n%s" % [Game.residents(),Game.beds(),ceil(Game.residents()/3.0),"Не хватает пищи" if Game.state.civic.foodShortage else "Снабжение в норме"])
	paragraph("Торговый авторитет: %d" % Game.state.civic.get("tradeReputation",0))
	button(content,"Пригласить работников",func(): show_page("squad"))
	button(content,"Торговля между островами",func(): show_page("economy"))
	label(content,"Запасы и баланс за минуту",18)
	for key in Game.catalog.RESOURCES:
		live_paragraph(func(): return "%s: %d · производство +%.1f / расход −%.1f" % [Game.catalog.RESOURCES[key].name,settlement_snapshot.stocks.get(key,0),settlement_snapshot.output.get(key,0),settlement_snapshot.input.get(key,0)])
	label(content,"Производство",18)
	for entry in settlement_snapshot.production:
		var building=entry.building
		live_paragraph(func():
			var production=Game.economy.production_state(building)
			return "%s · %s\n%d %s / 35 с%s" % [Game.label(building),production.get("status",""),production.get("amount",0),Game.catalog.RESOURCES.get(production.get("out",""),{}).get("name","")," · расход: "+_cost(production.input) if production.has("input") else ""]
		)
	label(content,"Жители",18)
	for resident in settlement_snapshot.residents:
		live_paragraph(func(): return "%s · %s · несёт %.1f кг" % [resident.name,{"gather":"Добывает","return":"Возвращается","build":"Строит","fight":"Сражается","idle":"Ожидает"}.get(resident.state,resident.state),Game.weight(resident.carry)])
	label(content,"Постройки и обслуживание",18)
	var stocks=Game.blank()
	for b in Game.state.buildings:
		if b.owner!="player" or b.hp<=0: continue
		for k in stocks: stocks[k]+=b.store.get(k,0)
		paragraph("%s · ур. %d · %d/%d HP\n%s" % [Game.label(b),b.level,b.hp,b.maxHp,b.get("productionStatus","")])
		var buttons=row(content)
		button(buttons,"Осмотреть",func(): show_page("object",b.id))
		button(buttons,"Ремонт",func(): Game.maintain(b.id); refresh())
		button(buttons,"Улучшить",func(): Game.maintain(b.id,true); refresh())
	paragraph("Запасы: "+_cost(stocks))
	for group in Game.state.groups: paragraph(group.name+" · "+group.phase)

func _trade(id: String):
	var n=Game.entity(id)
	if n.is_empty(): paragraph("Подойдите к торговцу и нажмите «Действие»."); return
	panel_title.text="Торговец · "+n.name
	paragraph("Ваши монеты: %d · Монеты торговца: %d · %d м. Цены меняются от запасов и спроса." % [Game.player.coins,n.coins,Game.distance(n,Game.player)])
	var available=n.alive and n.get("hostile",0)<=0 and Game.player.karma> -50 and Game.distance(n,Game.player)<=12 and not Game.player.dead
	var quantities=row(content)
	for amount in [1,5,10]: button(quantities,"Количество: %d" % amount,func(): trade_count=amount; refresh())
	for key in Game.catalog.RESOURCES:
		label(content,"%s · у торговца %d · у вас %d" % [Game.catalog.RESOURCES[key].name,n.marketStock.get(key,0),Game.player.inventory.get(key,0)],15)
		var buttons=row(content)
		button(buttons,"Купить · %d" % Game.quote(n,key,trade_count,true),func(): Game.trade(id,key,trade_count,true); refresh(),210).disabled=not available or n.marketStock.get(key,0)<trade_count or Game.player.coins<Game.quote(n,key,trade_count,true)
		button(buttons,"Продать · %d" % Game.quote(n,key,trade_count,false),func(): Game.trade(id,key,trade_count,false); refresh(),210).disabled=not available or Game.player.inventory.get(key,0)<trade_count or n.coins<Game.quote(n,key,trade_count,false)

func _object(id: String):
	var e=Game.entity(id)
	if e.is_empty(): return
	panel_title.text=Game.label(e)
	paragraph("Расстояние: %.1f м · Прочность: %d/%d" % [Game.distance(e,Game.player),e.get("hp",0),e.get("maxHp",0)])
	if e.entity_kind=="ships":
		button(content,"На борт",func(): if Game.board(e.id): close_panel())
		button(content,"Сойти / прыгнуть в воду",func(): Game.disembark(); close_panel())
		for key in Game.catalog.NAVAL_WEAPONS: button(content,"Оружие: "+Game.catalog.NAVAL_WEAPONS[key].name,func(): Game.player.navalWeapon=key; close_panel())
	elif e.entity_kind=="carts":
		button(content,"Отпустить тележку" if Game.player.cartId==id else "Прицепить тележку" if e.kind=="cart" else "Повозка: следовать за героем",func(): Game.toggle_cart(id); refresh())
		button(content,"Следовать за героем",func(): Game.set_vehicle_follow(id,"player"); refresh())
		button(content,"Остановиться",func(): Game.set_vehicle_follow(id,""); refresh())
	elif e.entity_kind=="buildings":
		paragraph(Game.catalog.BUILDING_BY_ID[e.type].description)
		if e.owner=="player":
			if e.hp<e.maxHp: paragraph("Ремонт: "+_cost(Game.maintenance_cost(e)))
			if e.level<3: paragraph("Улучшение: "+_cost(Game.maintenance_cost(e,true)))
			else: paragraph("Максимальный уровень")
		if e.type=="gate" and e.owner=="player": button(content,"Открыть / закрыть",func(): if Game.distance(e,Game.player)<12: e.open=not e.open; refresh())
		if e.type=="tent" and e.owner=="player": button(content,"Назначить лагерь возрождения",func(): if Game.distance(e,Game.player)<12: Game.player.respawn={"x":e.x+4,"z":e.z+4}; Game.notify("Точка возрождения установлена"))
		if e.type=="well": button(content,"Восстановить выносливость",func(): if Game.distance(e,Game.player)<8: Game.player.stamina=100)
		if e.owner=="player":
			button(content,"Ремонт",func(): Game.maintain(id); refresh()).disabled=e.hp>=e.maxHp
			button(content,"Улучшить",func(): Game.maintain(id,true); refresh()).disabled=e.level>=3
	if e.has("store"):
		paragraph("Груз: "+_cost(e.store))
		if e.owner=="player": button(content,"Открыть груз / склад",func(): cargo_to=id; show_page("cargo"))
		else:
			paragraph("Взлом длится 3 секунды. Движение и урон прерывают его. Требуется свободный бой с NPC; карма −12.")
			if e.get("raidOpenUntil",0)>Game.state.time:
				paragraph("Склад открыт ещё %.0f с" % (e.raidOpenUntil-Game.state.time))
				button(content,"Забрать доступные ресурсы",func(): Game.transfer(id,"bag","",99999,true); refresh())
				for key in Game.catalog.RESOURCES:
					if e.store.get(key,0)>0:
						button(content,"Взять 5: "+Game.catalog.RESOURCES[key].name,func(): Game.transfer(id,"bag",key,5,true); refresh())
			else: button(content,"Взломать · карма −12",func(): if Game.start_raid(id): close_panel())

func _map():
	panel_title.text="Эгейский архипелаг"
	var map_view=preload("res://scripts/map.gd").new()
	map_view.custom_minimum_size=Vector2(590,430)
	content.add_child(map_view)
	paragraph("Золотые суда — ваши, красные — пиратские, голубые — торговые. Светлые квадраты — поселения, зелёные — ваши постройки. Тонкие линии показывают текущие маршруты судов.")
	for island in Game.catalog.ISLANDS:
		paragraph(island.name+" · "+Game.catalog.ISLAND_ECONOMY[island.id].label+" · богатство: "+Game.catalog.RESOURCES[island.rich].name)
		var residents=Game.state.npcs.filter(func(n): return n.alive and n.home==island.id).size()
		var buildings=Game.state.buildings.filter(func(b): return b.hp>0 and b.owner==island.id).size()
		var building_now=""
		for settlement in Game.state.settlements:
			if settlement.id==island.id and settlement.get("construction") is Dictionary:
				building_now=" · строят "+Game.catalog.BUILDING_BY_ID.get(settlement.construction.get("type",""),{}).get("name","")
		paragraph("%d жителей · %d построек%s" % [residents,buildings,building_now])
		if Game.demo: button(content,"Демо: переместиться на "+island.name,func(): Game.player.x=island.x; Game.player.z=island.z+island.rz*0.5; Game.player.shipId=""; close_panel())
	if Game.demo: button(content,"Демо: к своим кораблям",func(): Game.player.x=Game.state.homeHarbor.x; Game.player.z=Game.state.homeHarbor.z-12; close_panel())

func _settings():
	panel_title.text="Настройки"
	for profile in [["Авто","auto"],["Экономное","low"],["Сбалансированное","medium"],["Высокое","high"],["Высокое — iPhone","iphone"],["Ультра — Mac / ПК","mac"]]:
		var b=button(content,profile[0],func(): world.apply_quality(profile[1]); refresh())
		b.toggle_mode=true; b.button_pressed=Game.quality==profile[1]
	paragraph("Профиль: %s · разрешение 3D: %d%%\nТекущий режим: %s" % [Game.quality,world.get_viewport().scaling_3d_scale*100,"2D-карта" if world.view_mode=="2d" else "3D-мир"])
	var modes=row(content)
	button(modes,"3D-мир",func(): world.set_view_mode("3d"); refresh())
	button(modes,"2D-карта",func(): world.set_view_mode("2d"); refresh())
	button(content,"Звуки мира: "+("ВКЛ" if world.audio_on else "ВЫКЛ"),func(): world.set_sound(not world.audio_on,world.music_on); refresh())
	button(content,"Музыка: "+("ВКЛ" if world.music_on else "ВЫКЛ"),func(): world.set_sound(world.audio_on,not world.music_on); refresh())
	for item in [["master","Общая громкость"],["ambience","Ветер и вода"],["music","Фоновая музыка"]]:
		var title=label(content,item[1]+" · %d%%" % (world.audio_levels[item[0]]*100),16)
		var slider=HSlider.new()
		slider.name="Volume_"+item[0]
		slider.min_value=0; slider.max_value=100; slider.step=1
		slider.value=world.audio_levels[item[0]]*100
		slider.custom_minimum_size=Vector2(300,36)
		slider.value_changed.connect(func(v): world.set_volume(item[0],v/100.0); title.text=item[1]+" · %d%%" % v)
		content.add_child(slider)
	button(content,"Сохранить сейчас",func(): Game.save_game())
	button(content,"Экспорт / импорт JSON",func(): show_page("save_transfer"))
	button(content,"Новый мир…",func(): show_start())
	if OS.get_name() in ["Linux","Windows","macOS"]:
		button(content,"Полный экран / окно",func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	button(content,"Авторы и лицензии",func(): show_page("licenses"))
	if not world.graphics_ready: paragraph("3D ещё не загружено. Выберите «3D-мир», чтобы повторить загрузку; в 2D можно продолжать игру.")
	if not world.assets.errors.is_empty(): paragraph("Не удалось загрузить ресурсы:\n"+"\n".join(world.assets.errors))
	paragraph("Диагностика: %d FPS · видимых объектов %d · NPC %d · зверей %d · чудовищ %d" % [Engine.get_frames_per_second(),world.meshes.size(),Game.state.npcs.size(),Game.state.animals.size(),Game.state.creatures.size()])

func _licenses():
	panel_title.text="Авторы и лицензии"
	paragraph("Модели и звук: Wildfire Games, Poly Haven, Quaternius, Kenney и другие авторы. Полные условия для включённых ресурсов:")
	var text=TextEdit.new()
	text.name="AssetLicenses"
	text.text=FileAccess.get_file_as_string("res://ASSET-LICENSES.md")
	text.editable=false
	text.custom_minimum_size=Vector2(570,380)
	text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(text)
	button(content,"Назад к настройкам",func(): show_page("settings"))

func _fleet():
	panel_title.text="Ваш флот"
	paragraph("На борту направление джойстика задаёт курс относительно камеры. Отпустите его, чтобы замедлиться. Орудия сначала расходуют материалы из трюма, затем из рюкзака. Посадка доступна рядом с кораблём.")
	for ship in Game.state.ships:
		if ship.owner!="player" or ship.hp<=0: continue
		paragraph("%s · %d/%d HP\nГруз %.1f / %.0f кг · %d м от героя" % [Game.label(ship),ship.hp,ship.maxHp,Game.weight(ship.store),Game.capacity(ship),Game.distance(ship,Game.player)])
		var controls=row(content)
		button(controls,"На борт",func(): if Game.board(ship.id): close_panel()).disabled=Game.player.shipId==ship.id or Game.distance(ship,Game.player)>Game.catalog.SHIPS[ship.kind].length*0.55+6
		button(controls,"Трюм",func(): cargo_from=ship.id; cargo_to="bag"; show_page("cargo"))
		button(controls,"Осмотреть",func(): show_page("object",ship.id))
	button(content,"Плот: развернуть / свернуть",func(): if Game.toggle_raft(): close_panel())
	button(content,"Строительство судов",func(): show_page("craft"))
	label(content,"Тележки и повозки",20)
	for cart in Game.state.carts:
		if cart.owner!="player" or cart.hp<=0: continue
		paragraph("%s · %d м · %.0f / %.0f кг\n%s" % [Game.label(cart),Game.distance(cart,Game.player),Game.weight(cart.store),Game.capacity(cart),cart.get("status","Ожидает")])
		var controls=row(content)
		button(controls,"Груз",func(): cargo_from=cart.id; cargo_to="bag"; show_page("cargo"))
		button(controls,"За героем",func(): Game.set_vehicle_follow(cart.id,"player"); refresh())
		button(controls,"Остановиться",func(): Game.set_vehicle_follow(cart.id,""); refresh())
		var leaders=Game.state.npcs.filter(func(n): return n.ally and n.alive)
		for n in leaders: button(content,"Следовать за "+n.name,func(): Game.set_vehicle_follow(cart.id,n.id); refresh())
	button(content,"Мастерская транспорта",func(): show_page("craft"))

func _economy():
	panel_title.text="Экономика островов · J"
	paragraph("Монеты: %d · Торговый авторитет: %d" % [Game.player.coins,Game.state.civic.get("tradeReputation",0)])
	var near=Game.nearest_market()
	for island in Game.catalog.ISLANDS:
		var info=Game.catalog.ISLAND_ECONOMY[island.id]
		var imports=[]
		for key in info.imports: imports.append(Game.catalog.RESOURCES[key].name)
		var settlement={}
		for place in Game.state.settlements:
			if place.id==island.id: settlement=place; break
		paragraph(island.name+" · "+info.label+"\nЭкспорт: "+Game.catalog.RESOURCES[info.export].name+" · запас %d" % settlement.get("store",{}).get(info.export,0)+"\nВвоз: "+", ".join(imports))
	if not near.is_empty():
		label(content,"Рынок · "+near.name,20)
		var sources=_near_containers()
		var ids=sources.map(func(c): return c.id)
		if not ids.has(barter_source): barter_source="bag"
		label(content,"Откуда взять груз",14)
		var choose=OptionButton.new()
		choose.name="BarterSource"
		for c in sources: choose.add_item(c.name+" · %.1f кг" % Game.weight(c.store))
		choose.select(ids.find(barter_source))
		choose.item_selected.connect(func(i): barter_source=ids[i]; refresh())
		content.add_child(choose)
		var source=Game.container(barter_source)
		for key in Game.catalog.ISLAND_ECONOMY[near.id].imports:
			var quote=Game.barter_quote(near.id,key,5)
			if quote.is_empty(): continue
			paragraph("5 %s → %d %s\nВ выбранном грузе: %d · %s" % [Game.catalog.RESOURCES[key].name,quote.reward,Game.catalog.RESOURCES[quote.export].name,source.get("store",{}).get(key,0),"Есть на рынке" if quote.available else "Ожидается пополнение"])
			var expected=quote.reward
			button(content,"Обменять",func():
				var fresh=Game.barter_quote(near.id,key,5)
				if fresh.get("reward",-1)!=expected: Game.notify("Курс изменился. Предложение обновлено")
				else: Game.barter(near.id,key,5,barter_source)
				refresh()
			).disabled=not quote.available or source.get("store",{}).get(key,0)<5
	else: paragraph("Для обмена подойдите на 18 м к поселению NPC или подплывите на 32 м к его порту. Можно торговать из рюкзака, своего трюма или тележки.")
	paragraph("Рынки отказываются от обмена при карме −50 и ниже. Ресурсы и свободное место проверяются до списаний.")
	label(content,"Торговцы ресурсов",20)
	for npc in Game.state.npcs:
		if npc.role=="merchant" and npc.alive: button(content,"Торговать: %s · %d м" % [npc.name,Game.distance(npc,Game.player)],func(): show_page("trade",npc.id))
	button(content,"Производственные цепочки",func(): show_page("craft"))

func _karma():
	panel_title.text="Карма и последствия"
	paragraph("Карма: %d · Убийства: %d\nРежим нападений: %s" % [Game.player.karma,Game.player.kills,"Включён" if Game.state.pvp else "Выключен"])
	paragraph("Нападение на мирных NPC и грабёж снижают карму. При карме −50 и ниже торговцы отказываются торговать, а стража становится враждебной. Союзники защищены от ваших атак. Это локальный бой с NPC, не сетевой PvP.")
	button(content,"Переключить нападения",func(): Game.state.pvp=not Game.state.pvp; refresh())

func _help():
	panel_title.text="Как играть"
	paragraph("Слева — движение. Проведите по свободной правой части экрана для поворота камеры. Кнопки «Шаг» и «Бег +» переключаются нажатием; по умолчанию герой бежит умеренно. Прыжок находится справа.")
	paragraph("Добыча: выберите топор или кирку на нижней панели, подойдите к ресурсу и удерживайте «Действие». Удар засчитывается после замаха. При заполнении рюкзака откройте «Меню → Грузы» рядом с транспортом.")
	paragraph("Бой: «Цель» переключает противников, «Удар» атакует. Мощный удар прерывает атаку противника. Защита работает спереди, уклонение кратковременно защищает от урона. Для нападения на мирных NPC включите PvP в меню: это снижает карму.")
	paragraph("Строительство: выберите одну из 28 моделей, переместитесь к площадке, поверните и подтвердите. Собственные склады и транспорт поблизости снабжают стройку. Верфь требует доски, слитки и парусину, которые производятся в мастерских.")
	paragraph("Море: свои корабли находятся у южного берега Эоса; их видно на карте. На борту направление джойстика задаёт курс относительно камеры. Баллисты и пушки расходуют камень, дерево и уголь сначала из трюма, затем из рюкзака.")
	paragraph("Клавиатура: WASD движение · Alt ходьба · Shift спринт · Space прыжок. E действие / добыча (удерживать), F атака (удерживать), Q/R/G/T умения, Z цель, Y автобой, V посадка / плот. 1–5 оружие. При строительстве: R поворот, Enter или E поставить.")
	paragraph("Меню: I или Tab сумка · B стройка · C ремесло · M карта · K карма · H справка · L флот · N поселение · J торговля · P отряд. Escape закрывает меню, отменяет стройку или открывает настройки. Экспорт / импорт JSON находится в настройках.")
	paragraph("Игровые меню и действия AEGEA 5.6 работают в нативной симуляции Godot. Рендерер, физика и управление адаптированы для Xogot; это локальная игра с NPC, без сетевой MMO. Сведения о проверке и оставшихся различиях находятся в docs/PARITY.md.")
	paragraph("Автосохранение каждые 20 игровых секунд и при сворачивании. Начав новую игру или демонстрацию, вы замените прежний мир при следующем сохранении. Сохранения находятся в пользовательских данных приложения, а не в этом ZIP. Предыдущая запись сохраняется в резервный файл .bak.")

func interact():
	if world.build_type!="": world.confirm_build(); gather_held=false; return
	if Game.player.dead: show_page("menu"); return
	if Game.player.shipId!="": cargo_from=Game.player.shipId; cargo_to="bag"; show_page("cargo"); return
	var e=Game.nearest()
	if e.is_empty(): Game.notify("Подойдите к объекту"); return
	match e.entity_kind:
		"resources": Game.gather(e.id)
		"drops": Game.loot(e.id)
		"npcs":
			if e.role=="merchant": show_page("trade",e.id)
			else: show_page("squad",e.id)
		_: show_page("object",e.id)

func _save_transfer():
	panel_title.text="Перенос сохранения · JSON"
	paragraph("Экспортируйте копию мира перед переносом на другое устройство. Импорт заменяет текущий мир только после проверки и подтверждения; предыдущий мир сохраняется в резервную копию. Можно загрузить JSON нативной AEGEA Xogot или поддерживаемой браузерной AEGEA, включая 5.6.")
	button(content,"Сохранить JSON в файл…",func(): _file_dialog(false))
	button(content,"Загрузить JSON из файла…",func(): _file_dialog(true))
	label(content,"Перенос текстом",20)
	paragraph("Если системный выбор файла недоступен в Xogot, скопируйте JSON или вставьте его ниже. Ограничение импорта: 5 МБ.")
	var text=TextEdit.new()
	text.name="SaveJSON"
	text.placeholder_text="Вставьте JSON сохранения"
	text.custom_minimum_size=Vector2(540,200)
	text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(text)
	button(content,"Показать текущий JSON",func(): text.text=Game.export_json())
	button(content,"Скопировать текущий JSON",func(): DisplayServer.clipboard_set(Game.export_json()); Game.notify("JSON скопирован"))
	button(content,"Вставить из буфера обмена",func(): text.text=DisplayServer.clipboard_get())
	button(content,"Проверить и импортировать текст…",func(): _request_import(text.text))
	button(content,"Назад к настройкам",func(): show_page("settings"))

func _file_dialog(importing: bool):
	var dialog=FileDialog.new()
	dialog.name="ImportJSONFile" if importing else "ExportJSONFile"
	dialog.title="Загрузить мир AEGEA" if importing else "Экспорт мира AEGEA"
	dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog=true
	dialog.filters=PackedStringArray(["*.json ; Сохранение AEGEA JSON ; application/json"])
	dialog.current_dir=OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if dialog.current_dir.is_empty(): dialog.current_dir=OS.get_user_data_dir()
	if not importing: dialog.current_file="aegea-xogot-"+Time.get_date_string_from_system()+".json"
	root.add_child(dialog)
	dialog.file_selected.connect(func(path):
		if importing: _read_import_file(path)
		else: _write_export_file(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.85)

func _write_export_file(path: String) -> bool:
	var text=Game.export_json()
	if text.is_empty(): Game.notify("Не удалось подготовить сохранение"); return false
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null: Game.notify("Не удалось записать файл. Выберите другую папку или скопируйте JSON"); return false
	file.store_string(text)
	file.flush()
	var err=file.get_error()
	file.close()
	if err!=OK: Game.notify("Ошибка записи JSON"); return false
	Game.notify("Копия JSON сохранена: "+path.get_file())
	return true

func _read_import_file(path: String):
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null: Game.notify("Файл не удалось открыть"); return
	if file.get_length()>5000000: file.close(); Game.notify("Файл больше 5 МБ. Импорт отменён"); return
	var text=file.get_as_text()
	file.close()
	_request_import(text)

func _request_import(text: String) -> bool:
	if text.to_utf8_buffer().size()>5000000: Game.notify("Файл больше 5 МБ. Импорт отменён"); return false
	var parser=JSON.new()
	if parser.parse(text)!=OK: Game.notify("JSON повреждён. Текущий мир не изменён"); return false
	var parsed=parser.data
	if not parsed is Dictionary or not parsed.get("player") is Dictionary or not parsed.get("buildings") is Array:
		Game.notify("Это не сохранение AEGEA. Текущий мир не изменён")
		return false
	var dialog=ConfirmationDialog.new()
	dialog.name="ConfirmImportJSON"
	dialog.title="Заменить текущий мир?"
	dialog.dialog_text="Версия: %s. Импорт JSON заменит текущий мир и сохранение. Сначала будет создана резервная копия текущего мира. Продолжить?" % parsed.get("native_version",parsed.get("version","не указана"))
	dialog.ok_button_text="Импортировать"
	dialog.cancel_button_text="Отмена"
	root.add_child(dialog)
	dialog.confirmed.connect(func():
		if Game.import_json(text): close_panel()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(600,220))
	return true

func _confirm_load():
	var dialog=ConfirmationDialog.new()
	dialog.name="ConfirmLoadSave"
	dialog.title="Загрузить сохранение?"
	dialog.dialog_text="Изменения после последнего сохранения будут заменены. Продолжить?"
	root.add_child(dialog)
	dialog.confirmed.connect(func():
		if Game.load_game(): close_panel()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(560,180))
