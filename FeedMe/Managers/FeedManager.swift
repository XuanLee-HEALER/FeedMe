//
//  FeedManager.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Combine
import Foundation

/// Feed 刷新管理器
@MainActor
final class FeedManager: ObservableObject {
    /// 刷新状态
    @Published private(set) var isRefreshing = false

    /// 最后刷新时间
    @Published private(set) var lastRefreshDate: Date?

    /// 定时器
    private var timer: Timer?

    /// 正在刷新的源 ID 集合（避免重复刷新）
    private var refreshingSourceIds = Set<String>()

    /// 单例
    static let shared = FeedManager()

    private init() {
        #if !DEBUG
            setupTimer()
        #else
            print("🔧 开发模式：跳过定时刷新设置")
        #endif
    }

    /// 设置定时器
    private func setupTimer() {
        // 取消旧定时器
        timer?.invalidate()

        // 创建新定时器
        let interval = TimeInterval(AppSettings.shared.globalRefreshInterval * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }

    /// 刷新所有订阅源
    func refreshAll() async {
        guard !isRefreshing else { return }

        isRefreshing = true

        do {
            let storage = FeedStorage.shared
            let sources = try storage.fetchEnabledSources()

            // 并发拉取所有源（网络请求本身已经是异步的）
            let results = await FeedFetcher.shared.fetchMultiple(sources: sources)

            // 处理结果并收集新文章
            var allNewArticles: [FeedItem] = []
            var sourceNamesWithNewArticles: Set<String> = []

            for (source, result) in results {
                let newItems = processRefreshResultSync(source: source, result: result)
                if !newItems.isEmpty {
                    allNewArticles.append(contentsOf: newItems)
                    sourceNamesWithNewArticles.insert(source.title)
                }
            }

            // 发送通知（如果有新文章）
            if !allNewArticles.isEmpty {
                // 按时间排序（最新的在前）
                let sortedNewArticles = allNewArticles.sorted { $0.displayDate > $1.displayDate }

                NotificationService.shared.sendNewArticlesNotification(
                    newArticles: sortedNewArticles,
                    sourceNames: Array(sourceNamesWithNewArticles)
                )
            }

            // 发送数据变化通知，更新 UI（包括状态栏 badge）
            NotificationCenter.default.post(name: .feedDataDidChange, object: nil)

        } catch {
            print("Failed to refresh all: \(error)")
        }

        isRefreshing = false
        lastRefreshDate = Date()
    }

    /// 同步处理刷新结果（在 MainActor 上下文中调用）
    /// - Returns: 是否有新文章
    private func processRefreshResultSync(source: FeedSource, result: Result<FeedFetcher.FetchResult, Error>) -> [FeedItem] {
        do {
            var updatedSource = source
            let storage = FeedStorage.shared

            switch result {
            case let .success(fetchResult):
                switch fetchResult {
                case let .success(data, etag, lastModified):
                    let items = try FeedParserService.parse(data: data, sourceId: source.id)
                    let (_, newItems) = try storage.saveItems(items, for: source.id)
                    updatedSource.markSuccess(etag: etag, lastModified: lastModified)
                    try storage.updateSource(updatedSource)
                    return newItems

                case .notModified:
                    updatedSource.markSuccess()
                    try storage.updateSource(updatedSource)
                    return []
                }

            case let .failure(error):
                let errorMessage = (error as? FeedError)?.shortDescription ?? error.localizedDescription
                updatedSource.markFailure(error: errorMessage)
                try storage.updateSource(updatedSource)
                return []
            }

        } catch {
            print("Failed to process refresh result for \(source.title): \(error)")
            return []
        }
    }

    /// 刷新单个订阅源
    func refresh(sourceId: String) async {
        // 防止重复刷新
        guard !refreshingSourceIds.contains(sourceId) else { return }
        refreshingSourceIds.insert(sourceId)
        defer { refreshingSourceIds.remove(sourceId) }

        do {
            let storage = FeedStorage.shared
            guard var source = try storage.fetchSource(id: sourceId) else { return }

            // 拉取数据
            do {
                let fetchResult = try await FeedFetcher.shared.fetch(
                    url: source.feedURL,
                    etag: source.etag,
                    lastModified: source.lastModified
                )

                // 处理结果
                switch fetchResult {
                case let .success(data, etag, lastModified):
                    // 解析文章
                    let items = try FeedParserService.parse(data: data, sourceId: sourceId)

                    // 保存到数据库
                    let (newCount, _) = try storage.saveItems(items, for: sourceId)

                    // 更新源状态
                    source.markSuccess(etag: etag, lastModified: lastModified)
                    try storage.updateSource(source)

                    print("✅ Refreshed \(source.title): \(items.count) items (\(newCount) new)")

                case .notModified:
                    // 304 未修改
                    source.markSuccess()
                    try storage.updateSource(source)
                    print("📝 Not modified: \(source.title)")
                }

            } catch {
                // 刷新失败 - 打印详细错误信息
                print("❌ ========== 刷新失败详情 ==========")
                print("❌ 订阅源: \(source.title)")
                print("❌ Feed URL: \(source.feedURL)")
                print("❌ 错误类型: \(type(of: error))")
                print("❌ 错误描述: \(error)")
                print("❌ localizedDescription: \(error.localizedDescription)")

                if let feedError = error as? FeedError {
                    print("❌ FeedError.shortDescription: \(feedError.shortDescription)")
                }

                // 打印 NSError 信息（Error 桥接到 NSError）
                let nsError = error as NSError
                print("❌ NSError domain: \(nsError.domain)")
                print("❌ NSError code: \(nsError.code)")
                print("❌ NSError userInfo: \(nsError.userInfo)")
                print("❌ =====================================")

                let errorMessage = (error as? FeedError)?.shortDescription ?? error.localizedDescription
                source.markFailure(error: errorMessage)
                try? storage.updateSource(source)
            }

        } catch {
            print("Failed to refresh source \(sourceId): \(error)")
        }
    }

    /// 处理刷新结果（用于单源刷新）
    /// - Returns: 是否有新文章
    @discardableResult
    private func processRefreshResult(source: FeedSource, result: Result<FeedFetcher.FetchResult, Error>) async -> Bool {
        do {
            var updatedSource = source
            let storage = FeedStorage.shared

            switch result {
            case let .success(fetchResult):
                switch fetchResult {
                case let .success(data, etag, lastModified):
                    // 解析文章
                    let items = try FeedParserService.parse(data: data, sourceId: source.id)

                    // 保存到数据库（返回新增数量和新文章）
                    let (newCount, _) = try storage.saveItems(items, for: source.id)

                    // 更新源状态
                    updatedSource.markSuccess(etag: etag, lastModified: lastModified)
                    try storage.updateSource(updatedSource)

                    return newCount > 0

                case .notModified:
                    // 304 未修改
                    updatedSource.markSuccess()
                    try storage.updateSource(updatedSource)
                    return false
                }

            case let .failure(error):
                // 刷新失败
                let errorMessage = (error as? FeedError)?.shortDescription ?? error.localizedDescription
                updatedSource.markFailure(error: errorMessage)
                try storage.updateSource(updatedSource)
                return false
            }

        } catch {
            print("Failed to process refresh result for \(source.title): \(error)")
            return false
        }
    }

    /// 应用启动时刷新一次
    func refreshOnLaunch() {
        Task {
            await refreshAll()
        }
    }

    /// 设置变更时重置定时器
    func resetTimer() {
        setupTimer()
    }
}
