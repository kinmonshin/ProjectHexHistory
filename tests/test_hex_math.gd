extends Node

func _ready():
	print("--- 开始 HexMath 几何测试 ---")
	
	var hex_size = 32.0 # 假设每个六边形半径 32 像素
	
	# 测试用例 1: 原点 (0,0)
	var pixel_0 = HexMath.hex_to_pixel(0, 0, hex_size)
	print("Hex(0,0) -> Pixel: ", pixel_0, " (预期接近 0,0)")
	
	# 测试用例 2: 计算右边邻居 (1,0) 的像素位置
	var pixel_1 = HexMath.hex_to_pixel(1, 0, hex_size)
	print("Hex(1,0) -> Pixel: ", pixel_1)
	
	# 测试用例 3: 逆向工程 (像素 -> Hex)
	# 我们把刚才算出来的 pixel_1 稍微加点偏移（模拟鼠标点偏了一点点），看能不能算回 (1,0)
	var mouse_pos = pixel_1 + Vector2(2.0, 2.0) 
	var hex_result = HexMath.pixel_to_hex(mouse_pos, hex_size)
	print("Pixel ", mouse_pos, " -> Hex: ", hex_result)
	
	if hex_result == Vector2i(1, 0):
		print("✅ 坐标转换逻辑验证通过！")
	else:
		print("❌ 坐标转换逻辑错误！")
		
	print("--- 测试结束 ---")
