# res://view/hex_map_viewer.gd
class_name HexMapViewer
extends Node2D

# --- 扩展视图接口 ---
enum ViewMode {
	PHYSICAL,   # 自然地理 (只看地形)
	POLITICAL,  # 政治区划 (只看国家颜色)
	RELIGIOUS,  # 宗教分布 (预留)
	CULTURAL,   # 文化圈 (预留)
	HEIGHT_MAP  # 海拔热力图 (预留)
}

signal hex_clicked(cell_coord: Vector2i)
signal selection_changed(count: int)
# 新增信号：当数据发生改变（画了新格子）时发出，通知外部保存或刷新
signal region_modified 

@export var hex_size: float = 32.0         
@export var grid_color: Color = Color.GRAY 
@export var highlight_color: Color = Color(1.0, 1.0, 0.0, 0.6)
@export var paint_color_preview: Color = Color(0.0, 1.0, 0.0, 0.3) # 绘制时的预览色
@export var selection_color: Color = Color(0.0, 1.0, 1.0, 0.4) # 青色半透明
@onready var terrain_layer = $TerrainLayer

var current_region: RegionData
var hovered_coord: Vector2i = Vector2i(9999, 9999)
var current_paint_terrain: int = HexCell.TerrainType.PLAINS
# 当前模式
var current_view_mode: ViewMode = ViewMode.PHYSICAL
# 当前工具模式
var current_tool: String = "select" 
# 新增：已选中的格子列表
var selected_cells: Array[Vector2i] = []
# 选中颜色

# 新增状态变量
var is_river_mode: bool = false
var last_river_coord: Vector2i = Vector2i(9999, 9999) # 记录鼠标上一次所在的格子

# ⚠️ 请根据实际情况修改这个 ID！(TileSet面板左侧显示的数字)
var terrain_source_id: int = 0 

var tile_size_vec: Vector2 = Vector2(64, 64) # 默认值，会被 _ready 覆盖

# ⚠️ 请根据实际情况修改坐标！(鼠标悬停在贴图上显示的 Atlas Coordinates)
var terrain_atlas_map = {
	HexCell.TerrainType.OCEAN: Vector2i(3, 1),
	HexCell.TerrainType.COAST: Vector2i(0, 0),
	HexCell.TerrainType.PLAINS: Vector2i(2, 1),
	HexCell.TerrainType.FOREST: Vector2i(1, 1),
	HexCell.TerrainType.HILLS: Vector2i(0, 1),
	HexCell.TerrainType.MOUNTAIN: Vector2i(1, 0),
	HexCell.TerrainType.DESERT: Vector2i(3, 0),
	HexCell.TerrainType.SNOW: Vector2i(2, 0)
}

# --- 将 Axial(q, r) 转换为 Godot TileMap 坐标 ---
func _axial_to_tilemap(q: int, r: int) -> Vector2i:
	var col = q + (r - (r & 1)) / 2
	var row = r
	return Vector2i(col, row)

# --- 刷新贴图 ---
func _refresh_tiles():
	if not terrain_layer: return
	terrain_layer.clear()
	
	if current_region:
		_set_tiles_recursive(current_region)

func _set_tiles_recursive(region: RegionData):
	# 仅在自然视图下显示贴图
	if current_view_mode == ViewMode.PHYSICAL:
		for cell in region.hex_cells:
			if terrain_atlas_map.has(cell.terrain):
				var atlas_coord = terrain_atlas_map[cell.terrain]
				var tile_pos = _axial_to_tilemap(cell.q, cell.r)
				terrain_layer.set_cell(tile_pos, terrain_source_id, atlas_coord)
	
	for child in region.children:
		_set_tiles_recursive(child)

# 外部调用接口
func set_river_mode(enabled: bool):
	is_river_mode = enabled
	print("河流模式: ", enabled)

# 外部切换接口
func set_view_mode(mode_id: int):
	current_view_mode = mode_id as ViewMode
	print("视图模式切换为: ", ViewMode.keys()[mode_id])
	_refresh_tiles()
	queue_redraw()

# 新增设置函数
func set_paint_terrain(terrain_id: int):
	current_paint_terrain = terrain_id
	
func _ready():
	if SessionManager:
		SessionManager.world_loaded.connect(_on_world_loaded)
	if SessionManager.current_world:
		_on_world_loaded(SessionManager.current_world)
		
	# 从 TileMapLayer 获取真实的图块大小配置
	if terrain_layer and terrain_layer.tile_set:
		tile_size_vec = terrain_layer.tile_set.tile_size
		# 如果之前调了 Hex Size，现在那个值已经没用了，
		# 我们完全依赖 tile_size_vec

# 根据 TileSet 尺寸计算六边形的 6 个顶点
func _get_hex_vertices(center: Vector2) -> PackedVector2Array:
	var w = tile_size_vec.x
	var h = tile_size_vec.y
	
	# Godot 默认 Pointy Top 六边形在矩形框内的顶点分布：
	# 0: 顶部 (Top)
	# 1: 右上 (Top Right)
	# 2: 右下 (Bottom Right)
	# 3: 底部 (Bottom)
	# 4: 左下 (Bottom Left)
	# 5: 左上 (Top Left)
	
	# 注意：这里的 0.25 和 0.5 是基于标准六边形切分的比例。
	# 如果您的图片留白很大，可能需要微调这些系数，但通常这就是 Godot 的逻辑边界。
	
	var points = PackedVector2Array([
		Vector2(center.x, center.y - h * 0.5),            # Top
		Vector2(center.x + w * 0.5, center.y - h * 0.25), # Top Right
		Vector2(center.x + w * 0.5, center.y + h * 0.25), # Bottom Right
		Vector2(center.x, center.y + h * 0.5),            # Bottom
		Vector2(center.x - w * 0.5, center.y + h * 0.25), # Bottom Left
		Vector2(center.x - w * 0.5, center.y - h * 0.25)  # Top Left
	])
	
	return points

# 外部调用：设置工具模式
func set_tool(tool_name: String):
	current_tool = tool_name
	print("地图模式切换为: ", current_tool)

func _unhandled_input(event: InputEvent):
	# 1. 鼠标松开逻辑 (重置河流连线)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			last_river_coord = Vector2i(9999, 9999)

	# 2. 鼠标移动逻辑
	if event is InputEventMouseMotion:
		var local_pos = get_local_mouse_position()
		var new_coord = _get_hex_from_mouse(local_pos)
		if new_coord != hovered_coord:
			hovered_coord = new_coord
			queue_redraw()
			
			# --- 拖拽绘制逻辑 ---
			if current_tool == "paint" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if is_river_mode:
					# 河流模式
					_try_paint_river(new_coord)
				else:
					# 地形模式
					_try_paint_hex(new_coord)
			
			# (可选) 保持之前的多选拖拽逻辑
			elif current_tool == "select" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_key_pressed(KEY_SHIFT):
				_add_to_selection(new_coord)

	# 3. 鼠标点击逻辑 (保持不变)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if current_tool == "paint":
				if is_river_mode:
					_try_paint_river(hovered_coord)
				else:
					_try_paint_hex(hovered_coord)
			elif current_tool == "select":
				# ... (select 逻辑)
				if Input.is_key_pressed(KEY_SHIFT):
					_toggle_selection(hovered_coord)
				else:
					hex_clicked.emit(hovered_coord)

# 核心：画河算法
func _try_paint_river(coord: Vector2i):
	if not current_region: return
	
	# 1. 获取当前鼠标指着的格子
	var current_cell = current_region.get_hex(coord.x, coord.y)
	
	# 如果没地，不能画河 (或者你可以选择自动填陆地，这里暂定必须先有地)
	if not current_cell: return
	
	if current_cell.terrain == HexCell.TerrainType.OCEAN or \
		current_cell.terrain == HexCell.TerrainType.COAST:
		return # 禁止在海里画河

	# 2. 状态 A: 刚按下鼠标 (起点)
	if last_river_coord == Vector2i(9999, 9999):
		# 这是一个新起点
		current_cell.has_river = true
		if not current_cell.has_river: # 标记为源头
			current_cell.is_river_source = true
		else:
			# 如果它已经是河了，保持它的 source 状态不变 (或者强制设为 false? 视情况而定)
			# 这里什么都不做比较安全，或者显式设为 false 防止误标
			pass 
		current_cell.river_direction = -1   # 暂时没有流向

		last_river_coord = coord # 记录下来，准备连下一格
		_refresh_tiles()
		region_modified.emit()
		queue_redraw()
		return

	# 3. 状态 B: 拖拽到了新格子 (连线)
	if coord != last_river_coord:
		# 找到上一个格子 (上游)
		var prev_cell = current_region.get_hex(last_river_coord.x, last_river_coord.y)
		
		if prev_cell:
			# 计算流向：从 上一个 -> 当前
			var direction = _calculate_direction(last_river_coord, coord)
			
			# 只有相邻才能连线
			if direction != -1:

				prev_cell.has_river = true
				prev_cell.river_direction = direction

				current_cell.has_river = true
				current_cell.is_river_source = false 

				if current_cell.river_direction == -1:
					pass 

				_refresh_tiles()
				region_modified.emit()
				queue_redraw()
		
		# 更新记录，当前格子变成下一次连线的“上游”
		last_river_coord = coord

# 辅助：计算方向
func _calculate_direction(from: Vector2i, to: Vector2i) -> int:
	var diff = to - from
	# 遍历 HexMath 里的 6 个方向常量
	for i in range(HexMath.DIRECTIONS.size()):
		if HexMath.DIRECTIONS[i] == diff:
			return i
	return -1 # 不相邻，无法连线

# 辅助函数：只添加，不移除（用于拖拽刷选）
func _add_to_selection(coord: Vector2i):
	if not selected_cells.has(coord):
		# 只有存在的格子才能选
		if current_region and current_region.has_hex(coord.x, coord.y):
			selected_cells.append(coord)
			selection_changed.emit(selected_cells.size())
			queue_redraw()

# 切换某个格子的选中状态
func _toggle_selection(coord: Vector2i):
	if selected_cells.has(coord):
		selected_cells.erase(coord)
	else:
		# 只有当前层级有的格子才能被选中
		if current_region and current_region.has_hex(coord.x, coord.y):
			selected_cells.append(coord)
	queue_redraw()
	
	selection_changed.emit(selected_cells.size())


# 获取当前选中的所有格子 (给外部调用)
func get_selected_cells() -> Array[Vector2i]:
	return selected_cells

# 清空选择
func clear_selection():
	selected_cells.clear()
	queue_redraw()
	selection_changed.emit(selected_cells.size())

# 动作：添加格子
func _try_paint_hex(coord: Vector2i):
	if not current_region: return
	
	# 查找当前区域是否已有该格子
	var existing_cell = null
	for cell in current_region.hex_cells:
		if cell.q == coord.x and cell.r == coord.y:
			existing_cell = cell
			break
	
	if existing_cell:
		# 如果格子已存在，就修改它的地形 (刷地形功能)
		if existing_cell.terrain != current_paint_terrain:
			existing_cell.terrain = current_paint_terrain
			_refresh_tiles()
			region_modified.emit()
			queue_redraw()
	else:
		# 如果格子不存在，创建新格子并赋予地形
		var new_cell = HexCell.new()
		new_cell.q = coord.x
		new_cell.r = coord.y
		new_cell.terrain = current_paint_terrain
		current_region.hex_cells.append(new_cell)
		_refresh_tiles()
		region_modified.emit()
		queue_redraw()


# 动作：删除格子
func _try_erase_hex(coord: Vector2i):
	if not current_region: return
	
	if current_region.has_hex(coord.x, coord.y):
		current_region.remove_hex(coord.x, coord.y)
		_refresh_tiles()
		region_modified.emit()
		queue_redraw()

# res://view/hex_map_viewer.gd

# 获取某个 HexCell 在屏幕上的绝对中心点 (基于 TileMapLayer)
func _get_cell_center(q: int, r: int) -> Vector2:
	# 1. 先转成 TileMap 坐标
	var tile_pos = _axial_to_tilemap(q, r)
	
	# 2. 问 TileMapLayer 这个格子在哪
	# 注意：map_to_local 返回的是格子的中心像素坐标
	if terrain_layer:
		return terrain_layer.map_to_local(tile_pos)
	else:
		# 降级方案 (如果还没加载图层，才用数学公式，仅作备用)
		return HexMath.hex_to_pixel(q, r, hex_size)

# 获取鼠标点击的 Hex 坐标 (反向查询)
func _get_hex_from_mouse(local_mouse_pos: Vector2) -> Vector2i:
	if terrain_layer:
		# 1. 问 TileMapLayer 这是哪个格子
		var tile_pos = terrain_layer.local_to_map(local_mouse_pos)
		# 2. 转回 Axial (需要写一个反向转换公式)
		return _tilemap_to_axial(tile_pos)
	else:
		return HexMath.pixel_to_hex(local_mouse_pos, hex_size)

# 补充：TileMap坐标 -> Axial坐标 (Odd-r / Horizontal 的逆运算)
func _tilemap_to_axial(tile_pos: Vector2i) -> Vector2i:
	var col = tile_pos.x
	var row = tile_pos.y
	var q = col - (row - (row & 1)) / 2
	var r = row
	return Vector2i(q, r)

func _on_world_loaded(world: RegionData):
	# 1. 开始转场：先变淡/变透明
	var tween = create_tween()
	# 0.2秒内把整个地图变透明 (modulate.a 是透明度)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	
	# 等动画播完，再切换数据
	await tween.finished
	
	# 2. 切换数据
	current_region = world
	_refresh_tiles()
	queue_redraw()
	
	# 3. 结束转场：变回实体
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _draw():
	if not current_region: return

	match current_view_mode:
		
		# --- 情况 A: 政治视图 (Political) ---
		# 逻辑：需要画填充色 (Color) + 网格线 (Grid) + 河流 (可选)
		ViewMode.POLITICAL:
			_draw_political_recursive(current_region)
			
		# --- 情况 B: 自然视图 (Physical) ---
		# 逻辑：底层由 TileMapLayer 画贴图 (代码不在这里)
		#      这里只画叠加层：河流 (River) + 网格线 (Grid)
		ViewMode.PHYSICAL:
			_draw_physical_overlay_recursive(current_region)

	# --- 公共绘制：高亮框 ---
	if hovered_coord != Vector2i(9999, 9999):
		
		var highlight_color = Color.WHITE
		var line_width = 2.0
		var do_fill = false # 是否填充半透明色
		
		# 根据工具改变样式
		if current_tool == "paint":
			if is_river_mode:
				highlight_color = Color(0.2, 0.6, 1.0, 0.8) # 蓝色提示画河
				line_width = 4.0
			else:
				highlight_color = Color(0.0, 1.0, 0.0, 0.8) # 绿色提示画地
				line_width = 4.0
				do_fill = true # 绘制模式下填充一下，让瞄准更清楚
				
		elif current_tool == "select":
			# 选择模式：优雅的白色细框
			highlight_color = Color(1.0, 1.0, 1.0, 0.4) 
			line_width = 2.0
			# 或者：如果您希望选择模式下完全不显示框，除非点击，可以在这里 return
		
		# 开始绘制
		var center = _get_cell_center(hovered_coord.x, hovered_coord.y)
		var points = _get_hex_vertices(center)
		
		if do_fill:
			# 绘制半透明填充
			var fill_c = highlight_color
			fill_c.a = 0.2
			draw_colored_polygon(points, fill_c)
			
		points.append(points[0])
		draw_polyline(points, highlight_color, line_width)

# 递归绘制：政治视图 (色块 + 网格)
func _draw_political_recursive(region: RegionData):
	# 1. 确定颜色
	var poly_color = region.map_color
	# 如果是世界层级且没设色，给个默认淡色
	if poly_color == Color.WHITE and region.type == RegionData.Type.WORLD:
		poly_color = Color(1, 1, 1, 0.1)
	
	# 2. 绘制该区域的所有格子
	for cell in region.hex_cells:
		# 调用底层的画六边形函数 (带填充)
		_draw_hex_at(cell.q, cell.r, poly_color, grid_color)
		
		# 如果要在政治地图上也显示河流，可以在这里加 _draw_river(cell)
	
	# 3. 递归子节点
	for child in region.children:
		_draw_political_recursive(child)

# 递归绘制：自然视图叠加层 (河流 + 网格线)
# 注意：这里不画底色，因为底色是 TileMapLayer 负责的
func _draw_physical_overlay_recursive(region: RegionData):
	
	for cell in region.hex_cells:
		# 1. 画河流 (如果有)
		if cell.has_river:
			_draw_river(cell)
		
		# 2. 画网格线 (仅描边，不填充)
		# 我们不能直接调 _draw_hex_at，因为它会填充颜色。
		# 我们需要一个只画线框的函数。
		_draw_hex_grid_only(cell.q, cell.r)
	
	for child in region.children:
		_draw_physical_overlay_recursive(child)

# 仅绘制六边形边框 (无填充)
func _draw_hex_grid_only(q: int, r: int):
	# 1. 获取绝对中心 (Single Source of Truth)
	var center = _get_cell_center(q, r)
	
	# 2. 获取匹配 TileSet 形状的顶点 (New Geometry)
	var points = _get_hex_vertices(center)
	
	# 3. 闭合路径并绘制
	points.append(points[0]) 
	draw_polyline(points, grid_color, 1.0)

func _draw_region_recursive(region: RegionData):
	# 根据不同的模式，决定用什么颜色画格子
	match current_view_mode:
		
		# --- 模式 A: 自然地理 ---
		ViewMode.PHYSICAL:
			for cell in region.hex_cells:
				# 直接调用 Cell 的地形色
				_draw_hex_at(cell.q, cell.r, cell.get_color(), grid_color)
		
		# --- 模式 B: 政治区划 ---
		ViewMode.POLITICAL:
			# 逻辑：如果有区域颜色就用区域颜色，否则用默认灰色
			var poly_color = region.map_color
			# 特殊处理：如果还在 World 层级没分配颜色，给个半透明白
			if poly_color == Color.WHITE and region.type == RegionData.Type.WORLD:
				poly_color = Color(1, 1, 1, 0.1)
			
			for cell in region.hex_cells:
				_draw_hex_at(cell.q, cell.r, poly_color, grid_color)
		
		# --- 模式 C: 预留接口 (例如宗教) ---
		ViewMode.RELIGIOUS:
			# 将来这里可以写：var color = region.lore.religion_color
			# 目前暂时用粉色占位，方便测试接口是否通了
			for cell in region.hex_cells:
				_draw_hex_at(cell.q, cell.r, Color.DEEP_PINK, grid_color)

		# 1. 画地形 (Pass 1)
	match current_view_mode:
		ViewMode.PHYSICAL:
			for cell in region.hex_cells:
				_draw_hex_at(cell.q, cell.r, cell.get_color(), grid_color)
		# ... (其他模式)

	# 2. 画河流 (Pass 2) - 只有在自然视图下才画
	if current_view_mode == ViewMode.PHYSICAL:
		for cell in region.hex_cells:
			if cell.has_river and cell.river_direction != -1:
				_draw_river(cell)

	# 递归绘制子节点
	for child in region.children:
		_draw_region_recursive(child)

# 新增：绘制河流
func _draw_river(cell: HexCell):
	var start_pos = HexMath.hex_to_pixel(cell.q, cell.r, hex_size)
	
	# 计算终点：邻居的中心
	# 注意：这只是简化的画法（中心到中心）。
	# 更漂亮的画法是：中心 -> 边缘中点 -> 邻居中心 (贝塞尔曲线)
	
	# 获取流向的邻居坐标
	var neighbor_coord = HexMath.get_neighbor(cell, cell.river_direction)
	# 转换邻居像素坐标
	var end_pos = HexMath.hex_to_pixel(neighbor_coord.x, neighbor_coord.y, hex_size)
	
	# 绘制线条
	# 颜色：深蓝，宽度：3.0
	draw_line(start_pos, end_pos, Color(0.2, 0.4, 0.8), 3.0)
	
	# 画个小圆点表示源头
	if cell.is_river_source:
		draw_circle(start_pos, 4.0, Color(0.2, 0.4, 0.8))

func _draw_hex_at(q: int, r: int, inner_color: Color, border_color: Color, width: float = 1.0):
	var center = _get_cell_center(q, r)
	var points = _get_hex_vertices(center)
	
	draw_colored_polygon(points, inner_color)
	points.append(points[0]) 
	draw_polyline(points, border_color, width)
