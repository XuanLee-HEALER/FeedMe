//
//  FeedFetcher.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation

/// Feed 网络请求服务
final class FeedFetcher {
    /// 请求结果
    enum FetchResult {
        /// 成功获取新数据
        case success(data: Data, etag: String?, lastModified: String?)

        /// 304 Not Modified（内容未变化）
        case notModified
    }

    /// 并发限制
    private let semaphore = AsyncSemaphore(value: 5)

    /// 超时时间（秒）
    private let timeout: TimeInterval = 15

    /// User-Agent
    private let userAgent = "FeedMe/1.0"

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
        await semaphore.wait()
        defer { semaphore.signal() }

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

// MARK: - AsyncSemaphore

/// 异步信号量（并发控制）
private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        value -= 1
        if value >= 0 { return }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        value += 1
        if value <= 0, !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}
