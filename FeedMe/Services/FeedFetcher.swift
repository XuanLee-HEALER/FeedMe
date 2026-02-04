//
//  FeedFetcher.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation

/// 异步信号量，用于限制并发数量（纯 Swift Concurrency 实现，避免优先级反转）
private actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.count = value
    }

    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        } else {
            count += 1
        }
    }
}

/// Feed 网络请求服务
final class FeedFetcher: Sendable {
    /// 请求结果
    enum FetchResult: Sendable {
        /// 成功获取新数据
        case success(data: Data, etag: String?, lastModified: String?)

        /// 304 Not Modified（内容未变化）
        case notModified
    }

    /// 并发限制（使用 AsyncSemaphore 避免优先级反转问题）
    private let semaphore = AsyncSemaphore(value: 5)

    /// 超时时间（秒）
    private let timeout: TimeInterval = 15

    /// 最大响应大小（10MB）
    private let maxResponseSize = 10 * 1024 * 1024

    /// User-Agent
    private let userAgent = "FeedMe/1.0"

    /// 允许的内容类型
    private let allowedContentTypes = [
        "application/rss+xml",
        "application/atom+xml",
        "application/xml",
        "text/xml",
        "application/json",
        "text/html"  // 用于 Feed 自动发现
    ]

    /// 单例
    static let shared = FeedFetcher()

    private init() {}

    /// 拉取 Feed 数据
    /// - Parameters:
    ///   - url: Feed URL
    ///   - etag: 缓存的 ETag
    ///   - lastModified: 缓存的 Last-Modified
    /// - Returns: 拉取结果
    func fetch(
        url: String,
        etag: String? = nil,
        lastModified: String? = nil
    ) async throws -> FetchResult {
        // 等待信号量（纯 async/await，无优先级反转）
        await semaphore.wait()
        defer { Task { await semaphore.signal() } }

        guard let url = URL(string: url) else {
            throw FeedError.invalidURL(url)
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        // 条件请求
        if let etag = etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FeedError.unknown("非 HTTP 响应")
            }

            // 检查响应大小
            if data.count > maxResponseSize {
                throw FeedError.parseError("响应过大（超过 10MB）")
            }

            // 检查内容类型（如果有的话）
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() {
                let isAllowed = allowedContentTypes.contains { contentType.contains($0) }
                if !isAllowed && !contentType.contains("text/") {
                    throw FeedError.parseError("不支持的内容类型: \(contentType)")
                }
            }

            // 处理 HTTP 状态码
            switch httpResponse.statusCode {
            case 200:
                // 成功获取新数据
                let newEtag = httpResponse.value(forHTTPHeaderField: "ETag")
                let newLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")
                return .success(data: data, etag: newEtag, lastModified: newLastModified)

            case 304:
                // 未修改
                return .notModified

            case 400..<500:
                throw FeedError.httpError(httpResponse.statusCode)

            case 500..<600:
                throw FeedError.httpError(httpResponse.statusCode)

            default:
                throw FeedError.httpError(httpResponse.statusCode)
            }

        } catch let error as FeedError {
            throw error

        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw FeedError.timeout
            } else {
                throw FeedError.networkError(urlError)
            }

        } catch {
            throw FeedError.networkError(error)
        }
    }

    /// 批量拉取多个源（并发控制）
    func fetchMultiple(
        sources: [FeedSource]
    ) async -> [(source: FeedSource, result: Result<FetchResult, Error>)] {
        await withTaskGroup(of: (FeedSource, Result<FetchResult, Error>).self) { group in
            for source in sources where source.isEnabled {
                group.addTask {
                    do {
                        let fetchResult = try await self.fetch(
                            url: source.feedURL,
                            etag: source.etag,
                            lastModified: source.lastModified
                        )
                        return (source, .success(fetchResult))
                    } catch {
                        return (source, .failure(error))
                    }
                }
            }

            var results: [(FeedSource, Result<FetchResult, Error>)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}

