# res://core/data/region_data.gd
class_name RegionData
extends Resource

# 定义区域层级枚举
enum Type {
	WORLD,
	CONTINENT,
	NATION,
	PROVINCE,
	CITY,
	HEX_CELL
}

# 基础信息
@export_group("Basic Info")
@export var id: String = ""            # 唯一标识符 (UUID)
@export var name: String = "New Region"
@export var type: Type = Type.PROVINCE
@export_multiline var description: String = ""

# 设定/剧情数据 (Lore)
@export_group("Lore")
@export var history: String = ""
@export var notable_npcs: Array[String] = []

# 层级关系
@export_group("Hierarchy")
# 这是一个递归结构，Resource 数组可以存放其他的 RegionData
@export var children: Array[RegionData] = []
# 父级引用通常不在 Resource 中强引用导出，以免造成循环引用导致保存崩溃
# 运行时可以通过代码动态设置 parent

# 空间数据 (只对最底层的区域如 Province/City 有效)
@export_group("Spatial")
@export var hex_cells: Array[HexCell] = []
# 颜色，用于在大地图上显示势力范围
@export var map_color: Color = Color.WHITE

# 初始化 ID
func _init():
	if id == "":
		# 简单的 UUID 生成 (Godot 4 暂无内置 UUID，用时间戳+随机数模拟)
		id = str(Time.get_unix_time_from_system()) + "_" + str(randi())

# 添加子区域
func add_child(region: RegionData):
	if not children.has(region):
		children.append(region)

# 添加六边格
func add_hex(q: int, r: int):
	var cell = HexCell.new()
	cell.q = q
	cell.r = r
	hex_cells.append(cell)

# 检查当前区域是否已经拥有该坐标的格子
func has_hex(q: int, r: int) -> bool:
	for cell in hex_cells:
		if cell.q == q and cell.r == r:
			return true
	return false

# 删除指定坐标的格子
func remove_hex(q: int, r: int):
	for i in range(hex_cells.size() - 1, -1, -1):
		var cell = hex_cells[i]
		if cell.q == q and cell.r == r:
			hex_cells.remove_at(i)
			return # 删完就跑

func get_hex(q: int, r: int) -> HexCell:
	for cell in hex_cells:
		if cell.q == q and cell.r == r:
			return cell
	return null
