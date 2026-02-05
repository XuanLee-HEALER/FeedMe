//
//  FaviconService.swift
//  FeedMe
//
//  Created by Claude on 2026/2/5.
//  v1.3: Favicon 获取和缓存服务
//

import Cocoa
import Foundation

/// Favicon 服务
final class FaviconService {
    /// 单例
    static let shared = FaviconService()

    /// 缓存目录: ~/Library/Application Support/FeedMe/favicons/
    private let cacheDirectory: URL

    /// 内存缓存
    private let memoryCache = NSCache<NSString, NSImage>()

    /// 元数据文件路径
    private let metadataURL: URL

    /// 元数据：记录获取时间和失败状态
    private struct FaviconMetadata: Codable {
        var lastFetchDate: Date
        var failedAttempts: Int

        init(lastFetchDate: Date = Date(), failedAttempts: Int = 0) {
            self.lastFetchDate = lastFetchDate
            self.failedAttempts = failedAttempts
        }
    }

    private var metadata: [String: FaviconMetadata] = [:]
    private let metadataQueue = DispatchQueue(label: "com.feedme.favicon.metadata")

    /// 占位图标 (globe)
    static let placeholderIcon: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: "globe", accessibilityDescription: "Website")!
            .withSymbolConfiguration(config)!
    }()

    /// 初始化
    private init() {
        let fileManager = FileManager.default
        let appSupport = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let feedMeDir = appSupport.appendingPathComponent("FeedMe", isDirectory: true)
        cacheDirectory = feedMeDir.appendingPathComponent("favicons", isDirectory: true)
        metadataURL = cacheDirectory.appendingPathComponent(".metadata.json")

        // 创建缓存目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // 加载元数据
        loadMetadata()

        // 配置内存缓存
        memoryCache.countLimit = 100
    }

    /// 获取 Favicon（异步，优先缓存）
    /// - Parameter url: 网站 URL 或 Feed URL
    /// - Returns: Favicon 图像，失败返回占位图
    func favicon(for url: String) async -> NSImage {
        guard let domain = extractDomain(from: url) else {
            return Self.placeholderIcon
        }

        let cacheKey = domain as NSString

        // 1. 检查内存缓存
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        // 2. 检查磁盘缓存
        let diskPath = cacheDirectory.appendingPathComponent("\(domain).png")
        if FileManager.default.fileExists(atPath: diskPath.path),
           let diskImage = NSImage(contentsOf: diskPath) {
            memoryCache.setObject(diskImage, forKey: cacheKey)
            return diskImage
        }

        // 3. 检查是否应该重试（失败过且未到重试时间）
        if let meta = metadata[domain], shouldSkipFetch(metadata: meta) {
            return Self.placeholderIcon
        }

        // 4. 从网络获取
        if let image = await fetchFaviconFromNetwork(domain: domain) {
            // 保存到磁盘和内存
            saveToCache(image: image, domain: domain)
            updateMetadata(domain: domain, success: true)
            return image
        } else {
            // 获取失败，更新元数据
            updateMetadata(domain: domain, success: false)
            return Self.placeholderIcon
        }
    }

    /// 提取域名
    private func extractDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        return host
    }

    /// 判断是否应该跳过获取（失败过且未到重试时间）
    private func shouldSkipFetch(metadata: FaviconMetadata) -> Bool {
        let retryInterval: TimeInterval = metadata.failedAttempts >= 3 ? 86400 : 3600  // 失败3次后24小时重试，否则1小时
        return Date().timeIntervalSince(metadata.lastFetchDate) < retryInterval
    }

    /// 从网络获取 Favicon
    private func fetchFaviconFromNetwork(domain: String) async -> NSImage? {
        // 策略1: 尝试 /favicon.ico
        if let image = await fetchFaviconICO(domain: domain) {
            return image
        }

        // 策略2: 尝试 Google Favicon API
        if let image = await fetchGoogleFavicon(domain: domain) {
            return image
        }

        return nil
    }

    /// 策略1: 获取 /favicon.ico
    private func fetchFaviconICO(domain: String) async -> NSImage? {
        let urlString = "https://\(domain)/favicon.ico"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = NSImage(data: data) else {
                return nil
            }
            return resizeIfNeeded(image)
        } catch {
            return nil
        }
    }

    /// 策略2: Google Favicon API
    private func fetchGoogleFavicon(domain: String) async -> NSImage? {
        let urlString = "https://www.google.com/s2/favicons?domain=\(domain)&sz=32"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = NSImage(data: data) else {
                return nil
            }
            return resizeIfNeeded(image)
        } catch {
            return nil
        }
    }

    /// 调整图像大小（如果需要）
    private func resizeIfNeeded(_ image: NSImage) -> NSImage {
        let targetSize = NSSize(width: 16, height: 16)

        // 如果已经是目标大小，直接返回
        if image.size == targetSize {
            return image
        }

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        resized.unlockFocus()

        return resized
    }

    /// 保存到缓存
    private func saveToCache(image: NSImage, domain: String) {
        // 内存缓存
        memoryCache.setObject(image, forKey: domain as NSString)

        // 磁盘缓存 (PNG)
        let diskPath = cacheDirectory.appendingPathComponent("\(domain).png")
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: diskPath)
        }
    }

    /// 更新元数据
    private func updateMetadata(domain: String, success: Bool) {
        metadataQueue.async { [weak self] in
            guard let self = self else { return }

            var meta = self.metadata[domain] ?? FaviconMetadata()
            meta.lastFetchDate = Date()
            meta.failedAttempts = success ? 0 : (meta.failedAttempts + 1)

            self.metadata[domain] = meta
            self.saveMetadata()
        }
    }

    /// 加载元数据
    private func loadMetadata() {
        guard FileManager.default.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let loaded = try? JSONDecoder().decode([String: FaviconMetadata].self, from: data) else {
            return
        }
        metadata = loaded
    }

    /// 保存元数据
    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        try? data.write(to: metadataURL)
    }
}
