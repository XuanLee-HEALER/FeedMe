//
//  FeedParserTests.swift
//  FeedMeTests
//

import Foundation
import Testing
@testable import FeedMe

struct FeedParserTests {
    // MARK: - RSS 解析

    @Test func parseRSS_basicItems() throws {
        let data = Data(TestFixtures.rss2XML.utf8)
        let items = try FeedParserService.parse(data: data, sourceId: "src-1")

        #expect(items.count == 2)
        #expect(items[0].title == "First Post")
        #expect(items[0].link == "https://example.com/post-1")
        #expect(items[0].guidOrId == "guid-001")
        #expect(items[0].summary == "Summary of first post")
        #expect(items[0].publishedAt != nil)
        #expect(items[1].title == "Second Post")
    }

    @Test func parseRSS_skipsItemsWithoutLink() throws {
        let data = Data(TestFixtures.rssWithMissingLinkXML.utf8)
        let items = try FeedParserService.parse(data: data, sourceId: "src-1")

        #expect(items.count == 1)
        #expect(items[0].title == "Has Link")
    }

    @Test func parseRSS_usesGuidAsDedupeKey() throws {
        let data = Data(TestFixtures.rss2XML.utf8)
        let items = try FeedParserService.parse(data: data, sourceId: "src-1")

        // guidOrId 应该映射到 dedupeKey
        #expect(items[0].guidOrId == "guid-001")
        #expect(items[0].dedupeKey == "guid-001")
    }

    @Test func parseRSS_emptyFeed() throws {
        let data = Data(TestFixtures.rssEmptyChannelXML.utf8)
        let items = try FeedParserService.parse(data: data, sourceId: "src-1")

        #expect(items.isEmpty)
    }

    // MARK: - Atom 解析

    @Test func parseAtom_basicEntries() throws {
        let data = Data(TestFixtures.atomXML.utf8)
        let items = try FeedParserService.parse(data: data, sourceId: "src-1")

        #expect(items.count == 2)
        #expect(items[0].title == "Atom Entry 1")
        #expect(items[0].link == "https://example.com/entry-1")
        #expect(items[0].guidOrId == "urn:uuid:entry-1")
        #expect(items[0].summary == "Summary of entry 1")
        #expect(items[0].publishedAt != nil)
    }

    @Test func parseAtom_prefersAlternateLink() throws {
        let data = Data(TestFixtures.atomXML.utf8)
        let items = try FeedParserService.parse(data: data, sourceId: "src-1")

        // Entry 1 有 alternate 和 enclosure 两个 link，应该取 alternate
        #expect(items[0].link == "https://example.com/entry-1")
    }

    // MARK: - JSON Feed 解析

    @Test func parseJSON_basicItems() throws {
        let data = Data(TestFixtures.jsonFeedJSON.utf8)
        let items = try FeedParserService.parse(data: data, sourceId: "src-1")

        #expect(items.count == 2)
        #expect(items[0].title == "JSON Post 1")
        #expect(items[0].link == "https://example.com/json-1")
        #expect(items[0].guidOrId == "json-001")
        #expect(items[0].summary == "Summary of JSON post 1")
        #expect(items[0].publishedAt != nil)
    }

    // MARK: - extractFeedTitle

    @Test func extractFeedTitle_rss() throws {
        let data = Data(TestFixtures.rss2XML.utf8)
        let title = FeedParserService.extractFeedTitle(from: data)

        #expect(title == "Test RSS Feed")
    }

    @Test func extractFeedTitle_atom() throws {
        let data = Data(TestFixtures.atomXML.utf8)
        let title = FeedParserService.extractFeedTitle(from: data)

        #expect(title == "Test Atom Feed")
    }
}
