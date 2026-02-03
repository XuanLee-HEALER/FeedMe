//
//  AppDelegate.swift
//  FeedMe
//
//  Created by lixuan on 2026/2/3.
//
import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menuBuilder = MenuBuilder()
    private var managementWindow: NSWindow?
    private var settingsWindow: NSWindow?

    // 刷新状态相关
    private var isRefreshing = false
    private let refreshIcon = "arrow.triangle.2.circlepath"
    private let normalIcon = "newspaper"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置菜单构建器代理
        menuBuilder.delegate = self

        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // 使用 SF Symbol 图标（设置为模板图像，自动适应菜单栏颜色）
            if let image = NSImage(systemSymbolName: normalIcon,
                                   accessibilityDescription: "FeedMe") {
                image.isTemplate = true
                button.image = image
            }
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
        }

        // 更新未读计数
        updateUnreadBadge()

        // 请求通知权限
        NotificationService.shared.requestAuthorization()

        // 监听数据变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFeedDataChange),
            name: .feedDataDidChange,
            object: nil
        )

        // 启动时刷新一次
        refreshAll()
    }

    @objc private func handleFeedDataChange() {
        updateUnreadBadge()
    }

    // MARK: - 刷新动画 (Core Animation 旋转，GPU 加速)

    private var originalAnchorPoint: CGPoint?
    private var originalPosition: CGPoint?

    private func startRefreshAnimation() {
        guard !isRefreshing else { return }
        isRefreshing = true

        guard let button = statusItem.button else { return }

        // 1. 隐藏未读数字（这样旋转时只有图标）
        button.title = ""

        // 2. 切换到刷新图标（只设置一次）
        updateStatusIcon(symbolName: refreshIcon)

        // 3. 对 layer 添加旋转动画
        button.wantsLayer = true
        if let layer = button.layer {
            // 保存原始值
            originalAnchorPoint = layer.anchorPoint
            originalPosition = layer.position

            // 计算新的 position 以保持视觉位置不变
            let bounds = layer.bounds
            let newAnchorPoint = CGPoint(x: 0.5, y: 0.5)
            let newPosition = CGPoint(
                x: layer.position.x + (newAnchorPoint.x - layer.anchorPoint.x) * bounds.width,
                y: layer.position.y + (newAnchorPoint.y - layer.anchorPoint.y) * bounds.height
            )

            layer.anchorPoint = newAnchorPoint
            layer.position = newPosition

            // 创建旋转动画
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = 0
            rotation.toValue = -Double.pi * 2  // 逆时针
            rotation.duration = 1.0
            rotation.repeatCount = .infinity
            rotation.timingFunction = CAMediaTimingFunction(name: .linear)
            layer.add(rotation, forKey: "refreshRotation")
        }
    }

    private func stopRefreshAnimation() {
        isRefreshing = false

        // 1. 移除动画并恢复 layer 状态
        if let button = statusItem.button, let layer = button.layer {
            layer.removeAnimation(forKey: "refreshRotation")

            // 恢复原始 anchorPoint 和 position
            if let anchorPoint = originalAnchorPoint, let position = originalPosition {
                layer.anchorPoint = anchorPoint
                layer.position = position
            }
        }

        // 2. 恢复正常图标
        updateStatusIcon(symbolName: normalIcon)

        // 3. 恢复未读数字
        updateUnreadBadge()
    }

    private func updateStatusIcon(symbolName: String) {
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            if let image = NSImage(systemSymbolName: symbolName,
                                   accessibilityDescription: "FeedMe")?
                .withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            }
        }
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // 右键：应用菜单
            let menu = menuBuilder.buildAppMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // 左键：文章列表
            let menu = menuBuilder.buildArticleListMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        }
    }

    /// 更新未读计数 badge
    private func updateUnreadBadge() {
        do {
            let count = try FeedStorage.shared.fetchUnreadCount()
            if let button = statusItem.button {
                // 设置标题显示未读数
                button.title = count > 0 ? " \(count)" : ""
            }
        } catch {
            print("Failed to update unread count: \(error)")
        }
    }
}

// MARK: - MenuBuilderDelegate

extension AppDelegate: MenuBuilderDelegate {
    @objc func openArticle(_ sender: NSMenuItem) {
        guard let itemId = sender.representedObject as? String else { return }

        do {
            // 获取文章
            let items = try FeedStorage.shared.fetchItems()
            guard let item = items.first(where: { $0.id == itemId }) else { return }

            // 打开浏览器
            if let url = URL(string: item.link) {
                NSWorkspace.shared.open(url)
            }

            // 根据设置标记为已读
            if AppSettings.shared.markAsReadOnClick {
                try FeedStorage.shared.markAsRead(itemId: itemId)
                updateUnreadBadge()
            }
        } catch {
            print("Failed to open article: \(error)")
        }
    }

    @objc func refreshAll() {
        startRefreshAnimation()

        Task {
            await FeedManager.shared.refreshAll()
            await MainActor.run {
                stopRefreshAnimation()
                updateUnreadBadge()
            }
        }
    }

    @objc func markAllAsRead() {
        do {
            try FeedStorage.shared.markAllAsRead()
            updateUnreadBadge()
        } catch {
            print("Failed to mark all as read: \(error)")
        }
    }

    @objc func openManagement() {
        if managementWindow == nil {
            let contentView = FeedManagementView()
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "订阅源管理"
            window.setContentSize(NSSize(width: 600, height: 400))
            window.styleMask = [.titled, .closable, .resizable]
            window.center()

            managementWindow = window
        }

        managementWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let contentView = ContentView()
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "设置"
            window.setContentSize(NSSize(width: 450, height: 300))
            window.styleMask = [.titled, .closable]
            window.center()

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
