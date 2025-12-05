# res://core/utils/map_generator.gd
class_name MapGenerator
extends RefCounted

const FREQUENCY = 0.08  
const OCTAVES = 4       

static func generate_island(target: RegionData, radius: int, map_seed: int):
	print("正在生成地图... 种子: ", map_seed)
	
	var noise = FastNoiseLite.new()
	noise.seed = map_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = FREQUENCY
	noise.fractal_octaves = OCTAVES
	
	target.hex_cells.clear()
	
	# 为了计算归一化距离，我们需要知道这一圈格子的最大物理半径
	# 在六边形网格中，当 r = radius 时，y 轴距离最大
	# max_phys_radius ≈ 1.5 * radius (假设六边形 size=1)
	var max_dist_phys = 1.5 * radius
	
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(-q-r) <= radius:
				
				# 1. 噪声采样
				var noise_val = noise.get_noise_2d(q * 10, r * 10)
				
				# 2. 坐标转换 (Hex -> Pixel)
				# 这一步是为了消除六边形坐标系的拉伸畸变
				# x = sqrt(3) * q + sqrt(3)/2 * r
				# y = 3/2 * r
				var real_x = 1.732 * q + 0.866 * r
				var real_y = 1.5 * r
				
				# 计算当前点到中心(0,0)的物理距离
				var current_dist_phys = sqrt(real_x * real_x + real_y * real_y)
				
				# 归一化 (0.0 在中心, 1.0 在边缘)
				var dist_ratio = current_dist_phys / max_dist_phys
				
				# 3. 应用遮罩
				# 公式：Height = Noise - (Distance ^ a) * b
				# a 控制边缘下降的曲线陡峭度 (2.0 是抛物线，比较自然)
				# b 控制下降的力度 (越大，边缘越容易变成海)
				var height = noise_val - (pow(dist_ratio, 2.0) * 1.8) + 0.4
				
				# 4. 地形判定 (阈值微调)
				var terrain_type = HexCell.TerrainType.OCEAN
				
				if height < -0.2:
					terrain_type = HexCell.TerrainType.OCEAN
				elif height < 0.05: # 稍微提高一点海岸线
					terrain_type = HexCell.TerrainType.COAST
				elif height < 0.4:
					terrain_type = HexCell.TerrainType.PLAINS
				elif height < 0.6:
					terrain_type = HexCell.TerrainType.FOREST
				elif height < 0.8:
					terrain_type = HexCell.TerrainType.HILLS
				else:
					terrain_type = HexCell.TerrainType.MOUNTAIN
				
				var cell = HexCell.new()
				cell.q = q
				cell.r = r
				cell.terrain = terrain_type
				cell.elevation = (height + 1.0) * 50.0 
				
				target.hex_cells.append(cell)
