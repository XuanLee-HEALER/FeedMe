//
//  FeedItem.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation
import GRDB
import CryptoKit

/// Feed 文章条目模型
struct FeedItem: Codable, Identifiable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "feedItems"

    /// 内部唯一标识符
    var id: String

    /// 所属订阅源 ID
    var sourceId: String

    /// 外部 guid 或 id
    var guidOrId: String?

    /// 文章链接
    var link: String

    /// 文章标题
    var title: String

    /// 发布时间
    var publishedAt: Date?

    /// 摘要
    var summary: String?

    /// 是否已读
    var isRead: Bool

    /// 首次发现时间
    var firstSeenAt: Date

    /// 去重键（计算属性存储到数据库）
    var dedupeKey: String

    /// 初始化
    init(
        id: String = UUID().uuidString,
        sourceId: String,
        guidOrId: String? = nil,
        link: String,
        title: String,
        publishedAt: Date? = nil,
        summary: String? = nil,
        isRead: Bool = false,
        firstSeenAt: Date = Date()
    ) {
        self.id = id
        self.sourceId = sourceId
        self.guidOrId = guidOrId
        self.link = link
        self.title = title
        self.publishedAt = publishedAt
        self.summary = summary
        self.isRead = isRead
        self.firstSeenAt = firstSeenAt

        // 计算去重键
        self.dedupeKey = Self.calculateDedupeKey(
            guidOrId: guidOrId,
            link: link,
            title: title,
            publishedAt: publishedAt,
            sourceId: sourceId
        )
    }

    /// 计算去重键
    /// 优先级: guid > link > hash(title + publishedAt + sourceId)
    static func calculateDedupeKey(
        guidOrId: String?,
        link: String,
        title: String,
        publishedAt: Date?,
        sourceId: String
    ) -> String {
        // 1. 优先使用 guid
        if let guid = guidOrId, !guid.isEmpty {
            return guid
        }

        // 2. 否则使用 link
        if !link.isEmpty {
            return link
        }

        // 3. 兜底：hash(title + publishedAt + sourceId)
        let publishedString = publishedAt?.ISO8601Format() ?? ""
        let combined = "\(title)-\(publishedString)-\(sourceId)"
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - GRDB Columns

extension FeedItem {
    /// 定义列名
    enum Columns {
        static let id = Column("id")
        static let sourceId = Column("sourceId")
        static let guidOrId = Column("guidOrId")
        static let link = Column("link")
        static let title = Column("title")
        static let publishedAt = Column("publishedAt")
        static let summary = Column("summary")
        static let isRead = Column("isRead")
        static let firstSeenAt = Column("firstSeenAt")
        static let dedupeKey = Column("dedupeKey")
    }
}

// MARK: - Associations

extension FeedItem {
    /// 关联到 FeedSource
    static let source = belongsTo(FeedSource.self)
}

// MARK: - Helpers

extension FeedItem {
    /// 显示用的标题（处理空标题情况）
    var displayTitle: String {
        title.isEmpty ? "(无标题)" : title
    }

    /// 显示用的时间（优先 publishedAt，否则 firstSeenAt）
    var displayDate: Date {
        publishedAt ?? firstSeenAt
    }
}
