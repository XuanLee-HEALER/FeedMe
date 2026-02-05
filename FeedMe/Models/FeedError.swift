//
//  FeedError.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation

/// Feed 相关错误类型
enum FeedError: LocalizedError {
    /// 网络错误
    case networkError(Error)

    /// 解析错误
    case parseError(String)

    /// 无效 URL
    case invalidURL(String)

    /// 超时
    case timeout

    /// HTTP 错误
    case httpError(Int)

    /// 未找到 Feed
    case feedNotFound

    /// 其他错误
    case unknown(String)

    /// 错误描述（中文）
    var errorDescription: String? {
        switch self {
        case let .networkError(error):
            return "网络错误: \(error.localizedDescription)"

        case let .parseError(message):
            return "解析失败: \(message)"

        case let .invalidURL(url):
            return "无效的 URL: \(url)"

        case .timeout:
            return "请求超时"

        case let .httpError(code):
            return "HTTP 错误 \(code)"

        case .feedNotFound:
            return "未找到 RSS/Atom Feed"

        case let .unknown(message):
            return "未知错误: \(message)"
        }
    }

    /// 简短描述（用于 UI 显示）
    var shortDescription: String {
        switch self {
        case .networkError:
            return "网络错误"

        case .parseError:
            return "解析失败"

        case .invalidURL:
            return "无效 URL"

        case .timeout:
            return "请求超时"

        case let .httpError(code):
            return "HTTP \(code)"

        case .feedNotFound:
            return "未找到 Feed"

        case .unknown:
            return "未知错误"
        }
    }
}
