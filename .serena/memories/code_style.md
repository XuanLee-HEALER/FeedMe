# FeedMe 代码风格和约定

## 命名约定
- **类型**: PascalCase (FeedSource, FeedManager)
- **变量/函数**: camelCase (fetchItems, isRefreshing)
- **常量**: camelCase (databaseTableName, maxResponseSize)
- **枚举值**: camelCase (FetchResult.success, FetchResult.notModified)

## 代码组织
- 使用 `// MARK: -` 分隔代码区域
- 使用 `extension` 分离协议实现和功能模块
- 中文注释说明复杂逻辑

## Swift 并发
- 使用 `@MainActor` 标记 UI 相关类 (FeedManager)
- Task 中更新 @State 时使用 `Task { @MainActor in ... }`
- 避免在 defer 中调用 actor-isolated 方法

## GRDB 使用
- 模型实现 `FetchableRecord`, `PersistableRecord`
- 使用 `Columns` 枚举定义列名
- 配置 `foreignKeysEnabled = true`

## SwiftUI 约定
- View 使用 `@State` 管理本地状态
- 使用 `@Environment(\.dismiss)` 关闭 Sheet
- 使用 `.accessibilityLabel()` 添加无障碍支持

## 错误处理
- 自定义 `FeedError` 枚举实现 `LocalizedError`
- 网络错误提供 `shortDescription` 简短描述
- 使用 `do-catch` 而非强制解包

## 安全规范
- URL 打开前校验 scheme (仅 http/https)
- 网络响应限制大小 (10MB)
- 验证 Content-Type
