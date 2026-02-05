//
//  MenuBuilder.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Cocoa

/// 菜单构建器
final class MenuBuilder: NSObject, NSMenuDelegate {
    weak var delegate: MenuBuilderDelegate?

    /// 当前高亮的菜单项（用于清除旧高亮）
    private weak var currentHighlightedItem: NSMenuItem?

    /// 当前打开的文章列表菜单（用于动态更新）
    private weak var currentArticleMenu: NSMenu?

    /// 构建左键菜单（文章列表）
    func buildArticleListMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self  // 设置菜单代理以接收高亮变化
        menu.autoenablesItems = false  // 防止没有 action 的菜单项被自动禁用

        // 保存菜单引用，用于动态更新
        currentArticleMenu = menu

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

            // 获取全部未读文章，按时间倒序排列
            let allUnread = try storage.fetchItems(unreadOnly: true)
            let sortedUnread = allUnread.sorted { $0.displayDate > $1.displayDate }

            if sortedUnread.isEmpty {
                // 空状态：全部已读
                let allReadItem = NSMenuItem(title: "✓ 全部已读", action: nil, keyEquivalent: "")
                allReadItem.isEnabled = false
                menu.addItem(allReadItem)
            } else {
                // 取前 displayCount 条显示在主列表
                let displayCount = settings.displayCount
                let topItems = Array(sortedUnread.prefix(displayCount))
                let remainingItems = Array(sortedUnread.dropFirst(displayCount))

                // 预加载源名称缓存
                var sourceNameCache: [String: String] = [:]
                for source in sources {
                    sourceNameCache[source.id] = source.title
                }

                // 添加两行展示的文章条目
                for item in topItems {
                    let sourceName = sourceNameCache[item.sourceId] ?? "未知来源"
                    menu.addItem(createTwoLineArticleMenuItem(item, sourceName: sourceName))
                }

                // 折叠"更多" - 按源分组的二级结构
                if !remainingItems.isEmpty {
                    menu.addItem(NSMenuItem.separator())
                    let moreItem = NSMenuItem(title: "… 更多 (\(remainingItems.count))", action: nil, keyEquivalent: "")
                    let moreSubmenu = NSMenu()

                    // 将剩余文章按源分组
                    let groupedBySource = Dictionary(grouping: remainingItems) { $0.sourceId }

                    // 按源名称排序
                    let sortedSources = try storage.fetchAllSourcesSortedByName()

                    for source in sortedSources {
                        guard let items = groupedBySource[source.id], !items.isEmpty else { continue }

                        let sourceItem = NSMenuItem(title: "\(source.title) (\(items.count))", action: nil, keyEquivalent: "")
                        let sourceSubmenu = NSMenu()

                        // 按时间倒序排列该源下的文章
                        let sortedSourceItems = items.sorted { $0.displayDate > $1.displayDate }

                        for item in sortedSourceItems {
                            // 二级菜单使用简单的单行展示：时间 · 标题
                            sourceSubmenu.addItem(createSimpleArticleMenuItem(item))
                        }

                        sourceItem.submenu = sourceSubmenu
                        moreSubmenu.addItem(sourceItem)
                    }

                    moreItem.submenu = moreSubmenu
                    menu.addItem(moreItem)
                }
            }

            // 底部操作
            menu.addItem(NSMenuItem.separator())

            if !sortedUnread.isEmpty {
                let markAllReadItem = NSMenuItem(title: "全部标为已读", action: #selector(MenuBuilderDelegate.markAllAsRead), keyEquivalent: "")
                markAllReadItem.target = delegate
                menu.addItem(markAllReadItem)
            }

            // 刷新全部源
            let refreshItem = NSMenuItem(title: "刷新全部源", action: #selector(MenuBuilderDelegate.refreshAll), keyEquivalent: "r")
            refreshItem.target = delegate
            menu.addItem(refreshItem)

        } catch {
            // 错误状态
            let errorItem = NSMenuItem(title: "⚠️ 加载失败", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)

            let detailItem = NSMenuItem(title: error.localizedDescription, action: nil, keyEquivalent: "")
            detailItem.isEnabled = false
            detailItem.indentationLevel = 1
            menu.addItem(detailItem)
        }

        return menu
    }

    /// 构建右键菜单（应用菜单）
    func buildAppMenu() -> NSMenu {
        let menu = NSMenu()

        do {
            let storage = FeedStorage.shared
            let sources = try storage.fetchAllSourcesSortedByName()

            if !sources.isEmpty {
                // 按名称排序显示所有订阅源
                for source in sources {
                    let sourceItem = NSMenuItem(title: source.title, action: nil, keyEquivalent: "")

                    // 禁用的源置灰
                    if !source.isEnabled {
                        sourceItem.isEnabled = false
                    }

                    // 创建子菜单
                    let submenu = NSMenu()

                    let refreshSourceItem = NSMenuItem(
                        title: "刷新此源",
                        action: #selector(MenuBuilderDelegate.refreshSource(_:)),
                        keyEquivalent: ""
                    )
                    refreshSourceItem.target = delegate
                    refreshSourceItem.representedObject = source.id
                    refreshSourceItem.isEnabled = source.isEnabled
                    submenu.addItem(refreshSourceItem)

                    // 显示最后刷新时间（如果有）
                    if let lastFetched = source.lastFetchedAt {
                        let formatter = RelativeDateTimeFormatter()
                        formatter.unitsStyle = .abbreviated
                        let relativeTime = formatter.localizedString(for: lastFetched, relativeTo: Date())

                        let lastFetchedItem = NSMenuItem(title: "上次刷新: \(relativeTime)", action: nil, keyEquivalent: "")
                        lastFetchedItem.isEnabled = false
                        submenu.addItem(lastFetchedItem)
                    }

                    // 显示错误信息（如果有）
                    if let lastError = source.lastError, !lastError.isEmpty {
                        submenu.addItem(NSMenuItem.separator())
                        let errorItem = NSMenuItem(title: "⚠️ \(lastError)", action: nil, keyEquivalent: "")
                        errorItem.isEnabled = false
                        submenu.addItem(errorItem)
                    }

                    sourceItem.submenu = submenu
                    menu.addItem(sourceItem)
                }

                menu.addItem(NSMenuItem.separator())
            }
        } catch {
            // 静默处理错误
            print("Failed to load sources for app menu: \(error)")
        }

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

    /// 创建两行展示的文章菜单项（用于主列表）
    private func createTwoLineArticleMenuItem(_ item: FeedItem, sourceName: String) -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.isEnabled = true  // 确保菜单项是启用的

        // 使用自定义视图
        let customView = ArticleMenuItemView(item: item, sourceName: sourceName)

        // 设置回调
        customView.onOpenArticle = { [weak self] itemId, link in
            self?.delegate?.openArticleByIdAndLink(itemId, link: link)
        }

        customView.onMarkAsRead = { [weak self] itemId in
            // 先标记已读
            self?.delegate?.markAsReadById(itemId)

            // 然后动态更新菜单
            self?.updateMenuAfterMarkingRead(itemId: itemId, menuItem: menuItem)
        }

        menuItem.view = customView

        return menuItem
    }

    /// 创建简单的单行文章菜单项（用于"更多"子菜单）
    private func createSimpleArticleMenuItem(_ item: FeedItem) -> NSMenuItem {
        // 格式：时间 · 标题
        let prefix = item.isRead ? "" : "● "
        let timeString = Self.timeFormatter.localizedString(for: item.displayDate, relativeTo: Date())
        let title = "\(prefix)\(timeString) · \(item.displayTitle)"

        let menuItem = NSMenuItem(
            title: title,
            action: #selector(MenuBuilderDelegate.openArticle(_:)),
            keyEquivalent: ""
        )

        menuItem.target = delegate
        menuItem.representedObject = item.id

        return menuItem
    }

    // MARK: - Formatters

    private static let timeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    // MARK: - Dynamic Menu Update

    /// 标记已读后动态更新菜单
    /// - Parameters:
    ///   - itemId: 被标记已读的文章 ID
    ///   - menuItem: 对应的菜单项
    func updateMenuAfterMarkingRead(itemId: String, menuItem: NSMenuItem) {
        guard let menu = currentArticleMenu else { return }

        do {
            let storage = FeedStorage.shared
            let settings = AppSettings.shared

            // 获取最新的未读文章列表
            let allUnread = try storage.fetchItems(unreadOnly: true)
            let sortedUnread = allUnread.sorted { $0.displayDate > $1.displayDate }

            // 找到被标记的菜单项的索引
            guard let itemIndex = menu.items.firstIndex(of: menuItem) else { return }

            // 移除已标记的菜单项
            menu.removeItem(at: itemIndex)

            // 检查是否需要补充新文章
            let displayCount = settings.displayCount

            // 计算当前主列表中有多少文章（排除标题、分隔符等）
            var currentArticleCount = 0
            for item in menu.items {
                if item.view is ArticleMenuItemView {
                    currentArticleCount += 1
                }
            }

            // 如果文章数少于 displayCount，且还有未读文章，则补充
            if currentArticleCount < displayCount, currentArticleCount < sortedUnread.count {
                let nextItem = sortedUnread[currentArticleCount]

                // 获取源名称
                let sources = try storage.fetchAllSources()
                let sourceName = sources.first(where: { $0.id == nextItem.sourceId })?.title ?? "未知来源"

                // 创建新菜单项
                let newMenuItem = createTwoLineArticleMenuItem(nextItem, sourceName: sourceName)

                // 插入到正确的位置（在 itemIndex 处）
                menu.insertItem(newMenuItem, at: itemIndex)
            }

            // 如果主列表已空，显示"全部已读"
            if currentArticleCount == 0 && sortedUnread.isEmpty {
                // 找到"最近更新"标题后的分隔符
                if let separatorIndex = menu.items.firstIndex(where: { $0.isSeparatorItem && $0.title.isEmpty }),
                   separatorIndex > 0 {
                    let allReadItem = NSMenuItem(title: "✓ 全部已读", action: nil, keyEquivalent: "")
                    allReadItem.isEnabled = false
                    menu.insertItem(allReadItem, at: separatorIndex + 1)
                }
            }

            // 更新"更多"菜单的计数
            if let moreItemIndex = menu.items.firstIndex(where: { $0.title.hasPrefix("… 更多") }) {
                let remainingCount = sortedUnread.count - currentArticleCount
                if remainingCount > 0 {
                    menu.items[moreItemIndex].title = "… 更多 (\(remainingCount))"
                } else {
                    // 没有更多文章了，移除"更多"菜单
                    if moreItemIndex > 0, menu.items[moreItemIndex - 1].isSeparatorItem {
                        menu.removeItem(at: moreItemIndex - 1)  // 移除分隔符
                    }
                    menu.removeItem(at: moreItemIndex)
                }
            }

        } catch {
            print("Failed to update menu after marking read: \(error)")
        }
    }

    // MARK: - NSMenuDelegate

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // 清除旧的高亮
        if let oldItem = currentHighlightedItem,
           let oldView = oldItem.view as? ArticleMenuItemView {
            oldView.isHighlighted = false
        }

        // 设置新的高亮
        if let newItem = item,
           let newView = newItem.view as? ArticleMenuItemView {
            newView.isHighlighted = true
        }

        currentHighlightedItem = item
    }
}

// MARK: - Delegate Protocol

@objc protocol MenuBuilderDelegate: AnyObject {
    func openArticle(_ sender: NSMenuItem)
    func openArticleByIdAndLink(_ itemId: String, link: String)
    func refreshAll()
    func refreshSource(_ sender: NSMenuItem)
    func markAsReadById(_ itemId: String)
    func markAllAsRead()
    func openManagement()
    func openSettings()
    func openAbout()
    func quit()
}
