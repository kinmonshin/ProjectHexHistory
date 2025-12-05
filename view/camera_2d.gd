# res://view/camera_controller.gd
extends Camera2D

# 配置
@export var min_zoom: float = 0.2
@export var max_zoom: float = 5.0
@export var zoom_speed: float = 0.1
@export var pan_speed: float = 1.0 # 如果需要键盘移动，可调大

# 状态
var _is_dragging: bool = false
var _last_mouse_pos: Vector2

func _unhandled_input(event: InputEvent):
	# 1. 鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(zoom_speed, zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(zoom_speed, zoom_speed)
		
		# 限制缩放范围
		zoom.x = clamp(zoom.x, min_zoom, max_zoom)
		zoom.y = clamp(zoom.y, min_zoom, max_zoom)
		
		# 2. 中键拖拽 (按下)
		if event.button_index == MOUSE_BUTTON_MIDDLE: # 也可以改成 MOUSE_BUTTON_RIGHT
			if event.pressed:
				_is_dragging = true
				_last_mouse_pos = event.position
			else:
				_is_dragging = false

	# 3. 中键拖拽 (移动)
	elif event is InputEventMouseMotion:
		if _is_dragging:
			# 计算移动差值
			# 注意：移动摄像机 position 的方向与鼠标移动方向相反
			# 且需要除以缩放倍率，否则缩放后拖拽速度会变
			var delta = event.position - _last_mouse_pos
			position -= delta / zoom
			_last_mouse_pos = event.position
