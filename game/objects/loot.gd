# res://game/objects/loot.gd
extends Node2D

# 存储自己的逻辑坐标，方便主逻辑查询距离
var hex_coords: Vector2i = Vector2i(0, 0)
