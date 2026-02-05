//
//  NotificationService.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation
import UserNotifications

/// 通知服务
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private override init() {
        super.init()
    }

    /// 请求通知权限
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
        UNUserNotificationCenter.current().delegate = self
    }

    /// 发送新文章通知
    /// - Parameters:
    ///   - count: 新文章数量
    ///   - sourceNames: 来源名称列表
    func sendNewArticlesNotification(newArticles: [FeedItem], sourceNames: [String]) {
        guard AppSettings.shared.enableNotifications else { return }
        guard !newArticles.isEmpty else { return }

        let content = UNMutableNotificationContent()
        let count = newArticles.count

        // 标题
        content.title = "\(count) 篇新文章"

        // 正文策略
        if count <= 3 {
            // 1-3 篇：逐行列出每篇文章标题（单行截断）
            let titles = newArticles.prefix(3).map { truncateTitle($0.title, maxLength: 60) }
            content.body = titles.joined(separator: "\n")
        } else {
            // 4 篇及以上：显示前 2 篇 + 汇总
            let topTitles = newArticles.prefix(2).map { truncateTitle($0.title, maxLength: 60) }
            let remaining = count - 2

            var bodyLines = topTitles
            bodyLines.append("以及来自 \(sourceNames.count) 个订阅源的 \(remaining) 篇文章")

            content.body = bodyLines.joined(separator: "\n")
        }

        content.sound = .default
        content.categoryIdentifier = "NEW_ARTICLES"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // 立即发送
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    /// 截断标题（单行截断）
    private func truncateTitle(_ title: String, maxLength: Int) -> String {
        if title.count <= maxLength {
            return title
        }
        let truncated = String(title.prefix(maxLength - 3))
        return truncated + "..."
    }

    /// 清除所有通知
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// 前台显示通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 即使在前台也显示通知
        completionHandler([.banner, .sound])
    }

    /// 用户点击通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 点击通知后可以打开应用或显示文章列表
        // 这里暂时只是完成回调
        completionHandler()
    }
}
