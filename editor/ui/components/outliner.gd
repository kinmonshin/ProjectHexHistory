# res://view/ui/components/outliner.gd
extends PanelContainer

@onready var tree = $MarginContainer/VBoxContainer/RegionTree # 请确认节点路径
@onready var context_menu = $ContextMenu

var item_map = {} # TreeItem -> RegionData
var current_parent: RegionData
var context_target_region: RegionData

func _ready():
	# 1. 监听: 进入了新地图 -> 刷新列表
	SignalBus.navigation_view_changed.connect(_on_view_changed)
	
	# 2. 监听: 数据变了 (比如新建了区域) -> 刷新列表
	SignalBus.map_data_modified.connect(_refresh_tree)
	
	# 3. 监听: 树操作
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_double_clicked)
	
	# 1. 监听鼠标点击 (用于检测右键)
	# 注意：item_selected 通常只响应左键。右键需要用 item_mouse_selected
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	# 2. 监听菜单点击
	context_menu.id_pressed.connect(_on_menu_item_pressed)

func _on_view_changed(region: RegionData):
	current_parent = region
	_refresh_tree()

func _refresh_tree():
	tree.clear()
	item_map.clear()
	
	if not current_parent: return
	
	var root = tree.create_item() # 隐形根
	
	# 遍历当前地图的所有子区域
	for child in current_parent.children:
		var item = tree.create_item(root)
		
		# 设置显示文本
		item.set_text(0, child.name)
		
		# 记录映射
		item_map[item] = child

# 单击 -> 选中
func _on_item_selected():
	var item = tree.get_selected()
	if item_map.has(item):
		var region = item_map[item]
		# 发射信号：选中了它
		SignalBus.selection_updated.emit([region])

# 双击 -> 进入 (下钻)
func _on_item_double_clicked():
	var item = tree.get_selected()
	if item_map.has(item):
		var region = item_map[item]
		# 发射信号：请求进入该区域
		SignalBus.request_navigate_to.emit(region)

# 鼠标在树节点上点击
func _on_item_mouse_selected(position: Vector2, mouse_button_index: int):
	# DEBUG 打印一下，看看右键点击是否有反应
	print("Tree clicked: ", mouse_button_index) 
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var item = tree.get_item_at_position(position)
		if item and item_map.has(item):
			# 记录目标
			context_target_region = item_map[item]
			
			# 选中它 (视觉反馈)
			item.select(0)
			
			# 查找对应的数据
			if item_map.has(item):
				context_target_region = item_map[item]
				print("右键目标: ", context_target_region.name)
				
			# 弹出菜单
			_popup_context_menu(get_viewport().get_mouse_position())

# 构建并弹出菜单
func _popup_context_menu(screen_pos: Vector2):
	context_menu.clear()
	
	# 添加选项 (ID 0: 删除, ID 1: 重命名...)
	context_menu.add_item(tr("UI_BTN_DELETE"), 0) # 借用之前的删除 Key
	# context_menu.add_item("Rename", 1) # 未来功能
	
	# 设置位置并弹出
	context_menu.position = Vector2i(screen_pos)
	context_menu.popup()

# 处理菜单选择
func _on_menu_item_pressed(id: int):
	if not context_target_region: return
	
	match id:
		0: # Delete
			_delete_region(context_target_region)

# 执行删除逻辑
func _delete_region(target: RegionData):
	print("正在删除区域: ", target.name)
	
	# 1. 归还领土 (重要逻辑！)
	# 如果删除了一个省份，它的格子该去哪？
	# 方案 A: 销毁 (变成虚空)
	# 方案 B: 归还给父级 (变成未分配领土) -> 推荐方案
	if current_parent:
		for cell in target.hex_cells:
			current_parent.hex_cells.append(cell)
		
		# 2. 从父级移除该节点
		current_parent.children.erase(target)
		
		# 3. 刷新
		# 刷新树
		_refresh_tree()
		
		# 刷新地图 (需要通知 Viewer)
		SignalBus.map_data_modified.emit()
		# 刷新贴图 (因为颜色变了)
		# 我们可以发送一个强制重绘的请求，或者 map_data_modified 已经涵盖了
		
		print("删除完成")
