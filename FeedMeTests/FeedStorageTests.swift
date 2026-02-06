//
//  FeedStorageTests.swift
//  FeedMeTests
//

import Foundation
import GRDB
import Testing
@testable import FeedMe

struct FeedStorageTests {
    // MARK: - saveItems

    @Test func saveItems_insertsNewItems() throws {
        let storage = try TestFixtures.makeStorage()
        let source = TestFixtures.makeSource()
        try storage.addSource(source)

        let items = [
            TestFixtures.makeItem(sourceId: source.id, guidOrId: "g1", link: "https://a.com/1", title: "Post 1"),
            TestFixtures.makeItem(sourceId: source.id, guidOrId: "g2", link: "https://a.com/2", title: "Post 2"),
        ]

        let result = try storage.saveItems(items, for: source.id)

        #expect(result.newCount == 2)
    }

    @Test func saveItems_deduplicatesByDedupeKey() throws {
        let storage = try TestFixtures.makeStorage()
        let source = TestFixtures.makeSource()
        try storage.addSource(source)

        // 使用固定时间以避免 Date 精度问题
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)

        // 第一次插入
        let item1 = TestFixtures.makeItem(
            id: "item-dedup-1",
            sourceId: source.id,
            guidOrId: "same-guid",
            link: "https://a.com/1",
            title: "Original",
            publishedAt: fixedDate
        )
        let result1 = try storage.saveItems([item1], for: source.id)
        #expect(result1.newCount == 1)

        // 标记为已读
        try storage.markAsRead(itemId: "item-dedup-1")

        // 再次插入相同 dedupeKey 的文章（更新标题）
        let item2 = TestFixtures.makeItem(
            sourceId: source.id,
            guidOrId: "same-guid",
            link: "https://a.com/1",
            title: "Updated",
            publishedAt: fixedDate
        )
        let result2 = try storage.saveItems([item2], for: source.id)

        #expect(result2.newCount == 0)

        // 验证已读状态保留
        let fetched = try storage.fetchItems(for: source.id)
        #expect(fetched.count == 1)
        #expect(fetched[0].isRead == true)
    }

    @Test func saveItems_returnsNewItems() throws {
        let storage = try TestFixtures.makeStorage()
        let source = TestFixtures.makeSource()
        try storage.addSource(source)

        // 先插入一篇
        let existing = TestFixtures.makeItem(sourceId: source.id, guidOrId: "old", link: "https://a.com/old", title: "Old")
        try storage.saveItems([existing], for: source.id)

        // 再插入两篇（一新一旧）
        let items = [
            TestFixtures.makeItem(sourceId: source.id, guidOrId: "old", link: "https://a.com/old", title: "Old Updated"),
            TestFixtures.makeItem(sourceId: source.id, guidOrId: "new", link: "https://a.com/new", title: "New"),
        ]
        let result = try storage.saveItems(items, for: source.id)

        #expect(result.newCount == 1)
        #expect(result.newItems.count == 1)
        #expect(result.newItems[0].title == "New")
    }

    // MARK: - fetchUnreadCount

    @Test func fetchUnreadCount_global() throws {
        let storage = try TestFixtures.makeStorage()
        let source1 = TestFixtures.makeSource(id: "s1", title: "Source 1")
        let source2 = TestFixtures.makeSource(id: "s2", title: "Source 2")
        try storage.addSource(source1)
        try storage.addSource(source2)

        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s1", guidOrId: "a", link: "https://a.com/a", title: "A"),
            TestFixtures.makeItem(sourceId: "s1", guidOrId: "b", link: "https://a.com/b", title: "B"),
        ], for: "s1")
        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s2", guidOrId: "c", link: "https://a.com/c", title: "C"),
        ], for: "s2")

        let count = try storage.fetchUnreadCount()
        #expect(count == 3)
    }

    @Test func fetchUnreadCount_bySource() throws {
        let storage = try TestFixtures.makeStorage()
        let source1 = TestFixtures.makeSource(id: "s1", title: "Source 1")
        let source2 = TestFixtures.makeSource(id: "s2", title: "Source 2")
        try storage.addSource(source1)
        try storage.addSource(source2)

        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s1", guidOrId: "a", link: "https://a.com/a", title: "A"),
            TestFixtures.makeItem(sourceId: "s1", guidOrId: "b", link: "https://a.com/b", title: "B"),
        ], for: "s1")
        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s2", guidOrId: "c", link: "https://a.com/c", title: "C"),
        ], for: "s2")

        let count = try storage.fetchUnreadCount(for: "s1")
        #expect(count == 2)
    }

    // MARK: - markAsRead

    @Test func markAsRead_singleItem() throws {
        let storage = try TestFixtures.makeStorage()
        let source = TestFixtures.makeSource()
        try storage.addSource(source)

        let item = TestFixtures.makeItem(sourceId: source.id, guidOrId: "g1", link: "https://a.com/1", title: "Post 1")
        try storage.saveItems([item], for: source.id)

        #expect(try storage.fetchUnreadCount() == 1)

        try storage.markAsRead(itemId: item.id)

        #expect(try storage.fetchUnreadCount() == 0)
    }

    @Test func markAllAsRead_global() throws {
        let storage = try TestFixtures.makeStorage()
        let source1 = TestFixtures.makeSource(id: "s1", title: "Source 1")
        let source2 = TestFixtures.makeSource(id: "s2", title: "Source 2")
        try storage.addSource(source1)
        try storage.addSource(source2)

        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s1", guidOrId: "a", link: "https://a.com/a", title: "A"),
        ], for: "s1")
        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s2", guidOrId: "b", link: "https://a.com/b", title: "B"),
        ], for: "s2")

        try storage.markAllAsRead()

        #expect(try storage.fetchUnreadCount() == 0)
    }

    @Test func markAllAsRead_bySource() throws {
        let storage = try TestFixtures.makeStorage()
        let source1 = TestFixtures.makeSource(id: "s1", title: "Source 1")
        let source2 = TestFixtures.makeSource(id: "s2", title: "Source 2")
        try storage.addSource(source1)
        try storage.addSource(source2)

        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s1", guidOrId: "a", link: "https://a.com/a", title: "A"),
        ], for: "s1")
        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s2", guidOrId: "b", link: "https://a.com/b", title: "B"),
        ], for: "s2")

        try storage.markAllAsRead(sourceId: "s1")

        #expect(try storage.fetchUnreadCount(for: "s1") == 0)
        #expect(try storage.fetchUnreadCount(for: "s2") == 1)
    }

    // MARK: - Tag 分组

    @Test func fetchSourcesGroupedByTag_ordering() throws {
        let storage = try TestFixtures.makeStorage()

        // Tag 分组在前，未分类在后
        try storage.addSource(TestFixtures.makeSource(id: "s1", title: "Ungrouped", tag: nil))
        try storage.addSource(TestFixtures.makeSource(id: "s2", title: "Tech Blog", tag: "Tech"))

        let groups = try storage.fetchSourcesGroupedByTag()

        #expect(groups.count == 2)
        #expect(groups[0].tag == "Tech")
        #expect(groups[1].tag == nil)
    }

    @Test func fetchSourcesGroupedByTag_multipleTagsSorted() throws {
        let storage = try TestFixtures.makeStorage()

        try storage.addSource(TestFixtures.makeSource(id: "s1", title: "Z Blog", tag: "Zettelkasten"))
        try storage.addSource(TestFixtures.makeSource(id: "s2", title: "A Blog", tag: "Apple"))
        try storage.addSource(TestFixtures.makeSource(id: "s3", title: "M Blog", tag: "Music"))

        let groups = try storage.fetchSourcesGroupedByTag()

        #expect(groups.count == 3)
        #expect(groups[0].tag == "Apple")
        #expect(groups[1].tag == "Music")
        #expect(groups[2].tag == "Zettelkasten")
    }

    @Test func fetchUnreadCountForTag() throws {
        let storage = try TestFixtures.makeStorage()

        try storage.addSource(TestFixtures.makeSource(id: "s1", title: "Blog 1", tag: "Tech"))
        try storage.addSource(TestFixtures.makeSource(id: "s2", title: "Blog 2", tag: "Tech"))
        try storage.addSource(TestFixtures.makeSource(id: "s3", title: "Blog 3", tag: nil))

        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s1", guidOrId: "a", link: "https://a.com/a", title: "A"),
            TestFixtures.makeItem(sourceId: "s1", guidOrId: "b", link: "https://a.com/b", title: "B"),
        ], for: "s1")
        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s2", guidOrId: "c", link: "https://a.com/c", title: "C"),
        ], for: "s2")
        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s3", guidOrId: "d", link: "https://a.com/d", title: "D"),
        ], for: "s3")

        let techCount = try storage.fetchUnreadCountForTag("Tech")
        let ungroupedCount = try storage.fetchUnreadCountForTag(nil)

        #expect(techCount == 3)
        #expect(ungroupedCount == 1)
    }

    @Test func markAllAsReadForTag() throws {
        let storage = try TestFixtures.makeStorage()

        try storage.addSource(TestFixtures.makeSource(id: "s1", title: "Blog 1", tag: "Tech"))
        try storage.addSource(TestFixtures.makeSource(id: "s2", title: "Blog 2", tag: nil))

        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s1", guidOrId: "a", link: "https://a.com/a", title: "A"),
        ], for: "s1")
        try storage.saveItems([
            TestFixtures.makeItem(sourceId: "s2", guidOrId: "b", link: "https://a.com/b", title: "B"),
        ], for: "s2")

        try storage.markAllAsReadForTag("Tech")

        #expect(try storage.fetchUnreadCount(for: "s1") == 0)
        #expect(try storage.fetchUnreadCount(for: "s2") == 1)
    }

    // MARK: - 源管理

    @Test func addAndDeleteSource_cascadeDeleteItems() throws {
        let storage = try TestFixtures.makeStorage()
        let source = TestFixtures.makeSource()
        try storage.addSource(source)

        try storage.saveItems([
            TestFixtures.makeItem(sourceId: source.id, guidOrId: "a", link: "https://a.com/a", title: "A"),
            TestFixtures.makeItem(sourceId: source.id, guidOrId: "b", link: "https://a.com/b", title: "B"),
        ], for: source.id)

        #expect(try storage.fetchItems(for: source.id).count == 2)

        try storage.deleteSource(id: source.id)

        // 级联删除：文章也应该被清除
        #expect(try storage.fetchItems(for: source.id).count == 0)
        #expect(try storage.fetchSource(id: source.id) == nil)
    }

    @Test func updateSourcesOrder() throws {
        let storage = try TestFixtures.makeStorage()

        var s1 = TestFixtures.makeSource(id: "s1", title: "First", displayOrder: 0)
        var s2 = TestFixtures.makeSource(id: "s2", title: "Second", displayOrder: 1)
        var s3 = TestFixtures.makeSource(id: "s3", title: "Third", displayOrder: 2)
        try storage.addSource(s1)
        try storage.addSource(s2)
        try storage.addSource(s3)

        // 重新排序：Third -> First -> Second
        s3.displayOrder = 0
        s1.displayOrder = 1
        s2.displayOrder = 2
        try storage.updateSourcesOrder([s3, s1, s2])

        let fetched = try storage.fetchAllSources()
        #expect(fetched[0].id == "s3")
        #expect(fetched[1].id == "s1")
        #expect(fetched[2].id == "s2")
    }

    // MARK: - 迁移

    @Test func databaseMigration_v3HasTagColumn() throws {
        let storage = try TestFixtures.makeStorage()

        // 插入带 tag 的源
        let source = TestFixtures.makeSource(id: "s1", title: "Tagged", tag: "MyTag")
        try storage.addSource(source)

        // 查询验证 tag 可读
        let fetched = try storage.fetchSource(id: "s1")
        #expect(fetched?.tag == "MyTag")
    }
}
