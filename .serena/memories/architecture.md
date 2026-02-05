# FeedMe 架构

## 目录结构
```
FeedMe/
├── FeedMeApp.swift          # SwiftUI App 入口
├── AppDelegate.swift        # 菜单栏逻辑（NSStatusItem）
├── ContentView.swift        # 设置界面
├── Info.plist               # 应用配置 (LSUIElement=YES)
├── Models/
│   ├── FeedSource.swift     # 订阅源模型 (GRDB)
│   ├── FeedItem.swift       # 文章模型 (GRDB)
│   ├── FeedError.swift      # 错误类型枚举
│   └── AppSettings.swift    # 应用设置 (@AppStorage)
├── Services/
│   ├── FeedStorage.swift    # 数据库 CRUD (SQLite/GRDB)
│   ├── FeedFetcher.swift    # 网络请求 (URLSession)
│   ├── FeedParser.swift     # Feed 解析 (FeedKit)
│   ├── FeedDiscovery.swift  # Feed 自动发现
│   ├── OPMLService.swift    # OPML 导入/导出
│   └── NotificationService.swift  # 系统通知
├── Managers/
│   └── FeedManager.swift    # 刷新管理器（单例，@MainActor）
├── Views/
│   ├── MenuBuilder.swift    # 菜单构建器
│   └── FeedManagementView.swift  # 订阅源管理窗口
└── Assets.xcassets/         # 资源文件
```

## 核心类关系

### 数据层
- `FeedSource` - 订阅源实体，包含 URL、ETag、错误状态等
- `FeedItem` - 文章实体，包含去重键 (dedupeKey)
- `FeedStorage` - 单例，管理 SQLite 数据库操作

### 网络层
- `FeedFetcher` - 网络请求，支持 ETag/Last-Modified 条件请求
- `FeedParser` (FeedParserService) - 解析 RSS/Atom/JSON Feed
- `FeedDiscovery` - 从网站 HTML 发现 Feed URL

### UI 层
- `AppDelegate` - 管理 NSStatusItem 和菜单交互
- `MenuBuilder` - 构建左键/右键菜单
- `FeedManagementView` - SwiftUI 订阅管理窗口

### 管理层
- `FeedManager` - 单例，协调刷新流程，定时器管理

## 数据流
1. 用户添加订阅源 → FeedStorage.addSource()
2. FeedManager.refreshAll() → FeedFetcher.fetch() → FeedParser.parse()
3. 解析结果 → FeedStorage.saveItems() (带去重)
4. UI 通过 NotificationCenter 更新菜单栏未读数

## 关键设计
- **去重策略**: (sourceId, dedupeKey) 唯一约束，dedupeKey = guid > link > hash
- **并发控制**: FeedFetcher 使用 DispatchSemaphore 限制最多 5 个并发请求
- **错误退避**: 连续失败时延长刷新间隔 (15min → 30min → 60min → 120min)
- **安全**: URL scheme 白名单 (http/https)，响应大小限制 (10MB)
