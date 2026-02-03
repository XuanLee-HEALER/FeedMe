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
    func sendNewArticlesNotification(count: Int, sourceNames: [String]) {
        guard AppSettings.shared.enableNotifications else { return }
        guard count > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "FeedMe"

        if count == 1 {
            content.body = "1 篇新文章"
        } else {
            content.body = "\(count) 篇新文章"
        }

        if !sourceNames.isEmpty {
            let sources = sourceNames.prefix(3).joined(separator: ", ")
            if sourceNames.count > 3 {
                content.body += "\n来自 \(sources) 等"
            } else {
                content.body += "\n来自 \(sources)"
            }
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
