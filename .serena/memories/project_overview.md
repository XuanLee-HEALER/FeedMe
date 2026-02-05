# FeedMe 项目概述

## 项目目的
FeedMe 是一个 macOS 菜单栏 RSS 阅读器应用，以最少打扰的方式浏览订阅源的最新文章。

## 核心功能
- **菜单栏常驻** - 无 Dock 图标，仅在菜单栏显示
- **左键点击** - 显示最新文章列表（最多 5 条，超出显示"更多"）
- **右键点击** - 显示应用菜单（管理订阅、设置、刷新等）
- **自动刷新** - 后台定时刷新，支持 ETag/Last-Modified 增量更新
- **OPML 支持** - 导入/导出订阅源

## 技术栈
- **语言**: Swift 5.9+
- **UI 框架**: SwiftUI + AppKit (NSStatusItem, NSMenu)
- **数据存储**: SQLite via GRDB.swift
- **Feed 解析**: FeedKit (RSS/Atom/JSON Feed)
- **最低系统**: macOS 13.0+

## 仓库地址
https://github.com/XuanLee-HEALER/FeedMe

## 版本历史
- v1.0.0 - 初始发布
- v1.0.1 - 安全和质量修复
