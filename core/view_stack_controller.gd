# res://core/view_stack_controller.gd
class_name ViewStackController
extends Node

# --- 新增信号 ---
# 当视图切换时，发出此信号，把当前的区域数据传出去
signal view_changed(current_region: RegionData) 
signal request_navigate_back() 
signal breadcrumbs_updated(stack_names: Array[String])

# 依赖引用
@export var map_viewer: HexMapViewer

# 视图堆栈：存储从根节点到当前节点的所有 RegionData
var stack: Array[RegionData] = []

func _ready():
	# 监听 SessionManager，当加载新世界时重置堆栈
	if SessionManager:
		SessionManager.world_loaded.connect(_on_world_loaded)

	# 监听地图点击（下钻逻辑）
	if map_viewer:
		map_viewer.hex_clicked.connect(_on_hex_clicked)
		
	# ✅ 新增：监听“返回”信号
	# 以前是 map_ui.back_requested.connect(...)
	# 现在是谁发的无所谓，只要总线说“要返回”，我就执行
	if SignalBus:
		SignalBus.request_navigate_back.connect(_on_back_pressed)
		
	SignalBus.request_navigate_to.connect(_push_view)

# 当加载新世界时，初始化堆栈
func _on_world_loaded(world_root: RegionData):
	stack.clear()
	_push_view(world_root)

# 进入下一层
func _push_view(region: RegionData):
	stack.append(region)
	_update_view()

# 返回上一层
func _on_back_pressed():
	if stack.size() > 1:
		stack.pop_back() # 移除当前层
		_update_view()

# 统一更新视图和UI
func _update_view():
	var current = stack.back()
	
	# 1. 通知地图渲染器 (原有)
	map_viewer._on_world_loaded(current)
	
	# 2. 构建面包屑并通知 TopBar (原有)
	var names: Array[String] = []
	for r in stack: names.append(r.name)
	SignalBus.breadcrumbs_updated.emit(names)
	
	# 3. 🔴 关键修复：通知大纲和属性面板！
	SignalBus.navigation_view_changed.emit(current)

# 处理点击下钻逻辑
func _on_hex_clicked(coord: Vector2i):
	var current_region = stack.back()
	
	# 如果已经是最低层级（没有子区域），则无法下钻
	if current_region.children.is_empty():
		print("已在最底层，无法下钻")
		return

	# 查找点击的格子属于哪个 子区域 (Child Region)
	# 这里的逻辑是：遍历当前区域的所有子区域，看谁拥有这个格子
	var target_child = _find_owner_of_hex(current_region, coord)
	
	if target_child:
		print("进入区域: ", target_child.name)
		_push_view(target_child)
	else:
		print("点击区域没有定义子区域")

# 辅助查找：谁拥有这个格子？
func _find_owner_of_hex(parent: RegionData, coord: Vector2i) -> RegionData:
	for child in parent.children:
		# 检查这个子区域是否直接包含该格子
		for cell in child.hex_cells:
			if cell.q == coord.x and cell.r == coord.y:
				return child
		
		# 递归检查（如果子区域还有子区域，但格子存在于孙子里）
		# 注：为了简化，通常点击“国家”地图时，只需要判断格子是否属于“省份”
		# 暂时只做一层浅层查找，或者通过 _collect_all_hexes 检查
		var child_hexes = _collect_hexes_simple(child)
		for cell in child_hexes:
			if cell.q == coord.x and cell.r == coord.y:
				return child
	return null

# 简单的递归收集 helper (类似 HexMapViewer 里的)
func _collect_hexes_simple(node: RegionData) -> Array[HexCell]:
	var results: Array[HexCell] = []
	if node.hex_cells.size() > 0:
		results.append_array(node.hex_cells)
	for child in node.children:
		results.append_array(_collect_hexes_simple(child))
	return results
