# ScoreNest

一个简单的 iOS 乐谱管理应用，支持乐谱浏览、自动翻页播放及数据导入导出。

## 功能特性

- 📚 **乐谱管理**：创建、编辑和组织你的乐谱集合
- 📄 **多页浏览**：支持导入多页乐谱图片，流畅浏览
- 🎵 **自动播放**：自定义时间轴，自动翻页播放乐谱
- ✂️ **区域裁剪**：为自动播放精确裁剪乐谱区域
- 🔍 **缩放查看**：支持手势缩放，查看乐谱细节
- 💾 **数据导入导出**：轻松备份和恢复所有乐谱数据
- 🗂️ **智能排序**：按日期或标题排序乐谱

## 系统要求

- iOS 17.0 或更高版本
- Xcode 15.0 或更高版本
- SwiftUI 和 SwiftData 支持

## 项目结构

```
ScoreNest/
├── Models/              # 数据模型
│   ├── MusicScore.swift
│   ├── ScorePage.swift
│   ├── AutoPlayTimeline.swift
│   └── AutoPlaySegment.swift
├── Views/               # 视图组件
│   ├── ScoreListView.swift
│   ├── ScoreView.swift
│   ├── EditScoreView.swift
│   ├── AutoPlayView.swift
│   └── ...
├── AppDataIO.swift      # 数据导入导出逻辑
└── ScoreNestApp.swift   # 应用入口
```
