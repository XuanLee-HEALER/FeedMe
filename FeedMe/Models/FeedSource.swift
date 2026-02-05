//
//  FeedSource.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation
import GRDB

/// 订阅源模型
struct FeedSource: Codable, Identifiable, Hashable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "feedSources"

    /// 唯一标识符
    var id: String

    /// 源标题
    var title: String

    /// 站点 URL (可选)
    var siteURL: String?

    /// Feed URL
    var feedURL: String

    /// 是否启用
    var isEnabled: Bool

    /// 刷新间隔（分钟），0 表示使用全局设置
    var refreshIntervalMinutes: Int

    /// 显示顺序
    var displayOrder: Int

    /// 最后拉取时间
    var lastFetchedAt: Date?

    /// ETag 缓存
    var etag: String?

    /// Last-Modified 缓存
    var lastModified: String?

    /// 最后一次错误信息
    var lastError: String?

    /// 连续失败次数（用于错误退避）
    var consecutiveFailures: Int

    /// 分组标签（nil = "未分类"）
    var tag: String?

    /// 初始化
    init(
        id: String = UUID().uuidString,
        title: String,
        siteURL: String? = nil,
        feedURL: String,
        isEnabled: Bool = true,
        refreshIntervalMinutes: Int = 0,
        displayOrder: Int = 0,
        lastFetchedAt: Date? = nil,
        etag: String? = nil,
        lastModified: String? = nil,
        lastError: String? = nil,
        consecutiveFailures: Int = 0,
        tag: String? = nil
    ) {
        self.id = id
        self.title = title
        self.siteURL = siteURL
        self.feedURL = feedURL
        self.isEnabled = isEnabled
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.displayOrder = displayOrder
        self.lastFetchedAt = lastFetchedAt
        self.etag = etag
        self.lastModified = lastModified
        self.lastError = lastError
        self.consecutiveFailures = consecutiveFailures
        self.tag = tag
    }
}

// MARK: - GRDB Columns

extension FeedSource {
    /// 定义列名
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let siteURL = Column("siteURL")
        static let feedURL = Column("feedURL")
        static let isEnabled = Column("isEnabled")
        static let refreshIntervalMinutes = Column("refreshIntervalMinutes")
        static let displayOrder = Column("displayOrder")
        static let lastFetchedAt = Column("lastFetchedAt")
        static let etag = Column("etag")
        static let lastModified = Column("lastModified")
        static let lastError = Column("lastError")
        static let consecutiveFailures = Column("consecutiveFailures")
        static let tag = Column("tag")
    }
}

// MARK: - Helpers

extension FeedSource {
    /// 计算下次刷新时间
    func nextRefreshDate(globalInterval: Int) -> Date? {
        guard let lastFetched = lastFetchedAt else { return nil }

        let interval = refreshIntervalMinutes > 0 ? refreshIntervalMinutes : globalInterval

        // 错误退避：连续失败时延长间隔
        let backoffMultiplier = min(pow(2.0, Double(consecutiveFailures)), 8.0) // 最多 8 倍
        let effectiveInterval = Double(interval) * backoffMultiplier

        return lastFetched.addingTimeInterval(effectiveInterval * 60)
    }

    /// 标记刷新成功
    mutating func markSuccess(etag: String? = nil, lastModified: String? = nil) {
        lastFetchedAt = Date()
        self.etag = etag
        self.lastModified = lastModified
        lastError = nil
        consecutiveFailures = 0
    }

    /// 标记刷新失败
    mutating func markFailure(error: String) {
        lastFetchedAt = Date()
        lastError = error
        consecutiveFailures += 1
    }
}
