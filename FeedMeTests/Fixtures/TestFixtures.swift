//
//  TestFixtures.swift
//  FeedMeTests
//

import Foundation
import GRDB
@testable import FeedMe

/// 测试数据工厂和 Fixture 常量
enum TestFixtures {
    // MARK: - 内存数据库

    /// 创建使用内存数据库的 FeedStorage 实例
    static func makeStorage() throws -> FeedStorage {
        var config = Configuration()
        config.foreignKeysEnabled = true
        let dbQueue = try DatabaseQueue(configuration: config)
        return try FeedStorage(dbQueue: dbQueue)
    }

    // MARK: - FeedSource 工厂

    static func makeSource(
        id: String = "source-1",
        title: String = "Test Blog",
        feedURL: String = "https://example.com/feed.xml",
        tag: String? = nil,
        displayOrder: Int = 0,
        refreshIntervalMinutes: Int = 0,
        consecutiveFailures: Int = 0,
        lastFetchedAt: Date? = nil,
        lastError: String? = nil
    ) -> FeedSource {
        FeedSource(
            id: id,
            title: title,
            feedURL: feedURL,
            refreshIntervalMinutes: refreshIntervalMinutes,
            displayOrder: displayOrder,
            lastFetchedAt: lastFetchedAt,
            lastError: lastError,
            consecutiveFailures: consecutiveFailures,
            tag: tag
        )
    }

    // MARK: - FeedItem 工厂

    static func makeItem(
        id: String = UUID().uuidString,
        sourceId: String = "source-1",
        guidOrId: String? = "guid-1",
        link: String = "https://example.com/post-1",
        title: String = "Test Post",
        publishedAt: Date? = Date(),
        summary: String? = "Test summary",
        isRead: Bool = false
    ) -> FeedItem {
        FeedItem(
            id: id,
            sourceId: sourceId,
            guidOrId: guidOrId,
            link: link,
            title: title,
            publishedAt: publishedAt,
            summary: summary,
            isRead: isRead
        )
    }

    // MARK: - RSS 2.0 Fixture

    static let rss2XML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Test RSS Feed</title>
        <link>https://example.com</link>
        <description>A test RSS feed</description>
        <item>
          <title>First Post</title>
          <link>https://example.com/post-1</link>
          <guid>guid-001</guid>
          <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
          <description>Summary of first post</description>
        </item>
        <item>
          <title>Second Post</title>
          <link>https://example.com/post-2</link>
          <guid>guid-002</guid>
          <pubDate>Tue, 02 Jan 2024 12:00:00 +0000</pubDate>
          <description>Summary of second post</description>
        </item>
      </channel>
    </rss>
    """

    // MARK: - RSS 无 link 的项

    static let rssWithMissingLinkXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Test RSS</title>
        <item>
          <title>Has Link</title>
          <link>https://example.com/has-link</link>
          <guid>guid-ok</guid>
        </item>
        <item>
          <title>No Link</title>
          <guid>guid-nolink</guid>
        </item>
      </channel>
    </rss>
    """

    // MARK: - RSS 空 channel

    static let rssEmptyChannelXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Empty Feed</title>
      </channel>
    </rss>
    """

    // MARK: - Atom Fixture

    static let atomXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Test Atom Feed</title>
      <link href="https://example.com" rel="alternate"/>
      <id>urn:uuid:test-atom-feed</id>
      <updated>2024-01-02T12:00:00Z</updated>
      <entry>
        <title>Atom Entry 1</title>
        <link href="https://example.com/entry-1" rel="alternate"/>
        <link href="https://example.com/entry-1.json" rel="enclosure"/>
        <id>urn:uuid:entry-1</id>
        <updated>2024-01-01T12:00:00Z</updated>
        <summary>Summary of entry 1</summary>
      </entry>
      <entry>
        <title>Atom Entry 2</title>
        <link href="https://example.com/entry-2" rel="alternate"/>
        <id>urn:uuid:entry-2</id>
        <updated>2024-01-02T12:00:00Z</updated>
        <summary>Summary of entry 2</summary>
      </entry>
    </feed>
    """

    // MARK: - JSON Feed Fixture

    static let jsonFeedJSON = """
    {
      "version": "https://jsonfeed.org/version/1.1",
      "title": "Test JSON Feed",
      "home_page_url": "https://example.com",
      "feed_url": "https://example.com/feed.json",
      "items": [
        {
          "id": "json-001",
          "url": "https://example.com/json-1",
          "title": "JSON Post 1",
          "date_published": "2024-01-01T12:00:00+00:00",
          "summary": "Summary of JSON post 1"
        },
        {
          "id": "json-002",
          "url": "https://example.com/json-2",
          "title": "JSON Post 2",
          "date_published": "2024-01-02T12:00:00+00:00",
          "summary": "Summary of JSON post 2"
        }
      ]
    }
    """
}
