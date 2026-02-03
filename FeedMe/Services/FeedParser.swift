//
//  FeedParser.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation
import FeedKit
import XMLKit

/// 重命名本地 FeedError 以避免与 FeedKit.FeedError 冲突
typealias AppFeedError = FeedMe.FeedError

/// Feed 解析服务
final class FeedParserService {
    /// 解析 RSS/Atom Feed 数据
    /// - Parameters:
    ///   - data: Feed XML 数据
    ///   - sourceId: 订阅源 ID
    /// - Returns: 解析后的文章列表
    static func parse(data: Data, sourceId: String) throws -> [FeedItem] {
        // 先检测 Feed 类型（FeedKit 的检测只看前 128 字节，可能漏掉）
        let feedType = detectFeedType(data: data)

        do {
            switch feedType {
            case .rss:
                let rssFeed = try RSSFeed(data: data)
                return parseRSS(rssFeed, sourceId: sourceId)

            case .atom:
                let atomFeed = try AtomFeed(data: data)
                return parseAtom(atomFeed, sourceId: sourceId)

            case .json:
                let jsonFeed = try JSONFeed(data: data)
                return parseJSON(jsonFeed, sourceId: sourceId)

            case .unknown:
                throw AppFeedError.parseError("无法识别的 Feed 格式")
            }
        } catch let error as AppFeedError {
            throw error
        } catch {
            throw AppFeedError.parseError(error.localizedDescription)
        }
    }

    /// 检测 Feed 类型（扩展检测范围到 1024 字节）
    private static func detectFeedType(data: Data) -> DetectedFeedType {
        // 检查前 1024 字节（比 FeedKit 默认的 128 字节更可靠）
        let prefixLength = min(1024, data.count)
        let string = String(decoding: data.prefix(prefixLength), as: UTF8.self).lowercased()

        // JSON Feed
        if string.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
            return .json
        }

        // RSS
        if string.contains("<rss") {
            return .rss
        }

        // Atom
        if string.contains("<feed") {
            return .atom
        }

        return .unknown
    }

    private enum DetectedFeedType {
        case rss, atom, json, unknown
    }

    /// 解析 RSS Feed
    private static func parseRSS(_ feed: RSSFeed, sourceId: String) -> [FeedItem] {
        guard let channel = feed.channel, let items = channel.items else { return [] }

        return items.compactMap { item -> FeedItem? in
            // 获取链接
            guard let link = item.link, !link.isEmpty else {
                return nil
            }

            let title = item.title ?? "(无标题)"
            // GUID 是 XMLElement 类型，使用 .text 获取字符串值
            let guidOrId = item.guid?.text ?? link
            let publishedAt = item.pubDate
            // Content 类型使用 .encoded 获取 content:encoded 内容
            let summary = item.description ?? item.content?.encoded

            return FeedItem(
                sourceId: sourceId,
                guidOrId: guidOrId,
                link: link,
                title: title,
                publishedAt: publishedAt,
                summary: summary
            )
        }
    }

    /// 解析 Atom Feed
    private static func parseAtom(_ feed: AtomFeed, sourceId: String) -> [FeedItem] {
        guard let entries = feed.entries else { return [] }

        return entries.compactMap { entry -> FeedItem? in
            // 查找 alternate link 或第一个 link
            var link: String = ""

            if let links = entry.links {
                // 优先找 alternate 类型的链接
                for linkItem in links {
                    if let attributes = linkItem.attributes {
                        if attributes.rel == "alternate", let href = attributes.href {
                            link = href
                            break
                        }
                    }
                }
                // 如果没找到 alternate，使用第一个链接
                if link.isEmpty, let firstLink = links.first,
                   let attributes = firstLink.attributes,
                   let href = attributes.href {
                    link = href
                }
            }

            guard !link.isEmpty else { return nil }

            // 获取标题 - AtomFeedEntry.title 是直接的 String?
            let title = entry.title ?? "(无标题)"

            let guidOrId = entry.id
            let publishedAt = entry.published ?? entry.updated
            // AtomFeedSummary 和 AtomFeedContent 是 XMLElement，使用 .text 获取内容
            let summary = entry.summary?.text ?? entry.content?.text

            return FeedItem(
                sourceId: sourceId,
                guidOrId: guidOrId,
                link: link,
                title: title,
                publishedAt: publishedAt,
                summary: summary
            )
        }
    }

    /// 解析 JSON Feed
    private static func parseJSON(_ feed: JSONFeed, sourceId: String) -> [FeedItem] {
        guard let items = feed.items else { return [] }

        return items.compactMap { item -> FeedItem? in
            // 获取链接
            guard let link = item.url ?? item.externalURL, !link.isEmpty else {
                return nil
            }

            let title = item.title ?? "(无标题)"
            let guidOrId = item.id
            let publishedAt = item.datePublished
            let summary = item.summary ?? item.contentText

            return FeedItem(
                sourceId: sourceId,
                guidOrId: guidOrId,
                link: link,
                title: title,
                publishedAt: publishedAt,
                summary: summary
            )
        }
    }

    /// 提取 Feed 标题
    static func extractFeedTitle(from data: Data) -> String? {
        guard let feed = try? Feed(data: data) else { return nil }

        switch feed {
        case .rss(let rssFeed):
            return rssFeed.channel?.title

        case .atom(let atomFeed):
            // AtomFeed.title 是 XMLElement，使用 .text 获取内容
            return atomFeed.title?.text

        case .json(let jsonFeed):
            return jsonFeed.title
        }
    }
}
