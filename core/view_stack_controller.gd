# res://core/view_stack_controller.gd
class_name ViewStackController
extends Node

# --- 新增信号 ---
# 当视图切换时，发出此信号，把当前的区域数据传出去
signal view_changed(current_region: RegionData) 

# 依赖引用
@export var map_viewer: HexMapViewer
@export var map_ui: MapUI

# 视图堆栈：存储从根节点到当前节点的所有 RegionData
var stack: Array[RegionData] = []

func _ready():
	# 监听 SessionManager，当加载新世界时重置堆栈
	if SessionManager:
		SessionManager.world_loaded.connect(_on_world_loaded)
	
	# 监听 UI 返回按钮
	if map_ui:
		map_ui.back_requested.connect(_on_back_pressed)
		
	# 监听地图点击（下钻逻辑）
	if map_viewer:
		map_viewer.hex_clicked.connect(_on_hex_clicked)

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
	var current = stack.back() # 获取栈顶元素
	
	# 1. 通知渲染器显示当前节点
	map_viewer._on_world_loaded(current) 
	
	# 2. 更新 UI 面包屑
	map_ui.update_breadcrumbs(stack)
	map_ui.set_back_enabled(stack.size() > 1)
	
	# --- 新增：发射信号 ---
	# 通知任何监听者（比如编辑器面板）："我们换地图了，快更新显示！"
	view_changed.emit(current)
	
	# --- 新增：重置工具状态 ---
	# 我们需要告诉 UI 把按钮弹起来，并告诉 Viewer 切回 Select
	# 这需要 MapUI 提供一个方法
	if map_ui:
		map_ui.reset_tool_to_select()

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
