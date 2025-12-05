# res://core/utils/hex_math.gd
class_name HexMath
extends RefCounted

# --- 之前的代码保留 (Directions 等) ---

const DIRECTIONS = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

static func get_neighbor(cell: HexCell, direction_index: int) -> Vector2i:
	var dir = DIRECTIONS[direction_index % 6]
	return Vector2i(cell.q + dir.x, cell.r + dir.y)

static func get_distance(a: HexCell, b: HexCell) -> int:
	var dq = abs(a.q - b.q)
	var dr = abs(a.r - b.r)
	var ds = abs(a.get_s() - b.get_s())
	return int((dq + dr + ds) / 2)

# --- 新增代码：几何转换 ---

# 1. 六边格坐标 -> 屏幕像素坐标 (中心点)
# size: 六边形中心到顶点的距离 (即外接圆半径)
static func hex_to_pixel(q: int, r: int, size: float) -> Vector2:
	var x = size * (sqrt(3) * q + sqrt(3) / 2 * r)
	var y = size * (3.0 / 2 * r)
	return Vector2(x, y)

# 2. 屏幕像素坐标 -> 六边格坐标 (用于鼠标点击检测)
# 返回 Vector2i(q, r)，后续需要用来 new HexCell
static func pixel_to_hex(local_pos: Vector2, size: float) -> Vector2i:
	var q_frac = (sqrt(3) / 3 * local_pos.x - 1.0 / 3 * local_pos.y) / size
	var r_frac = (2.0 / 3 * local_pos.y) / size
	return _hex_round(q_frac, r_frac)

# 3. 六边形舍入算法 (私有辅助函数)
# 将浮点数坐标转换回最接近的整数六边形坐标
static func _hex_round(frac_q: float, frac_r: float) -> Vector2i:
	var frac_s = -frac_q - frac_r
	var q = roundi(frac_q)
	var r = roundi(frac_r)
	var s = roundi(frac_s)

	var q_diff = abs(q - frac_q)
	var r_diff = abs(r - frac_r)
	var s_diff = abs(s - frac_s)

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	else:
		# s 只是用来辅助计算平衡的，不需要返回
		pass 
	
	return Vector2i(q, r)
