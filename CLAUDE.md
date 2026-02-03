# FeedMe

macOS 菜单栏 RSS 阅读器应用。

## 技术栈
- Swift 5.9+
- SwiftUI + AppKit
- macOS 13+

## 架构
- `AppDelegate`: 管理菜单栏状态和交互，处理左键（文章列表）和右键（设置菜单）点击
- `FeedMeApp`: SwiftUI App 入口，提供设置窗口
- `ContentView`: SwiftUI 设置界面

## 项目结构
```
FeedMe/
├── FeedMe/                 # 主应用代码
│   ├── FeedMeApp.swift    # App 入口
│   ├── AppDelegate.swift  # 菜单栏逻辑
│   └── ContentView.swift  # 设置视图
├── FeedMeTests/           # 单元测试
└── FeedMeUITests/         # UI 测试
```

## 开发命令
```bash
# 构建
xcodebuild -project FeedMe.xcodeproj -scheme FeedMe build

# 测试
xcodebuild test -project FeedMe.xcodeproj -scheme FeedMe

# 代码检查 (需要 swiftlint)
swiftlint lint

# 代码格式化 (需要 swiftformat)
swiftformat .
```

## 代码风格
- 使用 Swift 标准命名规范
- 中文注释说明复杂逻辑
- 遵循 Apple Human Interface Guidelines
