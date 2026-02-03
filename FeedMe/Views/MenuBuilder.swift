//
//  MenuBuilder.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Cocoa

/// 菜单构建器
final class MenuBuilder {
    weak var delegate: MenuBuilderDelegate?

    /// 构建左键菜单（文章列表）
    func buildArticleListMenu() -> NSMenu {
        let menu = NSMenu()

        do {
            let storage = FeedStorage.shared
            let settings = AppSettings.shared

            // 检查是否有订阅源
            let sources = try storage.fetchAllSources()
            if sources.isEmpty {
                // 空状态：无订阅源
                let emptyItem = NSMenuItem(title: "还没有订阅任何 Feed", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                menu.addItem(emptyItem)

                menu.addItem(NSMenuItem.separator())

                let addItem = NSMenuItem(title: "添加订阅源…", action: #selector(MenuBuilderDelegate.openManagement), keyEquivalent: "")
                addItem.target = delegate
                menu.addItem(addItem)

                return menu
            }

            // 顶部：最近更新
            let headerItem = NSMenuItem(title: "最近更新", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            menu.addItem(NSMenuItem.separator())

            // 获取文章列表
            let items = try storage.fetchItems(limit: nil, unreadOnly: false)

            if items.isEmpty {
                // 空状态：无文章
                let emptyItem = NSMenuItem(title: "暂无文章，点击刷新获取", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                menu.addItem(emptyItem)
            } else {
                // 排序
                let sortedItems = sortItems(items, by: settings.sortOrder)

                // 检查是否全部已读
                let unreadItems = sortedItems.filter { !$0.isRead }
                if unreadItems.isEmpty {
                    let allReadItem = NSMenuItem(title: "✓ 全部已读", action: nil, keyEquivalent: "")
                    allReadItem.isEnabled = false
                    menu.addItem(allReadItem)
                    menu.addItem(NSMenuItem.separator())
                }

                // 显示前 N 条
                let displayCount = settings.displayCount
                let visibleItems = Array(sortedItems.prefix(displayCount))
                let remainingItems = Array(sortedItems.dropFirst(displayCount))

                // 添加文章条目
                for item in visibleItems {
                    menu.addItem(createArticleMenuItem(item))
                }

                // 折叠"更多"
                if !remainingItems.isEmpty {
                    menu.addItem(NSMenuItem.separator())
                    let moreItem = NSMenuItem(title: "… 更多 (\(remainingItems.count))", action: nil, keyEquivalent: "")
                    let submenu = NSMenu()

                    for item in remainingItems {
                        submenu.addItem(createArticleMenuItem(item))
                    }

                    moreItem.submenu = submenu
                    menu.addItem(moreItem)
                }
            }

            // 底部操作
            menu.addItem(NSMenuItem.separator())

            let refreshItem = NSMenuItem(title: "刷新", action: #selector(MenuBuilderDelegate.refreshAll), keyEquivalent: "r")
            refreshItem.target = delegate
            menu.addItem(refreshItem)

            if !items.isEmpty {
                let markAllReadItem = NSMenuItem(title: "全部标为已读", action: #selector(MenuBuilderDelegate.markAllAsRead), keyEquivalent: "")
                markAllReadItem.target = delegate
                menu.addItem(markAllReadItem)
            }

        } catch {
            // 错误状态
            let errorItem = NSMenuItem(title: "⚠️ 加载失败", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)

            let detailItem = NSMenuItem(title: error.localizedDescription, action: nil, keyEquivalent: "")
            detailItem.isEnabled = false
            detailItem.indentationLevel = 1
            menu.addItem(detailItem)

            menu.addItem(NSMenuItem.separator())

            let retryItem = NSMenuItem(title: "重试", action: #selector(MenuBuilderDelegate.refreshAll), keyEquivalent: "r")
            retryItem.target = delegate
            menu.addItem(retryItem)
        }

        return menu
    }

    /// 构建右键菜单（应用菜单）
    func buildAppMenu() -> NSMenu {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "刷新所有源", action: #selector(MenuBuilderDelegate.refreshAll), keyEquivalent: "r")
        refreshItem.target = delegate
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let manageItem = NSMenuItem(title: "管理订阅源…", action: #selector(MenuBuilderDelegate.openManagement), keyEquivalent: "")
        manageItem.target = delegate
        menu.addItem(manageItem)

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(MenuBuilderDelegate.openSettings), keyEquivalent: ",")
        settingsItem.target = delegate
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "关于 FeedMe", action: #selector(MenuBuilderDelegate.openAbout), keyEquivalent: "")
        aboutItem.target = delegate
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(MenuBuilderDelegate.quit), keyEquivalent: "q")
        quitItem.target = delegate
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Private Helpers

    /// 创建文章菜单项
    private func createArticleMenuItem(_ item: FeedItem) -> NSMenuItem {
        // 标题格式: [●] 标题
        let prefix = item.isRead ? "" : "● "
        let title = "\(prefix)\(item.displayTitle)"

        let menuItem = NSMenuItem(
            title: title,
            action: #selector(MenuBuilderDelegate.openArticle(_:)),
            keyEquivalent: ""
        )

        menuItem.target = delegate
        menuItem.representedObject = item.id

        return menuItem
    }

    /// 排序文章
    private func sortItems(_ items: [FeedItem], by sortOrder: AppSettings.SortOrder) -> [FeedItem] {
        switch sortOrder {
        case .unreadFirst:
            return items.sorted { lhs, rhs in
                if lhs.isRead != rhs.isRead {
                    return !lhs.isRead // 未读在前
                }
                return lhs.displayDate > rhs.displayDate // 时间倒序
            }

        case .timeDescending:
            return items.sorted { $0.displayDate > $1.displayDate }
        }
    }
}

// MARK: - Delegate Protocol

@objc protocol MenuBuilderDelegate: AnyObject {
    func openArticle(_ sender: NSMenuItem)
    func refreshAll()
    func markAllAsRead()
    func openManagement()
    func openSettings()
    func openAbout()
    func quit()
}
