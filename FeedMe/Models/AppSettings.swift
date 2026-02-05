//
//  AppSettings.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Combine
import Foundation
import SwiftUI

/// 应用设置管理
final class AppSettings: ObservableObject {
    /// 全局刷新间隔（分钟）
    @AppStorage("globalRefreshInterval") var globalRefreshInterval: Int = 15

    /// 点击后自动标为已读
    @AppStorage("markAsReadOnClick") var markAsReadOnClick: Bool = true

    /// 排序方式
    var sortOrder: SortOrder {
        get {
            SortOrder(rawValue: UserDefaults.standard.string(forKey: "sortOrder") ?? "") ?? .unreadFirst
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "sortOrder")
            objectWillChange.send()
        }
    }

    /// 列表显示条数
    @AppStorage("displayCount") var displayCount: Int = 7

    /// 开机自动启动
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    /// 启用新文章通知
    @AppStorage("enableNotifications") var enableNotifications: Bool = false

    /// 单例
    static let shared = AppSettings()

    private init() {}
}

// MARK: - Types

extension AppSettings {
    /// 排序方式
    enum SortOrder: String, Codable, CaseIterable {
        /// 未读优先
        case unreadFirst = "unread_first"

        /// 纯时间倒序
        case timeDescending = "time_descending"

        var displayName: String {
            switch self {
            case .unreadFirst: return "未读优先"
            case .timeDescending: return "时间倒序"
            }
        }
    }

    /// 刷新间隔选项
    static let refreshIntervalOptions = [5, 15, 30, 60]

    /// 显示条数选项
    static let displayCountRange = 3 ... 10
}
