# FeedMe 符号索引

## 数据模型 (Models/)

### FeedSource.swift
```
struct FeedSource: Codable, Identifiable, FetchableRecord, PersistableRecord
├── Properties: id, title, siteURL, feedURL, isEnabled, refreshIntervalMinutes
│              lastFetchedAt, etag, lastModified, lastError, consecutiveFailures
├── init(id:title:siteURL:feedURL:isEnabled:refreshIntervalMinutes:...)
├── Columns: enum (id, title, siteURL, feedURL, ...)
├── nextRefreshDate(globalInterval:) -> Date?
├── markSuccess(etag:lastModified:)
└── markFailure(error:)
```

### FeedItem.swift
```
struct FeedItem: Codable, Identifiable, FetchableRecord, PersistableRecord
├── Properties: id, sourceId, guidOrId, link, title, publishedAt, summary
│              isRead, firstSeenAt, dedupeKey
├── init(id:sourceId:guidOrId:link:title:publishedAt:summary:isRead:firstSeenAt:)
├── calculateDedupeKey(...) -> String  [static]
├── Columns: enum
├── source: BelongsTo<FeedSource>
├── displayTitle: String
└── displayDate: String?
```

### FeedError.swift
```
enum FeedError: LocalizedError
├── .invalidURL(String)
├── .networkError(Error)
├── .parseError(String)
├── .httpError(Int)
├── .timeout
├── .unknown(String)
└── shortDescription: String
```

### AppSettings.swift
```
class AppSettings: ObservableObject
├── @AppStorage properties: globalRefreshInterval, markAsReadOnClick, sortOrder, displayCount
└── shared: AppSettings [static]
```

## 服务层 (Services/)

### FeedStorage.swift
```
class FeedStorage
├── shared: FeedStorage [static singleton]
├── dbQueue: DatabaseQueue
├── migrator: DatabaseMigrator
├── // FeedSource CRUD
│   ├── addSource(_:)
│   ├── deleteSource(id:)
│   ├── updateSource(_:)
│   ├── fetchAllSources() -> [FeedSource]
│   ├── fetchEnabledSources() -> [FeedSource]
│   └── fetchSource(id:) -> FeedSource?
└── // FeedItem CRUD
    ├── saveItems(_:for:) -> Int  [返回新增数量]
    ├── fetchItems(for:limit:unreadOnly:) -> [FeedItem]
    ├── markAsRead(itemId:)
    ├── markAllAsRead(sourceId:)
    ├── deleteItems(for:)
    └── fetchUnreadCount(for:) -> Int
```

### FeedFetcher.swift
```
class FeedFetcher: Sendable
├── shared: FeedFetcher [static singleton]
├── FetchResult: enum { success(data, etag, lastModified), notModified }
├── fetch(url:etag:lastModified:) async throws -> FetchResult
└── fetchMultiple(sources:) async -> [(source, Result<FetchResult, Error>)]
```

### FeedParserService (FeedParser.swift)
```
class FeedParserService
├── parse(data:sourceId:) throws -> [FeedItem]  [static]
├── detectFeedType(data:) -> DetectedFeedType  [static]
├── parseRSS(_:sourceId:) -> [FeedItem]  [static]
├── parseAtom(_:sourceId:) -> [FeedItem]  [static]
└── parseJSON(_:sourceId:) -> [FeedItem]  [static]
```

### FeedDiscovery.swift
```
class FeedDiscovery
├── discover(from:) async throws -> [DiscoveredFeed]  [static]
├── validateFeedURL(_:) async throws -> Bool  [static]
└── DiscoveredFeed: struct { url, title, type }
```

## 管理层 (Managers/)

### FeedManager.swift
```
@MainActor class FeedManager: ObservableObject
├── shared: FeedManager [static singleton]
├── @Published isRefreshing: Bool
├── @Published lastRefreshDate: Date?
├── refreshAll() async
├── refresh(sourceId:) async
├── refreshOnLaunch()
└── resetTimer()
```

## UI 层 (Views/)

### AppDelegate.swift
```
class AppDelegate: NSObject, NSApplicationDelegate
├── statusItem: NSStatusItem
├── menuBuilder: MenuBuilder
├── applicationDidFinishLaunching(_:)
├── handleStatusItemClick(_:)  [左键/右键分发]
├── updateUnreadBadge()
├── startRefreshAnimation() / stopRefreshAnimation()
└── // MenuBuilderDelegate
    ├── openArticle(_:)
    ├── refreshAll()
    ├── markAllAsRead()
    ├── openManagement()
    ├── openSettings()
    └── quit()
```

### MenuBuilder.swift
```
class MenuBuilder
├── delegate: MenuBuilderDelegate?
├── buildArticleListMenu() -> NSMenu
└── buildAppMenu() -> NSMenu

protocol MenuBuilderDelegate
├── openArticle(_:)
├── refreshAll()
├── markAllAsRead()
├── openManagement()
├── openSettings()
├── openAbout()
└── quit()
```

### FeedManagementView.swift
```
struct FeedManagementView: View
├── @State sources, selectedSources, searchText, ...
├── body: NavigationSplitView { List, Detail }
├── loadSources()
├── addSource(_:)
├── deleteSource(_:)
└── refreshSource(_:)

struct FeedSourceRow: View
struct FeedSourceDetailView: View
struct AddFeedSheet: View
struct EditFeedSheet: View
struct OPMLDocument: FileDocument
```

## 通知

### Notification.Name
```
.feedDataDidChange  // 数据变化时发送，UI 更新未读计数
```
