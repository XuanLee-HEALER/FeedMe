//
//  FeedSourceTests.swift
//  FeedMeTests
//

import Foundation
import Testing
@testable import FeedMe

struct FeedSourceTests {
    // MARK: - nextRefreshDate

    @Test func nextRefreshDate_usesCustomInterval() {
        let lastFetched = Date(timeIntervalSince1970: 1_000_000)
        let source = TestFixtures.makeSource(
            refreshIntervalMinutes: 30,
            lastFetchedAt: lastFetched
        )

        let nextDate = source.nextRefreshDate(globalInterval: 60)

        // 自定义间隔 30 分钟 = 1800 秒
        let expected = lastFetched.addingTimeInterval(30 * 60)
        #expect(nextDate == expected)
    }

    @Test func nextRefreshDate_usesGlobalInterval() {
        let lastFetched = Date(timeIntervalSince1970: 1_000_000)
        let source = TestFixtures.makeSource(
            refreshIntervalMinutes: 0,
            lastFetchedAt: lastFetched
        )

        let nextDate = source.nextRefreshDate(globalInterval: 15)

        // 全局间隔 15 分钟 = 900 秒
        let expected = lastFetched.addingTimeInterval(15 * 60)
        #expect(nextDate == expected)
    }

    @Test func nextRefreshDate_backoffMultiplier() {
        let lastFetched = Date(timeIntervalSince1970: 1_000_000)

        // 0 次失败 → 1x
        let s0 = TestFixtures.makeSource(consecutiveFailures: 0, lastFetchedAt: lastFetched)
        let d0 = s0.nextRefreshDate(globalInterval: 10)
        #expect(d0 == lastFetched.addingTimeInterval(10 * 60))

        // 1 次失败 → 2x
        let s1 = TestFixtures.makeSource(consecutiveFailures: 1, lastFetchedAt: lastFetched)
        let d1 = s1.nextRefreshDate(globalInterval: 10)
        #expect(d1 == lastFetched.addingTimeInterval(20 * 60))

        // 2 次失败 → 4x
        let s2 = TestFixtures.makeSource(consecutiveFailures: 2, lastFetchedAt: lastFetched)
        let d2 = s2.nextRefreshDate(globalInterval: 10)
        #expect(d2 == lastFetched.addingTimeInterval(40 * 60))

        // 3 次失败 → 8x
        let s3 = TestFixtures.makeSource(consecutiveFailures: 3, lastFetchedAt: lastFetched)
        let d3 = s3.nextRefreshDate(globalInterval: 10)
        #expect(d3 == lastFetched.addingTimeInterval(80 * 60))
    }

    @Test func nextRefreshDate_backoffCapsAt8x() {
        let lastFetched = Date(timeIntervalSince1970: 1_000_000)

        let source = TestFixtures.makeSource(consecutiveFailures: 10, lastFetchedAt: lastFetched)
        let nextDate = source.nextRefreshDate(globalInterval: 10)

        // 即使 10 次失败，倍数仍然是 8x（cap）
        let expected = lastFetched.addingTimeInterval(80 * 60)
        #expect(nextDate == expected)
    }

    @Test func nextRefreshDate_nilWhenNeverFetched() {
        let source = TestFixtures.makeSource(lastFetchedAt: nil)

        let nextDate = source.nextRefreshDate(globalInterval: 10)
        #expect(nextDate == nil)
    }

    // MARK: - markSuccess / markFailure

    @Test func markSuccess_resetsFailures() {
        var source = TestFixtures.makeSource(consecutiveFailures: 5, lastError: "some error")

        source.markSuccess(etag: "new-etag", lastModified: "Wed, 01 Jan 2024")

        #expect(source.consecutiveFailures == 0)
        #expect(source.lastError == nil)
        #expect(source.etag == "new-etag")
        #expect(source.lastModified == "Wed, 01 Jan 2024")
        #expect(source.lastFetchedAt != nil)
    }

    @Test func markFailure_incrementsFailures() {
        var source = TestFixtures.makeSource(consecutiveFailures: 2)

        source.markFailure(error: "timeout")

        #expect(source.consecutiveFailures == 3)
        #expect(source.lastError == "timeout")
        #expect(source.lastFetchedAt != nil)
    }
}
