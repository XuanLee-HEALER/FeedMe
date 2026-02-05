//
//  SearchMenuItemView.swift
//  FeedMe
//
//  Created by Claude on 2026/2/5.
//  v1.3: 菜单内搜索框视图
//

import Cocoa

/// 菜单内搜索框视图
final class SearchMenuItemView: NSView, NSSearchFieldDelegate {
    /// 搜索文本变化回调
    var onSearchTextChanged: ((String) -> Void)?

    /// 搜索框
    private let searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = "搜索文章…"
        field.sendsSearchStringImmediately = true // 立即发送搜索
        field.sendsWholeSearchString = false // 不等待回车
        return field
    }()

    /// 初始化
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 32))

        // 配置背景（与菜单背景一致）
        wantsLayer = true

        // 添加搜索框
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        // 布局约束
        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // 设置代理和 action
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 搜索框文本变化
    @objc private func searchFieldChanged() {
        onSearchTextChanged?(searchField.stringValue)
    }

    /// 代理方法：文本变化时立即触发
    func controlTextDidChange(_: Notification) {
        onSearchTextChanged?(searchField.stringValue)
    }

    /// 聚焦搜索框
    func focusSearchField() {
        window?.makeFirstResponder(searchField)
    }

    /// 清空搜索框
    func clearSearch() {
        searchField.stringValue = ""
        onSearchTextChanged?("")
    }

    /// 获取当前搜索文本
    var searchText: String {
        searchField.stringValue
    }
}
