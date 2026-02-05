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

## 任务执行规范 ⚠️ 重要

**本项目使用 `just` 作为统一任务执行器。**

### 核心原则

1. **优先使用 just recipe**
   - 任何任务执行前，先检查 `justfile` 是否有对应的 recipe
   - 运行 `just --list` 查看所有可用命令
   - 使用 just recipe 而不是直接运行原始命令

2. **高频任务必须写 recipe**
   - 如果某个命令需要频繁执行（超过 2 次）
   - 先在 `justfile` 中添加 recipe
   - 再执行任务
   - 这样保证团队一致性和可维护性

3. **Recipe 命名规范**
   - 使用小写字母和连字符：`build-release`、`clean-artifacts`
   - 动词开头：`update-version`、`check-deps`
   - 简洁明了，见名知义

### 示例

❌ **错误做法**：直接运行原始命令
```bash
xcodebuild -project FeedMe.xcodeproj -scheme FeedMe -configuration Release clean build
```

✅ **正确做法**：使用 just recipe
```bash
just build-release
```

❌ **错误做法**：重复执行相同命令
```bash
# 第一次
xcodebuild test -project FeedMe.xcodeproj -scheme FeedMe

# 第二次还是手动输入
xcodebuild test -project FeedMe.xcodeproj -scheme FeedMe
```

✅ **正确做法**：发现高频任务后，立即创建 recipe
```bash
# 在 justfile 中添加
test:
    xcodebuild test -project FeedMe.xcodeproj -scheme FeedMe

# 以后都使用
just test
```

## 开发命令

### 常用 Just Recipes

```bash
# 查看所有可用命令
just --list

# 构建
just build              # Debug 版本
just build-release      # Release 版本

# 测试
just test               # 运行测试

# 代码质量
just lint               # 代码检查
just format             # 代码格式化

# 安装
just install            # 本地安装到 /Applications

# 版本管理
just version            # 查看当前版本
just update-version 1.3.0  # 更新版本号

# 发布
just dmg 1.3.0          # 创建 DMG
just clean-artifacts    # 清理产物

# 工具
just check-deps         # 检查依赖
just dev                # 打开 Xcode
```

详见 [DEVELOPMENT.md](./DEVELOPMENT.md) 获取完整说明。

### 原始命令（仅供参考）

如果 just recipe 不满足需求，可以使用原始命令：

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

## UI 设计经验

### 全高度侧边栏（Full-height Sidebar）
实现遵循 Apple HIG 的全高度侧边栏设计：

```swift
// 窗口配置
window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden
window.toolbarStyle = .unified
```

**关键点**：
- 使用 `.fullSizeContentView` 让内容延伸到标题栏
- `titlebarAppearsTransparent = true` 创建透明标题栏效果
- `toolbarStyle = .unified` 实现统一工具栏样式
- 侧边栏和详情面板都需要添加 `.toolbar` 以创建正确的安全区域

### 自定义菜单项视图
创建两行展示的自定义菜单项：

**关键实现**：
- 使用 `NSMenuItem.view` 设置自定义视图
- 通过 `NSTrackingArea` 实现鼠标悬停高亮效果
- 使用 `NSColor.selectedMenuItemColor` 绘制选中背景
- 右键菜单通过 `NSMenu.popUpContextMenu()` 实现

**注意事项**：
- 自定义视图不会自动绘制标准 NSMenuItem 属性
- 需要手动实现高亮、点击等所有交互
- 视图尺寸需要固定，建议高度 40pt，宽度 280pt

### 工具栏配置
避免工具栏按钮对齐问题：

```swift
// ❌ 错误：使用 ToolbarItemGroup 可能导致对齐不一致
ToolbarItemGroup(placement: .primaryAction) {
    Button(...) { ... }
    Menu(...) { ... }
}

// ✅ 正确：分别使用 ToolbarItem
ToolbarItem(placement: .primaryAction) {
    Button { ... } label: { Label("添加", systemImage: "plus") }
}
ToolbarItem(placement: .primaryAction) {
    Menu { ... } label: { Label("更多", systemImage: "ellipsis.circle") }
}
```

## Bug 解决经验

### RSS 非标准 MIME 类型
**问题**：部分 RSS 源使用非标准 MIME 类型（如 `application/x-rss+xml`）导致解析失败

**解决方案**：
```swift
private let allowedContentTypes = [
    "application/rss+xml",
    "application/x-rss+xml",      // 非标准但常见
    "application/atom+xml",
    "application/x-atom+xml",     // 非标准但常见
    "application/xml",
    "text/xml",
    "application/json",
    "text/html"
]
```

### NSError 条件转换警告
**问题**：`if let nsError = error as? NSError` 导致编译器警告

**原因**：Swift 中 `Error` 协议会自动桥接到 `NSError`，条件转换总是成功

**解决方案**：
```swift
// ❌ 错误
if let nsError = error as? NSError { ... }

// ✅ 正确
let nsError = error as NSError
```

### NavigationSplitView 约束冲突
**问题**：`NSToolbarTitleView` 宽度约束冲突

**解决方案**：
1. 为侧边栏添加 `.toolbar` 并设置标题
2. 为详情面板也添加 `.toolbar` 创建安全区域
3. 使用 `.navigationSplitViewColumnWidth()` 设置合理的列宽

### 开发环境配置
使用条件编译避免开发时的自动刷新：

```swift
#if !DEBUG
refreshAll()
setupTimer()
#else
print("🔧 开发模式：跳过自动刷新")
#endif
```

**好处**：
- 方便在 Xcode 中调试网络请求
- 避免开发时频繁刷新干扰
- 保持生产环境行为不变

### 优先级反转警告
**问题**：使用 `DispatchSemaphore` 在 async/await 上下文中导致优先级反转警告

**解决方案**：
使用 actor 实现的 `AsyncSemaphore` 替代 `DispatchSemaphore`：

```swift
private actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.count = value
    }

    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        } else {
            count += 1
        }
    }
}
```

## 调试技巧

### RSS 解析失败诊断
添加详细日志以快速定位问题：

```swift
print("📝 FeedParser: 检测到 Feed 类型 = \(feedType)")
print("📝 FeedParser: 数据大小 = \(data.count) 字节")

// 解析失败时打印前 200 字节
let preview = String(decoding: data.prefix(200), as: UTF8.self)
print("❌ 数据预览: \(preview)")
```

### 网络错误详情
打印完整错误上下文：

```swift
print("❌ ========== 刷新失败详情 ==========")
print("❌ 订阅源: \(source.title)")
print("❌ Feed URL: \(source.feedURL)")
print("❌ 错误类型: \(type(of: error))")
print("❌ 错误描述: \(error)")

if let feedError = error as? FeedError {
    print("❌ FeedError.shortDescription: \(feedError.shortDescription)")
}

let nsError = error as NSError
print("❌ NSError domain: \(nsError.domain)")
print("❌ NSError code: \(nsError.code)")
print("❌ =====================================")
```
