# res://core/session_manager.gd
extends Node

const SAVE_DIR = "user://saves/"

# 信号：当加载新世界时发出，通知 UI 更新
signal world_loaded(world_root: RegionData)
# 信号：当保存完成时发出
signal world_saved()

# 当前加载的世界根节点
var current_world: RegionData

# 新增变量：记录当前正在编辑的文件路径
var current_file_path: String = ""

func _ready():
	# 增加打印
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		print("Session: 目录不存在，正在创建: ", SAVE_DIR)
		var err = DirAccess.make_dir_absolute(SAVE_DIR)
		if err != OK:
			push_error("Session: 无法创建存档目录! 错误码: ", err)
	else:
		print("Session: 存档目录检查 OK: ", SAVE_DIR)

# 获取所有存档文件列表 (按时间倒序排列)
func get_save_list() -> Array[Dictionary]:
	var dir = DirAccess.open(SAVE_DIR)
	var list: Array[Dictionary] = []
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				# 获取文件完整路径
				var full_path = SAVE_DIR + file_name
				# 获取修改时间 (Unix Timestamp)
				var mod_time = FileAccess.get_modified_time(full_path)
				
				list.append({
					"filename": file_name,
					"path": full_path,
					"time": mod_time,
					# 格式化时间字符串 (例如 "2023-10-01 12:00")
					"time_str": Time.get_datetime_string_from_unix_time(mod_time, true)
				})
			file_name = dir.get_next()
	
	# 按时间倒序排序 (最新的在前面)
	list.sort_custom(func(a, b): return a.time > b.time)
	return list

# 保存世界
func save_world(path: String):
	if not current_world:
		push_error("Session: 保存失败，current_world 为空！")
		return
		
	print("Session: 正在保存数据到 ", path)
	print("Session: 数据概况 - Name:", current_world.name, " Children:", current_world.children.size())
	
	var err = ResourceSaver.save(current_world, path)
	if err == OK:
		print("Session: ✅ 保存成功！")
		world_saved.emit()
	else:
		# 打印具体的错误码，这对诊断至关重要
		push_error("Session: ❌ 保存失败！错误码 Error Code: ", err)

# 完整的保存流程
func save_world_as(filename: String):
	if not filename.ends_with(".tres"):
		filename += ".tres"
	var path = SAVE_DIR + filename
	
	# 更新当前世界名称与文件名一致 (可选)
	if current_world:
		current_world.name = filename.replace(".tres", "")
	
	save_world(path)
	current_file_path = path

# 加载世界
func load_world(path: String):
	if FileAccess.file_exists(path):
		var res = ResourceLoader.load(path)
		if res is RegionData:
			current_world = res
			current_file_path = path # <--- 记录路径
			print("Session: 成功加载世界 - ", current_world.name)
			world_loaded.emit(current_world)
		else:
			push_error("Session: 文件不是有效的 RegionData")
	else:
		push_error("Session: 文件不存在 ", path)

# 删除存档
func delete_save(filename: String):
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.remove(filename)
