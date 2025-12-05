# res://core/data/hex_cell.gd
class_name HexCell
extends Resource

enum TerrainType {
	OCEAN,      # 深海
	COAST,      # 浅滩/海岸
	PLAINS,     # 平原 (默认)
	FOREST,     # 森林
	HILLS,      # 丘陵
	MOUNTAIN,   # 山脉
	DESERT,     # 沙漠
	SNOW        # 雪地
}

# 采用 Cube Coordinates (q, r, s)
# s 是计算属性，不需要存储，因为 q + r + s = 0
@export var q: int = 0
@export var r: int = 0
# 新增：地形属性
@export var terrain: TerrainType = TerrainType.PLAINS
# 新增：海拔 (0-100，用于未来生成 3D 网格或决定河流流向)
@export var elevation: float = 0.0
# 地形/生物群系类型 (未来扩展用)
@export var biome_type: String = "plains" 
# 新增：河流属性
@export var has_river: bool = false
# 流向：0-5 代表六个方向，-1 代表无流向/终点
@export var river_direction: int = -1 
# 水源：是否是发源地
@export var is_river_source: bool = false

# 获取 s 坐标
func get_s() -> int:
	return -q - r

# 获取地形颜色 (用于渲染)
func get_color() -> Color:
	match terrain:
		TerrainType.OCEAN: return Color("1f4c8f") # 深蓝
		TerrainType.COAST: return Color("42a7f5") # 浅蓝
		TerrainType.PLAINS: return Color("58a845") # 绿色
		TerrainType.FOREST: return Color("1e6312") # 深绿
		TerrainType.HILLS: return Color("8a8a4b") # 土黄
		TerrainType.MOUNTAIN: return Color("6e6e6e") # 灰色
		TerrainType.DESERT: return Color("d4c676") # 沙黄
		TerrainType.SNOW: return Color("ffffff") # 白色
		_: return Color.GRAY

# 比较两个格子是否相同
func equals(other: HexCell) -> bool:
	return q == other.q and r == other.r

# 生成唯一键值 (用于字典索引)
func get_key() -> Vector2i:
	return Vector2i(q, r)

func _to_string() -> String:
	return "Hex(%d, %d, %d)" % [q, r, get_s()]
