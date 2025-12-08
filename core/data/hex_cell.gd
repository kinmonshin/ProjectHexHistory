# res://core/data/hex_cell.gd
class_name HexCell
extends Resource

# 地形枚举
enum TerrainType {
	OCEAN,      # 0
	COAST,      # 1
	PLAINS,     # 2
	FOREST,     # 3
	HILLS,      # 4
	MOUNTAIN,   # 5
	DESERT,     # 6
	SNOW        # 7
}

# --- 核心坐标 ---
@export var q: int = 0
@export var r: int = 0

# --- 地理属性 ---
@export var terrain: TerrainType = TerrainType.PLAINS
@export var elevation: float = 0.0 # 海拔 (0-100)

# --- 水文属性 ---
@export var has_river: bool = false
@export var river_direction: int = -1 # 0-5 代表流向邻居的索引
@export var is_river_source: bool = false

# --- 辅助方法 ---

# 获取 s 坐标 (计算属性)
func get_s() -> int:
	return -q - r

# 获取地形默认颜色 (用于小地图或 Political 视图下的地形底色)
# 保留这个是为了方便调试，或者将来做小地图时用
func get_color() -> Color:
	match terrain:
		TerrainType.OCEAN: return Color("1f4c8f")
		TerrainType.COAST: return Color("42a7f5")
		TerrainType.PLAINS: return Color("58a845")
		TerrainType.FOREST: return Color("1e6312")
		TerrainType.HILLS: return Color("8a8a4b")
		TerrainType.MOUNTAIN: return Color("6e6e6e")
		TerrainType.DESERT: return Color("d4c676")
		TerrainType.SNOW: return Color("ffffff")
		_: return Color.GRAY

# 比较相等
func equals(other: HexCell) -> bool:
	return q == other.q and r == other.r
