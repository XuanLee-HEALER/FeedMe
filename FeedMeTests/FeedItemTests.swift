//
//  FeedItemTests.swift
//  FeedMeTests
//

import Foundation
import Testing
@testable import FeedMe

struct FeedItemTests {
    // MARK: - dedupeKey

    @Test func dedupeKey_prefersGuid() {
        let item = FeedItem(
            sourceId: "s1",
            guidOrId: "my-guid-123",
            link: "https://example.com/post",
            title: "Title"
        )

        #expect(item.dedupeKey == "my-guid-123")
    }

    @Test func dedupeKey_fallsBackToLink() {
        let item = FeedItem(
            sourceId: "s1",
            guidOrId: nil,
            link: "https://example.com/post",
            title: "Title"
        )

        #expect(item.dedupeKey == "https://example.com/post")
    }

    @Test func dedupeKey_hashFallback() {
        let item = FeedItem(
            sourceId: "s1",
            guidOrId: nil,
            link: "",
            title: "Some Title"
        )

        // 无 guid、无 link → SHA256 hash
        #expect(!item.dedupeKey.isEmpty)
        #expect(item.dedupeKey.count == 64) // SHA256 hex = 64 chars
    }

    // MARK: - displayTitle

    @Test func displayTitle_fallback() {
        let itemWithTitle = FeedItem(sourceId: "s1", link: "https://a.com", title: "Real Title")
        let itemEmpty = FeedItem(sourceId: "s1", link: "https://a.com", title: "")

        #expect(itemWithTitle.displayTitle == "Real Title")
        #expect(itemEmpty.displayTitle == "(无标题)")
    }

    // MARK: - displayDate

    @Test func displayDate_prefersPublishedAt() {
        let published = Date(timeIntervalSince1970: 1_000_000)
        let firstSeen = Date(timeIntervalSince1970: 2_000_000)

        let item = FeedItem(
            sourceId: "s1",
            link: "https://a.com",
            title: "T",
            publishedAt: published,
            firstSeenAt: firstSeen
        )

        #expect(item.displayDate == published)
    }

    @Test func displayDate_fallsBackToFirstSeenAt() {
        let firstSeen = Date(timeIntervalSince1970: 2_000_000)

        let item = FeedItem(
            sourceId: "s1",
            link: "https://a.com",
            title: "T",
            publishedAt: nil,
            firstSeenAt: firstSeen
        )

        #expect(item.displayDate == firstSeen)
    }
}
