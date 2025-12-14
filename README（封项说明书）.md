# 🔷 HexWorld Engine (Godot 4.5 Framework)

> 一个基于 Godot 4.5+ 的六边格地图探索与交互框架。
> 原型项目：Project HexHistory
> 状态：**已归档 (Archived)** / 仅作技术参考

## 🌟 核心功能 (Features)

该框架包含了一套完整的六边形网格游戏底层逻辑：

### 1. 地图系统 (Map System)
*   **坐标系**：基于 Cube/Axial Coordinates 的数学库 (`HexMath`)，支持坐标转换与距离计算。
*   **渲染层**：基于 `TileMapLayer` 的高性能渲染，解决了像素级对齐与遮挡问题。
*   **生成器**：支持矩形地图生成的噪声算法 (`MapGenerator`)，包含边界处理。

### 2. 交互系统 (Interaction)
*   **战争迷雾**：基于 TileMap 的高性能迷雾，支持动态视野与地形阻挡。
*   **寻路系统**：集成 `AStar2D`，支持基于地形权重的路径计算。
*   **单位移动**：支持摄像机平滑跟随与移动动画。

### 3. 工程架构 (Architecture)
*   **SignalBus**：解耦的全局信号总线设计。
*   **UI 框架**：模块化 HUD 设计 (TopBar, LensBar, Outliner)，支持动态布局。
*   **数据管理**：
    *   基于 `Resource` 的存档系统 (Save/Load)。
    *   基于 CSV 的 **i18n 国际化** 流程。

## 📂 目录结构

*   `res://core/` - **核心逻辑** (数学库、数据模型、信号总线)。最可复用的部分。
*   `res://view/` - **通用渲染** (地图查看器、基础 UI 组件)。
*   `res://game/` - **演示 Demo** (包含玩家控制、事件触发、资源循环的完整实现)。
*   `res://editor/` - **编辑器逻辑** (地图绘制、属性编辑)。

## 🛠️ 如何复用

1.  将 `core/` 和 `view/` 文件夹复制到新项目。
2.  在 Project Settings 中注册 `SignalBus` 和 `SessionManager` 为 Autoload。
3.  配置 TileSet 资源 (Horizontal Offset / Stacked)。

---
*Last Updated: 2025*