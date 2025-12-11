# res://game/player.gd
class_name Player
extends Node2D

var hex_coords: Vector2i = Vector2i(0, 0)
@onready var camera = $Camera2D # 之前加的摄像机引用

# --- 新增：移动状态标记 ---
var is_moving: bool = false 

signal movement_finished(new_coords: Vector2i)

func setup(start_coords: Vector2i, start_pixel_pos: Vector2):
	hex_coords = start_coords
	position = start_pixel_pos
	camera.make_current()

func move_to(target_coords: Vector2i, target_pixel_pos: Vector2):
	# 1. 标记开始移动
	is_moving = true 
	
	hex_coords = target_coords
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pixel_pos, 0.3)
	
	await tween.finished
	
	# 2. 标记移动结束
	is_moving = false
	
	movement_finished.emit(hex_coords)
