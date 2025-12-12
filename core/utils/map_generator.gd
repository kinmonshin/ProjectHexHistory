# res://core/utils/map_generator.gd
class_name MapGenerator
extends RefCounted

const FREQUENCY = 0.08  
const OCTAVES = 4       

# 生成矩形地图 (新)
# width, height: 地图的宽高 (例如 20x20)
static func generate_rectangular_map(target: RegionData, width: int, height: int, seed_val: int):
	print("正在生成矩形地图... 种子: ", seed_val)
	target.hex_cells.clear()
	
	var noise = FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = 0.08 # 频率越低，地形越平缓
	
	# 偏移量：让 (0,0) 处于地图中心，方便摄像机对齐
	var offset_x = -width / 2
	var offset_y = -height / 2
	
	for y in range(height):
		for x in range(width):
			# --- 核心：矩形转六边形坐标 (Odd-r 转换) ---
			# 这是为了让生成的地图在屏幕上看起来是方方正正的矩形
			var q = (x + offset_x) - ((y + offset_y) - ((y + offset_y) & 1)) / 2
			var r = (y + offset_y)
			
			# --- 边界处理 (The Abyss) ---
			# 如果是地图的最外圈 (边缘 1-2 格)，强制设为海洋/深渊
			# 这样玩家就永远走不出地图了
			if x <= 1 or x >= width - 2 or y <= 1 or y >= height - 2:
				_add_cell(target, q, r, HexCell.TerrainType.OCEAN)
				continue
			
			# --- 地形生成 ---
			var noise_val = noise.get_noise_2d(q * 10, r * 10)
			
			# 根据噪声值决定地形
			var terrain_type = HexCell.TerrainType.OCEAN
			if noise_val < -0.2:
				terrain_type = HexCell.TerrainType.OCEAN
			elif noise_val < 0.2:
				terrain_type = HexCell.TerrainType.PLAINS
			elif noise_val < 0.5:
				terrain_type = HexCell.TerrainType.FOREST
			else:
				terrain_type = HexCell.TerrainType.MOUNTAIN
			
			_add_cell(target, q, r, terrain_type)

# 辅助函数 (保持不变或添加)
static func _add_cell(target: RegionData, q: int, r: int, type: int):
	var cell = HexCell.new()
	cell.q = q
	cell.r = r
	cell.terrain = type
	target.hex_cells.append(cell)

# ➕ 新增：兼容旧编辑器的接口
# 编辑器还在调用这个名字，我们把它指向新的矩形生成逻辑，或者恢复旧逻辑
static func generate_island(target: RegionData, radius: int, seed_val: int):
	# 这里我们简单地转接给新的矩形生成器
	# 把半径 x2 变成宽高
	generate_rectangular_map(target, radius * 2, radius * 2, seed_val)
