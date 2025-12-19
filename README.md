# ScoreNest

English | [中文](./README_CN.md)

A simple iOS sheet music management application that supports sheet music browsing, auto-paging playback, and data import/export.

## Features

- 📚 **Sheet Music Management**: Create, edit, and organize your sheet music collection.
- 📄 **Multi-page Browsing**: Supports importing multi-page sheet music images with smooth browsing.
- 🎵 **Auto Play**: Customize timelines and automatically turn pages for sheet music playback.
- ✂️ **Area Cropping**: Precisely crop sheet music areas for auto-playback.
- 🔍 **Zoom View**: Supports gesture zooming to view sheet music details.
- 💾 **Data Import/Export**: Easily backup and restore all sheet music data.
- 🗂️ **Smart Sorting**: Sort sheet music by date or title.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- SwiftUI and SwiftData support

## Project Structure

```
ScoreNest/
├── Models/              # Data Models
│   ├── MusicScore.swift
│   ├── ScorePage.swift
│   ├── AutoPlayTimeline.swift
│   └── AutoPlaySegment.swift
├── Views/               # View Components
│   ├── ScoreListView.swift
│   ├── ScoreView.swift
│   ├── EditScoreView.swift
│   ├── AutoPlayView.swift
│   └── ...
├── AppDataIO.swift      # Data Import/Export Logic
└── ScoreNestApp.swift   # App Entry Point
```
