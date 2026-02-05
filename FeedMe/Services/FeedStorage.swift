//
//  FeedStorage.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation
import GRDB

/// Feed 数据存储管理器
final class FeedStorage {
    /// 数据库队列
    private let dbQueue: DatabaseQueue

    /// 单例
    static let shared: FeedStorage = {
        do {
            return try FeedStorage()
        } catch {
            fatalError("Failed to initialize FeedStorage: \(error)")
        }
    }()

    /// 初始化
    private init() throws {
        // 数据库路径: ~/Library/Application Support/FeedMe/
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let feedMeURL = appSupportURL.appendingPathComponent("FeedMe", isDirectory: true)
        try fileManager.createDirectory(at: feedMeURL, withIntermediateDirectories: true)

        let dbURL = feedMeURL.appendingPathComponent("feedme.db")

        // 创建数据库队列
        var config = Configuration()
        config.foreignKeysEnabled = true  // 显式启用外键约束
        dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)

        // 运行迁移
        try migrator.migrate(dbQueue)
    }

    /// 数据库迁移器
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // v1: 初始表结构
        migrator.registerMigration("v1_initial") { db in
            // FeedSource 表
            try db.create(table: "feedSources") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("siteURL", .text)
                t.column("feedURL", .text).notNull()
                t.column("isEnabled", .boolean).notNull().defaults(to: true)
                t.column("refreshIntervalMinutes", .integer).notNull().defaults(to: 0)
                t.column("lastFetchedAt", .datetime)
                t.column("etag", .text)
                t.column("lastModified", .text)
                t.column("lastError", .text)
                t.column("consecutiveFailures", .integer).notNull().defaults(to: 0)
            }

            // FeedItem 表
            try db.create(table: "feedItems") { t in
                t.column("id", .text).primaryKey()
                t.column("sourceId", .text).notNull()
                    .indexed()
                    .references("feedSources", onDelete: .cascade)
                t.column("guidOrId", .text)
                t.column("link", .text).notNull()
                t.column("title", .text).notNull()
                t.column("publishedAt", .datetime)
                t.column("summary", .text)
                t.column("isRead", .boolean).notNull().defaults(to: false)
                t.column("firstSeenAt", .datetime).notNull()
                t.column("dedupeKey", .text).notNull()

                // 唯一约束: (sourceId, dedupeKey)
                t.uniqueKey(["sourceId", "dedupeKey"])
            }

            // 索引
            try db.create(index: "idx_feedItems_isRead", on: "feedItems", columns: ["isRead"])
            try db.create(index: "idx_feedItems_publishedAt", on: "feedItems", columns: ["publishedAt"])
        }

        // v2: 添加显示顺序字段
        migrator.registerMigration("v2_add_display_order") { db in
            try db.alter(table: "feedSources") { t in
                t.add(column: "displayOrder", .integer).notNull().defaults(to: 0)
            }
        }

        // v3: 添加 Tag 分组字段
        migrator.registerMigration("v3_add_tag") { db in
            try db.alter(table: "feedSources") { t in
                t.add(column: "tag", .text)  // nullable, nil = "未分类"
            }
            try db.create(index: "idx_feedSources_tag", on: "feedSources", columns: ["tag"])
        }

        return migrator
    }
}

// MARK: - FeedSource CRUD

extension FeedStorage {
    /// 添加订阅源
    func addSource(_ source: FeedSource) throws {
        try dbQueue.write { db in
            try source.insert(db)
        }
    }

    /// 删除订阅源
    func deleteSource(id: String) throws {
        _ = try dbQueue.write { db in
            try FeedSource.deleteOne(db, key: id)
        }
    }

    /// 更新订阅源
    func updateSource(_ source: FeedSource) throws {
        try dbQueue.write { db in
            try source.update(db)
        }
    }

    /// 批量更新订阅源的显示顺序
    func updateSourcesOrder(_ sources: [FeedSource]) throws {
        try dbQueue.write { db in
            for (index, var source) in sources.enumerated() {
                source.displayOrder = index
                try source.update(db)
            }
        }
    }

    /// 获取所有订阅源
    func fetchAllSources() throws -> [FeedSource] {
        try dbQueue.read { db in
            try FeedSource
                .order(FeedSource.Columns.displayOrder)
                .fetchAll(db)
        }
    }

    /// 获取启用的订阅源
    func fetchEnabledSources() throws -> [FeedSource] {
        try dbQueue.read { db in
            try FeedSource
                .filter(FeedSource.Columns.isEnabled == true)
                .fetchAll(db)
        }
    }

    /// 获取单个订阅源
    func fetchSource(id: String) throws -> FeedSource? {
        try dbQueue.read { db in
            try FeedSource.fetchOne(db, key: id)
        }
    }
}

// MARK: - FeedItem CRUD

extension FeedStorage {
    /// 保存文章列表（带去重）
    /// - Returns: 新增的文章数量
    @discardableResult
    func saveItems(_ items: [FeedItem], for sourceId: String) throws -> Int {
        try dbQueue.write { db in
            var newCount = 0

            for var item in items {
                // 检查是否存在
                let existing = try FeedItem
                    .filter(FeedItem.Columns.sourceId == sourceId)
                    .filter(FeedItem.Columns.dedupeKey == item.dedupeKey)
                    .fetchOne(db)

                if let existing = existing {
                    // 已存在：更新标题/时间，但保留已读状态
                    item.id = existing.id
                    item.isRead = existing.isRead
                    item.firstSeenAt = existing.firstSeenAt
                    try item.update(db)
                } else {
                    // 不存在：插入新条目
                    try item.insert(db)
                    newCount += 1
                }
            }

            return newCount
        }
    }

    /// 获取文章列表
    func fetchItems(
        for sourceId: String? = nil,
        limit: Int? = nil,
        unreadOnly: Bool = false
    ) throws -> [FeedItem] {
        try dbQueue.read { db in
            var request = FeedItem.all()

            // 过滤订阅源
            if let sourceId = sourceId {
                request = request.filter(FeedItem.Columns.sourceId == sourceId)
            }

            // 过滤未读
            if unreadOnly {
                request = request.filter(FeedItem.Columns.isRead == false)
            }

            // 排序：publishedAt 降序（空值排后面），使用 COALESCE 处理空值
            // SQLite 中 NULL 在 DESC 排序时默认排在最前面，我们希望它排在最后面
            // 方案：先按是否为空排序（有值的排前面），再按时间降序
            request = request.order(
                (FeedItem.Columns.publishedAt == nil).asc,  // 有值的在前（false < true）
                FeedItem.Columns.publishedAt.desc,
                FeedItem.Columns.firstSeenAt.desc
            )

            // 限制数量
            if let limit = limit {
                request = request.limit(limit)
            }

            return try request.fetchAll(db)
        }
    }

    /// 标记为已读
    func markAsRead(itemId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE \(FeedItem.databaseTableName) SET isRead = 1 WHERE id = ?",
                arguments: [itemId]
            )
        }
    }

    /// 全部标为已读
    func markAllAsRead(sourceId: String? = nil) throws {
        try dbQueue.write { db in
            if let sourceId = sourceId {
                try db.execute(
                    sql: "UPDATE \(FeedItem.databaseTableName) SET isRead = 1 WHERE sourceId = ?",
                    arguments: [sourceId]
                )
            } else {
                try db.execute(
                    sql: "UPDATE \(FeedItem.databaseTableName) SET isRead = 1"
                )
            }
        }
    }

    /// 删除某个源的所有文章
    func deleteItems(for sourceId: String) throws {
        _ = try dbQueue.write { db in
            try FeedItem
                .filter(FeedItem.Columns.sourceId == sourceId)
                .deleteAll(db)
        }
    }

    /// 获取未读计数
    func fetchUnreadCount(for sourceId: String? = nil) throws -> Int {
        try dbQueue.read { db in
            var request = FeedItem.filter(FeedItem.Columns.isRead == false)

            if let sourceId = sourceId {
                request = request.filter(FeedItem.Columns.sourceId == sourceId)
            }

            return try request.fetchCount(db)
        }
    }
}


// MARK: - v1.1 新增查询方法

extension FeedStorage {
    /// 按名称排序获取所有订阅源（本地化排序）
    func fetchAllSourcesSortedByName() throws -> [FeedSource] {
        try dbQueue.read { db in
            try FeedSource
                .order(FeedSource.Columns.title.collating(.localizedCaseInsensitiveCompare))
                .fetchAll(db)
        }
    }

    /// 按源分组获取未读文章（源按名称排序）
    func fetchUnreadItemsGroupedBySource() throws -> [(source: FeedSource, items: [FeedItem])] {
        try dbQueue.read { db in
            // 1. 获取按名称排序的所有源
            let sources = try FeedSource
                .order(FeedSource.Columns.title.collating(.localizedCaseInsensitiveCompare))
                .fetchAll(db)

            // 2. 获取每个源的未读文章
            var result: [(source: FeedSource, items: [FeedItem])] = []

            for source in sources {
                let items = try FeedItem
                    .filter(FeedItem.Columns.sourceId == source.id)
                    .filter(FeedItem.Columns.isRead == false)
                    .order(
                        (FeedItem.Columns.publishedAt == nil).asc,
                        FeedItem.Columns.publishedAt.desc,
                        FeedItem.Columns.firstSeenAt.desc
                    )
                    .fetchAll(db)

                if !items.isEmpty {
                    result.append((source: source, items: items))
                }
            }

            return result
        }
    }

    /// 获取文章关联的源名称
    func fetchSourceName(for sourceId: String) throws -> String {
        try dbQueue.read { db in
            if let source = try FeedSource.fetchOne(db, key: sourceId) {
                return source.title
            }
            return "未知来源"
        }
    }
}


// MARK: - v1.3 Tag 分组相关查询

extension FeedStorage {
    /// 获取所有唯一 Tag（不包含 nil）
    func fetchAllTags() throws -> [String] {
        try dbQueue.read { db in
            let tags = try String.fetchAll(
                db,
                sql: """
                    SELECT DISTINCT tag
                    FROM \(FeedSource.databaseTableName)
                    WHERE tag IS NOT NULL
                    ORDER BY tag COLLATE NOCASE
                    """
            )
            return tags
        }
    }

    /// 按 Tag 分组获取订阅源
    /// - Returns: [(tag: String?, sources: [FeedSource])]
    ///   - tag = nil 表示未分类订阅源
    ///   - 未分类在前，Tag 分组在后（按字母/拼音排序）
    func fetchSourcesGroupedByTag() throws -> [(tag: String?, sources: [FeedSource])] {
        try dbQueue.read { db in
            var result: [(tag: String?, sources: [FeedSource])] = []

            // 1. 获取未分类订阅源 (tag IS NULL)
            let ungroupedSources = try FeedSource
                .filter(FeedSource.Columns.tag == nil)
                .order(FeedSource.Columns.displayOrder)
                .fetchAll(db)

            if !ungroupedSources.isEmpty {
                result.append((tag: nil, sources: ungroupedSources))
            }

            // 2. 获取所有 Tag
            let tags = try fetchAllTags()

            // 3. 获取每个 Tag 下的订阅源
            for tag in tags {
                let sources = try FeedSource
                    .filter(FeedSource.Columns.tag == tag)
                    .order(FeedSource.Columns.displayOrder)
                    .fetchAll(db)

                if !sources.isEmpty {
                    result.append((tag: tag, sources: sources))
                }
            }

            return result
        }
    }

    /// 获取 Tag 下的未读计数
    /// - Parameter tag: Tag 名称，nil 表示未分类
    func fetchUnreadCountForTag(_ tag: String?) throws -> Int {
        try dbQueue.read { db in
            // 获取该 Tag 下的所有订阅源 ID
            let sourceIds: [String]
            if let tag = tag {
                sourceIds = try FeedSource
                    .filter(FeedSource.Columns.tag == tag)
                    .select(FeedSource.Columns.id)
                    .fetchAll(db)
                    .map(\.id)
            } else {
                sourceIds = try FeedSource
                    .filter(FeedSource.Columns.tag == nil)
                    .select(FeedSource.Columns.id)
                    .fetchAll(db)
                    .map(\.id)
            }

            // 统计这些订阅源的未读数
            if sourceIds.isEmpty {
                return 0
            }

            return try FeedItem
                .filter(sourceIds.contains(FeedItem.Columns.sourceId))
                .filter(FeedItem.Columns.isRead == false)
                .fetchCount(db)
        }
    }

    /// 标记 Tag 下所有文章为已读
    /// - Parameter tag: Tag 名称，nil 表示未分类
    func markAllAsReadForTag(_ tag: String?) throws {
        try dbQueue.write { db in
            // 获取该 Tag 下的所有订阅源 ID
            let sourceIds: [String]
            if let tag = tag {
                sourceIds = try FeedSource
                    .filter(FeedSource.Columns.tag == tag)
                    .select(FeedSource.Columns.id)
                    .fetchAll(db)
                    .map(\.id)
            } else {
                sourceIds = try FeedSource
                    .filter(FeedSource.Columns.tag == nil)
                    .select(FeedSource.Columns.id)
                    .fetchAll(db)
                    .map(\.id)
            }

            // 标记这些订阅源的所有文章为已读
            if !sourceIds.isEmpty {
                let placeholders = sourceIds.map { _ in "?" }.joined(separator: ",")
                try db.execute(
                    sql: """
                        UPDATE \(FeedItem.databaseTableName)
                        SET isRead = 1
                        WHERE sourceId IN (\(placeholders))
                        """,
                    arguments: StatementArguments(sourceIds)
                )
            }
        }
    }
}
