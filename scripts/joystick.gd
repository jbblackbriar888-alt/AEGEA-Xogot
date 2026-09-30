extends Control
var value=Vector2.ZERO
var pointer=-1
var dragging=false
func _ready():
	mouse_filter=Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)

func _input(event):
	# Capture one finger through release, even when it leaves the joystick area.
	# Other fingers remain available to the camera and combat buttons.
	if event is InputEventScreenTouch:
		if event.pressed and pointer==-1 and get_global_rect().has_point(event.position):
			pointer=event.index; dragging=true; _set_value(event.position-global_position)
			get_viewport().set_input_as_handled(); queue_redraw()
		elif not event.pressed and event.index==pointer:
			pointer=-1; dragging=false; value=Vector2.ZERO
			get_viewport().set_input_as_handled(); queue_redraw()
	elif event is InputEventScreenDrag and event.index==pointer:
		_set_value(event.position-global_position)
		get_viewport().set_input_as_handled(); queue_redraw()

func _on_input(event):
	if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging=event.pressed
		if dragging: _set_value(event.position)
		else: value=Vector2.ZERO
		accept_event()
	elif event is InputEventMouseMotion and dragging: _set_value(event.position); accept_event()
	queue_redraw()
func _set_value(p): value=((p-size*0.5)/(size.x*0.34)).limit_length()
func _draw():
	var center=size*0.5
	draw_circle(center,size.x*0.42,Color(0.12,0.17,0.18,0.45))
	draw_arc(center,size.x*0.42,0,TAU,64,Color(0.75,0.69,0.52,0.6),2,true)
	draw_circle(center+value*size.x*0.28,size.x*0.17,Color(0.72,0.72,0.58,0.6))
func reset():
	value=Vector2.ZERO; dragging=false; pointer=-1; queue_redraw()

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: reset()
