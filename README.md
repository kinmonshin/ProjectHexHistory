# 🔷 HexWorld Engine

![Godot 4.5](https://img.shields.io/badge/Godot-4.5-478cbf?logo=godotengine&logoColor=white)
![License MIT](https://img.shields.io/badge/License-MIT-green)
![Status Archived](https://img.shields.io/badge/Status-Archived%20Prototype-orange)

一个轻量级、高度解耦的**六边形战棋/策略游戏底层框架**。
本项目原名为 *Project HexHistory*，经过重构后剥离为通用框架，旨在为独立开发者提供一套开箱即用的 4X 策略游戏基建。

## ✨ 核心特性 (Key Features)

### 🗺️ 地图与渲染
*   **TileMapLayer 集成**：解决了传统 hex 贴图对齐与像素抖动问题。
*   **高性能战争迷雾**：基于图块擦除的迷雾系统，支持动态视野半径。
*   **程序化生成**：内置噪声算法 (`FastNoiseLite`) 生成自然的大陆与海洋边界。

### ⚙️ 逻辑系统
*   **A* 寻路系统**：基于地形权重的六边格寻路（平原消耗低，山地消耗高）。
*   **信号总线架构 (SignalBus)**：UI 与 游戏逻辑完全解耦，模块化开发。
*   **数据持久化**：完整的 Save/Load 存档管理系统。

### 🎮 演示 Demo
`res://game/` 目录下包含一个完整的 Roguelite 探索 Demo：
*   资源管理（补给/生命）
*   叙事事件弹窗
*   兴趣点 (POI) 探索循环

## 🚀 快速开始

1. 克隆本仓库。
2. 使用 **Godot 4.5+** 导入 `project.godot`。
3. 运行 `res://game/game_main.tscn` 查看演示。
4. 将 `core/` 和 `view/` 文件夹复制到您的项目中即可复用核心逻辑。

## 📷 截图
(游戏运行时的截图)

## 📄 许可证
MIT License
