extends Node

func _ready():
	print("--- 开始数据结构测试 ---")
	
	# 1. 创建世界
	var world = RegionData.new()
	world.name = "艾泽拉斯 (Azeroth)"
	world.type = RegionData.Type.WORLD
	
	# 2. 创建一个国家
	var nation = RegionData.new()
	nation.name = "暴风王国 (Stormwind)"
	nation.type = RegionData.Type.NATION
	world.add_child(nation)
	
	# 3. 创建一个省份/地区
	var zone = RegionData.new()
	zone.name = "艾尔文森林 (Elwynn Forest)"
	zone.type = RegionData.Type.PROVINCE
	nation.add_child(zone)
	
	# 4. 为地区添加一些六边格
	zone.add_hex(0, 0) # 中心点
	zone.add_hex(1, 0) # 右侧一格
	
	# 5. 打印验证
	print("世界名称: ", world.name)
	print("  包含国家数量: ", world.children.size())
	print("    国家名称: ", world.children[0].name)
	print("      包含地区数量: ", world.children[0].children.size())
	
	var target_zone = world.children[0].children[0]
	print("        地区名称: ", target_zone.name)
	print("        六边格数量: ", target_zone.hex_cells.size())
	print("        第一个六边格: ", target_zone.hex_cells[0].to_string())
	
	# 6. 测试保存 (序列化)
	var save_path = "user://test_world.tres"
	var err = ResourceSaver.save(world, save_path)
	if err == OK:
		print("✅ 保存成功: ", save_path)
	else:
		print("❌ 保存失败: ", err)

	print("--- 测试结束 ---")
