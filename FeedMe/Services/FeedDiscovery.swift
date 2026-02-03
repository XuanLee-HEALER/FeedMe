//
//  FeedDiscovery.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation
import FeedKit

/// Feed 自动发现服务
final class FeedDiscovery {
    /// 发现的 Feed 信息
    struct DiscoveredFeed {
        let url: String
        let title: String?
        let type: FeedType

        enum FeedType: String {
            case rss = "application/rss+xml"
            case atom = "application/atom+xml"
        }
    }

    /// 从站点 URL 自动发现 Feed
    /// - Parameter siteURL: 站点 URL
    /// - Returns: 发现的 Feed 列表
    static func discover(from siteURL: String) async throws -> [DiscoveredFeed] {
        guard let url = URL(string: siteURL) else {
            throw FeedError.invalidURL(siteURL)
        }

        // 下载 HTML
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw FeedError.parseError("无法解析 HTML")
        }

        // 查找 <link> 标签
        return parseHTMLForFeeds(html, baseURL: url)
    }

    /// 解析 HTML 查找 Feed 链接
    private static func parseHTMLForFeeds(_ html: String, baseURL: URL) -> [DiscoveredFeed] {
        var feeds: [DiscoveredFeed] = []

        // 正则匹配 <link rel="alternate" type="application/(rss|atom)+xml" href="...">
        let pattern = #"<link[^>]+rel=["']alternate["'][^>]+type=["'](application/(rss|atom)\+xml)["'][^>]+href=["']([^"']+)["'][^>]*>"#

        // 也匹配反过来的顺序（type 在前）
        let pattern2 = #"<link[^>]+type=["'](application/(rss|atom)\+xml)["'][^>]+rel=["']alternate["'][^>]+href=["']([^"']+)["'][^>]*>"#

        for pattern in [pattern, pattern2] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = html as NSString
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

                for match in matches {
                    guard match.numberOfRanges == 4 else { continue }

                    let typeRange = match.range(at: 1)
                    let hrefRange = match.range(at: 3)

                    let typeString = nsString.substring(with: typeRange)
                    let hrefString = nsString.substring(with: hrefRange)

                    // 解析 type
                    let type: DiscoveredFeed.FeedType = typeString.contains("atom") ? .atom : .rss

                    // 解析 href（处理相对路径）
                    let feedURL: String
                    if hrefString.starts(with: "http") {
                        feedURL = hrefString
                    } else if hrefString.starts(with: "/") {
                        feedURL = baseURL.scheme! + "://" + baseURL.host! + hrefString
                    } else {
                        feedURL = baseURL.deletingLastPathComponent().appendingPathComponent(hrefString).absoluteString
                    }

                    // 尝试提取 title（可选）
                    let titlePattern = #"title=["']([^"']+)["']"#
                    var title: String?
                    if let titleRegex = try? NSRegularExpression(pattern: titlePattern),
                       let titleMatch = titleRegex.firstMatch(in: html, range: match.range),
                       titleMatch.numberOfRanges == 2 {
                        title = nsString.substring(with: titleMatch.range(at: 1))
                    }

                    feeds.append(DiscoveredFeed(url: feedURL, title: title, type: type))
                }
            }
        }

        return feeds
    }

    /// 验证 URL 是否为有效的 Feed
    static func validateFeedURL(_ urlString: String) async throws -> Bool {
        guard let url = URL(string: urlString) else {
            throw FeedError.invalidURL(urlString)
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // 尝试解析 Feed，如果成功则有效
            _ = try Feed(data: data)
            return true
        } catch {
            return false
        }
    }
}
