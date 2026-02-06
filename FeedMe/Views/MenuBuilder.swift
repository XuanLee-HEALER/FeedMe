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

    /// 搜索框后分隔线的 tag 标识，用于定位文章列表的起始位置
    private let kSearchSeparatorTag = 1001

    /// 当前高亮的菜单项（用于清除旧高亮）
    private weak var currentHighlightedItem: NSMenuItem?

    /// 当前打开的文章列表菜单（用于动态更新）
    private weak var currentArticleMenu: NSMenu?

    /// v1.3 搜索相关
    private weak var searchView: SearchMenuItemView?
    private var allUnreadItems = [FeedItem]()
    private var sourceNameCache = [String: String]()
    private var sourceTagCache = [String: String]()

    /// 构建左键菜单（文章列表）
    func buildArticleListMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self // 设置菜单代理以接收高亮变化
        menu.autoenablesItems = false // 防止没有 action 的菜单项被自动禁用

        // 保存菜单引用，用于动态更新
        currentArticleMenu = menu

        do {
            let storage = FeedStorage.shared

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

            // v1.3: 顶部搜索框
            let searchMenuItem = NSMenuItem()
            let searchView = SearchMenuItemView()
            searchView.onSearchTextChanged = { [weak self] searchText in
                self?.handleSearchTextChanged(searchText)
            }
            searchMenuItem.view = searchView
            menu.addItem(searchMenuItem)
            self.searchView = searchView

            // 搜索框后的分隔线，用 tag 标识作为锚点
            let searchSeparator = NSMenuItem.separator()
            searchSeparator.tag = kSearchSeparatorTag
            menu.addItem(searchSeparator)

            // 获取全部未读文章，按时间倒序排列
            let allUnread = try storage.fetchItems(unreadOnly: true)
            let sortedUnread = allUnread.sorted { $0.displayDate > $1.displayDate }

            // 保存到实例变量，供搜索使用
            allUnreadItems = sortedUnread

            // 预加载源名称和标签缓存
            var sourceNameCache: [String: String] = [:]
            var sourceTagCache: [String: String] = [:]
            for source in sources {
                sourceNameCache[source.id] = source.title
                if let tag = source.tag {
                    sourceTagCache[source.id] = tag
                }
            }
            self.sourceNameCache = sourceNameCache
            self.sourceTagCache = sourceTagCache

            // 填充文章列表和底部操作
            try populateDefaultArticleItems(menu: menu, sortedUnread: sortedUnread)

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

            // 一次性获取所有数据，避免数据库重入
            let groupedSources = try storage.fetchSourcesGroupedByTag()

            // 预先获取所有订阅源的未读数（在单独的事务中）
            var unreadCounts: [String: Int] = [:] // sourceId -> unreadCount
            for (_, sources) in groupedSources {
                for source in sources {
                    let count = try storage.fetchUnreadCount(for: source.id)
                    unreadCounts[source.id] = count
                }
            }

            if !groupedSources.isEmpty {
                // 按 Tag 分组展示订阅源
                for (tag, sources) in groupedSources {
                    if let tag = tag {
                        // Tag 分组：创建二级菜单
                        // 计算 Tag 的未读总数
                        let tagUnreadCount = sources.reduce(0) { sum, source in
                            sum + (unreadCounts[source.id] ?? 0)
                        }

                        let tagTitle = "\(tag)(\(sources.count))"
                        let tagItem = NSMenuItem(title: tagTitle, action: nil, keyEquivalent: "")
                        let tagSubmenu = NSMenu()

                        // 添加该 Tag 下的所有订阅源
                        for source in sources {
                            let sourceUnreadCount = unreadCounts[source.id] ?? 0
                            tagSubmenu.addItem(buildSourceMenuItem(source, unreadCount: sourceUnreadCount))
                        }

                        // 分隔线
                        if !sources.isEmpty {
                            tagSubmenu.addItem(NSMenuItem.separator())
                        }

                        // Tag 级别的"全部标为已读"
                        let markTagReadItem = NSMenuItem(
                            title: "全部标为已读",
                            action: #selector(MenuBuilderDelegate.markTagAsRead(_:)),
                            keyEquivalent: ""
                        )
                        markTagReadItem.target = delegate
                        markTagReadItem.representedObject = tag
                        markTagReadItem.isEnabled = tagUnreadCount > 0
                        tagSubmenu.addItem(markTagReadItem)

                        tagItem.submenu = tagSubmenu
                        menu.addItem(tagItem)
                    } else {
                        // 未分类订阅源：直接平铺展示（与 Tag 分组同级）
                        for source in sources {
                            let sourceUnreadCount = unreadCounts[source.id] ?? 0
                            menu.addItem(buildSourceMenuItem(source, unreadCount: sourceUnreadCount))
                        }
                    }
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
        menuItem.isEnabled = true // 确保菜单项是启用的

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

    /// 构建单个订阅源的菜单项（带子菜单）
    /// - Parameter source: 订阅源
    /// - Returns: NSMenuItem
    private func buildSourceMenuItem(_ source: FeedSource, unreadCount: Int) -> NSMenuItem {
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

        // 分隔线
        submenu.addItem(NSMenuItem.separator())

        // 单个源的"标记为已读"（使用传入的未读数，避免数据库重入）
        let markReadItem = NSMenuItem(
            title: "标记为已读",
            action: #selector(MenuBuilderDelegate.markSourceAsRead(_:)),
            keyEquivalent: ""
        )
        markReadItem.target = delegate
        markReadItem.representedObject = source.id
        markReadItem.isEnabled = unreadCount > 0
        submenu.addItem(markReadItem)

        sourceItem.submenu = submenu
        return sourceItem
    }

    /// v1.3: 处理搜索文本变化
    private func handleSearchTextChanged(_ searchText: String) {
        guard let menu = currentArticleMenu else { return }

        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 找到搜索框后的分隔线作为锚点
        guard let separatorIndex = menu.items.firstIndex(where: { $0.tag == kSearchSeparatorTag }) else { return }

        // 移除分隔线之后的所有内容
        while menu.items.count > separatorIndex + 1 {
            menu.removeItem(at: separatorIndex + 1)
        }

        if trimmedText.isEmpty {
            // 清空搜索：恢复为原始 displayCount 条 + "更多" 结构
            do {
                try populateDefaultArticleItems(menu: menu, sortedUnread: allUnreadItems)
            } catch {
                print("Failed to restore article list: \(error)")
            }
        } else {
            // 搜索过滤
            let filteredItems = filterArticles(searchText: trimmedText)
            populateSearchResults(menu: menu, filteredItems: filteredItems)
        }
    }

    /// 填充默认文章列表（displayCount 条 + "更多" 折叠 + 底部操作）
    private func populateDefaultArticleItems(menu: NSMenu, sortedUnread: [FeedItem]) throws {
        let settings = AppSettings.shared

        if sortedUnread.isEmpty {
            let allReadItem = NSMenuItem(title: "✓ 全部已读", action: nil, keyEquivalent: "")
            allReadItem.isEnabled = false
            menu.addItem(allReadItem)
        } else {
            let displayCount = settings.displayCount
            let topItems = Array(sortedUnread.prefix(displayCount))

            for item in topItems {
                let sourceName = sourceNameCache[item.sourceId] ?? "未知来源"
                menu.addItem(createTwoLineArticleMenuItem(item, sourceName: sourceName))
            }

            // "…" 子菜单 - 全部未读文章按 Tag→源→文章的层级分组浏览
            if sortedUnread.count > displayCount {
                menu.addItem(NSMenuItem.separator())
                let moreItem = NSMenuItem(title: "…", action: nil, keyEquivalent: "")
                let moreSubmenu = NSMenu()
                moreSubmenu.autoenablesItems = false

                // 用全部未读文章按源分组
                let groupedBySource = Dictionary(grouping: sortedUnread) { $0.sourceId }

                // 按 Tag 分组源
                var tagSourceMap: [String: [String]] = [:] // tag -> [sourceId]
                var ungroupedSourceIds: [String] = []

                for (sourceId, _) in groupedBySource {
                    if let tag = sourceTagCache[sourceId] {
                        tagSourceMap[tag, default: []].append(sourceId)
                    } else {
                        ungroupedSourceIds.append(sourceId)
                    }
                }

                // 先添加有 Tag 的组（按 Tag 名排序）
                for tag in tagSourceMap.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
                    let sourceIds = tagSourceMap[tag]!
                    let tagArticleCount = sourceIds.reduce(0) { $0 + (groupedBySource[$1]?.count ?? 0) }
                    let tagItem = NSMenuItem(title: "\(tag)[\(sourceIds.count)](\(tagArticleCount))", action: nil, keyEquivalent: "")
                    let tagSubmenu = NSMenu()
                    tagSubmenu.autoenablesItems = false

                    for sourceId in sourceIds.sorted(by: { (sourceNameCache[$0] ?? "") < (sourceNameCache[$1] ?? "") }) {
                        guard let items = groupedBySource[sourceId], !items.isEmpty else { continue }
                        let sourceName = sourceNameCache[sourceId] ?? "未知来源"
                        let sourceItem = NSMenuItem(title: "\(sourceName) (\(items.count))", action: nil, keyEquivalent: "")
                        let sourceSubmenu = NSMenu()
                        sourceSubmenu.autoenablesItems = false
                        for item in items.sorted(by: { $0.displayDate > $1.displayDate }) {
                            sourceSubmenu.addItem(createSimpleArticleMenuItem(item))
                        }
                        sourceItem.submenu = sourceSubmenu
                        tagSubmenu.addItem(sourceItem)
                    }

                    tagItem.submenu = tagSubmenu
                    moreSubmenu.addItem(tagItem)
                }

                // 未分类源排在最后，直接平铺
                for sourceId in ungroupedSourceIds.sorted(by: { (sourceNameCache[$0] ?? "") < (sourceNameCache[$1] ?? "") }) {
                    guard let items = groupedBySource[sourceId], !items.isEmpty else { continue }
                    let sourceName = sourceNameCache[sourceId] ?? "未知来源"
                    let sourceItem = NSMenuItem(title: "\(sourceName) (\(items.count))", action: nil, keyEquivalent: "")
                    let sourceSubmenu = NSMenu()
                    sourceSubmenu.autoenablesItems = false
                    for item in items.sorted(by: { $0.displayDate > $1.displayDate }) {
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

        let refreshItem = NSMenuItem(title: "刷新全部源", action: #selector(MenuBuilderDelegate.refreshAll), keyEquivalent: "r")
        refreshItem.target = delegate
        menu.addItem(refreshItem)
    }

    /// 填充搜索结果（最多 20 条 + 更多提示 + 底部操作）
    private func populateSearchResults(menu: NSMenu, filteredItems: [FeedItem]) {
        if filteredItems.isEmpty {
            let emptyItem = NSMenuItem(title: "未找到相关文章", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            let maxResults = 20
            let displayItems = Array(filteredItems.prefix(maxResults))

            for item in displayItems {
                let sourceName = sourceNameCache[item.sourceId] ?? "未知来源"
                menu.addItem(createTwoLineArticleMenuItem(item, sourceName: sourceName))
            }

            if filteredItems.count > maxResults {
                menu.addItem(NSMenuItem.separator())
                let moreItem = NSMenuItem(title: "还有 \(filteredItems.count - maxResults) 条结果未显示", action: nil, keyEquivalent: "")
                moreItem.isEnabled = false
                menu.addItem(moreItem)
            }
        }

        // 底部操作
        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "刷新全部源", action: #selector(MenuBuilderDelegate.refreshAll), keyEquivalent: "r")
        refreshItem.target = delegate
        menu.addItem(refreshItem)
    }

    /// v1.3: 过滤文章（搜索标题和摘要）
    private func filterArticles(searchText: String) -> [FeedItem] {
        let lowercasedText = searchText.localizedLowercase

        return allUnreadItems.filter { item in
            item.title.localizedLowercase.contains(lowercasedText) ||
                (item.summary ?? "").localizedLowercase.contains(lowercasedText)
        }
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
    func updateMenuAfterMarkingRead(itemId _: String, menuItem: NSMenuItem) {
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
            if currentArticleCount == 0, sortedUnread.isEmpty {
                // 找到搜索框后的分隔线作为锚点
                if let separatorIndex = menu.items.firstIndex(where: { $0.tag == kSearchSeparatorTag }) {
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
                        menu.removeItem(at: moreItemIndex - 1) // 移除分隔符
                    }
                    menu.removeItem(at: moreItemIndex)
                }
            }

        } catch {
            print("Failed to update menu after marking read: \(error)")
        }
    }

    // MARK: - NSMenuDelegate

    func menu(_: NSMenu, willHighlight item: NSMenuItem?) {
        // 清除旧的高亮
        if let oldItem = currentHighlightedItem,
           let oldView = oldItem.view as? ArticleMenuItemView
        {
            oldView.isHighlighted = false
        }

        // 设置新的高亮
        if let newItem = item,
           let newView = newItem.view as? ArticleMenuItemView
        {
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
    func markSourceAsRead(_ sender: NSMenuItem) // v1.3: 标记单个源为已读
    func markTagAsRead(_ sender: NSMenuItem) // v1.3: 标记 Tag 下所有源为已读
    func openManagement()
    func openSettings()
    func openAbout()
    func quit()
}
