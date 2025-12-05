# res://core/session_manager.gd
extends Node

# 信号：当加载新世界时发出，通知 UI 更新
signal world_loaded(world_root: RegionData)
# 信号：当保存完成时发出
signal world_saved()

# 当前加载的世界根节点
var current_world: RegionData

# 创建新世界
func new_world(world_name: String = "New World"):
	current_world = RegionData.new()
	current_world.name = world_name
	current_world.type = RegionData.Type.WORLD
	print("Session: 新世界已创建 - ", world_name)
	world_loaded.emit(current_world)

# 保存世界
func save_world(path: String):
	if not current_world:
		return
	var err = ResourceSaver.save(current_world, path)
	if err == OK:
		print("Session: 世界已保存至 ", path)
		world_saved.emit()
	else:
		push_error("Session: 保存失败 code %d" % err)

# 加载世界
func load_world(path: String):
	if FileAccess.file_exists(path):
		var res = ResourceLoader.load(path)
		if res is RegionData:
			current_world = res
			print("Session: 成功加载世界 - ", current_world.name)
			world_loaded.emit(current_world)
		else:
			push_error("Session: 文件不是有效的 RegionData")
	else:
		push_error("Session: 文件不存在 ", path)
